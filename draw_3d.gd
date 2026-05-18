extends Node

var _box_mesh := BoxMesh.new()
var _sphere_mesh := SphereMesh.new()
var _cone_mesh := CylinderMesh.new()
var _material_cache: Dictionary = {}
var _to_free: Array[Node] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box_mesh.size = Vector3.ONE
	_sphere_mesh.radius = 0.5
	_sphere_mesh.height = 1.0
	_cone_mesh.top_radius = 0.0
	_cone_mesh.bottom_radius = 0.5
	_cone_mesh.height = 1.0

func _process(_delta: float) -> void:
	if get_tree().paused:
		return
		
	for node in _to_free:
		if is_instance_valid(node):
			node.queue_free()
	_to_free.clear()

func _get_mat(color: Color, priority: int, no_depth: bool, shaded: bool, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY) -> ORMMaterial3D:
	var key := [color, priority, no_depth, shaded, depth_draw]
	if _material_cache.has(key):
		return _material_cache[key] as ORMMaterial3D
	
	var mat: ORMMaterial3D = ORMMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not shaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = color
	mat.render_priority = priority
	mat.no_depth_test = no_depth
	mat.depth_draw_mode = depth_draw
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_cache[key] = mat
	return mat

func line(pos1: Vector3, pos2: Vector3, color := Color.WHITE_SMOKE, persist_ms := 0, thickness := 0.0, render_priority := 0, no_depth_test := false, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, sorting_offset := 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.sorting_offset = sorting_offset
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := _get_mat(color, render_priority, no_depth_test, false, depth_draw)

	if thickness <= 0.0:
		var immediate_mesh := ImmediateMesh.new()
		mesh_instance.mesh = immediate_mesh
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
		immediate_mesh.surface_add_vertex(pos1)
		immediate_mesh.surface_add_vertex(pos2)
		immediate_mesh.surface_end()
	else:
		var dir := pos2 - pos1
		var dist := dir.length()
		if dist < 0.001: return _register(mesh_instance, persist_ms)
		mesh_instance.mesh = _box_mesh
		mesh_instance.material_override = material
		mesh_instance.position = (pos1 + pos2) * 0.5
		mesh_instance.quaternion = Quaternion(Vector3.UP, dir / dist)
		mesh_instance.scale = Vector3(thickness, dist, thickness)

	return _register(mesh_instance, persist_ms)

func point(pos: Vector3, radius := 0.05, color := Color.WHITE_SMOKE, persist_ms := 0, sorting_offset := 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.sorting_offset = sorting_offset
	mesh_instance.mesh = _sphere_mesh
	mesh_instance.material_override = _get_mat(color, 0, false, false)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos
	mesh_instance.scale = Vector3(radius * 2, radius * 2, radius * 2)
	return _register(mesh_instance, persist_ms)

func square(pos: Vector3, size: Vector2, color := Color.WHITE_SMOKE, persist_ms := 0, sorting_offset := 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.sorting_offset = sorting_offset
	mesh_instance.mesh = _box_mesh
	mesh_instance.material_override = _get_mat(color, 0, false, false)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos
	mesh_instance.scale = Vector3(size.x, size.y, 1.0)
	return _register(mesh_instance, persist_ms)

func cone(tip_pos: Vector3, direction: Vector3, radius := 0.05, height := 0.15, color := Color.WHITE_SMOKE, persist_ms := 0, render_priority := 0, no_depth_test := false, shaded := false, sorting_offset := 0.0, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.sorting_offset = sorting_offset
	mesh_instance.mesh = _cone_mesh
	mesh_instance.material_override = _get_mat(color, render_priority, no_depth_test, shaded, depth_draw)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dir := direction.normalized()
	mesh_instance.quaternion = Quaternion(Vector3.UP, dir)
	mesh_instance.position = tip_pos - dir * (height * 0.5)
	mesh_instance.scale = Vector3(radius * 2, height, radius * 2)
	return _register(mesh_instance, persist_ms)

func _register(node: Node, persist_ms: float) -> MeshInstance3D:
	get_tree().get_root().add_child(node)
	if persist_ms == 1:
		_to_free.append(node)
	elif persist_ms > 0:
		@warning_ignore("return_value_discarded")
		get_tree().create_timer(persist_ms).timeout.connect(node.queue_free)
	return node as MeshInstance3D
