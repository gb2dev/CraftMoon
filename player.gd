class_name Character
extends CharacterBody3D


const NORMAL_SPEED = 6.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 10
const DOUBLETAP_DELAY = 0.35

@export_category("Objects")
@export var _body: Body = null
@export var _spring_arm_offset: Node3D = null
@export var editor: Editor
@export var crosshair: TextureRect
@export var meshes: Node3D

var camera: Camera3D
var first_person: bool:
	set(value):
		first_person = value
		crosshair.visible = value
		meshes.visible = not value
		_set_current_camera()
		_update_thought_bubble()
var fly := false
var doubletap_time := DOUBLETAP_DELAY

var thought_bubble: ThoughtBubble
@export var thought_bubble_base_frames: SpriteFrames
@export var thought_bubble_content_frames: SpriteFrames
@export var synced_thought: String = "":
	set(value):
		synced_thought = value
		_update_thought_bubble()

@onready var nickname: Label3D = $PlayerNick/Nickname
@onready var body: MeshInstance3D = $"3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head"
@onready var pivot: Node3D = $Pivot
@onready var color_picker := get_tree().current_scene.get_node("%ColorPickerButton") as ColorPickerButton

var _current_speed: float
var _respawn_point := Vector3(0, 5, 0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

	_set_current_camera()
	var _error := Signals.level_select_closed.connect(_set_current_camera)
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func _ready() -> void:
	thought_bubble = preload("res://thought_bubble.gd").new()
	thought_bubble.bubble_frames = thought_bubble_base_frames
	thought_bubble.content_frames = thought_bubble_content_frames
	add_child(thought_bubble)
	thought_bubble.position = Vector3(0, 2.0, 0)
	_update_thought_bubble()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return

	if editor and editor.pie_menu.visible:
		freeze()
		return

	var world := get_tree().get_current_scene() as World
	if world and world.is_chat_visible() and is_on_floor():
		freeze()
		return

	doubletap_time -= delta
	if Input.is_action_just_pressed(&"jump") and editor.process_mode == PROCESS_MODE_INHERIT and not Menu.shown:
		if doubletap_time >= 0:
			fly = not fly
		else:
			doubletap_time = DOUBLETAP_DELAY

	if not is_on_floor() and not fly:
		velocity.y -= gravity * delta
		_body.animate(velocity)

	if is_on_floor() and not Menu.shown:
		if Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= gravity * delta

	if fly:
		if Input.is_action_pressed(&"jump") and not Menu.shown:
			velocity.y = JUMP_VELOCITY
		elif Input.is_action_pressed(&"crouch") and not Menu.shown:
			velocity.y = -JUMP_VELOCITY
		else:
			velocity.y = 0

	_move()
	var _collided := move_and_slide()
	_body.animate(velocity)


func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()


func freeze() -> void:
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_body.animate(Vector3.ZERO)


func _move() -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority() and not Menu.shown and not (editor and editor.pie_menu.visible):
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_back"
			)

	var _direction: Vector3 = transform.basis * Vector3(_input_direction.x, 0, _input_direction.y).normalized()

	var _is_running := is_running()
	if first_person:
		_direction = _direction.rotated(Vector3.UP, pivot.rotation.y)
	else:
		_direction = _direction.rotated(Vector3.UP, _spring_arm_offset.rotation.y)

	if _direction:
		velocity.x = _direction.x * _current_speed
		velocity.z = _direction.z * _current_speed
		if not first_person:
			_body.apply_rotation(velocity)
		return

	velocity.x = move_toward(velocity.x, 0, _current_speed)
	velocity.z = move_toward(velocity.z, 0, _current_speed)


func is_running() -> bool:
	if Input.is_action_pressed("sprint"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false


func _check_fall_and_respawn() -> void:
	if global_transform.origin.y < -15.0:
		_respawn()


func _respawn() -> void:
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO


func _set_current_camera() -> void:
	if camera:
		camera.current = false
	if first_person:
		camera = $Pivot/Camera3D
	else:
		camera = $SpringArmOffset/SpringArm3D/Camera3D
	camera.current = is_multiplayer_authority()


@rpc("any_peer", "call_local", "reliable")
func change_nick(new_nick: String) -> void:
	if nickname:
		nickname.text = new_nick


@rpc("any_peer", "call_local", "reliable")
func set_player_skin(color: Color) -> void:
	if multiplayer.get_unique_id() == multiplayer.get_remote_sender_id():
		color_picker.color = color
	var material := body.get_surface_override_material(0) as ShaderMaterial
	if material:
		material.set_shader_parameter("tint_color", color)


func _update_thought_bubble() -> void:
	if not thought_bubble:
		return
	if synced_thought.is_empty():
		thought_bubble.hide_thought()
	else:
		if is_multiplayer_authority() and first_person:
			thought_bubble.hide_thought()
		else:
			thought_bubble.show_thought(synced_thought)
