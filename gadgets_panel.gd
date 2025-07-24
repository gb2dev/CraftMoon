class_name GadgetsPanel
extends Panel


const GADGET_ITEM_SCENE = preload("res://gadgets/gadget_item.tscn")

@export var tabs: TabContainer
@export var object_properties: ObjectProperties


func _ready() -> void:
	var dir_path := "res://gadgets"
	var dir := DirAccess.open(dir_path)

	if dir:
		var _error := dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var file_path := dir_path + "/" + file_name
				var gadget_data := ResourceLoader.load(file_path) as GadgetData
				if gadget_data:
					var tab := tabs.get_node_or_null(gadget_data.category)
					if tab:
						var gadget_item := GADGET_ITEM_SCENE.instantiate() as GadgetItem
						gadget_item.object_properties = object_properties
						gadget_item.gadget_data = gadget_data
						tab.get_child(0).add_child(gadget_item)
					else:
						printerr("Gadget category \"%s\" not found" % gadget_data.category)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		printerr("Failed to open gadgets directory")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		var gadget := get_tree().get_first_node_in_group(&"Dragging") as Gadget
		if gadget:
			# Delete Gadget
			gadget.set_mouse_filters(MOUSE_FILTER_STOP)
			gadget.queue_free()
			gadget.update_connection_positions()
			Audio.play_sound("destroy")
