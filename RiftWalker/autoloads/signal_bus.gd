extends Node


signal display_text(text: String)
signal text_window_closed
signal cursor_come_to_me(my_position: Vector2, is_ally: bool)

signal battle_won
signal battle_lost

signal label_index_changed(newIndex: int)
signal selected_label
