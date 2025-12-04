extends Node

func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event
	if event.is_pressed():
		match key.keycode:
			KEY_R:
				get_tree().reload_current_state()
			KEY_Q:
				get_tree().reload_current_scene()
			KEY_F11:
				var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				var target_mode: int = DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(target_mode)
