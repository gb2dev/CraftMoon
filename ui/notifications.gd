extends VBoxContainer


const NOTIFICATION_SCENE = preload("res://ui/notification.tscn")


func _ready() -> void:
	var _error := Signals.ui_notification.connect(spawn_notification)


func spawn_notification(icon: String, text: String, timeout: float) -> void:
	var notification_instance := NOTIFICATION_SCENE.instantiate() as Notification
	notification_instance.set_icon(get_icon_from_string(icon))
	notification_instance.set_text(text)
	notification_instance.set_timeout(timeout)
	add_child(notification_instance)


func get_icon_from_string(icon: String) -> Texture2D:
	var dir_path := "res://icons/" + icon.get_base_dir()
	for file: String in ResourceLoader.list_directory(dir_path):
		if file.get_basename() == icon.get_file():
			return load(dir_path + "/" + file)
	return null
