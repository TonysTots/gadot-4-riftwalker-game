extends Node

# --- DATA: Battle & Economy ---
## Holds data for the CURRENT battle being played.
var battle: BattleData
## Global currency persistent across runs.
var coins: int = 0
## Total coins collected across all runs.
var lifetime_coins: int = 0

# --- DATA: Run State ---
## The base difficulty setting for the current run (Layer 1 = this value).
var map_base_difficulty: int = 1
## The current difficulty tier the player is effectively on (calculated from map position).
var current_round: int = 1
## The highest round ever reached (for leaderboards).
var highest_round: int = 1
## Upgrade points available for each character in the current run.
var party_points: Dictionary = {} # Key: String (AllyName), Value: int (Points)
## Tracks if there are pending points to alert the UI (Legacy/Compatibility).
var upgrade_points_pending: int = 1

# --- DATA: Preferences & Settings ---
## Speed multiplier for animations and gameplay.
var game_speed: float = 1.0:
	set(value):
		game_speed = value
		if SignalBus: 
			SignalBus.game_speed_changed.emit(value)

## User's preferred starting difficulty Level (e.g. starts at Round 10).
var starting_round: int = 1

# --- DATA: Authentication ---
var access_token: String = ""
var user_id: String = ""
var device_id: String = ""
var current_username: String = ""

# --- DATA: Map System ---
## The current generated map structure.
var map_data: MapData = null
## Temporary offset for specific battles (e.g. Boss = +10 difficulty).
## Temporary offset for specific battles (e.g. Boss = +10 difficulty).
var battle_round_offset: int = 0
## Tracks if a run is currently active and should be Resumed instead of Restarted.
var run_in_progress: bool = false

# --- CONSTANTS ---
const SAVE_PATH: String = "user://savegame.save"

## List of available battle scenarios (Loaded dynamically).
var all_battles: Array[String] = [
	"res://battle_data/ship.tres",
	"res://battle_data/space.tres"
]

func _ready() -> void:
	load_game() 
	
	# Device ID Initialization
	if device_id == "":
		device_id = OS.get_unique_id()
		save_game()
	
	# Ensure initial state
	pick_new_battle()

## Selects a random battle configuration from the available list.
func pick_new_battle() -> void:
	var battle_path: String = all_battles.pick_random()
	battle = load(battle_path)
	
	if battle and battle.allies:
		apply_pending_allies_data(battle.allies)

# --- ECONOMY & PROGRESSION ---

## Calculates the current difficulty multiplier based on round and offsets.
## Formula: 1.0 + ((Round - 1)^2 * 0.05)
func get_current_difficulty_multiplier() -> float:
	var effective_round: int = current_round + battle_round_offset
	if effective_round <= 1:
		return 1.0
	return 1.0 + (pow(effective_round - 1, 2) * 0.05)

## Updates stats after a battle and persists data.
func update_lifetime_stats(round_reached: int, coins_gained_in_battle: int) -> void:
	if round_reached > highest_round:
		highest_round = round_reached
	
	lifetime_coins += coins_gained_in_battle
	save_game()

# --- SAVE SYSTEM ---

const PARTY_PATHS: Array[String] = [
	"res://stats/ally_stats/blake.tres",
	"res://stats/ally_stats/michael.tres",
	"res://stats/ally_stats/mitchell.tres"
]

## Serializes and saves current game state to disk (and Cloud if logged in).
func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	# Serialize Allies (Hybrid Approach)
	# 1. Prefer Live Battle Data (Captures current HP/MP/Inventory changes in battle)
	# 2. Fallback to Master List (Captures Upgrade Menu changes when no battle exists)
	
	var allies_data: Dictionary = {}
	var source_list: Array = []
	
	if battle and battle.allies:
		source_list = battle.allies
	else:
		# Fallback to loading from disk/cache
		for path in PARTY_PATHS:
			if ResourceLoader.exists(path):
				var ally = load(path)
				if ally: source_list.append(ally)
	
	for ally: AllyStats in source_list:
		var item_paths: Array[String] = []
		for item in ally.items:
			if item and item.resource_path != "":
				item_paths.append(item.resource_path)
		
		allies_data[ally.name] = {
			"body": ally.body,
			"mind": ally.mind,
			"spirit": ally.spirit,
			"damage_taken": ally.damage_taken,
			"mana_used": ally.mana_used,
			"items": item_paths
		}

	var data: Dictionary = { 
		"coins": coins,
		"game_speed": game_speed,
		"current_round": current_round,
		"starting_round": starting_round,
		"highest_round": highest_round,
		"map_base_difficulty": map_base_difficulty,
		"party_points": party_points,
		"lifetime_coins": lifetime_coins,
		"current_username": current_username,
		"allies_data": allies_data,
		"run_in_progress": run_in_progress,
		"map_dict": map_data.to_dict() if map_data else {} # Save Map Data
	}
	
	file.store_string(JSON.stringify(data))
	file.close()
	
	# Cloud Sync
	if AuthManager:
		AuthManager.call_deferred("upload_save", SAVE_PATH)

## Loads game state from disk.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return 
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(text)
	
	if parse_result == OK:
		var data: Dictionary = json.data
		
		# Safely load usage properties
		coins = data.get("coins", 0)
		game_speed = data.get("game_speed", 1.0)
		current_round = data.get("current_round", 1)
		starting_round = data.get("starting_round", 1)
		highest_round = data.get("highest_round", 1)
		
		# Dictionary type safety
		if data.has("party_points"):
			party_points = data["party_points"]
			
		if data.has("lifetime_coins"):
			lifetime_coins = data["lifetime_coins"]
		
		# Protect Device ID: Only update if save has a valid one
		var loaded_id = data.get("device_id", "")
		if loaded_id != "":
			device_id = loaded_id
			
		current_username = data.get("current_username", "")
		map_base_difficulty = data.get("map_base_difficulty", 1)
		run_in_progress = data.get("run_in_progress", false)
		
		# Load Allies Data
		if data.has("allies_data"):
			_restore_allies(data["allies_data"])
			
		# Load Map Data
		if data.has("map_dict") and not data["map_dict"].is_empty():
			map_data = MapData.from_dict(data["map_dict"])

func _restore_allies(allies_data: Dictionary) -> void:
	Global.pending_allies_data = allies_data
	# Apply immediately to master resources
	apply_pending_allies_data()

var pending_allies_data: Dictionary = {}

func apply_pending_allies_data(target_allies: Array = []) -> void:
	if pending_allies_data.is_empty(): return
	
	var allies_to_update: Array = target_allies
	if allies_to_update.is_empty():
		# Default to Master Party List
		for path in PARTY_PATHS:
			if ResourceLoader.exists(path):
				var res = load(path)
				if res is AllyStats:
					allies_to_update.append(res)
	
	for ally in allies_to_update:
		if ally is AllyStats and ally.name in pending_allies_data:
			var save_data = pending_allies_data[ally.name]
			ally.body = int(save_data.get("body", ally.base_body))
			ally.mind = int(save_data.get("mind", ally.base_mind))
			ally.spirit = int(save_data.get("spirit", ally.base_spirit))
			ally.damage_taken = int(save_data.get("damage_taken", 0))
			ally.mana_used = int(save_data.get("mana_used", 0))
			
			# Restore Items
			if save_data.has("items"):
				var new_items: Array[Item] = []
				for path in save_data["items"]:
					if ResourceLoader.exists(path):
						var item = load(path)
						if item is Item:
							new_items.append(item)
				ally.items = new_items
