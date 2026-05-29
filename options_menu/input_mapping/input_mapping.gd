extends Control


enum { KBM, JOYPAD }

const PROMPTS_PREFIX = "res://options_menu/input_mapping/prompts/"
const PROMPTS_SUFFIX = ".png"
const ACTION_LABELS := {
	&"move_forward": "Move Forward",
	&"move_back": "Move Back",
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"look_up": "Look Up",
	&"look_down": "Look Down",
	&"look_left": "Look Left",
	&"look_right": "Look Right",
	&"jump": "Jump",
	&"sprint": "Sprint",
	&"crouch": "Crouch / Descend",
	&"action": "Build / Use",
	&"destroy": "Destroy",
	&"interact": "Interact",
	&"object_builder": "Object Builder",
	&"object_properties": "Object Properties & Guides",
	&"toggle_chat": "Open Chat",
}

var joy_name := "Joypad"
var selected_mapping_button: Button = null


func _ready() -> void:
	joy_connection_changed(-1, true)
	var _connect_error := Input.joy_connection_changed.connect(joy_connection_changed)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or selected_mapping_button == null:
		return

	accept_event()

	var action: StringName = selected_mapping_button.get_parent().get_parent().name
	var unbind := false
	if (event is InputEventKey and event.keycode == KEY_ESCAPE
			or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		unbind = true

	if selected_mapping_button.name == "KBMMappingButton":
		if unbind:
			update_mapping_button(null)
			update_input_map(action, null, KBM)
		elif get_input_type(event) == KBM:
			update_mapping_button(event)
			update_input_map(action, event, KBM)
		elif get_input_type(event) == JOYPAD:
			update_mapping_button(get_input_map(action)[KBM])
	elif selected_mapping_button.name == "ControllerMappingButton":
		if unbind:
			update_mapping_button(null)
			update_input_map(action, null, JOYPAD)
		elif get_input_type(event) == KBM:
			update_mapping_button(get_input_map(action)[JOYPAD])
		elif get_input_type(event) == JOYPAD:
			update_mapping_button(event)
			update_input_map(action, event, JOYPAD)

	toggle_action_mapping(false, selected_mapping_button)


func connect_selected_mapping_button() -> void:
	if selected_mapping_button != null and selected_mapping_button.toggled.get_connections().is_empty():
		var _connect_error := selected_mapping_button.toggled.connect(toggle_action_mapping.bind(selected_mapping_button))


func get_axis_str(axis: int, axis_value: float) -> String:
	var axis_str := str(axis)
	if axis_value > 0:
		axis_str += "+"
	elif axis_value < 0:
		axis_str += "-"
	return axis_str


func get_input_map(action: StringName) -> Array:
	var input_map: Array = [null, null]
	var events: Array[InputEvent] = InputMap.action_get_events(action)

	for index: int in events.size():
		var event: InputEvent = events[-index - 1]

		if input_map[KBM] == null and get_input_type(event) == KBM:
			input_map[KBM] = event

		if input_map[JOYPAD] == null and get_input_type(event) == JOYPAD:
			input_map[JOYPAD] = event

		if input_map[KBM] != null and input_map[JOYPAD] != null:
			break

	return input_map


func get_input_str(input: Variant) -> String:
	if input == null:
		return ""
	if input is InputEventKey:
		if input.physical_keycode:
			return OS.get_keycode_string(input.physical_keycode)
		return OS.get_keycode_string(input.keycode)
	if input is InputEventMouseButton:
		return "Mouse_" + str(input.button_index)
	if input is InputEventJoypadButton:
		return "Button_" + str(input.button_index)
	if input is InputEventJoypadMotion:
		return "Axis_" + get_axis_str(input.axis, input.axis_value)
	return ""


func get_input_type(input: Variant) -> int:
	if input is InputEventKey or input is InputEventMouseButton:
		return KBM
	if input is InputEventJoypadButton or input is InputEventJoypadMotion:
		return JOYPAD
	return -1


func initialize_actions() -> void:
	var actions_container := $ScrollContainer/VBoxContainer
	for action_node: Node in actions_container.get_children():
		var action_panel := action_node as Control
		if action_panel == null or not action_panel.is_in_group(&"Action"):
			continue

		if not InputMap.has_action(action_panel.name):
			action_panel.visible = false
			continue
		action_panel.visible = true

		var input_map := get_input_map(action_panel.name)

		for input_type: int in [KBM, JOYPAD]:
			var option: String = action_panel.name
			if input_type == KBM:
				option += "_kbm"
			else:
				option += "_joypad"

			var saved_input: Variant = OptionsConfig.get_config_value("InputMapping", option, null)
			if saved_input == null:
				continue

			var event: InputEvent = build_input_event(str(saved_input))
			if input_map[input_type] != null:
				InputMap.action_erase_event(action_panel.name, input_map[input_type])
			if event != null:
				InputMap.action_add_event(action_panel.name, event)

		input_map = get_input_map(action_panel.name)

		var hbox := action_panel.get_node(^"HBoxContainer") as HBoxContainer
		var action_label := hbox.get_node(^"Action") as Label
		action_label.text = ACTION_LABELS.get(StringName(action_panel.name), action_panel.name)

		selected_mapping_button = hbox.get_node(^"KBMMappingButton") as Button
		connect_selected_mapping_button()
		if input_map[KBM] != null:
			input_map[KBM].set_meta(&"customizable", true)
			update_mapping_button(input_map[KBM])
		else:
			update_mapping_button(null)

		selected_mapping_button = hbox.get_node(^"ControllerMappingButton") as Button
		connect_selected_mapping_button()
		if input_map[JOYPAD] != null:
			input_map[JOYPAD].set_meta(&"customizable", true)
			update_mapping_button(input_map[JOYPAD])
		else:
			update_mapping_button(null)

	selected_mapping_button = null


func build_input_event(saved_input: String) -> InputEvent:
	if saved_input.begins_with("Mouse_"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = saved_input.trim_prefix("Mouse_").to_int() as MouseButton
		return mouse_event
	if saved_input.begins_with("Button_"):
		var joypad_button := InputEventJoypadButton.new()
		joypad_button.button_index = saved_input.trim_prefix("Button_").to_int() as JoyButton
		return joypad_button
	if saved_input.begins_with("Axis_"):
		var joypad_motion := InputEventJoypadMotion.new()
		var axis_data := saved_input.trim_prefix("Axis_")
		joypad_motion.axis = axis_data.trim_suffix("+").trim_suffix("-").to_int() as JoyAxis
		joypad_motion.axis_value = -1.0 if axis_data.ends_with("-") else 1.0
		return joypad_motion
	if saved_input.is_empty():
		return null

	var key_event := InputEventKey.new()
	var keycode := OS.find_keycode_from_string(saved_input)
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event


func joy_connection_changed(device: int, connected: bool) -> void:
	if selected_mapping_button:
		toggle_action_mapping(false, selected_mapping_button)

	if connected and device >= 0:
		joy_name = Input.get_joy_name(device)
	else:
		var joypads := Input.get_connected_joypads()
		if joypads.is_empty():
			joy_name = "Joypad"
		else:
			joy_name = Input.get_joy_name(joypads.back())

	initialize_actions()


func restore_defaults() -> void:
	InputMap.load_from_project_settings()
	for button_node: Node in get_tree().get_nodes_in_group(&"MappingButton"):
		var button := button_node as Button
		if button:
			button.icon = null
			button.text = ""
	initialize_actions()


func toggle_action_mapping(button_pressed: bool, mapping_button: Button) -> void:
	for button_node: Node in get_tree().get_nodes_in_group(&"MappingButton"):
		var button := button_node as Button
		if button:
			button.disabled = button_pressed and button != mapping_button

	if button_pressed:
		selected_mapping_button = mapping_button
		mapping_button.icon = null
		mapping_button.text = "Press any button..."
		mapping_button.disabled = false
	else:
		selected_mapping_button = null
		mapping_button.button_pressed = false


func update_input_map(action: StringName, input: Variant, input_type: int) -> void:
	var input_map := get_input_map(action)
	if input_map[input_type] != null and input_map[input_type].get_meta(&"customizable", false):
		InputMap.action_erase_event(action, input_map[input_type])

	var option_suffix := "_kbm" if input_type == KBM else "_joypad"
	if input != null and not InputMap.action_has_event(action, input):
		input.set_meta(&"customizable", true)
		InputMap.action_add_event(action, input)

	OptionsConfig.set_config_value(get_input_str(input), "InputMapping", String(action) + option_suffix)


func update_mapping_button(input: Variant) -> void:
	if selected_mapping_button == null:
		return

	if input == null:
		selected_mapping_button.icon = null
		selected_mapping_button.text = ""
		return

	var input_str := get_input_str(input)
	var input_str_path := input_str.to_lower()
	var icon_path := ""

	if get_input_type(input) == KBM:
		icon_path = PROMPTS_PREFIX + "kbm/dark/" + input_str_path + PROMPTS_SUFFIX
	elif get_input_type(input) == JOYPAD:
		if joy_name.contains("PS3"):
			icon_path = PROMPTS_PREFIX + "ps3/" + input_str_path + PROMPTS_SUFFIX
		elif joy_name.contains("PS4"):
			icon_path = PROMPTS_PREFIX + "ps4/" + input_str_path + PROMPTS_SUFFIX
		elif joy_name.contains("PS5"):
			icon_path = PROMPTS_PREFIX + "ps5/" + input_str_path + PROMPTS_SUFFIX
		elif joy_name.contains("Switch"):
			icon_path = PROMPTS_PREFIX + "switch/" + input_str_path + PROMPTS_SUFFIX
		else:
			icon_path = PROMPTS_PREFIX + "xbox/" + input_str_path + PROMPTS_SUFFIX

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		selected_mapping_button.icon = load(icon_path)
		selected_mapping_button.text = ""
	else:
		selected_mapping_button.icon = null
		selected_mapping_button.text = input_str.replace("_", " ")
