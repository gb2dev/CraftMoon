extends Gadget


const AREA_MATERIAL = preload("res://materials/area.tres")

var area: Area3D
var area_visual: MeshInstance3D
var collision_shape: CollisionShape3D
var is_player_detected: bool:
	set(value):
		is_player_detected = value
		if is_input_data_powered(0, true):
			if World.time_paused:
				await Signals.time_played
				output(0, is_player_detected)
			else:
				output(0, is_player_detected)


func start() -> void:
	var _error := Signals.time_rewound.connect(_on_time_rewound)

	area = Area3D.new()
	area.scale = Vector3.ONE * 2
	area.collision_layer = 0
	area.collision_mask = 2
	_error = area.body_entered.connect(_on_area_3d_body_entered)
	_error = area.body_exited.connect(_on_area_3d_body_exited)
	node_3d.add_child(area)

	area_visual = MeshInstance3D.new()
	area_visual.material_override = AREA_MATERIAL
	area_visual.visible = false
	area.add_child(area_visual)

	collision_shape = CollisionShape3D.new()
	area.add_child(collision_shape)

	change_property(&"ZoneShape", 0) # Initialize with sphere shape

	_error = input_pulse.connect(func(_input_index: int) -> void:
		output(0, is_input_data_powered(0, true) and is_player_detected)
	)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(property: StringName, value: Variant) -> void:
	match property:
		&"ZoneShape":
			match value:
				0:
					collision_shape.shape = SphereShape3D.new()
					area_visual.mesh = SphereMesh.new()
				1:
					collision_shape.shape = BoxShape3D.new()
					area_visual.mesh = BoxMesh.new()
		&"ZoneWidth":
			area.scale.x = value
		&"ZoneHeight":
			area.scale.y = value
		&"ZoneDepth":
			area.scale.z = value


func setup_properties(gadget_properties: GadgetProperties) -> void:
	area_visual.show()
	var _error := gadget_properties.gadget_changed.connect(area_visual.hide, Object.CONNECT_ONE_SHOT)

	var shape_option := OptionButton.new()
	shape_option.name = "ZoneShape"
	shape_option.add_item("Sphere")
	shape_option.add_item("Cuboid")
	shape_option.selected = get_meta(&"ZoneShape", 0)
	gadget_properties.vbox.add_child(shape_option)

	const ZONE_SIZE_PREFIX = "Zone size: "
	var size_slider := gadget_properties.add_slider(ZONE_SIZE_PREFIX, [&"ZoneWidth", &"ZoneHeight", &"ZoneDepth"], 2, 0.1, 50, 0.1, self)
	size_slider.name = gadget_properties.get_control_name(ZONE_SIZE_PREFIX)

	const ZONE_WIDTH_PREFIX = "Zone width: "
	var width_slider := gadget_properties.add_slider(ZONE_WIDTH_PREFIX, [&"ZoneWidth"], 2, 0.1, 50, 0.1, self)
	width_slider.name = gadget_properties.get_control_name(ZONE_WIDTH_PREFIX)

	const ZONE_HEIGHT_PREFIX = "Zone height: "
	var height_slider := gadget_properties.add_slider(ZONE_HEIGHT_PREFIX, [&"ZoneHeight"], 2, 0.1, 50, 0.1, self)
	height_slider.name = gadget_properties.get_control_name(ZONE_HEIGHT_PREFIX)

	const ZONE_DEPTH_PREFIX = "Zone depth: "
	var depth_slider := gadget_properties.add_slider(ZONE_DEPTH_PREFIX, [&"ZoneDepth"], 2, 0.1, 50, 0.1, self)
	depth_slider.name = gadget_properties.get_control_name(ZONE_DEPTH_PREFIX)

	var item_selected := func(index: int) -> void:
		gadget_properties.sync_option_button_item_selected.rpc(shape_option.get_path(), index)
		sync_meta.rpc(&"ZoneShape", index)
		var is_uniform_scale := index == 0
		gadget_properties.sync_control_visible.rpc(size_slider.get_path(), is_uniform_scale)
		gadget_properties.sync_control_visible.rpc(width_slider.get_path(), not is_uniform_scale)
		gadget_properties.sync_control_visible.rpc(height_slider.get_path(), not is_uniform_scale)
		gadget_properties.sync_control_visible.rpc(depth_slider.get_path(), not is_uniform_scale)
		if is_uniform_scale:
			gadget_properties.sync_emit_signal.rpc(size_slider.get_path(), &"value_changed", size_slider.value)
			change_property.rpc.call_deferred(&"ZoneShape", index)
		else:
			change_property.rpc(&"ZoneShape", index)
			gadget_properties.sync_emit_signal.rpc(width_slider.get_path(), &"value_changed", width_slider.value)
			gadget_properties.sync_emit_signal.rpc(height_slider.get_path(), &"value_changed", height_slider.value)
			gadget_properties.sync_emit_signal.rpc(depth_slider.get_path(), &"value_changed", depth_slider.value)

	_error = shape_option.item_selected.connect(item_selected)

	item_selected.call(shape_option.selected)


func _on_area_3d_body_entered(_body: Node3D) -> void:
	is_player_detected = true


func _on_area_3d_body_exited(_body: Node3D) -> void:
	is_player_detected = false


func _on_time_rewound() -> void:
	output(0, false)
	is_player_detected = area.has_overlapping_bodies()
