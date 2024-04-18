extends RayCast3D


const SOUND_DESTROY = preload("res://sounds/destroy.wav")
const SOUND_POPUP = preload("res://sounds/popup.wav")
const HIGHLIGHT_MATERIAL = preload("res://materials/highlight.tres")

@onready var object_properties := %"Object Properties" as ObjectProperties
@onready var input_display := %InputDisplay as InputDisplay

@export var crosshair: TextureRect
@export var cursor: Node3D
@export var material: BaseMaterial3D
@export var audio_player: AudioStreamPlayer

var object_builder_active := false
var highlighted_geometry: GeometryInstance3D:
	set(value):
		if highlighted_geometry != value:
			if highlighted_geometry:
				highlighted_geometry.material_overlay = null
			if value:
				value.material_overlay = HIGHLIGHT_MATERIAL
			highlighted_geometry = value
var cursor_distance := -2.5
var vertices: Array[Vector3]
var st: SurfaceTool
var mi: MeshInstance3D
var construction_mode: int

var current_edge_left: Vector3
var current_edge_right: Vector3
var edge_node: Node3D
var height: int
var mouse_y_delta: float


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	new_object()
	set_object_builder_active(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Object Builder Toggle

	if Input.is_action_just_pressed(&"object_builder"):
		set_object_builder_active(not object_builder_active)

	if not object_builder_active:
		if Input.is_action_just_pressed(&"properties"):
			for control: Control in get_tree().get_nodes_in_group(&"UI"):
				if control.visible:
					return

			if get_collider() is CSGShape3D:
				audio_player.stream = SOUND_POPUP
				audio_player.play()
				object_properties.toggle(get_collider())

		for control: Control in get_tree().get_nodes_in_group(&"UI"):
			if control.visible:
				return

		if get_collider():
			if get_collider() is CSGShape3D:
				highlighted_geometry = get_collider()
				if Input.is_action_just_pressed(&"destroy"):
					audio_player.stream = SOUND_DESTROY
					audio_player.play()
					highlighted_geometry.queue_free()
				return
		highlighted_geometry = null

		return


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

	if Input.is_action_just_pressed(&"1"):
		construction_mode = 0
	elif Input.is_action_just_pressed(&"2"):
		construction_mode = 1
	elif Input.is_action_just_pressed(&"3"):
		construction_mode = 2

	match construction_mode:
		# Triangle Construction
		0:
			var construction_stage := vertices.size() % 3

			if construction_stage > 0:
				Draw3D.line(vertices[-construction_stage], cursor.global_position, Color.BLACK, 1)

				if construction_stage == 2:
					Draw3D.line(vertices[-1], vertices[-2], Color.BLACK, 1)
					Draw3D.line(vertices[-1], cursor.global_position, Color.BLACK, 1)

			if Input.is_action_just_pressed(&"action"):
				vertices.append(cursor.global_position)
				st.add_vertex(cursor.global_position)

				if not vertices.is_empty():
					if construction_stage == 2:
						st.generate_normals()
						mi.mesh = st.commit()
						mi.set_surface_override_material(0, material)

		# Quad Construction
		1:
			var construction_stage := vertices.size() % 3

			var pos_1: Vector3
			var pos_2: Vector3

			if construction_stage == 1:
				if is_equal_approx(cursor.global_position.y, vertices[-1].y):
					pos_1 = cursor.global_position
					pos_1.z = vertices[-1].z
					pos_2 = cursor.global_position
					pos_2.x = vertices[-1].x
				else:
					pos_1 = cursor.global_position
					pos_1.y = vertices[-1].y
					pos_2 = cursor.global_position
					pos_2.z = vertices[-1].z
					pos_2.x = vertices[-1].x

				Draw3D.line(vertices[-1], pos_1, Color.BLACK, 1)
				Draw3D.line(vertices[-1], pos_2, Color.BLACK, 1)
				Draw3D.line(pos_1, cursor.global_position, Color.BLACK, 1)
				Draw3D.line(pos_2, cursor.global_position, Color.BLACK, 1)

			if Input.is_action_just_pressed(&"action"):
				if construction_stage == 1:
					vertices.append(pos_1)
					st.add_vertex(pos_1)

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					vertices.append(vertices[-3])
					st.add_vertex(vertices[-4])

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					vertices.append(pos_2)
					st.add_vertex(pos_2)

					st.generate_normals()

					mi.mesh = st.commit()
					mi.set_surface_override_material(0, material)
				else:
					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

		# Box Construction
		2:
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

				Draw3D.line(vertices[-1], pos_1, Color.BLACK, 1)
				Draw3D.line(vertices[-1], pos_2, Color.BLACK, 1)
				Draw3D.line(vertices[-1], pos_3, Color.BLACK, 1)
				Draw3D.line(pos_1, pos_4, Color.BLACK, 1)
				Draw3D.line(pos_2, pos_5, Color.BLACK, 1)
				Draw3D.line(pos_3, pos_6, Color.BLACK, 1)
				Draw3D.line(pos_1, pos_6, Color.BLACK, 1)
				Draw3D.line(pos_2, pos_4, Color.BLACK, 1)
				Draw3D.line(pos_3, pos_5, Color.BLACK, 1)
				Draw3D.line(pos_4, cursor.global_position, Color.BLACK, 1)
				Draw3D.line(pos_5, cursor.global_position, Color.BLACK, 1)
				Draw3D.line(pos_6, cursor.global_position, Color.BLACK, 1)

			if Input.is_action_just_pressed(&"action"):
				if construction_stage == 1:
					# Back 1

					vertices.append(pos_1)
					st.add_vertex(pos_1)

					vertices.append(pos_6)
					st.add_vertex(pos_6)

					# Back 2

					vertices.append(pos_3)
					st.add_vertex(pos_3)

					vertices.append(vertices[-4])
					st.add_vertex(vertices[-5])

					vertices.append(pos_6)
					st.add_vertex(pos_6)

					# Left 1

					vertices.append(pos_3)
					st.add_vertex(pos_3)

					vertices.append(pos_5)
					st.add_vertex(pos_5)

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					# Left 2

					vertices.append(pos_6)
					st.add_vertex(pos_6)

					vertices.append(pos_3)
					st.add_vertex(pos_3)

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					# Right 1

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					vertices.append(vertices[-13])
					st.add_vertex(vertices[-14])

					vertices.append(pos_1)
					st.add_vertex(pos_1)

					# Right 2

					vertices.append(pos_2)
					st.add_vertex(pos_2)

					vertices.append(vertices[-16])
					st.add_vertex(vertices[-17])

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					# Bottom 1

					vertices.append(pos_2)
					st.add_vertex(pos_2)

					vertices.append(vertices[-19])
					st.add_vertex(vertices[-20])

					vertices.append(pos_5)
					st.add_vertex(pos_5)

					# Bottom 2

					vertices.append(pos_5)
					st.add_vertex(pos_5)

					vertices.append(vertices[-22])
					st.add_vertex(vertices[-23])

					vertices.append(pos_3)
					st.add_vertex(pos_3)

					# Top 1

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					vertices.append(pos_1)
					st.add_vertex(pos_1)

					vertices.append(pos_6)
					st.add_vertex(pos_6)

					# Top 2

					vertices.append(pos_6)
					st.add_vertex(pos_6)

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					# Front 1

					vertices.append(pos_2)
					st.add_vertex(pos_2)

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					vertices.append(pos_5)
					st.add_vertex(pos_5)

					# Front 2

					vertices.append(pos_4)
					st.add_vertex(pos_4)

					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)

					vertices.append(pos_5)
					st.add_vertex(pos_5)

					st.generate_normals()

					mi.mesh = st.commit()
					mi.set_surface_override_material(0, material)
				else:
					vertices.append(cursor.global_position)
					st.add_vertex(cursor.global_position)


	# Collision Creation

	if Input.is_action_just_pressed(&"ui_accept"):
		mi.create_convex_collision()
		vertices = []
		new_object()


func get_nearest_node(nodes: Array[Node], pos: Vector3) -> Node3D:
	nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return nodes[0]


func new_object() -> void:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	mi = MeshInstance3D.new()
	get_tree().current_scene.add_child.call_deferred(mi)


func set_object_builder_active(value: bool) -> void:
	object_builder_active = value
	cursor.visible = object_builder_active
	crosshair.visible = not object_builder_active
	target_position.z = -2.5 if object_builder_active else -5
	highlighted_geometry = null

	input_display.clear_input_prompts()
	if object_builder_active:
		input_display.add_input_prompt(&"1", tr(&"Triangle"))
		input_display.add_input_prompt(&"2", tr(&"Rectangle"))
		input_display.add_input_prompt(&"3", tr(&"Cuboid"))
	else:
		input_display.add_input_prompt(&"ui_cancel", tr(&"Pause Menu"))
		input_display.add_input_prompt(&"customize_player")
		input_display.add_input_prompt(&"object_builder")
		input_display.add_input_prompt(&"properties")
		input_display.add_input_prompt(&"destroy")
