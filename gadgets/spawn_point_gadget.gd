extends Gadget


func start() -> void:
	var _error := Signals.player_respawn.connect(respawn_player)


func tick(_delta: float) -> void:
	pass


@rpc("any_peer", "call_local")
func change_property(_property: StringName, _value: Variant) -> void:
	pass


func respawn_player(player: Character) -> void:
	if node_3d:
		player.position = node_3d.global_position
