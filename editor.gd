class_name Editor
extends RayCast3D


const HIGHLIGHT_MATERIAL = preload("res://materials/highlight.tres")

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
		for shape_item: ShapeItem in shape_items.get_children():
			shape_item.set_selected(value == shape_item.get_index())
var construction_material := preload("res://materials/bricks/bricks.tres") as BaseMaterial3D
var construction_collision := true

var _ghost: CSGShape3D
var _ghost_cached_shape := -1
var _ghost_material: Material

@onready var object_properties := get_tree().current_scene.get_node("%ObjectProperties") as ObjectProperties
@onready var input_display := get_tree().current_scene.get_node("%InputDisplay") as InputDisplay
@onready var shape_select := get_tree().current_scene.get_node("%ShapeSelect") as Control
@onready var shape_items := get_tree().current_scene.get_node("%ShapeItems") as Control
@onready var geometry_root := get_tree().current_scene.get_node(^"Geometry")
@onready var tree := get_tree()


func _ready() -> void:
	set_object_builder_active(false)
	selected_shape = 0


func _process(_delta: float) -> void:
	if not Menu.shown:
		if Input.is_action_just_pressed(&"object_builder"):
			if object_properties.visible:
				object_properties.close()
			else:
				set_object_builder_active(not object_builder_active)

		if not object_builder_active:
			_handle_editor_input()
			return

		if Input.is_action_just_pressed(&"properties"):
			object_properties.toggle(null)

	if object_builder_active:
		_update_cursor()
		_handle_construction()


func _handle_editor_input() -> void:
	for control: Control in tree.get_nodes_in_group(&"UI"):
		if control.visible:
			return

	var collider := get_collider()

	if Input.is_action_just_pressed(&"properties"):
		if collider is CSGShape3D:
			object_properties.toggle(collider)
	elif Input.is_action_just_pressed(&"customize_player"):
		object_properties.toggle(player)

	if collider:
		if collider is CSGShape3D:
			highlighted_geometry = collider
			if Input.is_action_just_pressed(&"destroy"):
				if not highlighted_geometry.is_in_group(&"Undeletable"):
					Audio.play_sound("destroy")
					destroy.rpc(highlighted_geometry.get_path())
			return
	highlighted_geometry = null


func _update_cursor() -> void:
	if Input.is_action_just_pressed(&"cursor_forward"):
		cursor_distance -= CURSOR_STEP
		target_position.z -= CURSOR_STEP
	elif Input.is_action_just_pressed(&"cursor_back"):
		cursor_distance += CURSOR_STEP
		target_position.z += CURSOR_STEP
	cursor_distance = clampf(cursor_distance, CURSOR_MIN, CURSOR_MAX)
	target_position.z = clampf(target_position.z, CURSOR_MIN, CURSOR_MAX)

	if is_colliding():
		cursor.global_position = get_collision_point()
	else:
		cursor.position = Vector3(0, 0, cursor_distance)

	cursor.global_position = cursor.global_position.snapped(Vector3.ONE)
	_draw_line(cursor.global_position, cursor.global_position + Vector3.DOWN * LINE_LENGTH, Color(0, 0.85, 0.85), 1, CURSOR_LINE_WIDTH, 0)


func _handle_construction() -> void:
	_handle_shape_selection()

	var has_first_vertex := not vertices.is_empty()
	if has_first_vertex:
		_draw_preview_box()

	for control: Control in tree.get_nodes_in_group(&"UI"):
		if control.visible:
			return

	if Input.is_action_just_pressed(&"action"):
		vertices.append(cursor.global_position)
		if has_first_vertex:
			_try_finish_shape()
		else:
			Audio.play_sound("click")


func _handle_shape_selection() -> void:
	if Input.is_action_just_pressed(&"previous", true):
		selected_shape = wrapi(selected_shape - 1, 0, SHAPE_COUNT)
	elif Input.is_action_just_pressed(&"next", true):
		selected_shape = wrapi(selected_shape + 1, 0, SHAPE_COUNT)
	elif Input.is_action_just_pressed(&"1"):
		selected_shape = 0
	elif Input.is_action_just_pressed(&"2"):
		selected_shape = 1
	elif Input.is_action_just_pressed(&"3"):
		selected_shape = 2
	elif Input.is_action_just_pressed(&"4"):
		selected_shape = 3
	elif Input.is_action_just_pressed(&"5"):
		selected_shape = 4
	elif Input.is_action_just_pressed(&"6"):
		selected_shape = 5


static func _draw_line(from: Vector3, to: Vector3, color: Color, persist_ms: int, thickness := 0.0, render_priority := 0) -> void:
	@warning_ignore("return_value_discarded")
	Draw3D.line(from, to, color, persist_ms, thickness, render_priority)


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

	_draw_line(Vector3(a.x - dx, a.y, a.z), Vector3(p1.x + dx, p1.y, p1.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(a.x, a.y - dy, a.z), Vector3(p2.x, p2.y + dy, p2.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(a.x, a.y, a.z - dz), Vector3(p3.x, p3.y, p3.z + dz), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p1.x, p1.y - dy, p1.z), Vector3(p4.x, p4.y + dy, p4.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p1.x, p1.y, p1.z - dz), Vector3(p6.x, p6.y, p6.z + dz), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p2.x - dx, p2.y, p2.z), Vector3(p4.x + dx, p4.y, p4.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p2.x, p2.y, p2.z - dz), Vector3(p5.x, p5.y, p5.z + dz), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p3.x - dx, p3.y, p3.z), Vector3(p6.x + dx, p6.y, p6.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p3.x, p3.y - dy, p3.z), Vector3(p5.x, p5.y + dy, p5.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p4.x, p4.y, p4.z - dz), Vector3(c.x, c.y, c.z + dz), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p5.x - dx, p5.y, p5.z), Vector3(c.x + dx, c.y, c.z), color, 1, PREVIEW_LINE_WIDTH, 1)
	_draw_line(Vector3(p6.x, p6.y - dy, p6.z), Vector3(c.x, c.y + dy, c.z), color, 1, PREVIEW_LINE_WIDTH, 1)

	if degenerate:
		_hide_ghost()
	else:
		_ensure_ghost()
		_update_ghost(a, c)


func _ensure_ghost() -> void:
	var shape_name := _shape_name()
	if shape_name.is_empty():
		return
	if selected_shape == _ghost_cached_shape and _ghost:
		_ghost.visible = true
		return
	if _ghost:
		_ghost.queue_free()
	_ghost = _create_shape(shape_name, Vector3.ONE)
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
	_ghost.position = center
	_ghost.rotation = Vector3.ZERO
	if _shape_name() == &"Polygon":
		_ghost.position.z += abs_size.z / 2
	_apply_shape_size(_ghost, _shape_name(), abs_size)


func _apply_shape_size(shape: CSGShape3D, type: String, size: Vector3) -> void:
	match type:
		"Cuboid":
			var s := shape as CSGBox3D
			if s: s.size = size
		"Ellipsoid":
			shape.scale = size
		"Cylinder", "Cone":
			shape.scale = size / 2
		"Torus":
			shape.scale = size / 2
		"Polygon":
			shape.scale = size


func _hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false


func _try_finish_shape() -> void:
	_hide_ghost()
	var size := vertices[-2] - vertices[-1]
	if _is_degenerate(size):
		vertices.clear()
		return
	Audio.play_sound("place")
	construct_shape.rpc(_shape_name(), vertices[-2] - size / 2, Vector3.ZERO, size.abs(), construction_material.resource_path, construction_collision)
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
	use_collision: bool
) -> CSGShape3D:
	var shape := _create_shape(type, size)
	if not shape:
		return null
	geometry_root.add_child(shape)
	shape.owner = geometry_root
	shape.add_to_group(&"Persist")
	shape.position = pos
	shape.rotation = rot
	shape.material = load(material)
	shape.use_collision = use_collision
	if type == &"Polygon":
		shape.position.z += size.z / 2
	if shape.get_index() == 0:
		shape.add_to_group(&"Undeletable")
	shape.name = str(shape.get_index())
	return shape


func _create_shape(type: String, size: Vector3) -> CSGShape3D:
	match type:
		"Cuboid":
			var s := CSGBox3D.new()
			s.size = size
			return s
		"Ellipsoid":
			var s := CSGSphere3D.new()
			s.radial_segments = 24
			s.rings = 12
			s.scale = size
			return s
		"Cylinder":
			var s := CSGCylinder3D.new()
			s.sides = 16
			s.radius = 1.0
			s.height = 2.0
			s.scale = size / 2
			return s
		"Cone":
			var s := CSGCylinder3D.new()
			s.cone = true
			s.sides = 16
			s.radius = 1.0
			s.height = 2.0
			s.scale = size / 2
			return s
		"Torus":
			var s := CSGTorus3D.new()
			s.ring_sides = 12
			s.sides = 16
			s.scale = size / 2
			return s
		"Polygon":
			var s := CSGPolygon3D.new()
			s.polygon = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5)])
			s.scale = size
			return s
	return null


func get_nearest_node(nodes: Array[Node], pos: Vector3) -> Node3D:
	nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return nodes[0]


func set_object_builder_active(value: bool) -> void:
	_hide_ghost()
	vertices.clear()
	object_properties.close()
	object_builder_active = value
	shape_select.visible = object_builder_active
	cursor.visible = object_builder_active
	target_position.z = -2.5 if object_builder_active else -5.0
	highlighted_geometry = null

	if not player.first_person:
		return

	input_display.clear_input_prompts()
	if object_builder_active:
		input_display.add_input_prompt(&"ui_cancel", tr(&"Pause Menu"))
		input_display.add_input_prompt(&"object_builder", tr(&"Exit Object Builder"))
		input_display.add_input_prompt(&"properties")
		input_display.add_input_prompt(&"action", tr(&"Place Shape Point"))
		input_display.add_input_prompt(&"previous", tr(&"Previous Shape"))
		input_display.add_input_prompt(&"next", tr(&"Next Shape"))
	else:
		input_display.add_input_prompt(&"ui_cancel", tr(&"Pause Menu"))
		input_display.add_input_prompt(&"customize_player")
		input_display.add_input_prompt(&"object_builder")
		input_display.add_input_prompt(&"properties")
		input_display.add_input_prompt(&"destroy")
		input_display.add_input_prompt(&"jump", tr(&"(Double Tap) Fly"))
		input_display.add_input_prompt(&"time_play_pause", tr(&"Play/Pause"))
		input_display.add_input_prompt(&"time_rewind", tr(&"Rewind"))
