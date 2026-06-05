class_name OptionsMenu
extends Control


const FSR: Array[float] = [0.77, 0.67, 0.59, 0.5]
const LOOK_DEADZONE_ACTIONS: Array[StringName] = [
	&"look_up",
	&"look_down",
	&"look_left",
	&"look_right",
]
const OPTION_LABELS := {
	&"MouseSensitivity": "Mouse Sensitivity",
	&"MouseHorizontalInverted": "Invert Mouse X",
	&"MouseVerticalInverted": "Invert Mouse Y",
	&"ControllerHorizontalSensitivity": "Controller X Sensitivity",
	&"ControllerVerticalSensitivity": "Controller Y Sensitivity",
	&"ControllerHorizontalInverted": "Invert Controller X",
	&"ControllerVerticalInverted": "Invert Controller Y",
	&"ControllerResponseCurve": "Controller Response Curve",
	&"ControllerDeadzone": "Controller Deadzone",
	&"ControllerOuterThreshold": "Controller Outer Threshold",
	&"3DScale": "3D Scale",
	&"AntiAliasing": "Anti-Aliasing",
	&"Bloom": "Bloom",
	&"Brightness": "Brightness",
	&"FOV": "Field of View",
	&"FSR": "FSR",
	&"Fullscreen": "Fullscreen",
	&"MaxFPS": "Max FPS",
	&"ShowFPS": "Show FPS",
	&"VSync": "VSync",
	&"VolumeMaster": "Master Volume",
	&"VolumeSFX": "SFX Volume",
	&"VolumeMusic": "Music Volume",
	&"VolumeDialog": "Dialog Volume",
}
const AUDIO_OPTION_BUSES := {
	&"VolumeMaster": &"Master",
	&"VolumeSFX": &"SFX",
	&"VolumeMusic": &"Music",
	&"VolumeDialog": &"Dialog",
}

@onready var options: VBoxContainer = $Options
@onready var pause_controls: VBoxContainer = $PauseControls
@onready var game_title: Label = $PauseControls/GameTitle
@onready var tab_bar: TabBar = $Options/TabBar
@onready var tabs: Control = $Options/Tabs
@onready var input_mapping := $Options/Tabs/InputMapping as Control

var player: Character = null
var look_controller: Node = null
var look_controller_3p: Node = null
var world_environment: WorldEnvironment = null
const FIRST_PERSON_SENSITIVITY_X: float = 0.2
const FIRST_PERSON_SENSITIVITY_Y: float = 0.14
const THIRD_PERSON_SENSITIVITY_MULTIPLIER: float = 1.5


func _ready() -> void:
	visible = false
	options.visible = true
	pause_controls.visible = false
	game_title.text = str(ProjectSettings.get_setting("application/config/name", "CraftMoon"))
	world_environment = get_tree().current_scene.get_node_or_null(^"DefaultEnvironment/WorldEnvironment") as WorldEnvironment

	configure_supported_options()
	_on_tab_bar_tab_changed(tab_bar.current_tab)

	for tab_node: Node in tabs.get_children():
		var tab := tab_node as Control
		if tab:
			initialize_tab(tab)


func set_player(new_player: Character) -> void:
	player = new_player
	look_controller = null
	look_controller_3p = null
	if player:
		look_controller = player.get_node_or_null(^"Pivot")
		look_controller_3p = player.get_node_or_null(^"SpringArmOffset")
	apply_saved_options()


func open() -> void:
	visible = true
	options.visible = true
	pause_controls.visible = false
	_on_tab_bar_tab_changed(tab_bar.current_tab)
	apply_saved_options()


func close() -> void:
	visible = false


func apply_saved_options() -> void:
	for tab_node: Node in tabs.get_children():
		var tab := tab_node as Control
		if tab == null:
			continue

		for option_node: Node in tab.get_children():
			var option := option_node as Control
			if option == null or not option.is_in_group(&"Option"):
				continue

			var setter := option.get_node_or_null(^"Setter") as Control
			if setter == null:
				continue

			var default_value: Variant = setter.get_meta(&"default_value")
			var config_value: Variant = OptionsConfig.get_config_value(tab.name, option.name, default_value)
			apply_option(config_value, option.name)


func apply_option(new_value: Variant, option: StringName) -> void:
	match option:
		# Mouse
		&"MouseSensitivity":
			if look_controller:
				look_controller.set(&"mouse_look_sensitivity", float(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"mouse_look_sensitivity", float(new_value))
		&"MouseHorizontalInverted":
			if look_controller:
				look_controller.set(&"mouse_look_inverted_x", bool(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"mouse_look_inverted_x", bool(new_value))
		&"MouseVerticalInverted":
			if look_controller:
				look_controller.set(&"mouse_look_inverted_y", bool(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"mouse_look_inverted_y", bool(new_value))

		# Controller
		&"ControllerHorizontalSensitivity":
			if look_controller:
				look_controller.set(&"joypad_look_sensitivity_x", FIRST_PERSON_SENSITIVITY_X * float(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_sensitivity_x", FIRST_PERSON_SENSITIVITY_X * float(new_value) * THIRD_PERSON_SENSITIVITY_MULTIPLIER)
		&"ControllerVerticalSensitivity":
			if look_controller:
				look_controller.set(&"joypad_look_sensitivity_y", FIRST_PERSON_SENSITIVITY_Y * float(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_sensitivity_y", FIRST_PERSON_SENSITIVITY_Y * float(new_value) * THIRD_PERSON_SENSITIVITY_MULTIPLIER)
		&"ControllerHorizontalInverted":
			if look_controller:
				look_controller.set(&"joypad_look_inverted_x", bool(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_inverted_x", bool(new_value))
		&"ControllerVerticalInverted":
			if look_controller:
				look_controller.set(&"joypad_look_inverted_y", bool(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_inverted_y", bool(new_value))
		&"ControllerResponseCurve":
			if look_controller:
				look_controller.set(&"joypad_look_curve", float(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_curve", float(new_value))
		&"ControllerDeadzone":
			for action: StringName in LOOK_DEADZONE_ACTIONS:
				if InputMap.has_action(action):
					InputMap.action_set_deadzone(action, float(new_value))
		&"ControllerOuterThreshold":
			if look_controller:
				look_controller.set(&"joypad_look_outer_threshold", float(new_value))
			if look_controller_3p:
				look_controller_3p.set(&"joypad_look_outer_threshold", float(new_value))

		# Video
		&"3DScale":
			get_viewport().scaling_3d_scale = float(new_value)
		&"AntiAliasing":
			match int(new_value):
				0:
					get_viewport().msaa_3d = Viewport.MSAA_DISABLED
					get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
				1:
					get_viewport().msaa_3d = Viewport.MSAA_DISABLED
					get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
				2:
					get_viewport().msaa_3d = Viewport.MSAA_2X
					get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		&"Bloom":
			if world_environment and world_environment.environment:
				world_environment.environment.glow_enabled = bool(new_value)
		&"Brightness":
			if world_environment and world_environment.environment:
				world_environment.environment.adjustment_enabled = true
				world_environment.environment.adjustment_brightness = float(new_value)
		&"FOV":
			apply_fov(float(new_value))
		&"FSR":
			var setter := tabs.get_node_or_null(^"Video/3DScale/Setter") as Range
			if setter == null:
				return

			if int(new_value) == 0:
				get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
				get_viewport().scaling_3d_scale = setter.value
				setter.editable = true
			else:
				get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
				get_viewport().scaling_3d_scale = FSR[int(new_value) - 1]
				setter.editable = false
		&"Fullscreen":
			if bool(new_value):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		&"MaxFPS":
			Engine.max_fps = int(new_value)
		&"ShowFPS":
			pass
		&"VSync":
			if bool(new_value):
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			else:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Audio
		&"VolumeMaster", &"VolumeSFX", &"VolumeMusic", &"VolumeDialog":
			apply_audio_volume(option, float(new_value))


func initialize_tab(tab: Control) -> void:
	for option_node: Node in tab.get_children():
		var option := option_node as Control
		if option == null or not option.is_in_group(&"Option"):
			continue

		var name_label := option.get_node_or_null(^"Name") as Label
		if name_label:
			name_label.text = OPTION_LABELS.get(StringName(option.name), option.name)

		var setter := option.get_node_or_null(^"Setter") as Control
		if setter == null:
			continue

		var default_value: Variant = setter.get_meta(&"default_value")
		var set_func := Callable()
		var change_signal: Signal

		if setter is Range:
			var slider := setter as Range
			set_func = slider.set_value
			change_signal = slider.value_changed
		elif setter is CheckBox:
			var checkbox := setter as CheckBox
			set_func = checkbox.set_pressed
			change_signal = checkbox.toggled
		elif setter is OptionButton:
			var option_button := setter as OptionButton
			set_func = option_button.select
			change_signal = option_button.item_selected
		else:
			continue

		var config_value: Variant = OptionsConfig.get_config_value(tab.name, option.name, default_value)
		set_func.call(config_value)

		update_value_label(config_value, setter)
		apply_option(config_value, option.name)

		if change_signal.get_connections().is_empty():
			var _update_error := change_signal.connect(update_value_label.bind(setter))
			var _config_error := change_signal.connect(OptionsConfig.set_config_value.bind(tab.name, option.name))
			var _apply_error := change_signal.connect(apply_option.bind(option.name))

	OptionsConfig.save_config_file()


func toggle_pause() -> void:
	if visible:
		close()
	else:
		open()


func update_value_label(new_value: Variant, setter: Control) -> void:
	if setter is Range:
		var value_label := setter.get_parent().get_node_or_null(^"Value") as Label
		if value_label == null:
			return

		var slider := setter as Range
		if floor(slider.step) == slider.step:
			value_label.text = str(int(round(float(new_value))))
		else:
			value_label.text = "%.2f" % float(new_value)
	elif setter is CheckBox:
		var checkbox := setter as CheckBox
		checkbox.text = "Enabled" if bool(new_value) else "Disabled"


func configure_supported_options() -> void:
	set_option_visible(&"Video", &"ShowFPS", false)
	set_option_visible(&"Audio", &"VolumeSFX", has_audio_bus(&"SFX"))
	set_option_visible(&"Audio", &"VolumeMusic", has_audio_bus(&"Music"))
	set_option_visible(&"Audio", &"VolumeDialog", has_audio_bus(&"Dialog"))

	var has_environment := world_environment != null and world_environment.environment != null
	set_option_visible(&"Video", &"Bloom", has_environment)
	set_option_visible(&"Video", &"Brightness", has_environment)


func set_option_visible(tab_name: StringName, option_name: StringName, should_be_visible: bool) -> void:
	var option_path := "%s/%s" % [String(tab_name), String(option_name)]
	var option := tabs.get_node_or_null(option_path) as Control
	if option:
		option.visible = should_be_visible


func has_audio_bus(bus_name: StringName) -> bool:
	return AudioServer.get_bus_index(String(bus_name)) != -1


func apply_audio_volume(option: StringName, volume: float) -> void:
	var bus_name := AUDIO_OPTION_BUSES.get(option, &"") as StringName
	if bus_name == StringName():
		return

	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index == -1:
		return

	AudioServer.set_bus_mute(bus_index, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))


func apply_fov(value: float) -> void:
	var cameras: Array[Camera3D] = []
	if player:
		var first_person_camera := player.get_node_or_null(^"Pivot/Camera3D") as Camera3D
		if first_person_camera:
			cameras.append(first_person_camera)

		var third_person_camera := player.get_node_or_null(^"SpringArmOffset/SpringArm3D/Camera3D") as Camera3D
		if third_person_camera:
			cameras.append(third_person_camera)

	if cameras.is_empty():
		var current_camera := get_viewport().get_camera_3d()
		if current_camera:
			cameras.append(current_camera)

	for camera: Camera3D in cameras:
		camera.fov = value


func _on_restore_defaults_button_pressed() -> void:
	var tab_title := tab_bar.get_tab_title(tab_bar.current_tab)

	OptionsConfig.restore_defaults(tab_title)
	if input_mapping.visible:
		OptionsConfig.save_config_file()
		input_mapping.restore_defaults()
	else:
		initialize_tab(tabs.get_child(tab_bar.current_tab) as Control)


func _on_tab_bar_tab_changed(index: int) -> void:
	for tab_node: Node in tabs.get_children():
		var tab := tab_node as Control
		if tab:
			tab.visible = tab.get_index() == index


func _on_resume_button_pressed() -> void:
	%SoundClick.play()
	close()


func _on_options_button_pressed() -> void:
	%SoundClick.play()
	open()


func _on_quit_button_pressed() -> void:
	%SoundClick.play()
	get_tree().quit()


func _on_button_mouse_entered() -> void:
	%SoundHover.play()
