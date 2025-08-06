extends Node

#region Time
signal time_played
signal time_paused
signal time_rewound
#endregion

#region UI Notifications
signal ui_notification(icon: String, text: String, timeout: float)
#endregion
