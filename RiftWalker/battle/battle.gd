extends Node

# --- NODES ---
@onready var battlers_node: Node = $Battlers
@onready var text_window: PanelContainer = $TextWindow
@onready var text_label: Label = $TextWindow/Label
@onready var battle_music: AudioStreamPlayer = $BattleMusic
@onready var round_label: Label = %RoundLabel
@onready var cursor: Node2D = $Cursor
@onready var background: Sprite2D = $Background
@onready var settings_button: Button = %SettingsButton

# --- MANAGERS ---
var turn_manager: TurnManager
var loot_manager: LootManager

# --- DATA ---
@export var battleData: BattleData
const ALLY_BATTLER_SCENE: PackedScene = preload("res://ally_battler/ally_battler.tscn")
const ENEMY_BATTLER_SCENE: PackedScene = preload("res://enemy_battler/enemy_battler.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://UI/settings_menu.tscn")

var settings_instance: CanvasLayer = null
var battle_ended: bool = false

# --- JUICE ---
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var camera: Camera2D

func _ready() -> void:
	_init_managers()
	_load_battle_data()
	_setup_ui()
	_setup_juice()
	
	# Start
	start_new_turn()

func _init_managers() -> void:
	turn_manager = TurnManager.new()
	loot_manager = LootManager.new()
	add_child(turn_manager)
	add_child(loot_manager)
	
	turn_manager.turn_phase_finished.connect(_on_turn_phase_finished)

func _load_battle_data() -> void:
	battleData = Global.battle
	
	# Visuals
	if battleData:
		background.texture = battleData.background
		background.scale = battleData.scale
		RenderingServer.set_default_clear_color(Color.BLACK)
		background.modulate.a = battleData.opacity
	
	_setup_music()
	
	# Spawn
	if battleData:
		_spawn_battlers(battleData.allies, ALLY_BATTLER_SCENE, $AllySpawnCircle)
		_spawn_battlers(battleData.enemies, ENEMY_BATTLER_SCENE, $EnemySpawnCircle)
	
	rename_enemies()

func _setup_music() -> void:
	var music_stream: AudioStream = battleData.battleMusic if battleData else null
	
	# Boss Override
	if Global.map_data:
		var node: MapNode = Global.map_data.get_node(Global.map_data.current_node_grid_pos)
		if node and node.type == MapNode.Type.BOSS:
			music_stream = load("res://assets/music/boss_battle.mp3")
			
	if music_stream:
		battle_music.stream = music_stream
		battle_music.play()

func _setup_ui() -> void:
	settings_button.pressed.connect(_on_settings_button_pressed)
	setup_button_sounds(settings_button)
	
	SignalBus.display_text.connect(display_text)
	SignalBus.cursor_come_to_me.connect(on_cursor_come_to_me)
	SignalBus.battle_won.connect(on_battle_won)
	SignalBus.battle_lost.connect(on_battle_lost)
	
	ScreenFade.fade_into_game()
	
	round_label.text = "Round " + str(Global.current_round)

func _setup_juice() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(288, 162) # Center
	add_child(camera)
	
	if SignalBus.has_signal("request_camera_shake"):
		SignalBus.request_camera_shake.connect(_on_request_camera_shake)
	if SignalBus.has_signal("request_hit_stop"):
		SignalBus.request_hit_stop.connect(_on_request_hit_stop)

func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)

# --- TURN LOGIC ---

func start_new_turn() -> void:
	if battle_ended: return
	turn_manager.start_turn(battlers_node.get_children())

func _on_turn_phase_finished() -> void:
	free_defeated_battlers()
	await get_tree().create_timer(0.01).timeout 
	start_new_turn() 

# --- VICTORY / DEFEAT ---

func on_battle_won() -> void:
	if battle_ended: return
	battle_ended = true
	turn_manager.set_battle_ended(true)
	
	cursor.get_node("AnimationPlayer").play("fade")
	
	# 1. Progression
	var coins_earned: int = loot_manager.calculate_loot(battleData.enemies, Global.get_current_difficulty_multiplier())
	_handle_progression_rewards(coins_earned)
	
	# 2. Upload
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())
	
	# 3. UI Feedback
	var reward_text: String = "Battle Won!\n\nLoot Found:\n" + str(coins_earned) + " Coins"
	SignalBus.display_text.emit(reward_text)
	
	battle_music.stop()
	Audio.won.play()
	
	await SignalBus.text_window_closed
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	
	# 4. Victory Condition (End Game)
	if Global.current_round >= 999: 
		Global.run_in_progress = false
		Global.save_game()
		get_tree().change_scene_to_file("res://UI/credits.tscn")
	else:
		Global.battle_round_offset = 0
		Global.save_game() # Save progress
		get_tree().change_scene_to_file("res://UI/map_screen.tscn")

func on_battle_lost() -> void:
	if battle_ended: return
	battle_ended = true
	turn_manager.set_battle_ended(true)
	
	Global.run_in_progress = false
	Global.save_game()
	
	cursor.get_node("AnimationPlayer").play("fade")
	
	# Run Upload
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())

	SignalBus.display_text.emit("Battle lost...")
	Audio.lost.play()
	
	# Reset Run
	Global.current_round = Global.starting_round
	Global.save_game()
	
	_reset_party_stats_generic() 
	
	Global.battle_round_offset = 0
	await SignalBus.text_window_closed
	
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("uid://0xc8hpp1566k") # Title Screen

# --- PROGRESSION HELPERS ---

func _handle_progression_rewards(coins: int) -> void:
	Global.coins += coins
	Global.current_round += 1
	
	# Update Map
	if Global.map_data:
		var current_x: int = int(Global.map_data.current_node_grid_pos.x)
		if current_x > Global.map_data.max_reached_layer:
			Global.map_data.max_reached_layer = current_x
	
	# Upgrade Points
	var points_to_add: int = 1
	if Global.map_data:
		var node: MapNode = Global.map_data.get_node(Global.map_data.current_node_grid_pos)
		if node and node.type == MapNode.Type.BOSS:
			points_to_add = 5
			
	for ally in battleData.allies:
		if ally.name in Global.party_points:
			Global.party_points[ally.name] += points_to_add
		else:
			Global.party_points[ally.name] = points_to_add
	
	Global.update_lifetime_stats(Global.current_round, coins)

## Generic reset that doesn't hardcode names. Resets to base 1/1/1 or similar.
func _reset_party_stats_generic() -> void:
	for stats: AllyStats in battleData.allies:
		# Reset to a base baseline. 
		# Ideally this should read from a "Default" resource, but setting to 1 is better than hardcoding names.
		stats.body = 1
		stats.mind = 1
		stats.spirit = 1
		# Note: This affects the Resource on disk if it's not a duplicate. 
		# Since these appear to be the master resources, this is a PERMANENT reset (Roguelike).

# --- SPAWNING ---

func _spawn_battlers(data_list: Array, battler_scene: PackedScene, circle: Marker2D) -> void:
	for i: int in range(len(data_list)):
		var battler: Battler = battler_scene.instantiate()
		var data_item = data_list[i]
		var stats = null
		
		# Resource Handling:
		# AllyStats: PERSISTENT. Do NOT duplicate.
		# EnemyStats: UNIQUE per battle. Duplicate.
		if data_item is AllyStats:
			stats = data_item 
		else:
			stats = data_item.duplicate()
		
		# Scaling for Enemies
		if stats is EnemyStats:
			var multiplier: float = Global.get_current_difficulty_multiplier()
			stats.health = int(stats.health * multiplier)
			stats.strength = int(stats.strength * multiplier)
			stats.magicStrength = int(stats.magicStrength * multiplier)
		
		if battler is AllyBattler:
			battler.stats = stats
		elif battler is EnemyBattler:
			battler.stats = stats
			
		battlers_node.add_child(battler)
		
		# Position
		var count: int = data_list.size()
		var calc: float = 360.0 / float(count) # Explict float
		circle.rotation_degrees = calc * i
		if count == 1:
			battler.global_position = circle.global_position
		else:
			battler.global_position = circle.get_node("SpawnPoint").global_position

func rename_enemies() -> void:
	var names: Dictionary = {}
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: EnemyBattler in enemies:
		if enemy.name_ in names:
			enemy.name_ += " " + str(names[enemy.name_] + 1)
			# Formatting logic preserved...
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

func free_defeated_battlers() -> void:
	for battler: Battler in battlers_node.get_children():
		if battler.isDefeated:
			battler.remove_from_group("enemies")
			battler.remove_from_group("allies")
			battler.reparent(self)
			battler.anim.play("fade_out")

# --- UI EVENTS ---

func display_text(text: String) -> void:
	text_window.show()
	text_label.text = text

func on_cursor_come_to_me(my_position: Vector2, is_ally: bool) -> void:
	var offset: Vector2
	if is_ally:
		cursor.get_node("AnimationPlayer").play("point_at_ally")
		offset = Vector2(-32, 32)
	else:
		cursor.get_node("AnimationPlayer").play("point_at_enemy")
		offset = Vector2(32, 32)
	
	var finalValue: Vector2 = my_position + offset
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(cursor, "global_position", finalValue, 0.1)

func _input(event: InputEvent) -> void:
	if settings_instance != null and settings_instance.visible:
		return

	var btn_clicked: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("left_click")
	if btn_clicked and text_window.visible:
		text_window.hide()
		SignalBus.text_window_closed.emit()

func _on_settings_button_pressed() -> void:
	Audio.btn_pressed.play()
	if settings_instance == null:
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		settings_instance.closed.connect(_on_settings_closed)
		settings_instance.end_run_requested.connect(_on_end_run_requested)
	
	settings_instance.enable_battle_mode()
	settings_instance.show()
	settings_button.release_focus()

func _on_end_run_requested() -> void:
	on_battle_lost()

func _on_settings_closed() -> void:
	pass # Resume?

# --- JUICE EVENTS ---

func _on_request_camera_shake(intensity: float, duration: float) -> void:
	shake_strength = intensity
	shake_decay = 5.0 / duration

func _on_request_hit_stop(time_scale: float, duration: float) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0

# --- UTILS ---

func get_party_leader_name() -> String:
	if battleData and battleData.allies.size() > 0:
		return battleData.allies[0].name 
	return "Unknown"

func setup_button_sounds(button: Button) -> void:
	button.focus_entered.connect(Audio.btn_mov.play)
	button.mouse_entered.connect(Audio.btn_mov.play)
