extends Node

@onready var battlers := $Battlers.get_children()
@onready var text_window: PanelContainer = $TextWindow
@onready var text_label: Label = $TextWindow/Label
@onready var battle_music: AudioStreamPlayer = $BattleMusic
@onready var round_label: Label = %RoundLabel

@export var battleData: BattleData
var battlersSortedSpeed: Array

const ALLY_BATTLER = preload("res://ally_battler/ally_battler.tscn")
const ENEMY_BATTLER = preload("res://enemy_battler/enemy_battler.tscn")
const SETTINGS_SCENE = preload("res://UI/settings_menu.tscn")
var settings_instance: CanvasLayer = null
var battle_ended: bool = false

func _ready() -> void:
	# Load battle data:
	battleData = Global.battle
	# Load assets:
	$Background.texture = battleData.background
	$Background.scale = battleData.scale
	RenderingServer.set_default_clear_color(Color.BLACK)
	$Background.modulate.a = battleData.opacity
	battle_music.stream = battleData.battleMusic
	battle_music.play()
	# Load allies:
	load_battlers(battleData.allies, ALLY_BATTLER, $AllySpawnCircle)
	# Load enemies:
	load_battlers(battleData.enemies, ENEMY_BATTLER, $EnemySpawnCircle)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	setup_button_sounds(%SettingsButton)
	SignalBus.display_text.connect(display_text)
	SignalBus.cursor_come_to_me.connect(on_cursor_come_to_me)
	SignalBus.battle_won.connect(on_battle_won)
	SignalBus.battle_lost.connect(on_battle_lost)
	ScreenFade.fade_into_game()
	
	round_label.text = "Round " + str(Global.current_round)
	
	rename_enemies()
	let_battlers_decide_actions()

func rename_enemies() -> void:
	# Dict to keep track of num of repeated enemies:
	var names: Dictionary = {}
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: EnemyBattler in enemies:
		if enemy.name_ in names:
			enemy.name_ += " " + str(names[enemy.name_] + 1)
			var temp: String = enemy.name_
			var formated: String = temp.erase(len(temp) - 2, 2)
			names[formated] += 1
			if names[formated] == 2:
				for enemy_: EnemyBattler in enemies:
					if enemy_.name_ == formated:
						enemy_.name_ += " 1"
						break
		else:
			names[enemy.name_] = 1
			enemy.name_ = enemy.name_ 

@warning_ignore("shadowed_variable")
func load_battlers(battlers: Array, battlerFile: PackedScene, circle: Marker2D) -> void:
	for i: int in range(len(battlers)):
		var allyScene: Battler = battlerFile.instantiate()
		var stats = battlers[i].duplicate()
		
		# Stats Scaling Logic
		if stats is EnemyStats:
			var multiplier: float = Global.get_current_difficulty_multiplier()
			stats.health = int(stats.health * multiplier)
			stats.strength = int(stats.strength * multiplier)
			stats.magicStrength = int(stats.magicStrength * multiplier)
		
		allyScene.stats = stats
		$Battlers.add_child(allyScene)
		var all: int = battlers.size()
		@warning_ignore("integer_division")
		var calc: float = 360 / all
		circle.rotation_degrees = calc * i
		if battlers.size() == 1:
			allyScene.global_position = circle.global_position
		else:
			allyScene.global_position = circle.get_node("SpawnPoint").global_position

func _input(event: InputEvent) -> void:
	if settings_instance != null and settings_instance.visible:
		return

	var btn_clicked: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("left_click")
	if btn_clicked and text_window.visible:
		text_window.hide()
		SignalBus.text_window_closed.emit()

func let_battlers_decide_actions() -> void:
	if battle_ended: return
	for battler: Battler in battlers:
		if battler.isDefeated: continue
		battler.set_process(true)
		battler.decide_action()
		await battler.deciding_finished
		battler.set_process(false)
	battlersSortedSpeed.clear()
	battlersSortedSpeed = battlers.duplicate()
	battlersSortedSpeed.sort_custom(sort_battlers_by_speed)
	let_battlers_perform_action()

func sort_battlers_by_speed(a: Battler, b: Battler) -> bool:
	if a.speed > b.speed:
		return true
	return false

# --- REFACTORED TURN LOGIC ---
var current_battler_index: int = 0

func let_battlers_perform_action() -> void:
	if battle_ended: return
	
	current_battler_index = 0
	process_next_battler()

func process_next_battler() -> void:
	if battle_ended: return
	
	# Check if we are done with all battlers
	if current_battler_index >= battlersSortedSpeed.size():
		print("DEBUG: All battlers finished. Ending turn phase.")
		finish_turn_phase()
		return
		
	var battler: Battler = battlersSortedSpeed[current_battler_index]
	print("DEBUG: Processing battler " + battler.name + " (Index: " + str(current_battler_index) + ")")
	
	if battler.isDefeated:
		current_battler_index += 1
		process_next_battler()
		return

	battler.set_process(true)
	battler.perform_action()
	
	# Wait for this specific battler to finish
	await battler.performing_action_finished
	print("DEBUG: Battler " + battler.name + " finished action.")
	
	battler.set_process(false)
	current_battler_index += 1
	process_next_battler() # Recursively call next

func finish_turn_phase() -> void:
	free_defeated_battlers()
	await get_tree().create_timer(0.01).timeout 
	let_battlers_decide_actions()
# -----------------------------

func free_defeated_battlers() -> void:
	for battler: Battler in battlers:
		if battler.isDefeated:
			battler.remove_from_group("enemies")
			battler.remove_from_group("allies")
			battler.reparent(self)
			battler.anim.play("fade_out")
	await get_tree().create_timer(0.01).timeout 
	battlers.clear()
	battlers = $Battlers.get_children()

func display_text(text: String) -> void:
	text_window.show()
	text_label.text = text

func on_cursor_come_to_me(my_position: Vector2, is_ally: bool) -> void:
	var offset: Vector2
	if is_ally:
		$Cursor/AnimationPlayer.play("point_at_ally")
		offset = Vector2(-32, 32)
	else:
		$Cursor/AnimationPlayer.play("point_at_enemy")
		offset = Vector2(32, 32)
	var finalValue: Vector2 = my_position + offset
	var tween: Tween = get_tree().create_tween()
	tween.tween_property($Cursor, "global_position", finalValue, 0.1)

func calculate_loot() -> int:
	var total_reward: int = 0
	var multiplier: float = Global.get_current_difficulty_multiplier()
	for enemy_stats: EnemyStats in battleData.enemies:
		var scaled_health = enemy_stats.health * multiplier
		var scaled_strength = enemy_stats.strength * multiplier
		var scaled_magic = enemy_stats.magicStrength * multiplier
		var coin_value = (scaled_health * 0.1) + (scaled_strength * 0.2) + (scaled_magic * 0.2)
		total_reward += int(coin_value)
	return max(10, total_reward)

# --- NEW HELPER ---
func get_party_leader_name() -> String:
	if battleData and battleData.allies.size() > 0:
		return battleData.allies[0].name 
	return "Unknown"

func on_battle_won() -> void:
	if battle_ended: return
	battle_ended = true
	$Cursor/AnimationPlayer.play("fade")
	
	var coins_earned = calculate_loot()
	Global.coins += coins_earned
	Global.current_round += 1
	
	# --- NEW: Update Lifetime Stats ---
	Global.update_lifetime_stats(Global.current_round, coins_earned)
	# ----------------------------------
	
	Global.save_game()
	
	# --- NEW: Upload Win Stats (Use Lifetime Values) ---
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())
	# -----------------------------
	
	var reward_text = "Battle Won!\n\nLoot Found:\n" + str(coins_earned) + " Coins"
	SignalBus.display_text.emit(reward_text)
	
	battle_music.playing = false
	Audio.won.play()
	
	await SignalBus.text_window_closed
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://UI/upgrade_menu.tscn")

func reset_stats() -> void:
	for stats: AllyStats in battleData.allies:
		match stats.name:
			"Blake":
				stats.body = 1
				stats.mind = 3
				stats.spirit = 4
			"Michael":
				stats.body = 3
				stats.mind = 4
				stats.spirit = 1
			"Mitchell":
				stats.body = 4
				stats.mind = 2
				stats.spirit = 2

func on_battle_lost() -> void:
	if battle_ended: return
	battle_ended = true
	$Cursor/AnimationPlayer.play("fade")
	
	# --- NEW: Upload Loss Stats (Use Lifetime Values) ---
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())
	# ------------------------------

	SignalBus.display_text.emit("Battle lost...")
	Audio.lost.play()
	
	Global.current_round = Global.starting_round
	Global.save_game()
	
	reset_stats()
	await SignalBus.text_window_closed
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("uid://0xc8hpp1566k")

func _on_settings_button_pressed() -> void:
	Audio.btn_pressed.play()
	if settings_instance == null:
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		settings_instance.closed.connect(_on_settings_closed)
		settings_instance.end_run_requested.connect(_on_end_run_requested)
	
	settings_instance.enable_battle_mode()
	settings_instance.show()
	%SettingsButton.release_focus()

func _on_end_run_requested() -> void:
	SignalBus.battle_lost.emit()

func _on_settings_closed() -> void:
	pass

func setup_button_sounds(button: Button) -> void:
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
