class_name Player
extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const DOUBLETAP_DELAY = 0.25

@export var pivot: Node3D
@export var camera: Camera3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var fly := false

var doubletap_time = DOUBLETAP_DELAY
var last_keycode = 0


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	camera.current = is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	doubletap_time -= delta

	# Add the gravity.
	if not is_on_floor() and not fly:
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if fly:
		if Input.is_action_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = 0

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var pivot_basis := pivot.transform.basis as Basis
	var direction := (pivot_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
		pivot.rotate_y(-mouse_motion.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-mouse_motion.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2, PI / 2)

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if last_keycode == event.keycode and doubletap_time >= 0: 
			if event.keycode == 32:
				fly = not fly
			last_keycode = 0
		else:
			last_keycode = event.keycode
		doubletap_time = DOUBLETAP_DELAY
