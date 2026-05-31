extends Node3D


@export var _body: Body

var joypad_look: Vector2
var joypad_look_curve: float = 3.0
var joypad_look_inverted_x: bool = false
var joypad_look_inverted_y: bool = false
var joypad_look_outer_threshold: float = 0.01
var joypad_look_sensitivity_x: float = 1.0
var joypad_look_sensitivity_y: float = 0.7

var mouse_look_inverted_x: bool = false
var mouse_look_inverted_y: bool = false
var mouse_look_sensitivity: float = 1.0
var _look_stick_blocked: bool = false
var _ignore_look_until_slow: bool = false
var _settle_frames_left: int = -1
var _mouse_motion_this_frame: Vector2 = Vector2.ZERO
const MOUSE_SETTLE_THRESHOLD: float = 1.5

@onready var camera := $Camera3D as Camera3D
@onready var player := get_parent() as Character


func _process(_delta: float) -> void:
	if not player.first_person: return
	if player.editor.pie_menu.visible:
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

	if player.editor.is_joypad_modifier_pressed():
		_look_stick_blocked = true
	elif _look_stick_blocked:
		if look_input == Vector2.ZERO:
			_look_stick_blocked = false
	if player.editor.is_joypad_modifier_pressed() or _look_stick_blocked:
		look_input = Vector2.ZERO

	if joypad_look_inverted_x:
		look_input.x *= -1
	if joypad_look_inverted_y:
		look_input.y *= -1

	if abs(look_input.x) > 1 - joypad_look_outer_threshold:
		look_input.x = round(look_input.x)
	joypad_look.x = abs(look_input.x) ** joypad_look_curve * joypad_look_sensitivity_x / 10
	if look_input.x < 0:
		joypad_look.x *= -1

	if abs(look_input.y) > 1 - joypad_look_outer_threshold:
		look_input.y = round(look_input.y)
	joypad_look.y = abs(look_input.y) ** joypad_look_curve * joypad_look_sensitivity_y / 10
	if look_input.y < 0:
		joypad_look.y *= -1

	rotate_y(-joypad_look.x)
	_body.apply_rotation_first_person(global_rotation.y)
	camera.rotate_x(-joypad_look.y)

	# Clamp vertical camera rotation for both mouse and joypad
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)


func _unhandled_input(event: InputEvent) -> void:
	if not player.first_person: return
	if not is_multiplayer_authority():
		return

	if player.editor.pie_menu.visible:
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
