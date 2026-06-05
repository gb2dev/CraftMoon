class_name JoypadLook
extends RefCounted


static var _look_stick_blocked: bool = false


static func update_block_state(is_modifier_pressed: bool, look_input: Vector2) -> bool:
	if is_modifier_pressed:
		_look_stick_blocked = true
	elif _look_stick_blocked and look_input == Vector2.ZERO:
		_look_stick_blocked = false
	return _look_stick_blocked or is_modifier_pressed


static func calculate(input: Vector2, curve: float, sens_x: float, sens_y: float, outer_threshold: float) -> Vector2:
	var result := Vector2.ZERO

	if abs(input.x) > 1 - outer_threshold:
		input.x = round(input.x)
	result.x = abs(input.x) ** curve * sens_x / 10
	if input.x < 0:
		result.x *= -1

	if abs(input.y) > 1 - outer_threshold:
		input.y = round(input.y)
	result.y = abs(input.y) ** curve * sens_y / 10
	if input.y < 0:
		result.y *= -1

	return result
