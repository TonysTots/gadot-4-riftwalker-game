extends Node

@onready var battlers_node := $Battlers
@onready var text_window: PanelContainer = $TextWindow
@onready var text_label: Label = $TextWindow/Label
@onready var battle_music: AudioStreamPlayer = $BattleMusic
@onready var round_label: Label = %RoundLabel

# --- MANAGERS ---
var turn_manager: TurnManager
var loot_manager: LootManager
# ----------------

@export var battleData: BattleData

const ALLY_BATTLER = preload("res://ally_battler/ally_battler.tscn")
const ENEMY_BATTLER = preload("res://enemy_battler/enemy_battler.tscn")
const SETTINGS_SCENE = preload("res://UI/settings_menu.tscn")
var settings_instance: CanvasLayer = null
var battle_ended: bool = false

# --- JUICE LOGIC ---
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var camera: Camera2D

func _ready() -> void:
	# Initialize Managers
	turn_manager = TurnManager.new()
	loot_manager = LootManager.new()
	add_child(turn_manager)
	add_child(loot_manager)
	
	# Connect Signals
	turn_manager.turn_phase_finished.connect(_on_turn_phase_finished)

	# Load battle data:
	battleData = Global.battle
	
	# Load assets:
	$Background.texture = battleData.background
	$Background.scale = battleData.scale
	RenderingServer.set_default_clear_color(Color.BLACK)
	$Background.modulate.a = battleData.opacity
	battle_music.stream = battleData.battleMusic
	battle_music.play()
	
	# Load battlers:
	load_battlers(battleData.allies, ALLY_BATTLER, $AllySpawnCircle)
	load_battlers(battleData.enemies, ENEMY_BATTLER, $EnemySpawnCircle)
	
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	setup_button_sounds(%SettingsButton)
	SignalBus.display_text.connect(display_text)
	SignalBus.cursor_come_to_me.connect(on_cursor_come_to_me)
	SignalBus.battle_won.connect(on_battle_won)
	SignalBus.battle_lost.connect(on_battle_lost)
	ScreenFade.fade_into_game()
	
	round_label.text = "Round " + str(Global.current_round)
	
	# Juice Setup
	camera = Camera2D.new()
	camera.position = Vector2(288, 162)
	add_child(camera)
	
	if SignalBus.has_signal("request_camera_shake"):
		SignalBus.request_camera_shake.connect(_on_request_camera_shake)
	if SignalBus.has_signal("request_hit_stop"):
		SignalBus.request_hit_stop.connect(_on_request_hit_stop)
	
	rename_enemies()
	
	# Start the loop
	start_new_turn()

func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if camera:
			camera.offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)

func _on_request_camera_shake(intensity: float, duration: float) -> void:
	shake_strength = intensity
	shake_decay = 5.0 / duration

func _on_request_hit_stop(time_scale: float, duration: float) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration * time_scale).timeout
	Engine.time_scale = 1.0

# --- TURN LOGIC DELEGATION ---
func start_new_turn() -> void:
	if battle_ended: return
	turn_manager.start_turn(battlers_node.get_children())

func _on_turn_phase_finished() -> void:
	free_defeated_battlers()
	await get_tree().create_timer(0.01).timeout 
	start_new_turn() 

func on_battle_won() -> void:
	if battle_ended: return
	battle_ended = true
	turn_manager.set_battle_ended(true) # Stop turn logic
	
	$Cursor/AnimationPlayer.play("fade")
	
	# Use Manager
	var coins_earned = loot_manager.calculate_loot(battleData.enemies, Global.get_current_difficulty_multiplier())
	
	Global.coins += coins_earned
	Global.current_round += 1
	Global.update_lifetime_stats(Global.current_round, coins_earned)
	Global.save_game()
	
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())
	
	var reward_text = "Battle Won!\n\nLoot Found:\n" + str(coins_earned) + " Coins"
	SignalBus.display_text.emit(reward_text)
	
	battle_music.playing = false
	Audio.won.play()
	
	await SignalBus.text_window_closed
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://UI/upgrade_menu.tscn")

func on_battle_lost() -> void:
	if battle_ended: return
	battle_ended = true
	turn_manager.set_battle_ended(true)
	
	$Cursor/AnimationPlayer.play("fade")
	
	if AuthManager:
		AuthManager.upload_run_data(Global.highest_round, Global.lifetime_coins, get_party_leader_name())

	SignalBus.display_text.emit("Battle lost...")
	Audio.lost.play()
	
	Global.current_round = Global.starting_round
	Global.save_game()
	
	reset_stats()
	await SignalBus.text_window_closed
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("uid://0xc8hpp1566k")

# --- UTILITIES ---

func free_defeated_battlers() -> void:
	for battler: Battler in battlers_node.get_children():
		if battler.isDefeated:
			battler.remove_from_group("enemies")
			battler.remove_from_group("allies")
			battler.reparent(self)
			battler.anim.play("fade_out")
	await get_tree().create_timer(0.01).timeout 

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

func load_battlers(data_list: Array, battlerFile: PackedScene, circle: Marker2D) -> void:
	for i: int in range(len(data_list)):
		var allyScene: Battler = battlerFile.instantiate()
		var stats = data_list[i].duplicate()
		
		# Stats Scaling Logic
		if stats is EnemyStats:
			var multiplier: float = Global.get_current_difficulty_multiplier()
			stats.health = int(stats.health * multiplier)
			stats.strength = int(stats.strength * multiplier)
			stats.magicStrength = int(stats.magicStrength * multiplier)
		
		allyScene.stats = stats
		battlers_node.add_child(allyScene)
		var all: int = data_list.size()
		@warning_ignore("integer_division")
		var calc: float = 360 / all
		circle.rotation_degrees = calc * i
		if data_list.size() == 1:
			allyScene.global_position = circle.global_position
		else:
			allyScene.global_position = circle.get_node("SpawnPoint").global_position

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

func get_party_leader_name() -> String:
	if battleData and battleData.allies.size() > 0:
		return battleData.allies[0].name 
	return "Unknown"

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
	%SettingsButton.release_focus()

func _on_end_run_requested() -> void:
	SignalBus.battle_lost.emit()

func _on_settings_closed() -> void:
	pass

func setup_button_sounds(button: Button) -> void:
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
