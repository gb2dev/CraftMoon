extends CompositorEffect
class_name StencilBasedOutlineCompositorEffect

## Screen-space outline CompositorEffect.
##
## Any mesh whose material writes [member stencil_value] into the stencil buffer
## (BaseMaterial3D: Stencil Mode = Custom, Flags = Write, Compare = Always,
## Reference = stencil_value) gets a solid outline of [member outline_color] and
## [member thickness] pixels, generated with a jump-flood distance field.
##
## Based on the stencil + jump-flood outline by David M. Lary
## (github.com/dmlary/godot-stencil-based-outline-compositor-effect),
## MIT license. Uses the jump-flood algorithm described by bgolus'
## "Quest for Very Wide Outlines"
## (https://bgolus.medium.com/the-quest-for-very-wide-outlines-ba82ed442cd9).

## Color of the outline.
@export var outline_color := Color.GOLD

## Thickness of the outline in pixels.
@export_range(0, 4096) var thickness: int = 4:
	set(value):
		thickness = clampi(value, 0, 4096)

## Stencil value that denotes pixels to be outlined.
@export var stencil_value := 1

## Stencil mask used when checking the stencil value.
@export var stencil_mask := 1

## Internal 3D render resolution; updated on the render thread each frame.
var render_resolution := Vector2i(1, 1)

## GLSL shader paths, resolved relative to this script.
var _shader_dir: String = get_script().get_path().get_base_dir() + "/shaders/"
var jf_shader_file: String = _shader_dir + "jump_flood.glsl"
var sc_shader_file: String = _shader_dir + "stencil_copy.glsl"
var do_shader_file: String = _shader_dir + "draw_outline.glsl"
var resolve_shader_file: String = _shader_dir + "resolve_msaa.glsl"

var rd: RenderingDevice

## Stencil-copy render pipeline (seeds the jump-flood buffer from the stencil).
var sc_shader: RID
var sc_framebuffer: RID
var sc_pipeline: RID

## Draw-outline render pipeline (blends the final outline onto the frame).
var do_shader: RID
var do_pipeline: RID
var do_framebuffer: RID

## Full-screen-triangle vertex array, shared by the two render pipelines.
var scdo_vertex_format: int
var scdo_vertex_buffer: RID
var scdo_vertex_array: RID

## Jump-flood compute pipeline and its two ping-pong uniform sets.
var jf_shader: RID
var jf_pipeline: RID
var jf_uniform_sets := [RID(), RID()]

## Cached scene texture RIDs; a change means the pipelines must be rebuilt.
var color_texture: RID
var depth_texture: RID
var resolution := Vector2i(1, 1)

## Ping-pong textures used by the stencil-copy and jump-flood pipelines.
var _textures := [RID(), RID()]

## MSAA resolve resources (only used when the viewport has MSAA enabled).
var _stencil_color_texture: RID
var resolve_shader: RID
var resolve_pipeline: RID
var _sampler: RID
var _msaa_samples: RenderingDevice.TextureSamples = RenderingDevice.TEXTURE_SAMPLES_1
var _cached_msaa_samples: RenderingDevice.TextureSamples = RenderingDevice.TEXTURE_SAMPLES_1

## Mutex guarding [member rebuild_pipelines].
var mutex := Mutex.new()

## Set when the pipelines are dirty and need to be rebuilt on the render thread.
var rebuild_pipelines := true:
	set(value):
		mutex.lock()
		rebuild_pipelines = value
		mutex.unlock()

## Number of jump-flood passes needed to cover the outline thickness.
func _get_render_passes() -> int:
	var max_t := ceilf(thickness * 1.5)
	if max_t <= 1:
		return 1
	# We need max_stride = 2^(passes-1) >= max_t.
	var passes := 1
	var stride := 1
	while stride < max_t:
		stride <<= 1
		passes += 1
	return passes

func _init() -> void:
	# POST_SKY so the outline is drawn after the sky (otherwise the sky paints
	# over outline pixels that fall on the background) but before transparent
	# geometry/gizmos.
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_SKY

	# Grab the rendering device. It is unavailable in headless/dummy contexts,
	# in which case the effect simply does nothing.
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Build the full-screen triangle used by the stencil-copy and draw-outline
	# render pipelines.
	var vertex_attr := RDVertexAttribute.new()
	vertex_attr.location = 0
	vertex_attr.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	vertex_attr.stride = 4 * 3
	scdo_vertex_format = rd.vertex_format_create([vertex_attr])

	# Counter-clockwise winding so the triangle faces the camera; required for
	# the front-face stencil ops configured in the pipelines.
	var vertex_data := PackedVector3Array([
		Vector3(-1, -1, 0),
		Vector3(3, -1, 0),
		Vector3(-1, 3, 0),
	])
	var vertex_bytes := vertex_data.to_byte_array()
	scdo_vertex_buffer = rd.vertex_buffer_create(vertex_bytes.size(), vertex_bytes)
	scdo_vertex_array = rd.vertex_array_create(3, scdo_vertex_format, [scdo_vertex_buffer])

	# Shared sampler for the jump-flood textures.
	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_sampler = rd.sampler_create(sampler_state)

	# Mark ourselves dirty so everything is created once we know the resolution.
	rebuild_pipelines = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not rd:
			return

		# Freeing the shaders cascades to their pipelines and uniform sets.
		if jf_shader.is_valid():
			rd.free_rid(jf_shader)
		if sc_shader.is_valid():
			rd.free_rid(sc_shader)
		if do_shader.is_valid():
			rd.free_rid(do_shader)
		if resolve_shader.is_valid():
			rd.free_rid(resolve_shader)

		if sc_framebuffer.is_valid():
			rd.free_rid(sc_framebuffer)
		if do_framebuffer.is_valid():
			rd.free_rid(do_framebuffer)

		for rid in _textures:
			if rid.is_valid():
				rd.free_rid(rid)
		if _stencil_color_texture.is_valid():
			rd.free_rid(_stencil_color_texture)

		if scdo_vertex_array.is_valid():
			rd.free_rid(scdo_vertex_array)
		if scdo_vertex_buffer.is_valid():
			rd.free_rid(scdo_vertex_buffer)

		if _sampler.is_valid():
			rd.free_rid(_sampler)

## Load and compile a GLSL shader from a resource path. Returns the SPIR-V, or
## null on failure.
func _load_glsl_from_file(path: String) -> RDShaderSPIRV:
	var shader_file := ResourceLoader.load(path) as RDShaderFile
	if not shader_file:
		push_error("failed to load shader: ", path)
		return null
	return shader_file.get_spirv()

## Stencil-copy pipeline: seeds the jump-flood buffer from the stencil buffer.
func _build_sc_pipeline() -> void:
	if sc_shader.is_valid():
		rd.free_rid(sc_shader)
		sc_shader = RID()

	var shader_spirv := _load_glsl_from_file(sc_shader_file)
	if not shader_spirv:
		push_error("failed to load stencil copy shader")
		return
	sc_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(sc_shader.is_valid())

	var color_tex: RID = _textures[0]
	if _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1:
		color_tex = _stencil_color_texture

	assert(color_tex.is_valid())
	assert(depth_texture.is_valid())

	var attachments := []
	var attachment_format := RDAttachmentFormat.new()

	var texture_format := rd.texture_get_format(color_tex)
	attachment_format.format = texture_format.format
	attachment_format.usage_flags = texture_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var depth_format := rd.texture_get_format(depth_texture)
	attachment_format = RDAttachmentFormat.new()
	attachment_format.format = depth_format.format
	attachment_format.usage_flags = depth_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var format: int
	if not sc_framebuffer.is_valid():
		format = rd.framebuffer_format_create(attachments)
		sc_framebuffer = rd.framebuffer_create([color_tex, depth_texture], format)
		assert(sc_framebuffer.is_valid())
	else:
		format = rd.framebuffer_get_format(sc_framebuffer)

	var blend := RDPipelineColorBlendState.new()
	blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())

	# Only write pixels where (stencil & mask) == reference, i.e. outlined objects.
	var stencil_state := RDPipelineDepthStencilState.new()
	stencil_state.enable_stencil = true
	stencil_state.front_op_compare = RenderingDevice.COMPARE_OP_EQUAL
	stencil_state.back_op_compare = RenderingDevice.COMPARE_OP_EQUAL
	stencil_state.front_op_compare_mask = stencil_mask
	stencil_state.back_op_compare_mask = stencil_mask
	stencil_state.front_op_reference = stencil_value
	stencil_state.back_op_reference = stencil_value
	stencil_state.front_op_fail = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.front_op_pass = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.back_op_fail = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.back_op_pass = RenderingDevice.STENCIL_OP_KEEP

	var multisample_state := RDPipelineMultisampleState.new()
	multisample_state.sample_count = _msaa_samples
	multisample_state.enable_sample_shading = true
	multisample_state.min_sample_shading = 1.0

	sc_pipeline = rd.render_pipeline_create(
		sc_shader,
		format,
		scdo_vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		multisample_state,
		stencil_state,
		blend,
	)
	assert(sc_pipeline.is_valid())

func _build_resolve_pipeline() -> void:
	if resolve_shader.is_valid():
		rd.free_rid(resolve_shader)
		resolve_shader = RID()

	var shader_spirv := _load_glsl_from_file(resolve_shader_file)
	if not shader_spirv:
		push_error("failed to load MSAA resolve shader")
		return

	resolve_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(resolve_shader.is_valid())
	resolve_pipeline = rd.compute_pipeline_create(resolve_shader)
	assert(resolve_pipeline.is_valid())

## Draw-outline pipeline: blends the generated outline onto the frame.
func _build_do_pipeline() -> void:
	if do_shader.is_valid():
		rd.free_rid(do_shader)
		do_shader = RID()

	var shader_spirv := _load_glsl_from_file(do_shader_file)
	if not shader_spirv:
		push_error("failed to load draw outline shader")
		return
	do_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(do_shader.is_valid())

	var attachments := []
	var attachment_format := RDAttachmentFormat.new()

	var texture_format := rd.texture_get_format(color_texture)
	attachment_format.format = texture_format.format
	attachment_format.usage_flags = texture_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var depth_format := rd.texture_get_format(depth_texture)
	attachment_format = RDAttachmentFormat.new()
	attachment_format.format = depth_format.format
	attachment_format.usage_flags = depth_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var format: int
	if not do_framebuffer.is_valid():
		format = rd.framebuffer_format_create(attachments)
		do_framebuffer = rd.framebuffer_create([color_texture, depth_texture], format)
		assert(do_framebuffer.is_valid())
	else:
		format = rd.framebuffer_get_format(do_framebuffer)

	var blend := RDPipelineColorBlendState.new()
	var blend_attachment := RDPipelineColorBlendStateAttachment.new()
	blend_attachment.enable_blend = true
	blend_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
	blend_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	blend_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
	blend_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	blend.attachments.push_back(blend_attachment)

	# Only draw where (stencil & mask) != reference, i.e. outside outlined objects.
	var stencil_state := RDPipelineDepthStencilState.new()
	stencil_state.enable_stencil = true
	stencil_state.front_op_compare = RenderingDevice.COMPARE_OP_NOT_EQUAL
	stencil_state.back_op_compare = RenderingDevice.COMPARE_OP_NOT_EQUAL
	stencil_state.front_op_compare_mask = stencil_mask
	stencil_state.back_op_compare_mask = stencil_mask
	stencil_state.front_op_reference = stencil_value
	stencil_state.back_op_reference = stencil_value
	stencil_state.front_op_fail = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.front_op_pass = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.back_op_fail = RenderingDevice.STENCIL_OP_KEEP
	stencil_state.back_op_pass = RenderingDevice.STENCIL_OP_KEEP

	var multisample_state := RDPipelineMultisampleState.new()
	multisample_state.sample_count = _msaa_samples
	multisample_state.enable_sample_shading = true
	multisample_state.min_sample_shading = 1.0

	do_pipeline = rd.render_pipeline_create(
		do_shader,
		format,
		scdo_vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		multisample_state,
		stencil_state,
		blend,
	)
	assert(do_pipeline.is_valid())

func _build_jf_pipeline() -> void:
	if jf_shader.is_valid():
		rd.free_rid(jf_shader)
		jf_shader = RID()

	var shader_spirv := _load_glsl_from_file(jf_shader_file)
	if not shader_spirv:
		push_error("failed to load jump flood shader")
		return
	jf_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(jf_shader.is_valid())

	jf_pipeline = rd.compute_pipeline_create(jf_shader)
	assert(jf_pipeline.is_valid())

	# Build the two ping-pong uniform sets used across the passes.
	assert(_textures[0].is_valid())
	assert(_textures[1].is_valid())
	for group in [[0, _textures[0], _textures[1]], [1, _textures[1], _textures[0]]]:
		var pass_number: int = group[0]
		var src_texture: RID = group[1]
		var dest_texture: RID = group[2]

		var src_uniform := RDUniform.new()
		src_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		src_uniform.binding = 0
		src_uniform.add_id(_sampler)
		src_uniform.add_id(src_texture)

		var dest_uniform := RDUniform.new()
		dest_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		dest_uniform.binding = 1
		dest_uniform.add_id(dest_texture)

		jf_uniform_sets[pass_number] = rd.uniform_set_create(
			[src_uniform, dest_uniform], jf_shader, 0)

func _free_framebuffers() -> void:
	if sc_framebuffer.is_valid():
		if rd.framebuffer_is_valid(sc_framebuffer):
			rd.free_rid(sc_framebuffer)
		sc_framebuffer = RID()

	if do_framebuffer.is_valid():
		if rd.framebuffer_is_valid(do_framebuffer):
			rd.free_rid(do_framebuffer)
		do_framebuffer = RID()

func _build_textures() -> void:
	var count := _textures.size()

	var texture_format := RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = resolution.x
	texture_format.height = resolution.y
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1

	var texture_view := RDTextureView.new()

	# Framebuffers reference these textures; free them before recreating.
	_free_framebuffers()

	for i in range(count):
		var rid: RID = rd.texture_create(texture_format, texture_view)
		assert(rid.is_valid())
		var old_rid: RID = _textures[i]
		_textures[i] = rid
		if old_rid.is_valid():
			rd.free_rid(old_rid)

	if _stencil_color_texture.is_valid():
		rd.free_rid(_stencil_color_texture)
		_stencil_color_texture = RID()

	if _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1:
		var msaa_format := RDTextureFormat.new()
		msaa_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		msaa_format.width = resolution.x
		msaa_format.height = resolution.y
		msaa_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
		msaa_format.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		)
		msaa_format.samples = _msaa_samples
		_stencil_color_texture = rd.texture_create(msaa_format, texture_view)
		assert(_stencil_color_texture.is_valid())

# Called by the rendering thread every frame.
func _render_callback(_p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not rd:
		return

	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return

	# The internal 3D render resolution.
	var size := render_scene_buffers.get_internal_size()
	if size.x == 0 and size.y == 0:
		return

	var rebuild := false

	if rebuild_pipelines:
		mutex.lock()
		rebuild_pipelines = false
		mutex.unlock()
		rebuild = true

	if resolution != size:
		resolution = size
		rebuild = true
	render_resolution = size

	# Match the viewport MSAA so our framebuffers are compatible.
	var msaa_3d := render_scene_buffers.get_msaa_3d()
	var new_msaa_samples := RenderingDevice.TEXTURE_SAMPLES_1
	match msaa_3d:
		RenderingServer.VIEWPORT_MSAA_2X:
			new_msaa_samples = RenderingDevice.TEXTURE_SAMPLES_2
		RenderingServer.VIEWPORT_MSAA_4X:
			new_msaa_samples = RenderingDevice.TEXTURE_SAMPLES_4
		RenderingServer.VIEWPORT_MSAA_8X:
			new_msaa_samples = RenderingDevice.TEXTURE_SAMPLES_8

	if new_msaa_samples != _cached_msaa_samples:
		_cached_msaa_samples = new_msaa_samples
		_msaa_samples = new_msaa_samples
		_free_framebuffers()
		rebuild = true

	var color_tex := render_scene_buffers.get_color_layer(0, _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1)
	if color_tex != color_texture:
		color_texture = color_tex
		_free_framebuffers()
		rebuild = true

	var depth_tex := render_scene_buffers.get_depth_layer(0, _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1)
	if depth_tex != depth_texture:
		depth_texture = depth_tex
		_free_framebuffers()
		rebuild = true

	if rebuild:
		_build_textures()
		_build_sc_pipeline()
		_build_resolve_pipeline()
		_build_jf_pipeline()
		_build_do_pipeline()

	# 1. Seed the jump-flood buffer from the stencil buffer. The color attachment
	#    is cleared to (-1, -1, ...) so untouched pixels read as "empty".
	var draw_list := rd.draw_list_begin(
		sc_framebuffer,
		RenderingDevice.DRAW_CLEAR_COLOR_0,
		[Color(-1, -1, 2 ** 15, -1)],
		1.0,
		0,
		Rect2(),
		RenderingDevice.OPAQUE_PASS)
	rd.draw_list_bind_render_pipeline(draw_list, sc_pipeline)
	rd.draw_list_bind_vertex_array(draw_list, scdo_vertex_array)
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()

	@warning_ignore("integer_division")
	var x_groups: int = (resolution.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups: int = (resolution.y - 1) / 8 + 1

	var compute_list := rd.compute_list_begin()

	# 2. Resolve MSAA samples into a single-sample seed texture when needed.
	if _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1 and _stencil_color_texture.is_valid() and _textures[0].is_valid():
		var resolve_src := RDUniform.new()
		resolve_src.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		resolve_src.binding = 0
		resolve_src.add_id(_sampler)
		resolve_src.add_id(_stencil_color_texture)

		var resolve_dst := RDUniform.new()
		resolve_dst.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		resolve_dst.binding = 1
		resolve_dst.add_id(_textures[0])

		var resolve_set := UniformSetCacheRD.get_cache(resolve_shader, 0, [resolve_src, resolve_dst])
		assert(resolve_set.is_valid())

		rd.compute_list_bind_compute_pipeline(compute_list, resolve_pipeline)
		rd.compute_list_bind_uniform_set(compute_list, resolve_set, 0)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

	# 3. Run the jump-flood: descending strides, then a final stride-1 pass to fix
	#    edge errors (JFA+1).
	var push_constant := PackedByteArray()
	push_constant.resize(16) # Must be a multiple of 16 bytes.

	var render_passes := _get_render_passes()
	rd.compute_list_bind_compute_pipeline(compute_list, jf_pipeline)

	for i in range(render_passes):
		var stride := (1 << (render_passes - i - 1))
		push_constant.encode_u32(0, stride)
		rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
		rd.compute_list_bind_uniform_set(compute_list, jf_uniform_sets[i & 0x1], 0)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_add_barrier(compute_list)

	push_constant.encode_u32(0, 1)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	rd.compute_list_bind_uniform_set(compute_list, jf_uniform_sets[render_passes & 0x1], 0)
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	rd.compute_list_add_barrier(compute_list)
	var final_pass := render_passes + 1

	rd.compute_list_end()

	# 4. Draw the outline onto the frame. The uniform set is rebuilt each frame
	#    because the color layer can vanish during a resize.
	var src_uniform := RDUniform.new()
	src_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	src_uniform.binding = 0
	src_uniform.add_id(_sampler)
	src_uniform.add_id(_textures[final_pass & 0x1])

	var uniform_set := UniformSetCacheRD.get_cache(do_shader, 0, [src_uniform])
	assert(uniform_set.is_valid())

	var do_push_constant := PackedByteArray()
	do_push_constant.resize(32)
	do_push_constant.encode_float(0, outline_color.r)
	do_push_constant.encode_float(4, outline_color.g)
	do_push_constant.encode_float(8, outline_color.b)
	do_push_constant.encode_float(12, outline_color.a)
	do_push_constant.encode_float(16, float(resolution.x))
	do_push_constant.encode_float(20, float(resolution.y))
	do_push_constant.encode_u32(24, thickness ** 2)

	var do_draw_list := rd.draw_list_begin(do_framebuffer, 0, [], 1.0, 0, Rect2(), 0)
	rd.draw_list_bind_render_pipeline(do_draw_list, do_pipeline)
	rd.draw_list_bind_vertex_array(do_draw_list, scdo_vertex_array)
	rd.draw_list_bind_uniform_set(do_draw_list, uniform_set, 0)
	rd.draw_list_set_push_constant(do_draw_list, do_push_constant, do_push_constant.size())
	rd.draw_list_draw(do_draw_list, false, 1)
	rd.draw_list_end()
