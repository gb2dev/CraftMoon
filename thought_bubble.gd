class_name ThoughtBubble
extends Node3D

@export var bubble_frames: SpriteFrames
@export var content_frames: SpriteFrames
@export var pixel_size: float = 0.0012

var _bubble_sprite: AnimatedSprite3D
var _content_sprite: AnimatedSprite3D

var _current_tool_name: String = ""
var _target_tool_name: String = ""
var _is_hiding: bool = false


func _ready() -> void:
	_bubble_sprite = AnimatedSprite3D.new()
	_bubble_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble_sprite.double_sided = true
	_bubble_sprite.shaded = false
	_bubble_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_bubble_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_bubble_sprite.sorting_offset = 0.0
	_bubble_sprite.pixel_size = pixel_size
	_bubble_sprite.centered = false
	_bubble_sprite.offset = Vector2(0, -256)

	if bubble_frames:
		_bubble_sprite.sprite_frames = bubble_frames
	else:
		var frames := SpriteFrames.new()
		if ResourceLoader.exists("res://icons/thought_bubble.svg"):
			var texture := load("res://icons/thought_bubble.svg")
			frames.add_frame(&"default", texture)
		_bubble_sprite.sprite_frames = frames

	var _err_bubble := _bubble_sprite.animation_finished.connect(_on_bubble_animation_finished)
	add_child(_bubble_sprite)

	_content_sprite = AnimatedSprite3D.new()
	_content_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_content_sprite.double_sided = true
	_content_sprite.shaded = false
	_content_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_content_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_content_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_content_sprite.sorting_offset = 1.0
	_content_sprite.sprite_frames = content_frames
	_content_sprite.pixel_size = pixel_size
	_content_sprite.centered = false
	_content_sprite.offset = Vector2(0, -256)

	var _err_content := _content_sprite.animation_finished.connect(_on_content_animation_finished)
	_bubble_sprite.add_child(_content_sprite)
	
	visible = false


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
	if not _bubble_sprite.sprite_frames:
		_play_content_show()
		return
	if _bubble_sprite.sprite_frames.has_animation(&"show"):
		_bubble_sprite.play(&"show")
	else:
		if _bubble_sprite.sprite_frames.has_animation(&"default"):
			_bubble_sprite.play(&"default")
		_play_content_show()


func _play_bubble_hide() -> void:
	if not _bubble_sprite.sprite_frames:
		visible = false
		return
	if _bubble_sprite.sprite_frames.has_animation(&"hide"):
		_bubble_sprite.play(&"hide")
	else:
		visible = false


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


func _on_bubble_animation_finished() -> void:
	if _bubble_sprite.animation == &"show":
		if _bubble_sprite.sprite_frames.has_animation(&"default"):
			_bubble_sprite.play(&"default")
		elif _bubble_sprite.sprite_frames.has_animation(&"idle"):
			_bubble_sprite.play(&"idle")
		_play_content_show()
	elif _bubble_sprite.animation == &"hide":
		visible = false


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
		if not _bubble_sprite.sprite_frames or not _bubble_sprite.sprite_frames.has_animation(&"hide"):
			visible = false
