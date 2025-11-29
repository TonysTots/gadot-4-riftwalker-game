extends Node
class_name AnimationDemo

@export var animationPlayer: AnimationPlayer
@export var animationName: String

func _ready():
	animationPlayer.play(animationName)
