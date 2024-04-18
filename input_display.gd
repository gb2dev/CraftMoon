class_name InputDisplay
extends Control


const INPUT_PROMPT = preload("res://input_prompt.tscn")

@export var hbox: HBoxContainer


func add_input_prompt(action: StringName, custom_text: String = "") -> void:
	var input_prompt := INPUT_PROMPT.instantiate() as InputPrompt
	input_prompt.action = action
	if not custom_text.is_empty():
		input_prompt.text = custom_text
	hbox.add_child(input_prompt)


func clear_input_prompts() -> void:
	get_tree().call_group(&"InputPrompt", &"queue_free")
