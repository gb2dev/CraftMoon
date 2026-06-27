class_name GroupEntity
extends Node3D

var group_id := ""
var editor: Node

static var simulation_active := false

func _ready() -> void:
	add_to_group(&"Persist")
	if not Signals.time_played.is_connected(_on_time_played):
		Signals.time_played.connect(_on_time_played)
	if not Signals.time_rewound.is_connected(_on_time_rewound):
		Signals.time_rewound.connect(_on_time_rewound)

static func _on_time_played() -> void:
	simulation_active = true

static func _on_time_rewound() -> void:
	simulation_active = false

func get_affected_nodes() -> Array[Node3D]:
	var affected: Array[Node3D] = []
	for child in get_children():
		if child is CSGShape3D:
			affected.append(child)
		elif child.has_method(&"get_affected_nodes"):
			affected.append_array(child.get_affected_nodes())
	return affected


func update_transform_from_members() -> void:
	var members = get_children()
	if members.is_empty(): return
	var center := Vector3.ZERO
	var valid_members := 0
	for node in members:
		if node is CSGShape3D or node is GroupEntity:
			center += node.global_position
			valid_members += 1
	if valid_members == 0: return
	center /= valid_members
	
	if global_position.distance_squared_to(center) < 0.0001:
		return
	
	var child_transforms := {}
	for node in members:
		if node is CSGShape3D or node is GroupEntity:
			child_transforms[node] = node.global_transform
	global_position = center
	for node in members:
		if node in child_transforms:
			node.global_transform = child_transforms[node]

func _process(_delta: float) -> void:
	if is_instance_valid(editor) and World.time_paused and not simulation_active:
		var scene = get_tree().current_scene
		if is_instance_valid(scene) and scene.get("edit_mode") == true:
			update_transform_from_members()
