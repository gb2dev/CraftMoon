extends CompositorEffect
class_name ScopeFocusCompositorEffect

@export_range(0.0, 1.0) var saturation := 0.0
@export_range(0.0, 1.0) var vignette_inner := 0.25
@export_range(0.0, 1.0) var darken := 0.85
@export var stencil_value := 0x80
@export var stencil_mask := 0x80

var _shader_dir: String = get_script().get_path().get_base_dir() + "/shaders/"
var sf_shader_file: String = _shader_dir + "scope_focus.glsl"
var copy_shader_file: String = _shader_dir + "blit.glsl"

var rd: RenderingDevice

var sf_shader: RID
var sf_pipeline: RID
var sf_framebuffer: RID

var _copy_shader: RID
var _copy_pipeline: RID
var _copy_framebuffer: RID
var _copy_format: int

var vertex_format: int
var vertex_buffer: RID
var vertex_array: RID

var _sampler: RID

var _color_copy: RID

var color_texture: RID
var depth_texture: RID
var resolution := Vector2i(1, 1)

var _msaa_samples: RenderingDevice.TextureSamples = RenderingDevice.TEXTURE_SAMPLES_1
var _cached_msaa_samples: RenderingDevice.TextureSamples = RenderingDevice.TEXTURE_SAMPLES_1

var mutex := Mutex.new()
var rebuild_pipelines := true:
	set(value):
		mutex.lock()
		rebuild_pipelines = value
		mutex.unlock()

func _init() -> void:
	# Must run before the outline effect (same stage, earlier in the array) or it
	# would desaturate the outlines.
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_SKY

	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	var vertex_attr := RDVertexAttribute.new()
	vertex_attr.location = 0
	vertex_attr.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	vertex_attr.stride = 4 * 3
	vertex_format = rd.vertex_format_create([vertex_attr])

	var vertex_data := PackedVector3Array([
		Vector3(-1, -1, 0),
		Vector3(3, -1, 0),
		Vector3(-1, 3, 0),
	])
	var vertex_bytes := vertex_data.to_byte_array()
	vertex_buffer = rd.vertex_buffer_create(vertex_bytes.size(), vertex_bytes)
	vertex_array = rd.vertex_array_create(3, vertex_format, [vertex_buffer])

	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = rd.sampler_create(sampler_state)

	rebuild_pipelines = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not rd:
			return
		if sf_shader.is_valid():
			rd.free_rid(sf_shader)
		if sf_framebuffer.is_valid():
			rd.free_rid(sf_framebuffer)
		if _copy_shader.is_valid():
			rd.free_rid(_copy_shader)
		if _copy_framebuffer.is_valid():
			rd.free_rid(_copy_framebuffer)
		if _color_copy.is_valid():
			rd.free_rid(_color_copy)
		if vertex_array.is_valid():
			rd.free_rid(vertex_array)
		if vertex_buffer.is_valid():
			rd.free_rid(vertex_buffer)
		if _sampler.is_valid():
			rd.free_rid(_sampler)

func _load_glsl_from_file(path: String) -> RDShaderSPIRV:
	var shader_file := ResourceLoader.load(path) as RDShaderFile
	if not shader_file:
		push_error("failed to load shader: ", path)
		return null
	return shader_file.get_spirv()

func _free_framebuffer() -> void:
	if sf_framebuffer.is_valid():
		if rd.framebuffer_is_valid(sf_framebuffer):
			rd.free_rid(sf_framebuffer)
		sf_framebuffer = RID()

func _free_copy_framebuffer() -> void:
	if _copy_framebuffer.is_valid():
		if rd.framebuffer_is_valid(_copy_framebuffer):
			rd.free_rid(_copy_framebuffer)
		_copy_framebuffer = RID()

func _build_color_copy() -> void:
	_free_framebuffer()
	_free_copy_framebuffer()

	var texture_format := RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = resolution.x
	texture_format.height = resolution.y
	var src_format := rd.texture_get_format(color_texture)
	texture_format.format = src_format.format
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
		RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	)
	texture_format.samples = _msaa_samples

	if _color_copy.is_valid():
		rd.free_rid(_color_copy)
	_color_copy = rd.texture_create(texture_format, RDTextureView.new())
	assert(_color_copy.is_valid())

func _build_copy_resources() -> void:
	if _copy_shader.is_valid():
		rd.free_rid(_copy_shader)
		_copy_shader = RID()

	var shader_spirv := _load_glsl_from_file(copy_shader_file)
	if not shader_spirv:
		push_error("failed to load blit shader")
		return
	_copy_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(_copy_shader.is_valid())

	if not _color_copy.is_valid():
		return

	var attachment_format := RDAttachmentFormat.new()
	var tex_format := rd.texture_get_format(_color_copy)
	attachment_format.format = tex_format.format
	attachment_format.usage_flags = tex_format.usage_bits
	attachment_format.samples = _msaa_samples
	_copy_format = rd.framebuffer_format_create([attachment_format])
	_copy_framebuffer = rd.framebuffer_create([_color_copy], _copy_format)
	assert(_copy_framebuffer.is_valid())

	var blend := RDPipelineColorBlendState.new()
	blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())

	var multisample_state := RDPipelineMultisampleState.new()
	multisample_state.sample_count = _msaa_samples
	multisample_state.enable_sample_shading = _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1
	multisample_state.min_sample_shading = 1.0

	_copy_pipeline = rd.render_pipeline_create(
		_copy_shader,
		_copy_format,
		vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		multisample_state,
		RDPipelineDepthStencilState.new(),
		blend,
	)
	assert(_copy_pipeline.is_valid())

func _build_pipeline() -> void:
	if sf_shader.is_valid():
		rd.free_rid(sf_shader)
		sf_shader = RID()

	var shader_spirv := _load_glsl_from_file(sf_shader_file)
	if not shader_spirv:
		push_error("failed to load scope focus shader")
		return
	sf_shader = rd.shader_create_from_spirv(shader_spirv)
	assert(sf_shader.is_valid())

	var attachments := []
	var color_format := rd.texture_get_format(color_texture)
	var attachment_format := RDAttachmentFormat.new()
	attachment_format.format = color_format.format
	attachment_format.usage_flags = color_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var depth_format := rd.texture_get_format(depth_texture)
	attachment_format = RDAttachmentFormat.new()
	attachment_format.format = depth_format.format
	attachment_format.usage_flags = depth_format.usage_bits
	attachment_format.samples = _msaa_samples
	attachments.push_back(attachment_format)

	var format: int
	if not sf_framebuffer.is_valid():
		format = rd.framebuffer_format_create(attachments)
		sf_framebuffer = rd.framebuffer_create([color_texture, depth_texture], format)
		assert(sf_framebuffer.is_valid())
	else:
		format = rd.framebuffer_get_format(sf_framebuffer)

	var blend := RDPipelineColorBlendState.new()
	blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())

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
	multisample_state.enable_sample_shading = _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1
	multisample_state.min_sample_shading = 1.0

	sf_pipeline = rd.render_pipeline_create(
		sf_shader,
		format,
		vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(),
		multisample_state,
		stencil_state,
		blend,
	)
	assert(sf_pipeline.is_valid())

func _render_callback(_p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not rd:
		return

	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if not render_scene_buffers:
		return

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
		_free_framebuffer()
		rebuild = true

	var multisampled := _msaa_samples != RenderingDevice.TEXTURE_SAMPLES_1

	var color_tex := render_scene_buffers.get_color_layer(0, multisampled)
	if color_tex != color_texture:
		color_texture = color_tex
		_free_framebuffer()
		rebuild = true

	var depth_tex := render_scene_buffers.get_depth_layer(0, multisampled)
	if depth_tex != depth_texture:
		depth_texture = depth_tex
		_free_framebuffer()
		rebuild = true

	if rebuild:
		_build_color_copy()
		_build_copy_resources()
		_build_pipeline()

	if not _color_copy.is_valid() or not sf_pipeline.is_valid():
		return

	var copy_src_uniform := RDUniform.new()
	copy_src_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	copy_src_uniform.binding = 0
	copy_src_uniform.add_id(_sampler)
	copy_src_uniform.add_id(color_texture)
	var copy_uniform_set := UniformSetCacheRD.get_cache(_copy_shader, 0, [copy_src_uniform])
	assert(copy_uniform_set.is_valid())

	var copy_draw_list := rd.draw_list_begin(_copy_framebuffer, 0, [], 1.0, 0, Rect2(), 0)
	rd.draw_list_bind_render_pipeline(copy_draw_list, _copy_pipeline)
	rd.draw_list_bind_vertex_array(copy_draw_list, vertex_array)
	rd.draw_list_bind_uniform_set(copy_draw_list, copy_uniform_set, 0)
	rd.draw_list_draw(copy_draw_list, false, 1)
	rd.draw_list_end()

	var src_uniform := RDUniform.new()
	src_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	src_uniform.binding = 0
	src_uniform.add_id(_sampler)
	src_uniform.add_id(_color_copy)
	var uniform_set := UniformSetCacheRD.get_cache(sf_shader, 0, [src_uniform])
	assert(uniform_set.is_valid())

	var push_constant := PackedByteArray()
	push_constant.resize(32)
	push_constant.encode_float(0, float(resolution.x))
	push_constant.encode_float(4, float(resolution.y))
	push_constant.encode_float(8, saturation)
	push_constant.encode_float(12, vignette_inner)
	push_constant.encode_float(16, darken)

	var draw_list := rd.draw_list_begin(sf_framebuffer, 0, [], 1.0, 0, Rect2(), 0)
	rd.draw_list_bind_render_pipeline(draw_list, sf_pipeline)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	rd.draw_list_set_push_constant(draw_list, push_constant, push_constant.size())
	rd.draw_list_draw(draw_list, false, 1)
	rd.draw_list_end()
