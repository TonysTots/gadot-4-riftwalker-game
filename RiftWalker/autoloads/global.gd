extends Node

# This holds the data for the CURRENT battle
var battle: BattleData

# GLOBAL CURRENCY
var coins: int = 0

# SAVE SYSTEM CONSTANTS
const SAVE_PATH = "user://savegame.save"

# Define list of possible battles here
var all_battles: Array[BattleData] = [
	preload("res://battle_data/ship.tres"),
	preload("res://battle_data/space.tres")
]

func _ready() -> void:
	load_game() # Attempt to load coins when game starts
	# Ensure we have a valid battle ready when the game starts
	pick_new_battle()

# Pick a random battle from the list
func pick_new_battle() -> void:
	battle = all_battles.pick_random()

# --- SAVE SYSTEM ---

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = {
		"coins": coins
	}
	file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return # No save file found
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(text)
	
	if parse_result == OK:
		var data = json.data
		if data.has("coins"):
			coins = data["coins"]
