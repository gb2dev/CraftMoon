class_name InputDisplay
extends PanelContainer


const INPUT_PROMPT = preload("res://input_prompt.tscn")

@export var vbox: VBoxContainer


func _ready() -> void:
	moon_inputs()


func _process(_delta: float) -> void:
	if not owner:
		return

	var menu: Control = owner.get_node_or_null("%Menu")
	var main_menu: Control = owner.get_node_or_null("%MainMenu")
	var obj_props: Control = owner.get_node_or_null("%ObjectProperties")

	if (menu and menu.visible) or (main_menu and main_menu.visible) or (obj_props and obj_props.visible):
		modulate.a = 0.0
	else:
		modulate.a = 1.0


func moon_inputs() -> void:
	visible = false


func add_input_prompt(action: StringName, custom_text: String = "") -> void:
	var input_prompt := INPUT_PROMPT.instantiate() as InputPrompt
	input_prompt.action = action
	if not custom_text.is_empty():
		input_prompt.text = custom_text
	vbox.add_child(input_prompt)


func clear_input_prompts() -> void:
	get_tree().call_group(&"InputPrompt", &"queue_free")
