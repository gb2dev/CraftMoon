class_name Editor
extends RayCast3D


const HIGHLIGHT_MATERIAL = preload("res://materials/highlight.tres")

const CURSOR_STEP := 0.5
const CURSOR_MIN := -10.5
const CURSOR_MAX := -0.5
const LINE_LENGTH := 1000
const SHAPE_COUNT := 6

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
var _construction_mode_backing: int
var construction_mode: int:
	get:
		return _construction_mode_backing
	set(value):
		if _construction_mode_backing == value:
			return
		_construction_mode_backing = value
		for shape_item: ShapeItem in shape_items.get_children():
			shape_item.set_selected(value == shape_item.get_index())
var construction_material := preload("res://materials/bricks/bricks.tres") as BaseMaterial3D
var construction_collision := true

@onready var object_properties := get_tree().current_scene.get_node("%ObjectProperties") as ObjectProperties
@onready var input_display := get_tree().current_scene.get_node("%InputDisplay") as InputDisplay
@onready var shape_select := get_tree().current_scene.get_node("%ShapeSelect") as Control
@onready var shape_items := get_tree().current_scene.get_node("%ShapeItems") as Control
@onready var geometry_root := get_tree().current_scene.get_node(^"Geometry")
@onready var tree := get_tree()


func _ready() -> void:
	set_object_builder_active(false)
	construction_mode = 0


func _process(_delta: float) -> void:
	if Menu.shown:
		return

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

	_update_cursor()
	_handle_construction()


func _handle_editor_input() -> void:
	for control: Control in tree.get_nodes_in_group(&"UI"):
		if control.visible:
			return

	if Input.is_action_just_pressed(&"properties"):
		var collider := get_collider()
		if collider is CSGShape3D:
			object_properties.toggle(collider)
	elif Input.is_action_just_pressed(&"customize_player"):
		object_properties.toggle(player)

	var collider := get_collider()
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
	await Draw3D.line(cursor.global_position, cursor.global_position + Vector3.DOWN * LINE_LENGTH, Color(0, 0.85, 0.85), 1)


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
		construction_mode = wrapi(construction_mode - 1, 0, SHAPE_COUNT)
	elif Input.is_action_just_pressed(&"next", true):
		construction_mode = wrapi(construction_mode + 1, 0, SHAPE_COUNT)
	elif Input.is_action_just_pressed(&"1"):
		construction_mode = 0
	elif Input.is_action_just_pressed(&"2"):
		construction_mode = 1
	elif Input.is_action_just_pressed(&"3"):
		construction_mode = 2
	elif Input.is_action_just_pressed(&"4"):
		construction_mode = 3
	elif Input.is_action_just_pressed(&"5"):
		construction_mode = 4
	elif Input.is_action_just_pressed(&"6"):
		construction_mode = 5


func _draw_preview_box() -> void:
	var a := vertices[-1]
	var c := cursor.global_position

	var p1 := Vector3(c.x, a.y, a.z)
	var p2 := Vector3(a.x, c.y, a.z)
	var p3 := Vector3(a.x, a.y, c.z)
	var p4 := Vector3(c.x, c.y, a.z)
	var p5 := Vector3(a.x, c.y, c.z)
	var p6 := Vector3(c.x, a.y, c.z)

	Draw3D.line(a, p1, Color.WHITE, 1)
	Draw3D.line(a, p2, Color.WHITE, 1)
	Draw3D.line(a, p3, Color.WHITE, 1)
	Draw3D.line(p1, p4, Color.WHITE, 1)
	Draw3D.line(p2, p5, Color.WHITE, 1)
	Draw3D.line(p3, p6, Color.WHITE, 1)
	Draw3D.line(p1, p6, Color.WHITE, 1)
	Draw3D.line(p2, p4, Color.WHITE, 1)
	Draw3D.line(p3, p5, Color.WHITE, 1)
	Draw3D.line(p4, c, Color.WHITE, 1)
	Draw3D.line(p5, c, Color.WHITE, 1)
	Draw3D.line(p6, c, Color.WHITE, 1)


func _try_finish_shape() -> void:
	var size := vertices[-2] - vertices[-1]
	if _is_degenerate(size):
		vertices.clear()
		return
	Audio.play_sound("place")
	construct_shape.rpc(_shape_name(), vertices[-2] - size / 2, Vector3.ZERO, size.abs(), construction_material.resource_path, construction_collision)
	vertices.clear()


static func _is_degenerate(size: Vector3) -> bool:
	return (is_zero_approx(size.x) and is_zero_approx(size.y)) \
		or (is_zero_approx(size.y) and is_zero_approx(size.z)) \
		or (is_zero_approx(size.x) and is_zero_approx(size.z))


func _shape_name() -> String:
	match construction_mode:
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
