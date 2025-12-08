extends Node


signal display_text(text: String)
signal text_window_closed
signal cursor_come_to_me(my_position: Vector2, is_ally: bool)
signal game_speed_changed(new_speed: float)

signal battle_won
signal battle_lost

signal label_index_changed(newIndex: int)
signal selected_label

# --- NEW: Juice Signals ---
signal request_camera_shake(intensity: float, duration: float)
signal request_hit_stop(time_scale: float, duration: float)
# --------------------------
