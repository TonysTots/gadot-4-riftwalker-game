extends Node

# This holds the data for the CURRENT battle
var battle: BattleData

# Define list of possible battles here
var all_battles: Array[BattleData] = [
	preload("res://battle_data/ship.tres"),
	preload("res://battle_data/space.tres")
]

func _ready() -> void:
	# Ensure we have a valid battle ready when the game starts
	pick_new_battle()

# Pick a random battle from the list
func pick_new_battle() -> void:
	battle = all_battles.pick_random()
