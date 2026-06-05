class_name Editor
extends RayCast3D


const HIGHLIGHT_MATERIAL = preload("res://materials/highlight.tres")

const ICON_CUBOID := preload("res://icons/cube.svg")
const ICON_ELLIPSOID := preload("res://icons/ellipsoid.svg")
const ICON_CYLINDER := preload("res://icons/cylinder.svg")
const ICON_CONE := preload("res://icons/cone.svg")
const ICON_TORUS := preload("res://icons/torus.svg")
const ICON_TRIANGLE := preload("res://icons/triangle.svg")

const CURSOR_STEP := 0.5
const CURSOR_MIN := -10.5
const CURSOR_MAX := -0.5
const LINE_LENGTH := 1000
const SHAPE_COUNT := 6
const PREVIEW_LINE_WIDTH := 0.016
const CURSOR_LINE_WIDTH := 0.015

@export var cursor: Node3D
@export var player: Character

var object_builder_active := false
var highlighted_geometry: GeometryInstance3D:
	set(value):
		if highlighted_geometry != value:
			if highlighted_geometry:
				highlighted_geometry.material_overlay = null
			if value:
				value.material_overlay = HIGHLIGHT_MATERIAL
			highlighted_geometry = value
			if not object_builder_active:
				_update_input_display()
var cursor_distance := -3.0
var vertices: Array[Vector3]
var _selected_shape := -1
var selected_shape: int:
	get:
		return _selected_shape
	set(value):
		if _selected_shape == value:
			return
		_selected_shape = value
		rotation_angles = Vector3.ZERO
		_update_player_thought()
var construction_material := preload("res://materials/bricks/bricks.tres") as BaseMaterial3D
var construction_collision := true

var rotation_angles := Vector3.ZERO
var uniform_scale_mode := false

var _ghost: CSGShape3D
var _ghost_cached_shape := -1
var _ghost_material: Material
var _angle_label_y: Label3D = null
var _angle_label_x: Label3D = null
var _dim_label_x: Label3D = null
var _dim_label_y: Label3D = null
var _dim_label_z: Label3D = null
var _block_action_from_pie_menu := false

@onready var object_properties := get_tree().current_scene.get_node("%ObjectProperties") as ObjectProperties
@onready var input_display := get_tree().current_scene.get_node("%InputDisplay") as InputDisplay
@onready var geometry_root := get_tree().current_scene.get_node(^"Geometry")
@onready var pie_menu: PieMenu = get_tree().current_scene.get_node("%PieMenu")
@onready var tree := get_tree()

func _ready() -> void:
	set_object_builder_active(false)
	selected_shape = 0

	if cursor:
		var mesh_instance := cursor as MeshInstance3D
		if mesh_instance:
			var mat := mesh_instance.get_active_material(0) as StandardMaterial3D
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.99
				mat.render_priority = 127

	pie_menu.set_items([
		{"label": "Cuboid", "icon": ICON_CUBOID},
		{"label": "Ellipsoid", "icon": ICON_ELLIPSOID},
		{"label": "Cylinder", "icon": ICON_CYLINDER},
		{"label": "Cone", "icon": ICON_CONE},
		{"label": "Torus", "icon": ICON_TORUS},
		{"label": "Polygon", "icon": ICON_TRIANGLE},
	])
	var _error := pie_menu.item_selected.connect(_on_pie_menu_item_selected)
	_error = pie_menu.cancelled.connect(_on_pie_menu_cancelled)
	pie_menu.add_to_group(&"UI")


func _process(_delta: float) -> void:
	if not Menu.shown:
		if _is_action_just_pressed(&"object_builder"):
			if object_properties.visible:
				object_properties.close()
			else:
				set_object_builder_active(not object_builder_active)

		if not object_builder_active:
			_handle_editor_input()
			return

		if _is_action_just_pressed(&"object_properties", true):
			object_properties.toggle(null)

		if object_builder_active:
			_update_cursor()
			_handle_construction()


func _handle_editor_input() -> void:
	for control: Control in tree.get_nodes_in_group(&"UI"):
		if control.visible:
			return

	var collider := get_collider()

	if _is_action_just_pressed(&"object_properties", true):
		if collider is CSGShape3D:
			object_properties.toggle(collider)

	if collider:
		if collider is CSGShape3D:
			highlighted_geometry = collider
			if _is_action_just_pressed(&"destroy"):
				if not highlighted_geometry.is_in_group(&"Undeletable"):
					Audio.play_sound("destroy")
					destroy.rpc(highlighted_geometry.get_path())
			return
	highlighted_geometry = null


func is_joypad_modifier_pressed() -> bool:
	var joy_idx: int = InputHelper.device_index if InputHelper.device_index >= 0 else 0
	if Input.is_joy_button_pressed(joy_idx, JOY_BUTTON_LEFT_SHOULDER):
		return true
	for id in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER):
			return true
	return false


func _is_action_just_pressed(action: StringName, require_joypad_modifier: bool = false, exact_match: bool = false) -> bool:
	if not Input.is_action_just_pressed(action, exact_match):
		return false
	if InputHelper.last_event_is_joypad:
		return is_joypad_modifier_pressed() == require_joypad_modifier
	return true


func _update_cursor() -> void:
	if _is_action_just_pressed(&"cursor_forward") and not Input.is_key_pressed(KEY_ALT):
		cursor_distance -= CURSOR_STEP
		target_position.z -= CURSOR_STEP
	elif _is_action_just_pressed(&"cursor_back") and not Input.is_key_pressed(KEY_ALT):
		cursor_distance += CURSOR_STEP
		target_position.z += CURSOR_STEP
	cursor_distance = clampf(cursor_distance, CURSOR_MIN, CURSOR_MAX)
	target_position.z = clampf(target_position.z, CURSOR_MIN, CURSOR_MAX)

	if is_colliding():
		cursor.global_position = get_collision_point()
	else:
		cursor.position = Vector3(0, 0, cursor_distance)

	cursor.global_position = cursor.global_position.snapped(Vector3.ONE)
	var cursor_line_color := Color(0, 0.85, 0.85, 0.99)
	_draw_line(cursor.global_position, cursor.global_position + Vector3.DOWN * LINE_LENGTH, cursor_line_color, 1, CURSOR_LINE_WIDTH, 1, false, BaseMaterial3D.DEPTH_DRAW_ALWAYS, 0.0)


func _handle_construction() -> void:
	var block_action := _block_action_from_pie_menu
	_block_action_from_pie_menu = false

	if _is_action_just_pressed(&"choose_shape") and not pie_menu.visible:
		pie_menu.open()

	if _is_action_just_pressed(&"rotate_up", true):
		rotation_angles.x += deg_to_rad(45)
	elif _is_action_just_pressed(&"rotate_down", true):
		rotation_angles.x -= deg_to_rad(45)
	elif _is_action_just_pressed(&"rotate_cw", true):
		rotation_angles.y -= deg_to_rad(45)
	elif _is_action_just_pressed(&"rotate_ccw", true):
		rotation_angles.y += deg_to_rad(45)
	elif _is_action_just_pressed(&"flip_h", true):
		rotation_angles.y = fmod(rotation_angles.y + PI, 2.0 * PI)
	elif _is_action_just_pressed(&"flip_v", true):
		rotation_angles.x = fmod(rotation_angles.x + PI, 2.0 * PI)

	if absf(rotation_angles.y) >= 2.0 * PI - 0.01:
		rotation_angles.y = 0.0
	if absf(rotation_angles.x) >= 2.0 * PI - 0.01:
		rotation_angles.x = 0.0

	if _is_action_just_pressed(&"toggle_uniform", true):
		uniform_scale_mode = not uniform_scale_mode

	var has_first_vertex := not vertices.is_empty()
	if has_first_vertex:
		_draw_preview_box()

	for control: Control in tree.get_nodes_in_group(&"UI"):
		if control.visible:
			return

	if not block_action and _is_action_just_pressed(&"action"):
		vertices.append(cursor.global_position)
		if has_first_vertex:
			_try_finish_shape()
		else:
			Audio.play_sound("click")


func _on_pie_menu_item_selected(index: int) -> void:
	selected_shape = index
	_block_action_from_pie_menu = true
	_recapture_mouse()


func _on_pie_menu_cancelled() -> void:
	_block_action_from_pie_menu = true
	_recapture_mouse()


func _recapture_mouse() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	if player and player.pivot:
		player.pivot._ignore_look_until_slow = true
		player.pivot._settle_frames_left = -1


static func _draw_line(from: Vector3, to: Vector3, color: Color, persist_ms: int, thickness := 0.0, render_priority := 0, no_depth_test := false, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, sorting_offset := 0.0) -> void:
	@warning_ignore("return_value_discarded")
	Draw3D.line(from, to, color, persist_ms, thickness, render_priority, no_depth_test, depth_draw, sorting_offset)


static func _draw_cone(tip_pos: Vector3, direction: Vector3, radius: float, height: float, color: Color, persist_ms: int, render_priority := 0, no_depth_test := false, shaded := false, sorting_offset := 0.0, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY) -> void:
	@warning_ignore("return_value_discarded")
	Draw3D.cone(tip_pos, direction, radius, height, color, persist_ms, render_priority, no_depth_test, shaded, sorting_offset, depth_draw)


static func _draw_dashed_line(from: Vector3, to: Vector3, color: Color, persist_ms: int, thickness := 0.0, render_priority := 0, segment_length := 0.15, gap_length := 0.1, no_depth_test := false, depth_draw := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, sorting_offset := 0.0) -> void:
	var dir := to - from
	var total_len := dir.length()
	if total_len < 0.001:
		return
	dir = dir.normalized()
	var step := segment_length + gap_length
	var current := 0.0
	while current < total_len:
		var start := from + dir * current
		var end := from + dir * minf(current + segment_length, total_len)
		_draw_line(start, end, color, persist_ms, thickness, render_priority, no_depth_test, depth_draw, sorting_offset)
		current += step


func _draw_preview_box() -> void:
	var a := vertices[-1]
	var c := cursor.global_position
	var degenerate := _is_degenerate(a - c)
	var color := Color.RED if degenerate else Color.WHITE

	var p1 := Vector3(c.x, a.y, a.z)
	var p2 := Vector3(a.x, c.y, a.z)
	var p3 := Vector3(a.x, a.y, c.z)
	var p4 := Vector3(c.x, c.y, a.z)
	var p5 := Vector3(a.x, c.y, c.z)
	var p6 := Vector3(c.x, a.y, c.z)

	var e := PREVIEW_LINE_WIDTH * 0.5
	var dx: float = sign(c.x - a.x) * e
	var dy: float = sign(c.y - a.y) * e
	var dz: float = sign(c.z - a.z) * e

	var c_alpha := color
	c_alpha.a = 0.99
	var d_draw := BaseMaterial3D.DEPTH_DRAW_DISABLED
	var p_line := 10
	var s_off := 5.0

	_draw_line(Vector3(a.x - dx, a.y, a.z), Vector3(p1.x + dx, p1.y, p1.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(a.x, a.y - dy, a.z), Vector3(p2.x, p2.y + dy, p2.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(a.x, a.y, a.z - dz), Vector3(p3.x, p3.y, p3.z + dz), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p1.x, p1.y - dy, p1.z), Vector3(p4.x, p4.y + dy, p4.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p1.x, p1.y, p1.z - dz), Vector3(p6.x, p6.y, p6.z + dz), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p2.x - dx, p2.y, p2.z), Vector3(p4.x + dx, p4.y, p4.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p2.x, p2.y, p2.z - dz), Vector3(p5.x, p5.y, p5.z + dz), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p3.x - dx, p3.y, p3.z), Vector3(p6.x + dx, p6.y, p6.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p3.x, p3.y - dy, p3.z), Vector3(p5.x, p5.y + dy, p5.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p4.x, p4.y, p4.z - dz), Vector3(c.x, c.y, c.z + dz), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p5.x - dx, p5.y, p5.z), Vector3(c.x + dx, c.y, c.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)
	_draw_line(Vector3(p6.x, p6.y - dy, p6.z), Vector3(c.x, c.y + dy, c.z), c_alpha, 1, PREVIEW_LINE_WIDTH, p_line, false, d_draw, s_off)

	if degenerate:
		_hide_ghost()
	else:
		_ensure_ghost()

		var diff := c - a
		var abs_diff := diff.abs()
		var sb := _get_snapped_label_basis(c)

		_dim_label_x.visible = abs_diff.x > 0.01
		_dim_label_x.text = _format_dim(abs_diff.x)
		_dim_label_x.global_position = c - Vector3(signf(diff.x) * 0.5, 0, 0)
		_dim_label_x.global_transform.basis = sb
		_dim_label_x.pixel_size = 0.0013

		_dim_label_y.visible = abs_diff.y > 0.01
		_dim_label_y.text = _format_dim(abs_diff.y)
		_dim_label_y.global_position = c - Vector3(0, signf(diff.y) * 0.5, 0)
		_dim_label_y.global_transform.basis = sb
		_dim_label_y.pixel_size = 0.0013

		_dim_label_z.visible = abs_diff.z > 0.01
		_dim_label_z.text = _format_dim(abs_diff.z)
		_dim_label_z.global_position = c - Vector3(0, 0, signf(diff.z) * 0.5)
		_dim_label_z.global_transform.basis = sb
		_dim_label_z.pixel_size = 0.0013

		_update_ghost(a, c)


func _format_dim(val: float) -> String:
	var s := "%.1f" % val
	return s.left(-2) if s.ends_with(".0") else s


func _ensure_ghost() -> void:
	var shape_name := _shape_name()
	if shape_name.is_empty():
		return

	if not _angle_label_y:
		_angle_label_y = _create_label(true, 120)
	if not _angle_label_x:
		_angle_label_x = _create_label(true, 120)
	if not _dim_label_x:
		_dim_label_x = _create_label(true, 120)
	if not _dim_label_y:
		_dim_label_y = _create_label(true, 120)
	if not _dim_label_z:
		_dim_label_z = _create_label(true, 120)

	if selected_shape == _ghost_cached_shape and _ghost:
		_ghost.visible = true
		return
	if _ghost:
		_ghost.queue_free()
	_ghost = _create_shape(shape_name)
	if not _ghost:
		return
	if not _ghost_material:
		_ghost_material = ORMMaterial3D.new()
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.albedo_color = Color(1, 1, 1, 0.3)
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.material = _ghost_material
	_ghost.use_collision = false
	_ghost_cached_shape = selected_shape
	geometry_root.add_child(_ghost)


func _update_ghost(a: Vector3, c: Vector3) -> void:
	if not _ghost:
		return
	var size := a - c
	var center := a - size / 2
	var abs_size := size.abs()
	var type := _shape_name()
	var tf := _compute_fit_transform(type, abs_size, rotation_angles)
	if type == "Cuboid":
		var sx := tf.basis.x.length()
		var sy := tf.basis.y.length()
		var sz := tf.basis.z.length()
		_ghost.size = Vector3(sx, sy, sz)
		tf.basis.x /= sx
		tf.basis.y /= sy
		tf.basis.z /= sz
	_ghost.transform = Transform3D(tf.basis, center + tf.origin)

	var camera := get_viewport().get_camera_3d()
	var dist := 5.0
	if camera:
		dist = maxf(1.0, camera.global_position.distance_to(center))
	var scale_factor := dist * 0.2

	var radius := 0.6 * scale_factor
	var forward_len := radius * 2.0
	var cone_height := 0.2 * scale_factor
	var cone_radius := 0.08 * scale_factor

	var axis_len_y := abs_size.y * 0.5
	var axis_len_x := abs_size.x * 0.5
	var axis_len_z := abs_size.z * 0.5

	var d_draw := BaseMaterial3D.DEPTH_DRAW_DISABLED
	var p_axis := 10
	var s_off := 5.0

	# Y Axis (Green)
	_draw_dashed_line(center + Vector3.UP * axis_len_y, center + Vector3.DOWN * axis_len_y, Color(0.3, 1.0, 0.0, 0.75), 1, 0, p_axis, 0.2, 0.1, false, d_draw, s_off)

	# X Axis (Red)
	_draw_dashed_line(center - Vector3.RIGHT * axis_len_x, center + Vector3.RIGHT * axis_len_x, Color(1.0, 0.2, 0.3, 0.75), 1, 0, p_axis, 0.2, 0.1, false, d_draw, s_off)

	# Z Axis (Blue)
	_draw_dashed_line(center - Vector3.FORWARD * axis_len_z, center + Vector3.FORWARD * axis_len_z, Color(0.2, 0.4, 1.0, 0.75), 1, 0, p_axis, 0.2, 0.1, false, d_draw, s_off)

	var pointer_basis := Basis.from_euler(rotation_angles, EULER_ORDER_YXZ)
	var forward_dir := pointer_basis.z.normalized()

	var p_gizmo := 5
	var s_gizmo := 0.0

	if rotation_angles.length_squared() > 0.001:
		_draw_line(center, center + Vector3.BACK * radius, Color(0, 0, 0, 0.8), 1, CURSOR_LINE_WIDTH * 1.5 * scale_factor, p_gizmo, true, BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, s_gizmo)
		_draw_line(center, center + forward_dir * (forward_len - cone_height), Color(0.9, 0.9, 0.9, 0.95), 1, CURSOR_LINE_WIDTH * 1.5 * scale_factor, p_gizmo + 1, true, BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, s_gizmo)
	else:
		_draw_line(center, center + forward_dir * (forward_len - cone_height), Color(0.9, 0.9, 0.9, 0.95), 1, CURSOR_LINE_WIDTH * 1.5 * scale_factor, p_gizmo + 1, true, BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY, s_gizmo)

	_draw_cone(center + forward_dir * forward_len, forward_dir, cone_radius, cone_height, Color(0.9, 0.9, 0.9, 0.95), 1, p_gizmo + 2, true, false, s_gizmo)

	var shared_label_basis := _get_snapped_label_basis(center)

	# Horizontal dial (Y rotation)
	var ry := rotation_angles.y
	var ry_deg := roundi(rad_to_deg(ry))
	if ry_deg != 0 and ry_deg != 360 and ry_deg != -360:
		var start_dir := Vector3.BACK
		var y_color := Color(0.3, 1.0, 0.0) # Vibrant green
		_draw_gizmo_arc(center, Vector3.UP, start_dir, ry, radius, y_color, true, scale_factor, p_gizmo)

		_angle_label_y.visible = true
		_angle_label_y.modulate = y_color
		_angle_label_y.text = "%d°" % ry_deg
		_angle_label_y.pixel_size = 0.0013 * scale_factor
		_angle_label_y.global_position = center + start_dir.rotated(Vector3.UP, signf(ry) * PI / 8.0).normalized() * (radius * 1.6)
		_angle_label_y.global_transform.basis = shared_label_basis
	else:
		_angle_label_y.visible = false

	# Vertical dial (X rotation)
	var rx := rotation_angles.x
	var rx_deg := roundi(rad_to_deg(rx))
	if rx_deg != 0 and rx_deg != 360 and rx_deg != -360:
		var start_dir := Vector3.BACK.rotated(Vector3.UP, ry).normalized()
		var v_normal := Vector3.RIGHT.rotated(Vector3.UP, ry).normalized()
		var x_color := Color(1.0, 0.2, 0.3) # Vibrant red

		_draw_gizmo_arc(center, v_normal, start_dir, rx, radius, x_color, true, scale_factor, p_gizmo)

		_angle_label_x.visible = true
		_angle_label_x.modulate = x_color
		_angle_label_x.text = "%d°" % rx_deg
		_angle_label_x.pixel_size = 0.0013 * scale_factor
		_angle_label_x.global_position = center + start_dir.rotated(v_normal, signf(rx) * PI / 8.0).normalized() * (radius * 1.6)
		_angle_label_x.global_transform.basis = shared_label_basis
	else:
		_angle_label_x.visible = false

	# Sort labels by distance to camera
	if camera:
		var cam_pos := camera.global_position
		var labels: Array[Label3D] = []
		for l: Label3D in [_dim_label_x, _dim_label_y, _dim_label_z, _angle_label_x, _angle_label_y]:
			if l and l.visible:
				labels.append(l)

		labels.sort_custom(func(a_label: Label3D, b_label: Label3D) -> bool:
			return a_label.global_position.distance_to(cam_pos) > b_label.global_position.distance_to(cam_pos)
		)

		var base_p := 110
		for i in range(labels.size()):
			var p := base_p + i * 2
			labels[i].render_priority = p
			labels[i].outline_render_priority = p - 1


func _draw_gizmo_arc(c: Vector3, normal: Vector3, start_dir: Vector3, angle_rad: float, radius: float, color: Color, no_depth_test := false, scale_factor := 1.0, priority := 0) -> void:
	var segments := 12
	var prev := c + start_dir * radius
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var curr := c + start_dir.rotated(normal, angle_rad * t) * radius
		_draw_line(prev, curr, color, 1, CURSOR_LINE_WIDTH * 1.5 * scale_factor, priority, no_depth_test)
		prev = curr


func _get_snapped_label_basis(_label_pos: Vector3) -> Basis:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Basis()

	var euler := camera.global_transform.basis.get_euler(EULER_ORDER_YXZ)

	var snap := PI / 4.0
	euler.x = roundf(euler.x / snap) * snap
	euler.y = roundf(euler.y / snap) * snap
	euler.z = 0

	return Basis.from_euler(euler, EULER_ORDER_YXZ)


func _get_base_scale(type: String) -> Vector3:
	match type:
		"Torus":
			if uniform_scale_mode:
				return Vector3(0.5, 0.5, 0.5)
			else:
				return Vector3(0.5, 2.0, 0.5)
		_:
			return Vector3.ONE


func _get_local_offset(type: String) -> Vector3:
	match type:
		"Polygon":
			return Vector3(0, 0, 0.5)
		_:
			return Vector3.ZERO


func _compute_rotated_aabb(type: String, R: Basis) -> Dictionary:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)

	match type:
		"Cuboid":
			for sx: float in [-0.5, 0.5]:
				for sy: float in [-0.5, 0.5]:
					for sz: float in [-0.5, 0.5]:
						var p := R * Vector3(sx, sy, sz)
						lo = lo.min(p)
						hi = hi.max(p)

		"Ellipsoid":
			lo = Vector3(-0.5, -0.5, -0.5)
			hi = Vector3(0.5, 0.5, 0.5)

		"Cylinder":
			for i: int in 3:
				var row := Vector3(R.x[i], R.y[i], R.z[i])
				var alpha := sqrt(row.x * row.x + row.z * row.z)
				var half := 0.5 * alpha + 0.5 * absf(row.y)
				lo[i] = -half
				hi[i] = half

		"Cone":
			for i: int in 3:
				var row := Vector3(R.x[i], R.y[i], R.z[i])
				var alpha := sqrt(row.x * row.x + row.z * row.z)
				var beta := row.y
				var base_max := 0.5 * alpha - 0.5 * beta
				var base_min := -0.5 * alpha - 0.5 * beta
				var apex := 0.5 * beta
				hi[i] = maxf(base_max, apex)
				lo[i] = minf(base_min, apex)

		"Torus":
			for i: int in 3:
				var row := Vector3(R.x[i], R.y[i], R.z[i])
				var alpha := sqrt(row.x * row.x + row.z * row.z)
				var beta := row.y
				var half: float
				if uniform_scale_mode:
					half = 0.375 * alpha + 0.125
				else:
					half = 0.375 * alpha + sqrt(0.015625 * alpha * alpha + 0.25 * beta * beta)
				lo[i] = -half
				hi[i] = half

		"Polygon":
			var verts: Array[Vector3] = [
				Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5), Vector3(0.5, -0.5, 0.5),
				Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5), Vector3(0.5, -0.5, -0.5),
			]
			for v: Vector3 in verts:
				var p := R * v
				lo = lo.min(p)
				hi = hi.max(p)

	return {"min": lo, "max": hi}


func _compute_fit_transform(type: String, box_size: Vector3, rot: Vector3) -> Transform3D:
	var R := Basis.from_euler(rot, EULER_ORDER_YXZ)
	var aabb := _compute_rotated_aabb(type, R)
	var aabb_size: Vector3 = aabb["max"] - aabb["min"]
	var aabb_center: Vector3 = (aabb["max"] + aabb["min"]) * 0.5

	var fit_scale := Vector3(
		box_size.x / aabb_size.x if aabb_size.x > 0.0001 else 1.0,
		box_size.y / aabb_size.y if aabb_size.y > 0.0001 else 1.0,
		box_size.z / aabb_size.z if aabb_size.z > 0.0001 else 1.0,
	)

	if not type.is_empty() and uniform_scale_mode:
		var u := minf(fit_scale.x, minf(fit_scale.y, fit_scale.z))
		fit_scale = Vector3(u, u, u)

	var base_scale := _get_base_scale(type)
	var local_offset := _get_local_offset(type)

	var fit_basis := Basis(
		R.x * fit_scale * base_scale.x,
		R.y * fit_scale * base_scale.y,
		R.z * fit_scale * base_scale.z
	)

	var rotated_offset := R * local_offset
	var origin := (rotated_offset - aabb_center) * fit_scale

	return Transform3D(fit_basis, origin)


func _hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false
	for l: Label3D in [_angle_label_y, _angle_label_x, _dim_label_x, _dim_label_y, _dim_label_z]:
		if l:
			l.visible = false


func _try_finish_shape() -> void:
	_hide_ghost()
	var size := vertices[-2] - vertices[-1]
	if _is_degenerate(size):
		vertices.clear()
		return
	Audio.play_sound("place")
	var unique_node_name := str(multiplayer.get_unique_id()) + "_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 1000)
	construct_shape.rpc(
		_shape_name(),
		vertices[-2] - size / 2,
		rotation_angles,
		size.abs(),
		construction_material.resource_path,
		construction_collision,
		uniform_scale_mode,
		unique_node_name
	)
	vertices.clear()


static func _is_degenerate(size: Vector3) -> bool:
	return is_zero_approx(size.x) or is_zero_approx(size.y) or is_zero_approx(size.z)


func _shape_name() -> String:
	match selected_shape:
		0: return &"Cuboid"
		1: return &"Ellipsoid"
		2: return &"Cylinder"
		3: return &"Cone"
		4: return &"Torus"
		5: return &"Polygon"
	return &""


func _create_label(no_depth: bool, priority: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = StandardMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = no_depth
	l.render_priority = priority
	l.sorting_offset = 50.0
	l.pixel_size = 0.0013
	l.font_size = 160
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	l.modulate = Color.WHITE
	l.outline_size = 48
	l.outline_modulate = Color(0, 0, 0, 1.0)
	l.outline_render_priority = priority - 1
	geometry_root.add_child(l)
	return l


@rpc("any_peer", "call_local")
func destroy(node_path: NodePath) -> void:
	var node := get_node_or_null(node_path)
	if node:
		node.queue_free()


@rpc("any_peer", "call_local")
func construct_shape(
	type: String,
	pos: Vector3,
	rot: Vector3,
	size: Vector3,
	material: String,
	use_collision: bool,
	uniform := false,
	node_name := ""
) -> CSGShape3D:
	var shape := _create_shape(type)
	if not shape:
		return null
	geometry_root.add_child(shape)
	shape.owner = geometry_root
	shape.add_to_group(&"Persist")

	var prev_uniform := uniform_scale_mode
	uniform_scale_mode = uniform
	var tf := _compute_fit_transform(type, size, rot)
	uniform_scale_mode = prev_uniform

	if type == "Cuboid":
		var sx := tf.basis.x.length()
		var sy := tf.basis.y.length()
		var sz := tf.basis.z.length()
		shape.size = Vector3(sx, sy, sz)
		tf.basis.x /= sx
		tf.basis.y /= sy
		tf.basis.z /= sz
	shape.transform = Transform3D(tf.basis, pos + tf.origin)
	shape.material = load(material)
	shape.use_collision = use_collision

	shape.set_meta(&"shape_type", type)
	shape.set_meta(&"rotation", rot)
	shape.set_meta(&"box_size", size)
	shape.set_meta(&"box_center", pos)
	shape.set_meta(&"uniform", uniform)

	if shape.get_index() == 0:
		shape.add_to_group(&"Undeletable")

	if node_name.is_empty():
		shape.name = str(shape.get_index())
	else:
		shape.name = node_name

	return shape


func _create_shape(type: String) -> CSGShape3D:
	match type:
		"Cuboid":
			var s := CSGBox3D.new()
			s.size = Vector3.ONE
			return s
		"Ellipsoid":
			var s := CSGSphere3D.new()
			s.radial_segments = 24
			s.rings = 12
			return s
		"Cylinder":
			var s := CSGCylinder3D.new()
			s.sides = 16
			s.radius = 0.5
			s.height = 1.0
			return s
		"Cone":
			var s := CSGCylinder3D.new()
			s.cone = true
			s.sides = 16
			s.radius = 0.5
			s.height = 1.0
			return s
		"Torus":
			var s := CSGTorus3D.new()
			s.ring_sides = 12
			s.sides = 16
			return s
		"Polygon":
			var s := CSGPolygon3D.new()
			s.polygon = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5)])
			return s
	return null


func get_nearest_node(nodes: Array[Node], pos: Vector3) -> Node3D:
	nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return nodes[0]


func set_object_builder_active(value: bool) -> void:
	_hide_ghost()
	vertices.clear()
	rotation_angles = Vector3.ZERO
	object_properties.close()
	object_builder_active = value
	cursor.visible = object_builder_active
	target_position.z = -2.5 if object_builder_active else -5.0
	highlighted_geometry = null

	_update_player_thought()
	_update_input_display()
	(get_tree().current_scene as World).update_mode_indicator()


func _update_input_display() -> void:
	if not player or not input_display:
		return

	input_display.clear_input_prompts()

	# TODO make input display category visibility customizable
	# TODO binding ctrl+... key combinations and L1+... button combinations

	# Common (shown in play and edit mode)
	input_display._add_common_prompts(not object_builder_active) # TODO Allow in object builder
	# TODO [COND MENU OPEN] Escape | O : Back

	if not player.first_person:
		return

	# Editor
	# # All Tools
	# # # Editor Movement
	input_display.add_input_prompt([&"jump"], &"Editor Movement", "(Double Tap) Fly") # TODO adjust label when flying
	# TODO [COND FLYING] CTRL | R3 : Fly Down
	# TODO [COND FLYING] Space | X : Fly Up

	# # # Time Control
	input_display.add_input_prompt([&"time_play_pause"], &"Time Control", "", false, true) # TODO adjust label when playing/pausing
	input_display.add_input_prompt([&"time_rewind"], &"Time Control", "", false, true) # TODO hide if rewound

	# # # Tools
	# TODO input_display.add_input_prompt([&"undo"], &"Tools") # TODO [COND UNDO >0]
	# TODO input_display.add_input_prompt([&"redo"], &"Tools") # TODO [COND REDO >0]

	if object_builder_active:
		input_display.add_input_prompt([&"object_builder"], &"Tools", "Exit Object Builder")

		# # Object Builder
		input_display.add_input_prompt([&"object_properties"], &"Object Builder", "", true, true)
		input_display.add_input_prompt([&"action"], &"Object Builder", "Place Shape Point", true)
		input_display.add_input_prompt([&"choose_shape"], &"Object Builder", "", true)
		input_display.add_input_prompt([&"toggle_uniform"], &"Object Builder", "", true, true)
		input_display.add_input_prompt([&"rotate_cw", &"rotate_ccw"], &"Object Builder", "Rotate Horizontally (Y)", true, true)
		input_display.add_input_prompt([&"rotate_up", &"rotate_down"], &"Object Builder", "Rotate Vertically (X)", true, true)
		input_display.add_input_prompt([&"flip_h"], &"Object Builder", "", true, true)
		input_display.add_input_prompt([&"flip_v"], &"Object Builder", "", true, true)
	else:
		input_display.add_input_prompt([&"object_builder"], &"Tools", "Enter Object Builder")

		# # Default
		if highlighted_geometry:
			# # # Highlighted Object TODO or Selected Object(s) TODO Quantify
			# TODO input_display.add_input_prompt([&"transform_objects"], &"Highlighted Object", "", true)
			input_display.add_input_prompt([&"object_properties"], &"Highlighted Object", "", true, true)
			input_display.add_input_prompt([&"destroy"], &"Highlighted Object", "", true) # TODO hide on undeletable objects
			# TODO input_display.add_input_prompt([&"action"], &"Highlighted Object", "Select Object", true)

		## TODO Grouping & Selecting Objects TODO Quantify
		#input_display.add_input_prompt([&"group_objects"], &"Selected Objects", "", true, true) # TODO make gamepad modifier button customizable
		#input_display.add_input_prompt([&"ungroup_objects"], &"Selected Objects", "", true, true)
		#input_display.add_input_prompt([&"scope_in"], &"Selected Objects", "", true, true)
		#input_display.add_input_prompt([&"scope_out"], &"Selected Objects", "", true, true)

		## TODO Transform Objects TODO Quantify
		#input_display.add_input_prompt([&"rotate_cw", &"rotate_ccw"], &"Transform Objects", "Rotate Horizontally (Y)", true, true)
		#input_display.add_input_prompt([&"rotate_up", &"rotate_down"], &"Transform Objects", "Rotate Vertically (X)", true, true)
		#input_display.add_input_prompt([&"flip_h"], &"Transform Objects", "", true, true)
		#input_display.add_input_prompt([&"flip_v"], &"Transform Objects", "", true, true)
		#input_display.add_input_prompt([&"scale_up", &"scale_down"], &"Transform Objects", "", true, true)


func _update_player_thought() -> void:
	if not player:
		return
	if object_builder_active:
		player.synced_thought = _shape_name()
	else:
		player.synced_thought = ""
