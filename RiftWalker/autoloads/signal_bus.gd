extends Node

# --- UI SIGNALS ---
## Request to display a message in the text window.
signal display_text(text: String)
## Emitted when the text window is closed by player input.
signal text_window_closed
## Highlights a target (Ally/Enemy) with the cursor.
signal cursor_come_to_me(my_position: Vector2, is_ally: bool)
## Emitted when the game speed setting is modified.
signal game_speed_changed(new_speed: float)

# --- BATTLE FLOW SIGNALS ---
signal battle_won
signal battle_lost

# --- BATTLE SELECTION SIGNALS ---
## Used by Title/Selection screens to navigate lists.
signal label_index_changed(newIndex: int)
signal selected_label

# --- JUICE SIGNALS ---
## Triggers a screen shake effect.
signal request_camera_shake(intensity: float, duration: float)
## Triggers a "Hit Stop" (freeze frame) effect for impact.
signal request_hit_stop(time_scale: float, duration: float)
