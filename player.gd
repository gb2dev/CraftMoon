class_name Player
extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const DOUBLETAP_DELAY = 0.25

@export var pivot: Node3D
@export var camera: Camera3D
@export var editor: Editor

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

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var fly := false

var doubletap_time := DOUBLETAP_DELAY


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	camera.current = is_multiplayer_authority()


func _process(_delta: float) -> void:
	var look_input := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")

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

	pivot.rotate_y(-joypad_look.x)
	camera.rotate_x(-joypad_look.y)

	# Clamp vertical camera rotation for both mouse and joypad
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	doubletap_time -= delta

	if Input.is_action_just_pressed(&"jump"):
		if doubletap_time >= 0:
			fly = not fly
		else:
			doubletap_time = DOUBLETAP_DELAY

	# Add the gravity.
	if not is_on_floor() and not fly:
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if fly:
		if Input.is_action_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY
		elif Input.is_action_pressed(&"crouch"):
			velocity.y = -JUMP_VELOCITY
		else:
			velocity.y = 0

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var pivot_basis := pivot.transform.basis as Basis
	var direction := (pivot_basis * Vector3(input_dir.x, 0, input_dir.y)).clamp(
		-Vector3.ONE,
		Vector3.ONE
	)
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion and DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
		var input := event.relative as Vector2
		if mouse_look_inverted_x:
			input.x *= -1
		if mouse_look_inverted_y:
			input.y *= -1

		var look_delta := Vector3(-input.x, 0, -input.y) * mouse_look_sensitivity / 500

		pivot.rotate_y(look_delta.x)
		camera.rotate_x(look_delta.z)
