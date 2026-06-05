class_name InputPrompt
extends HBoxContainer


enum SupportedInputs {ALL, KBM_ONLY, JOYPAD_ONLY}

@onready var label := $Label as Label

@export var actions: Array[StringName]:
	set(value):
		actions = value
		var new_text := "" if actions.is_empty() else tr(actions[0])
		for i in range(1, actions.size()):
			new_text += "/" + actions[i]
		text = new_text
@export var text: String
@export var has_joypad_modifier: bool = false
@export var separate_actions: bool = false

var supported_inputs: SupportedInputs = SupportedInputs.ALL


func _ready() -> void:
	var _error := InputHelper.device_changed.connect(_on_device_changed)
	label.text = text
	_on_device_changed(InputHelper.device, 0)


func _on_device_changed(next_device: String, _index: int) -> void:
	visible = (next_device == "keyboard" and supported_inputs == SupportedInputs.KBM_ONLY) \
		or (next_device != "keyboard" and supported_inputs == SupportedInputs.JOYPAD_ONLY) \
		or supported_inputs == SupportedInputs.ALL
	for child: Node in get_children():
		if child != label:
			child.queue_free()

	var use_consolidated_stick := false
	var stick_name := ""
	if next_device != "keyboard" and actions.size() > 0:
		var left_stick_count := 0
		var right_stick_count := 0
		var other_count := 0
		
		for action: StringName in actions:
			var bindings := InputHelper.get_joypad_inputs_for_action(action)
			for event: InputEvent in bindings:
				var label_str := InputHelper.get_label_for_input(event)
				if label_str.begins_with("Left Stick "):
					left_stick_count += 1
				elif label_str.begins_with("Right Stick "):
					right_stick_count += 1
				else:
					other_count += 1
		
		if other_count == 0 and (left_stick_count > 0 or right_stick_count > 0):
			var has_x_axis := false
			var has_y_axis := false
			for action: StringName in actions:
				var bindings := InputHelper.get_joypad_inputs_for_action(action)
				for event: InputEvent in bindings:
					if event is InputEventJoypadMotion:
						if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]:
							has_x_axis = true
						elif event.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
							has_y_axis = true
			var axis_suffix := ""
			if has_x_axis and not has_y_axis:
				axis_suffix = " Horizontal"
			elif has_y_axis and not has_x_axis:
				axis_suffix = " Vertical"
			if left_stick_count > 0 and right_stick_count == 0:
				use_consolidated_stick = true
				stick_name = "Left Stick" + axis_suffix
			elif right_stick_count > 0 and left_stick_count == 0:
				use_consolidated_stick = true
				stick_name = "Right Stick" + axis_suffix

	var is_look_action := false
	if next_device == "keyboard" and actions.size() > 1:
		var look_action_count := 0
		for action: StringName in actions:
			if action in [&"look_up", &"look_down", &"look_left", &"look_right"]:
				look_action_count += 1
		if look_action_count == actions.size():
			is_look_action = true

	var use_consolidated_scroll := false
	var scroll_modifiers: Array[String] = []
	if next_device == "keyboard" and actions.size() > 1:
		var wheel_actions_count := 0
		var scroll_ctrl := false
		var scroll_alt := false
		var scroll_shift := false
		var scroll_meta := false
		for action: StringName in actions:
			var bindings := InputHelper.get_keyboard_inputs_for_action(action)
			for event: InputEvent in bindings:
				if event is InputEventMouseButton:
					if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
						wheel_actions_count += 1
						if event.ctrl_pressed: scroll_ctrl = true
						if event.alt_pressed: scroll_alt = true
						if event.shift_pressed: scroll_shift = true
						if event.meta_pressed: scroll_meta = true
						break
		if wheel_actions_count == actions.size():
			use_consolidated_scroll = true
			if scroll_ctrl: scroll_modifiers.append("Ctrl")
			if scroll_alt: scroll_modifiers.append("Alt")
			if scroll_shift: scroll_modifiers.append("Shift")
			if scroll_meta: scroll_modifiers.append("Meta")

	var groups: Array[Array] = []
	if use_consolidated_stick:
		groups.append([{"label": stick_name, "event": null}])
	elif is_look_action:
		groups.append([{"label": "Mouse Move", "event": null}])
		
		var kbm_bindings: Array[Dictionary] = []
		for action: StringName in actions:
			var input_event: InputEvent = InputHelper.get_keyboard_or_joypad_input_for_action(action)
			if input_event:
				kbm_bindings.append({"label": InputHelper.get_label_for_input(input_event), "event": input_event})
		if not kbm_bindings.is_empty():
			groups.append(kbm_bindings)
	elif use_consolidated_scroll:
		groups.append([{"label": "Mouse Wheel Vertical", "event": null, "modifiers": scroll_modifiers}])
	else:
		if separate_actions:
			var overall_added_keys := []
			for action: StringName in actions:
				var bindings := InputHelper.get_keyboard_or_joypad_inputs_for_action(action)
				if not bindings.is_empty():
					var group: Array[Dictionary] = []
					var added_keys := []
					for input_event: InputEvent in bindings:
						var label_str := InputHelper.get_label_for_input(input_event)
						if not label_str in added_keys and not label_str in overall_added_keys:
							added_keys.append(label_str)
							overall_added_keys.append(label_str)
							group.append({"label": label_str, "event": input_event})
					if not group.is_empty():
						groups.append(group)
		else:
			var max_bindings := 0
			var actions_bindings: Array[Array] = []
			for action: StringName in actions:
				var bindings := InputHelper.get_keyboard_or_joypad_inputs_for_action(action)
				actions_bindings.append(bindings)
				if bindings.size() > max_bindings:
					max_bindings = bindings.size()
			
			for i in range(max_bindings):
				var group: Array[Dictionary] = []
				var added_keys := []
				for j: int in range(actions.size()):
					var bindings: Array = actions_bindings[j]
					if i < bindings.size():
						var input_event: InputEvent = bindings[i] as InputEvent
						var label_str := InputHelper.get_label_for_input(input_event)
						if not label_str in added_keys:
							added_keys.append(label_str)
							group.append({"label": label_str, "event": input_event})
				if not group.is_empty():
					groups.append(group)

	if groups.is_empty():
		label.text = text
		return

	var group_index := 0
	for group: Array in groups:
		if group_index > 0:
			var sep_label := Label.new()
			sep_label.text = " | "
			sep_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sep_label.modulate.a = 0.5
			add_child(sep_label)
			move_child(sep_label, get_child_count() - 2)

		for item: Dictionary in group:
			var parts: Array[String] = []
			var input_event: InputEvent = item["event"]
			var main_input: String = item["label"]
			
			if next_device != "keyboard" and has_joypad_modifier:
				var shoulder := InputEventJoypadButton.new()
				shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
				parts.append(InputHelper.get_label_for_input(shoulder))

			if input_event and input_event is InputEventWithModifiers:
				if input_event.ctrl_pressed:
					parts.append("Ctrl")
				if input_event.alt_pressed:
					parts.append("Alt")
				if input_event.shift_pressed:
					parts.append("Shift")
				if input_event.meta_pressed:
					parts.append("Meta")
			elif item.has("modifiers"):
				for m: String in item["modifiers"]:
					parts.append(m)

			if not main_input.is_empty():
				parts.append(main_input)

			var all_exist := true
			var texture_paths: Array[String] = []
			for p: String in parts:
				var texture_path := "res://icons/input/" + next_device + "/" + p + ".svg"
				if ResourceLoader.exists(texture_path):
					texture_paths.append(texture_path)
				else:
					all_exist = false
					break

			if all_exist and not texture_paths.is_empty():
				label.text = text

				for i: int in range(texture_paths.size()):
					var path := texture_paths[i]
					var texture_rect := TextureRect.new()
					texture_rect.custom_minimum_size = Vector2(34, 34)
					texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					texture_rect.texture = load(path)
					add_child(texture_rect)
					move_child(texture_rect, get_child_count() - 2)
			else:
				var fallback_str := ""
				for i: int in range(parts.size()):
					if i > 0:
						fallback_str += " + "
					fallback_str += parts[i]
				
				var fallback_label := Label.new()
				fallback_label.text = "[" + tr(fallback_str) + "]"
				fallback_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				add_child(fallback_label)
				move_child(fallback_label, get_child_count() - 2)
				label.text = text
		
		group_index += 1
