extends Node


@onready var config = ConfigFile.new()


func _ready():
	config.load("user://options.cfg")


func get_config_value(tab: String, option: String, default_value: Variant) -> Variant:
	if not config.has_section_key(tab, option):
		if default_value == null:
			return null
		else:
			config.set_value(tab, option, default_value)
	return config.get_value(tab, option)


func set_config_value(new_value: Variant, tab: String, option: String) -> void:
	config.set_value(tab, option, new_value)
	save_config_file()


func save_config_file() -> void:
	config.save("user://options.cfg")


func restore_defaults(tab: String) -> void:
	if config.has_section(tab):
		config.erase_section(tab)
