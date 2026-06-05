extends Node3D
class_name SpringArmCharacter


const MOUSE_SENSIBILITY: float = 0.005

@export_category("Objects")
@export var _spring_arm: SpringArm3D = null

var joypad_look_curve: float = 2.0
var joypad_look_sensitivity_x: float = 0.3
var joypad_look_sensitivity_y: float = 0.3
var joypad_look_outer_threshold: float = 0.01
var joypad_look_inverted_x: bool = false
var joypad_look_inverted_y: bool = false
var mouse_look_inverted_x: bool = false
var mouse_look_inverted_y: bool = false

@onready var player := get_parent() as Character


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if player.is_look_blocked():
		return

	var look_input := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")

	if joypad_look_inverted_x:
		look_input.x *= -1
	if joypad_look_inverted_y:
		look_input.y *= -1

	if JoypadLook.update_block_state(player.editor.is_joypad_modifier_pressed(), look_input):
		look_input = Vector2.ZERO

	var look := JoypadLook.calculate(look_input, joypad_look_curve, joypad_look_sensitivity_x, joypad_look_sensitivity_y, joypad_look_outer_threshold)

	rotate_y(look.x)
	_spring_arm.rotate_x(look.y)
	_spring_arm.rotation.x = clamp(_spring_arm.rotation.x, -PI/2, PI/3)


func _unhandled_input(event: InputEvent) -> void:
	if player.is_look_blocked():
		return

	var event_mouse_motion := event as InputEventMouseMotion
	if event_mouse_motion and is_multiplayer_authority():
		var input := event_mouse_motion.relative
		if mouse_look_inverted_x:
			input.x *= -1
		if mouse_look_inverted_y:
			input.y *= -1
		rotate_y(-input.x * MOUSE_SENSIBILITY)
		_spring_arm.rotate_x(-input.y * MOUSE_SENSIBILITY)
		_spring_arm.rotation.x = clamp(_spring_arm.rotation.x, -PI/2, PI/3)
