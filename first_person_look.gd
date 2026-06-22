extends Node3D


@export var _body: Body

var joypad_look_curve: float = 3.0
var joypad_look_inverted_x: bool = false
var joypad_look_inverted_y: bool = false
var joypad_look_outer_threshold: float = 0.01
var joypad_look_sensitivity_x: float = 0.2
var joypad_look_sensitivity_y: float = 0.14

var mouse_look_inverted_x: bool = false
var mouse_look_inverted_y: bool = false
var mouse_look_sensitivity: float = 1.0
var _ignore_look_until_slow: bool = false
var _settle_frames_left: int = -1
var _mouse_motion_this_frame: Vector2 = Vector2.ZERO
const MOUSE_SETTLE_THRESHOLD: float = 1.5

@onready var camera := $Camera3D as Camera3D
@onready var player := get_parent() as Character


func _process(_delta: float) -> void:
	if not player.first_person: return
	if player.is_look_blocked():
		return

	var look_input := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")

	if _ignore_look_until_slow:
		var mouse_speed := _mouse_motion_this_frame.length()
		var stick_released := look_input.length() < 0.1
		var mouse_slow := mouse_speed < MOUSE_SETTLE_THRESHOLD

		if stick_released and mouse_slow:
			if _settle_frames_left <= 0:
				_settle_frames_left = 3
			_settle_frames_left -= 1
			if _settle_frames_left == 0:
				_ignore_look_until_slow = false
		else:
			_settle_frames_left = -1

		_mouse_motion_this_frame = Vector2.ZERO
		return

	if joypad_look_inverted_x:
		look_input.x *= -1
	if joypad_look_inverted_y:
		look_input.y *= -1

	if JoypadLook.update_block_state(player.editor.is_joypad_modifier_pressed(), look_input):
		look_input = Vector2.ZERO

	var look := JoypadLook.calculate(look_input, joypad_look_curve, joypad_look_sensitivity_x, joypad_look_sensitivity_y, joypad_look_outer_threshold)

	rotate_y(-look.x)
	_body.apply_rotation_first_person(global_rotation.y)
	camera.rotate_x(-look.y)

	# Clamp vertical camera rotation for joypad look
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)


func _unhandled_input(event: InputEvent) -> void:
	if not player.first_person: return
	if not is_multiplayer_authority():
		return

	if player.is_look_blocked():
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion:
		if _ignore_look_until_slow:
			_mouse_motion_this_frame += mouse_motion.relative
			return
		
		if DisplayServer.mouse_get_mode() != DisplayServer.MOUSE_MODE_CAPTURED:
			return
		
		var input := mouse_motion.relative
		if mouse_look_inverted_x:
			input.x *= -1
		if mouse_look_inverted_y:
			input.y *= -1

		var look_delta := Vector3(-input.x, 0, -input.y) * mouse_look_sensitivity / 500

		rotate_y(look_delta.x)
		_body.apply_rotation_first_person(global_rotation.y)
		camera.rotate_x(look_delta.z)
