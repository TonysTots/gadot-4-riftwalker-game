extends Node2D

@onready var label: Label = $Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func setup(amount: int, is_critical: bool = false) -> void:
	# Set text and color
	label.text = str(amount)
	if is_critical:
		label.modulate = Color(1, 0, 0) # Red for critical
		label.text += "!"
		scale = Vector2(1.5, 1.5)
	else:
		label.modulate = Color(1, 1, 1) # White for normal
		
	# Randomize initial position slightly
	position += Vector2(randf_range(-10, 10), randf_range(-10, 10))

func _ready() -> void:
	animation_player.play("float_up")
	await animation_player.animation_finished
	queue_free()
