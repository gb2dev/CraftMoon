class_name Editor
extends RayCast3D


const SOUND_DESTROY = preload("res://sounds/destroy.wav")
const SOUND_CLICK = preload("res://sounds/click.wav")
const SOUND_PLACE = preload("res://sounds/place.wav")
const HIGHLIGHT_MATERIAL = preload("res://materials/highlight.tres")

@onready var object_properties := %"Object Properties" as ObjectProperties
@onready var input_display := %InputDisplay as InputDisplay

@export var crosshair: TextureRect
@export var cursor: Node3D
@export var material: BaseMaterial3D
@export var audio_player: AudioStreamPlayer
@export var player: Player
@export var shape_select: Control
@export var shape_items: Control

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
var construction_mode: int:
	set(value):
		construction_mode = value
		for shape_item: ShapeItem in shape_items.get_children():
			shape_item.set_selected(construction_mode == shape_item.get_index())
var construction_material := preload("res://materials/bricks/bricks.tres") as BaseMaterial3D
var construction_collision := true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_object_builder_active(false)
	construction_mode = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Object Builder Toggle

	if Input.is_action_just_pressed(&"object_builder"):
		if object_properties.visible:
			object_properties.close()
		else:
			set_object_builder_active(not object_builder_active)

	if not object_builder_active:
		for control: Control in get_tree().get_nodes_in_group(&"UI"):
			if control.visible:
				return

		if Input.is_action_just_pressed(&"properties"):
			if get_collider() is CSGShape3D:
				object_properties.toggle(get_collider())
		elif Input.is_action_just_pressed(&"customize_player"):
			object_properties.toggle(player)

		if get_collider():
			if get_collider() is CSGShape3D:
				highlighted_geometry = get_collider()
				if Input.is_action_just_pressed(&"destroy"):
					if not highlighted_geometry.is_in_group(&"Undeletable"):
						audio_player.stream = SOUND_DESTROY
						audio_player.play()
						highlighted_geometry.queue_free()
				return
		highlighted_geometry = null

		return

	if Input.is_action_just_pressed(&"properties"):
		object_properties.toggle(null)


	# Cursor

	if Input.is_action_just_pressed(&"cursor_forward"):
		cursor_distance -= 0.5
		target_position.z -= 0.5
	elif Input.is_action_just_pressed(&"cursor_back"):
		cursor_distance += 0.5
		target_position.z += 0.5
	cursor_distance = clampf(cursor_distance, -10.5, -0.5)
	target_position.z = clampf(target_position.z, -10.5, -0.5)

	if is_colliding():
		cursor.global_position = get_collision_point()
	else:
		cursor.position = Vector3(0, 0, cursor_distance)

	cursor.global_position = cursor.global_position.snapped(Vector3.ONE)

	Draw3D.line(cursor.global_position, cursor.global_position + Vector3.DOWN * 1000, Color(0, 0.85, 0.85), 1)


	# Object Construction

	for control: Control in get_tree().get_nodes_in_group(&"UI"):
		if control.visible:
			return

	if Input.is_action_just_pressed(&"previous", true):
		construction_mode = wrapi(construction_mode - 1, 0, 6)
	elif Input.is_action_just_pressed(&"next", true):
		construction_mode = wrapi(construction_mode + 1, 0, 6)
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

	match construction_mode:
		# Cuboid Construction
		0:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3
			var pos_3: Vector3
			var pos_4: Vector3
			var pos_5: Vector3
			var pos_6: Vector3

			if construction_stage == 1:
				pos_1 = cursor.global_position
				pos_1.x = vertices[-1].x
				pos_1.z = vertices[-1].z
				pos_2 = cursor.global_position
				pos_2.x = vertices[-1].x
				pos_2.y = vertices[-1].y
				pos_3 = cursor.global_position
				pos_3.y = vertices[-1].y
				pos_3.z = vertices[-1].z
				pos_4 = cursor.global_position
				pos_4.x = vertices[-1].x
				pos_5 = cursor.global_position
				pos_5.y = vertices[-1].y
				pos_6 = cursor.global_position
				pos_6.z = vertices[-1].z

				Draw3D.line(vertices[-1], pos_1, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_2, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_3, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.WHITE, 1)

			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				if construction_stage == 1:
					var size := vertices[-2] - vertices[-1]
					if not (
						is_zero_approx(size.x) and is_zero_approx(size.y)
						or
						is_zero_approx(size.y) and is_zero_approx(size.z)
						or
						is_zero_approx(size.x) and is_zero_approx(size.z)
					):
						audio_player.stream = SOUND_PLACE
						audio_player.play()
						construct_shape("Cuboid", vertices[-2] - size / 2, Vector3.ZERO, size.abs())
					vertices.clear()
				else:
					audio_player.stream = SOUND_CLICK
					audio_player.play()
		# Ellipsoid Construction
		1:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3
			var pos_3: Vector3
			var pos_4: Vector3
			var pos_5: Vector3
			var pos_6: Vector3

			if construction_stage == 1:
				pos_1 = cursor.global_position
				pos_1.x = vertices[-1].x
				pos_1.z = vertices[-1].z
				pos_2 = cursor.global_position
				pos_2.x = vertices[-1].x
				pos_2.y = vertices[-1].y
				pos_3 = cursor.global_position
				pos_3.y = vertices[-1].y
				pos_3.z = vertices[-1].z
				pos_4 = cursor.global_position
				pos_4.x = vertices[-1].x
				pos_5 = cursor.global_position
				pos_5.y = vertices[-1].y
				pos_6 = cursor.global_position
				pos_6.z = vertices[-1].z

				Draw3D.line(vertices[-1], pos_1, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_2, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_3, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.WHITE, 1)

			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				if construction_stage == 1:
					var size := vertices[-2] - vertices[-1]
					if not (
						is_zero_approx(size.x) and is_zero_approx(size.y)
						or
						is_zero_approx(size.y) and is_zero_approx(size.z)
						or
						is_zero_approx(size.x) and is_zero_approx(size.z)
					):
						audio_player.stream = SOUND_PLACE
						audio_player.play()
						construct_shape("Ellipsoid", vertices[-2] - size / 2, Vector3.ZERO, size.abs())
					vertices.clear()
				else:
					audio_player.stream = SOUND_CLICK
					audio_player.play()
		# Cylinder/Cone Construction
		2, 3:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3
			var pos_3: Vector3
			var pos_4: Vector3
			var pos_5: Vector3
			var pos_6: Vector3

			if construction_stage == 1:
				pos_1 = cursor.global_position
				pos_1.x = vertices[-1].x
				pos_1.z = vertices[-1].z
				pos_2 = cursor.global_position
				pos_2.x = vertices[-1].x
				pos_2.y = vertices[-1].y
				pos_3 = cursor.global_position
				pos_3.y = vertices[-1].y
				pos_3.z = vertices[-1].z
				pos_4 = cursor.global_position
				pos_4.x = vertices[-1].x
				pos_5 = cursor.global_position
				pos_5.y = vertices[-1].y
				pos_6 = cursor.global_position
				pos_6.z = vertices[-1].z

				Draw3D.line(vertices[-1], pos_1, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_2, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_3, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.WHITE, 1)

			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				if construction_stage == 1:
					var size := vertices[-2] - vertices[-1]
					if not (
						is_zero_approx(size.x) and is_zero_approx(size.y)
						or
						is_zero_approx(size.y) and is_zero_approx(size.z)
						or
						is_zero_approx(size.x) and is_zero_approx(size.z)
					):
						audio_player.stream = SOUND_PLACE
						audio_player.play()
						construct_shape("Cylinder" if construction_mode == 2 else "Cone", vertices[-2] - size / 2, Vector3.ZERO, size.abs())

					vertices.clear()
				else:
					audio_player.stream = SOUND_CLICK
					audio_player.play()
		# Torus Construction
		4:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3
			var pos_3: Vector3
			var pos_4: Vector3
			var pos_5: Vector3
			var pos_6: Vector3

			if construction_stage == 1:
				pos_1 = cursor.global_position
				pos_1.x = vertices[-1].x
				pos_1.z = vertices[-1].z
				pos_2 = cursor.global_position
				pos_2.x = vertices[-1].x
				pos_2.y = vertices[-1].y
				pos_3 = cursor.global_position
				pos_3.y = vertices[-1].y
				pos_3.z = vertices[-1].z
				pos_4 = cursor.global_position
				pos_4.x = vertices[-1].x
				pos_5 = cursor.global_position
				pos_5.y = vertices[-1].y
				pos_6 = cursor.global_position
				pos_6.z = vertices[-1].z

				Draw3D.line(vertices[-1], pos_1, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_2, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_3, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.WHITE, 1)

			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				if construction_stage == 1:
					var size := vertices[-2] - vertices[-1]
					if not (
						is_zero_approx(size.x) and is_zero_approx(size.y)
						or
						is_zero_approx(size.y) and is_zero_approx(size.z)
						or
						is_zero_approx(size.x) and is_zero_approx(size.z)
					):
						audio_player.stream = SOUND_PLACE
						audio_player.play()
						construct_shape("Torus", vertices[-2] - size / 2, Vector3.ZERO, size.abs())

					vertices.clear()
				else:
					audio_player.stream = SOUND_CLICK
					audio_player.play()
		# Polygon Construction
		5:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3
			var pos_3: Vector3
			var pos_4: Vector3
			var pos_5: Vector3
			var pos_6: Vector3

			if construction_stage == 1:
				pos_1 = cursor.global_position
				pos_1.x = vertices[-1].x
				pos_1.z = vertices[-1].z
				pos_2 = cursor.global_position
				pos_2.x = vertices[-1].x
				pos_2.y = vertices[-1].y
				pos_3 = cursor.global_position
				pos_3.y = vertices[-1].y
				pos_3.z = vertices[-1].z
				pos_4 = cursor.global_position
				pos_4.x = vertices[-1].x
				pos_5 = cursor.global_position
				pos_5.y = vertices[-1].y
				pos_6 = cursor.global_position
				pos_6.z = vertices[-1].z

				Draw3D.line(vertices[-1], pos_1, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_2, Color.WHITE, 1)
				Draw3D.line(vertices[-1], pos_3, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_1, pos_6, Color.WHITE, 1)
				Draw3D.line(pos_2, pos_4, Color.WHITE, 1)
				Draw3D.line(pos_3, pos_5, Color.WHITE, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.WHITE, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.WHITE, 1)

			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				if construction_stage == 1:
					var size := vertices[-2] - vertices[-1]
					if not (
						is_zero_approx(size.x) and is_zero_approx(size.y)
						or
						is_zero_approx(size.y) and is_zero_approx(size.z)
						or
						is_zero_approx(size.x) and is_zero_approx(size.z)
					):
						audio_player.stream = SOUND_PLACE
						audio_player.play()
						construct_shape("Polygon", vertices[-2] - size / 2, Vector3.ZERO, size.abs())
					vertices.clear()
				else:
					audio_player.stream = SOUND_CLICK
					audio_player.play()


func construct_shape(type: String, pos: Vector3, rot: Vector3, size: Vector3) -> CSGShape3D:
	match type:
		"Cuboid":
			var cuboid := CSGBox3D.new()
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(cuboid)
			cuboid.owner = geometry
			cuboid.add_to_group(&"Persist")
			cuboid.position = pos
			cuboid.rotation = rot
			cuboid.size = size
			cuboid.material = construction_material
			cuboid.use_collision = construction_collision
			if cuboid.get_index() == 0:
				cuboid.add_to_group(&"Undeletable")
			return cuboid
		"Ellipsoid":
			var ellipsoid := CSGSphere3D.new()
			ellipsoid.radial_segments = 24
			ellipsoid.rings = 12
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(ellipsoid)
			ellipsoid.owner = geometry
			ellipsoid.add_to_group(&"Persist")
			ellipsoid.position = pos
			ellipsoid.rotation = rot
			ellipsoid.scale = size
			ellipsoid.material = construction_material
			ellipsoid.use_collision = construction_collision
			if ellipsoid.get_index() == 0:
				ellipsoid.add_to_group(&"Undeletable")
			return ellipsoid
		"Cylinder":
			var cylinder := CSGCylinder3D.new()
			cylinder.sides = 16
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(cylinder)
			cylinder.owner = geometry
			cylinder.add_to_group(&"Persist")
			cylinder.position = pos
			cylinder.rotation = rot
			cylinder.radius = size.x / 2
			cylinder.height = size.y
			cylinder.material = construction_material
			cylinder.use_collision = construction_collision
			if cylinder.get_index() == 0:
				cylinder.add_to_group(&"Undeletable")
			return cylinder
		"Cone":
			var cone := CSGCylinder3D.new()
			cone.cone = true
			cone.sides = 16
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(cone)
			cone.owner = geometry
			cone.add_to_group(&"Persist")
			cone.position = pos
			cone.rotation = rot
			cone.radius = size.x / 2
			cone.height = size.y
			cone.material = construction_material
			cone.use_collision = construction_collision
			if cone.get_index() == 0:
				cone.add_to_group(&"Undeletable")
			return cone
		"Torus":
			var torus := CSGTorus3D.new()
			torus.ring_sides = 12
			torus.sides = 16
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(torus)
			torus.owner = geometry
			torus.add_to_group(&"Persist")
			torus.position = pos
			torus.rotation = rot
			torus.scale = size / 2
			torus.material = construction_material
			torus.use_collision = construction_collision
			if torus.get_index() == 0:
				torus.add_to_group(&"Undeletable")
			return torus
		"Polygon":
			var polygon := CSGPolygon3D.new()
			polygon.polygon = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, -0.5)])
			var geometry := get_tree().current_scene.get_node(^"Geometry")
			geometry.add_child(polygon)
			polygon.owner = geometry
			polygon.add_to_group(&"Persist")
			polygon.position = pos
			polygon.position.z += size.z / 2
			polygon.rotation = rot
			polygon.scale = size
			polygon.material = construction_material
			polygon.use_collision = construction_collision
			if polygon.get_index() == 0:
				polygon.add_to_group(&"Undeletable")
			return polygon
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
	crosshair.visible = not object_builder_active
	target_position.z = -2.5 if object_builder_active else -5.0
	highlighted_geometry = null

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


func toggle_ui() -> void:
	crosshair.visible = not crosshair.visible
	input_display.visible = not input_display.visible and (
		process_mode == PROCESS_MODE_INHERIT
		or get_tree().get_first_node_in_group(&"Moon")
	)
	if object_builder_active:
		shape_select.visible = not shape_select.visible
		crosshair.visible = false
