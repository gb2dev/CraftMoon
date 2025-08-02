extends Gadget


const AREA_MATERIAL = preload("res://materials/area.tres")

var area: Area3D
var area_visual: MeshInstance3D
var collision_shape: CollisionShape3D
var is_player_detected: bool:
	set(value):
		is_player_detected = value
		if is_input_data_powered(0, true):
			if World.time_paused:
				await Signals.time_played
				output(0, is_player_detected)
			else:
				output(0, is_player_detected)


func start() -> void:
	var _error := Signals.time_rewound.connect(_on_time_rewound)

	area = Area3D.new()
	area.scale = Vector3.ONE * 2
	area.collision_layer = 0
	area.collision_mask = 2
	_error = area.body_entered.connect(_on_area_3d_body_entered)
	_error = area.body_exited.connect(_on_area_3d_body_exited)
	node_3d.add_child(area)

	area_visual = MeshInstance3D.new()
	area_visual.material_override = AREA_MATERIAL
	area_visual.visible = false
	area.add_child(area_visual)

	collision_shape = CollisionShape3D.new()
	area.add_child(collision_shape)

	change_property(&"ZoneShape", 0) # Initialize with sphere shape

	_error = input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, true) and is_player_detected)
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"ZoneShape":
			match value:
				0:
					collision_shape.shape = SphereShape3D.new()
					area_visual.mesh = SphereMesh.new()
				1:
					collision_shape.shape = BoxShape3D.new()
					area_visual.mesh = BoxMesh.new()
		&"ZoneWidth":
			area.scale.x = value
		&"ZoneHeight":
			area.scale.y = value
		&"ZoneDepth":
			area.scale.z = value


func _on_area_3d_body_entered(_body: Node3D) -> void:
	is_player_detected = true


func _on_area_3d_body_exited(_body: Node3D) -> void:
	is_player_detected = false


func _on_time_rewound() -> void:
	output(0, false)
	is_player_detected = area.has_overlapping_bodies()
