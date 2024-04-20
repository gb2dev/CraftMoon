extends TextureRect


@onready var object_properties := %"Object Properties" as ObjectProperties
@onready var gadget_properties := %"Gadget Properties" as GadgetProperties

@export var gadgets_panel: GadgetsPanel
@export var item: PackedScene
@export var item_data: ItemData


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	texture = item_data.icon


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		if not get_tree().get_first_node_in_group(&"Dragging"):
			object_properties.create_gadget(item, item_data)
			accept_event()
