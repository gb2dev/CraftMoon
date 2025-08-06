class_name Notification
extends Control


const DEFAULT_TIMEOUT = 3.0

@export var icon: TextureRect
@export var text: Label
@export var timer: Timer
@export var hbox: HBoxContainer


func set_icon(value: Texture2D) -> void:
	icon.texture = value
	if icon.texture:
		hbox.add_theme_constant_override(&"separation", 4)


func set_text(value: String) -> void:
	text.text = value


func set_timeout(value: float) -> void:
	timer.wait_time = value
