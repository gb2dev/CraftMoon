class_name ThoughtBubble
extends Node3D

const DOT_TEXTURE_PATH := "res://textures/thought_bubble/bubble_%s_%d.png"
const DOT_FRAME_COUNT := 7
const STEP_TIME := 1.0 / 12.0
const DOTS: Array[Dictionary] = [
	{"name": "small", "position": Vector2(40, 30)},
	{"name": "medium", "position": Vector2(105, 95)},
	{"name": "large", "position": Vector2(185, 175)},
]
const CLOUD_POSITION := Vector2(470, 440)
const CONTENT_ART_OFFSET := Vector2(48, 64)

@export var bubble_frames: SpriteFrames
@export var content_frames: SpriteFrames
@export var pixel_size: float = 0.0012
@export var content_scale: float = 0.75

var _dot_sprites: Array[AnimatedSprite3D] = []
var _cloud_sprite: AnimatedSprite3D
var _content_sprite: AnimatedSprite3D

var _current_tool_name: String = ""
var _target_tool_name: String = ""
var _is_hiding: bool = false
var _sequence := 0


func _ready() -> void:
	for dot: Dictionary in DOTS:
		_dot_sprites.append(_create_sprite(_create_dot_frames(dot["name"]), pixel_size, dot["position"]))
	_cloud_sprite = _create_sprite(bubble_frames, pixel_size, CLOUD_POSITION)
	for sprite: AnimatedSprite3D in _bubble_sprites():
		var _err := sprite.animation_finished.connect(_on_piece_animation_finished.bind(sprite))

	_content_sprite = _create_sprite(content_frames, pixel_size * content_scale, CLOUD_POSITION / content_scale - CONTENT_ART_OFFSET)
	_content_sprite.sorting_offset = 1.0
	var _err_content := _content_sprite.animation_finished.connect(_on_content_animation_finished)

	visible = false


func _create_sprite(frames: SpriteFrames, size: float, sprite_offset: Vector2) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.double_sided = true
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.pixel_size = size
	sprite.offset = sprite_offset
	sprite.sprite_frames = frames
	sprite.visible = false
	add_child(sprite)
	return sprite


func _create_dot_frames(dot_name: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default", true)
	frames.set_animation_speed(&"default", 8.0)
	for i in range(2, DOT_FRAME_COUNT + 1):
		frames.add_frame(&"default", load(DOT_TEXTURE_PATH % [dot_name, i]) as Texture2D)
	var pop_texture := load(DOT_TEXTURE_PATH % [dot_name, 1]) as Texture2D
	for anim: StringName in [&"show", &"hide"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 12.0)
		frames.add_frame(anim, pop_texture)
	return frames


func _bubble_sprites() -> Array[AnimatedSprite3D]:
	var sprites := _dot_sprites.duplicate()
	sprites.append(_cloud_sprite)
	return sprites


func show_thought(tool_name: String) -> void:
	if visible and not _is_hiding:
		if _current_tool_name == tool_name:
			return
		_target_tool_name = tool_name
		_play_content_hide()
		return

	visible = true
	_is_hiding = false
	_current_tool_name = tool_name
	_target_tool_name = ""
	_content_sprite.visible = false

	_play_bubble_show()


func hide_thought() -> void:
	if not visible or _is_hiding:
		return
	_is_hiding = true
	_target_tool_name = ""

	_play_bubble_hide()
	_play_content_hide()


func _play_bubble_show() -> void:
	_sequence += 1
	var sequence := _sequence
	for sprite: AnimatedSprite3D in _bubble_sprites():
		sprite.visible = false
	for sprite: AnimatedSprite3D in _bubble_sprites():
		_play_piece(sprite, &"show")
		await get_tree().create_timer(STEP_TIME).timeout
		if sequence != _sequence:
			return
	if _cloud_sprite.is_playing() and _cloud_sprite.animation == &"show":
		await _cloud_sprite.animation_finished
		if sequence != _sequence:
			return
	_play_content_show()


func _play_bubble_hide() -> void:
	_sequence += 1
	var sequence := _sequence
	var sprites := _bubble_sprites()
	sprites.reverse()
	for sprite: AnimatedSprite3D in sprites:
		_play_piece(sprite, &"hide")
		await get_tree().create_timer(STEP_TIME).timeout
		if sequence != _sequence:
			return
	visible = false


func _play_piece(sprite: AnimatedSprite3D, anim: StringName) -> void:
	var frames := sprite.sprite_frames
	if not frames:
		sprite.visible = false
		return
	if anim == &"hide" and not frames.has_animation(anim):
		sprite.visible = false
		return
	sprite.visible = true
	if frames.has_animation(anim):
		sprite.play(anim)
	elif frames.has_animation(&"default"):
		sprite.play(&"default")


func _on_piece_animation_finished(sprite: AnimatedSprite3D) -> void:
	if sprite.animation == &"show":
		if sprite.sprite_frames.has_animation(&"default"):
			sprite.play(&"default")
	elif sprite.animation == &"hide":
		sprite.visible = false


func _play_content_show() -> void:
	if not _content_sprite.sprite_frames:
		_content_sprite.visible = false
		return
	var show_anim: String = _current_tool_name + "_show"
	if _content_sprite.sprite_frames.has_animation(show_anim) and _content_sprite.sprite_frames.get_frame_count(show_anim) > 0:
		_content_sprite.visible = true
		_content_sprite.play(show_anim)
	elif _content_sprite.sprite_frames.has_animation(&"show") and _content_sprite.sprite_frames.get_frame_count(&"show") > 0:
		_content_sprite.visible = true
		_content_sprite.play(&"show")
	else:
		_play_content_loop()


func _play_content_loop() -> void:
	if not _content_sprite.sprite_frames:
		_content_sprite.visible = false
		return
	var loop_anim: String = _current_tool_name
	if _content_sprite.sprite_frames.has_animation(loop_anim) and _content_sprite.sprite_frames.get_frame_count(loop_anim) > 0:
		_content_sprite.visible = true
		_content_sprite.play(loop_anim)
	else:
		_content_sprite.visible = false
		_content_sprite.stop()


func _play_content_hide() -> void:
	if not _content_sprite.sprite_frames or not _content_sprite.visible:
		_on_content_hidden()
		return
	var hide_anim: String = _current_tool_name + "_hide"
	if _content_sprite.sprite_frames.has_animation(hide_anim) and _content_sprite.sprite_frames.get_frame_count(hide_anim) > 0:
		_content_sprite.play(hide_anim)
	elif _content_sprite.sprite_frames.has_animation(&"hide") and _content_sprite.sprite_frames.get_frame_count(&"hide") > 0:
		_content_sprite.play(&"hide")
	else:
		_on_content_hidden()


func _on_content_animation_finished() -> void:
	var anim: StringName = _content_sprite.animation
	if anim.ends_with("_show") or anim == &"show":
		_play_content_loop()
	elif anim.ends_with("_hide") or anim == &"hide":
		_on_content_hidden()


func _on_content_hidden() -> void:
	if not _target_tool_name.is_empty():
		_current_tool_name = _target_tool_name
		_target_tool_name = ""
		_play_content_show()
	elif _is_hiding:
		_content_sprite.visible = false
