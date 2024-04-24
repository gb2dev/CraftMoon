extends Gadget


@onready var area := $"3D/Area3D" as Area3D
@onready var area_visual := $"3D/Area3D/AreaVisual" as MeshInstance3D
@onready var collision_shape := $"3D/Area3D/CollisionShape3D" as CollisionShape3D

var is_player_detected: bool


func _ready() -> void:
	super._ready()
	change_property(&"ThreeD", false)
	input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, false) and is_player_detected)
	)


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

	if is_input_data_powered(0, false):
		output(0, is_player_detected)


func _on_area_3d_body_exited(_body: Node3D) -> void:
	is_player_detected = false

	if is_input_data_powered(0, false):
		output(0, is_player_detected)
