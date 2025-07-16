class_name Body
extends Node3D

const LERP_VELOCITY = 0.15

@export_category("Objects")
@export var _character: Character = null
@export var animation_player: AnimationPlayer = null

func apply_rotation(_velocity: Vector3) -> void:
	var new_rotation_y := lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), LERP_VELOCITY)
	rotation.y = new_rotation_y

	var _error := rpc("sync_player_rotation", new_rotation_y)

func animate(_velocity: Vector3) -> void:
	if not _character.is_on_floor():
		if _velocity.y < 0:
			animation_player.play("Fall")
		else:
			animation_player.play("Jump")
		return

	if _velocity:
		if _character.is_running() and _character.is_on_floor():
			animation_player.play("Sprint")
			return

		animation_player.play("Run")
		return

	animation_player.play("Idle")

@rpc("any_peer", "reliable")
func sync_player_rotation(rotation_y: float) -> void:
	rotation.y = rotation_y
