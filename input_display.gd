class_name InputDisplay
extends Control


const INPUT_PROMPT = preload("res://input_prompt.tscn")
const EDGE_SPACING := 20
const COL_SPACING := 8

var category_boxes: Dictionary = {}
var _left_col: VBoxContainer
var _right_col: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_left_col = _make_col()
	_left_col.anchor_left = 0.0
	_left_col.anchor_right = 0.0
	_left_col.anchor_top = 1.0
	_left_col.anchor_bottom = 1.0
	_left_col.offset_left = EDGE_SPACING
	_left_col.offset_right = EDGE_SPACING
	_left_col.offset_bottom = -EDGE_SPACING
	_left_col.grow_horizontal = Control.GROW_DIRECTION_END
	_left_col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_left_col)

	_right_col = _make_col()
	_right_col.anchor_left = 1.0
	_right_col.anchor_right = 1.0
	_right_col.anchor_top = 1.0
	_right_col.anchor_bottom = 1.0
	_right_col.offset_left = -EDGE_SPACING
	_right_col.offset_right = -EDGE_SPACING
	_right_col.offset_bottom = -EDGE_SPACING
	_right_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right_col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_right_col)

	moon_inputs()


func _make_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", COL_SPACING)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col


func _process(_delta: float) -> void:
	if not owner:
		return

	var menu: Control = owner.get_node_or_null("%Menu")
	var main_menu: Control = owner.get_node_or_null("%MainMenu")
	var obj_props: Control = owner.get_node_or_null("%ObjectProperties")
	var menus_visible := (menu and menu.visible) \
		or (main_menu and main_menu.visible) \
		or (obj_props and obj_props.visible)
	modulate.a = 0.0 if menus_visible else 1.0


func moon_inputs() -> void:
	visible = false


func add_input_prompt(
	actions: Array[StringName],
	category: StringName,
	custom_text: String = "",
	other_side := false,
	has_joypad_modifier := false
) -> void:
	var input_prompt := INPUT_PROMPT.instantiate() as InputPrompt
	if category.ends_with("_keyboard"):
		category = category.trim_suffix("_keyboard")
		input_prompt.supported_inputs = InputPrompt.SupportedInputs.KBM_ONLY
	elif category.ends_with("_joypad"):
		category = category.trim_suffix("_joypad")
		input_prompt.supported_inputs = InputPrompt.SupportedInputs.JOYPAD_ONLY
	input_prompt.actions = actions
	input_prompt.has_joypad_modifier = has_joypad_modifier

	var target_vbox: VBoxContainer = category_boxes.get(category)
	if not target_vbox:
		var panel_container := PanelContainer.new()
		var margin_container := MarginContainer.new()
		margin_container.add_theme_constant_override(&"margin_left", 8)
		margin_container.add_theme_constant_override(&"margin_top", 8)
		margin_container.add_theme_constant_override(&"margin_right", 8)
		margin_container.add_theme_constant_override(&"margin_bottom", 8)

		target_vbox = VBoxContainer.new()
		target_vbox.add_theme_constant_override(&"separation", 6)

		var category_label := Label.new()
		category_label.text = tr(category).to_upper()
		category_label.add_theme_font_size_override(&"font_size", 13)
		category_label.modulate.a = 0.6

		target_vbox.add_child(category_label)
		margin_container.add_child(target_vbox)
		panel_container.add_child(margin_container)

		var column := _right_col if other_side else _left_col
		column.add_child(panel_container)
		column.move_child(panel_container, 0)

		category_boxes[category] = target_vbox

	if not custom_text.is_empty():
		input_prompt.text = tr(custom_text)
	target_vbox.add_child(input_prompt)


func clear_input_prompts() -> void:
	for child in _left_col.get_children():
		child.queue_free()
	for child in _right_col.get_children():
		child.queue_free()
	category_boxes.clear()
