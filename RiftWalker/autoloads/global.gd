extends Node

# This holds the data for the CURRENT battle
var battle: BattleData

# GLOBAL CURRENCY
var coins: int = 0

var game_speed: float = 1.0:
	set(value):
		game_speed = value
		# Verify SignalBus exists before emitting to prevent errors during shutdown
		if SignalBus: 
			SignalBus.game_speed_changed.emit(value)

var current_round: int = 1

var starting_round: int = 1

var upgrade_points_pending: int = 1
var highest_round: int = 1
var lifetime_coins: int = 0

var access_token: String = ""
var user_id: String = ""
var device_id: String = ""
var current_username: String = ""

# SAVE SYSTEM CONSTANTS
const SAVE_PATH = "user://savegame.save"

# Define list of possible battles here (Paths only, load on demand)
var all_battles: Array[String] = [
	"res://battle_data/ship.tres",
	"res://battle_data/space.tres"
]

func _ready() -> void:
	load_game() # Load coins when the game starts
	
	# If no save file existed or device_id was missing, generate one now
	if device_id == "":
		device_id = OS.get_unique_id()
		save_game()
	
	# Ensure we have a valid battle ready
	pick_new_battle()

# Pick a random battle from the list
func pick_new_battle() -> void:
	var battle_path = all_battles.pick_random()
	battle = load(battle_path)

# --- SAVE SYSTEM ---

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = { 
		"coins": coins,
		"game_speed": game_speed,
		"current_round": current_round,
		"starting_round": starting_round, # --- NEW: Save preference ---
		"highest_round": highest_round,
		"lifetime_coins": lifetime_coins,
		"device_id": device_id,
		"current_username": current_username
	}
	
	file.store_string(JSON.stringify(data))
	file.close() # Ensure close
	
	# --- NEW: Trigger Cloud Backup ---
	# We use call_deferred to avoid stalling the main thread too much, 
	# though HTTPRequest is async anyway.
	if AuthManager:
		AuthManager.call_deferred("upload_save", SAVE_PATH)

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
		if data.has("highest_round"):
			highest_round = data["highest_round"]
		if data.has("lifetime_coins"):
			lifetime_coins = data["lifetime_coins"]
		if data.has("device_id"):
			device_id = data["device_id"]
		if data.has("current_username"):
			current_username = data["current_username"]
	


# Returns the difficulty multiplier for the current round.
# Round 1 = 1.0, Round 2 = 1.05, Round 10 = 5.05 (approx)
func get_current_difficulty_multiplier() -> float:
	if current_round <= 1:
		return 1.0
	return 1.0 + (pow(current_round - 1, 2) * 0.05)
	
func update_lifetime_stats(round_reached: int, coins_gained_in_battle: int) -> void:
	if round_reached > highest_round:
		highest_round = round_reached
	
	lifetime_coins += coins_gained_in_battle
	save_game()
