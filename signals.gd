extends Node

#region Time
signal time_played
signal time_paused
signal time_rewound
signal objects_moved(objects: Array[Node3D])
#endregion

#region UI Notifications
signal ui_notification(icon: String, text: String, timeout: float)
#endregion

#region Level
signal player_respawn(player: Character)
#endregion

#region Moon
signal level_select_closed
#endregion
