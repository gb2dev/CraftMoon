extends Gadget


@onready var area := $"3D/Area3D" as Area3D
@onready var area_visual := $"3D/Area3D/AreaVisual" as MeshInstance3D
@onready var collision_shape := $"3D/Area3D/CollisionShape3D" as CollisionShape3D


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


func _on_area_3d_body_entered(body: Node3D) -> void:
	if signal_powered:
		output_signal(0, true)


func _on_area_3d_body_exited(body: Node3D) -> void:
	output_signal(0, false)
