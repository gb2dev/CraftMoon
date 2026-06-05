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


var _last_using_computer: bool = false
var _last_menu_visible: bool = false
var _last_pie_menu_visible: bool = false
var _last_sub_menu_visible: bool = false


func _process(_delta: float) -> void:
	if not owner:
		return

	var menu: Control = owner.get_node_or_null("%Menu")
	var main_menu: Control = owner.get_node_or_null("%MainMenu")
	var obj_props: Control = owner.get_node_or_null("%ObjectProperties")
	var chat: Control = owner.get_node_or_null("%MultiplayerChat")
	var pie_menu: Control = owner.get_node_or_null("%PieMenu")
	var menus_visible := (main_menu and main_menu.visible)
	modulate.a = 0.0 if menus_visible else 1.0

	var using_computer := Moon.is_using_computer
	var menu_visible := menu and menu.visible
	var pie_visible := pie_menu and pie_menu.visible
	var sub_menu_visible := (obj_props and obj_props.visible) \
		or (chat and chat.visible)

	if (using_computer != _last_using_computer \
		or menu_visible != _last_menu_visible \
		or pie_visible != _last_pie_menu_visible \
		or sub_menu_visible != _last_sub_menu_visible):

		_last_using_computer = using_computer
		_last_menu_visible = menu_visible
		_last_pie_menu_visible = pie_visible
		_last_sub_menu_visible = sub_menu_visible

		clear_input_prompts()

		if using_computer:
			add_input_prompt([&"ui_cancel"], &"UI", "Exit Computer")
		elif menu_visible:
			add_input_prompt([&"pause_menu", &"ui_cancel"], &"UI", "Close Pause Menu", false, false, true)
		elif pie_visible:
			add_input_prompt([&"ui_cancel", &"choose_shape"], &"UI", "Close Wheel", false, false, true)
		elif sub_menu_visible:
			add_input_prompt([&"ui_cancel"], &"UI", "Back")
		else:
			_restore_default_inputs_direct()


func _restore_default_inputs_direct() -> void:
	var editor: Editor = null
	if owner and owner.menu and owner.menu.player:
		editor = owner.menu.player.editor
	if editor and owner.edit_mode:
		editor._update_input_display()
	else:
		moon_inputs_direct()


func _restore_default_inputs() -> void:
	_restore_default_inputs_direct()


func moon_inputs_direct() -> void:
	clear_input_prompts()
	_add_common_prompts()
	visible = true


func moon_inputs() -> void:
	_last_using_computer = Moon.is_using_computer
	if owner:
		var menu: Control = owner.get_node_or_null("%Menu")
		_last_menu_visible = menu and menu.visible
		var pie_menu: Control = owner.get_node_or_null("%PieMenu")
		_last_pie_menu_visible = pie_menu and pie_menu.visible
		var obj_props: Control = owner.get_node_or_null("%ObjectProperties")
		var chat: Control = owner.get_node_or_null("%MultiplayerChat")
		_last_sub_menu_visible = (obj_props and obj_props.visible) \
			or (chat and chat.visible)
	else:
		_last_menu_visible = false
		_last_pie_menu_visible = false
		_last_sub_menu_visible = false
	moon_inputs_direct()


func _add_common_prompts(show_customize_player := true) -> void:
	add_input_prompt([&"move_forward", &"move_back", &"move_left", &"move_right"], &"Basic Movement", "Move")
	add_input_prompt([&"look_up", &"look_down", &"look_left", &"look_right"], &"Basic Movement", "Look")
	add_input_prompt([&"jump"], &"Basic Movement")
	add_input_prompt([&"sprint"], &"Basic Movement")
	if show_customize_player:
		add_input_prompt([&"customize_player"], &"UI")
	add_input_prompt([&"pause_menu"], &"UI", "Pause Menu")


func add_input_prompt(
	actions: Array[StringName],
	category: StringName,
	custom_text: String = "",
	other_side := false,
	has_joypad_modifier := false,
	separate_actions := false
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
	input_prompt.separate_actions = separate_actions

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
