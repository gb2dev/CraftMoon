extends TextureRect


@onready var object_properties := %"Object Properties" as ObjectProperties
@onready var gadget_properties := %"Gadget Properties" as GadgetProperties
@onready var gadgets := %"Gadgets"
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
			# Create new Gadget
			var gadget := item.instantiate() as Gadget
			get_tree().current_scene.add_child(gadget)
			gadget.attach_to_object(object_properties.object)
			gadget.set_icon(item_data.icon)
			gadget.open_properties.connect(func() -> void:
				gadget_properties.gadget_changed.emit()
			)
			gadget.open_properties.connect(gadget_properties.open.bind(item_data.name, gadget))
			gadget.open_properties.connect(gadgets.hide)
			accept_event()
