extends Node

# This holds the data for the CURRENT battle
var battle: BattleData

# GLOBAL CURRENCY
var coins: int = 0

var game_speed: float = 1.0

var current_round: int = 1

var starting_round: int = 1

var upgrade_points_pending: int = 1

# SAVE SYSTEM CONSTANTS
const SAVE_PATH = "user://savegame.save"

# Define list of possible battles here
var all_battles: Array[BattleData] = [
	preload("res://battle_data/ship.tres"),
	preload("res://battle_data/space.tres")
]

func _ready() -> void:
	load_game() # Load coins when the game starts
	
	# Ensure we have a valid battle ready
	pick_new_battle()

# Pick a random battle from the list
func pick_new_battle() -> void:
	battle = all_battles.pick_random()

# --- SAVE SYSTEM ---

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = { 
		"coins": coins,
		"game_speed": game_speed,
		"current_round": current_round,
		"starting_round": starting_round # --- NEW: Save preference ---
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
		# --- NEW: Load game_speed ---
		if data.has("game_speed"):
			game_speed = data["game_speed"]
		# --- NEW: Load round ---
		if data.has("current_round"):
			current_round = data["current_round"]
		if data.has("starting_round"): 
			starting_round = data["starting_round"]

# Returns the difficulty multiplier for the current round.
# Round 1 = 1.0, Round 2 = 1.05, Round 10 = 5.05 (approx)
func get_current_difficulty_multiplier() -> float:
	if current_round <= 1:
		return 1.0
	return 1.0 + (pow(current_round - 1, 2) * 0.05)
	
