extends Node

@onready var battlers := $Battlers.get_children()
@onready var text_window: PanelContainer = $TextWindow
@onready var text_label: Label = $TextWindow/Label
@onready var battle_music: AudioStreamPlayer = $BattleMusic

@export var battleData: BattleData
var battlersSortedSpeed: Array

const ALLY_BATTLER = preload("res://ally_battler/ally_battler.tscn")
const ENEMY_BATTLER = preload("res://enemy_battler/enemy_battler.tscn")
const SETTINGS_SCENE = preload("res://UI/settings_menu.tscn")
var settings_instance: CanvasLayer = null

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
	rename_enemies()
	let_battlers_decide_actions()

func rename_enemies() -> void:
	# Dict to keep track of num of repeated enemies:
	var names: Dictionary = {}
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy: EnemyBattler in enemies:
		# Check if this enemy is repeated:
		if enemy.name_ in names:
			# It's repeated: Add a number to it's name
			enemy.name_ += " " + str(names[enemy.name_] + 1)
			var temp: String = enemy.name_
			var formated: String = temp.erase(len(temp) - 2, 2)
			# Increase the count of this repeated enemy
			names[formated] += 1
			# Special case where we rename the 1st duplicated enemy:
			if names[formated] == 2:
				# Find the enemy:
				for enemy_: EnemyBattler in enemies:
					if enemy_.name_ == formated:
						enemy_.name_ += " 1"
						break
		# 1st time seeing this enemy:
		else:
			names[enemy.name_] = 1
			enemy.name_ = enemy.name_ # Force label to update.

@warning_ignore("shadowed_variable")
func load_battlers(battlers: Array, battlerFile: PackedScene, circle: Marker2D) -> void:
	for i: int in range(len(battlers)):
		var allyScene: Battler = battlerFile.instantiate()
		allyScene.stats = battlers[i]
		$Battlers.add_child(allyScene)
		var all: int = battlers.size()
		@warning_ignore("integer_division")
		var calc: float = 360 / all
		circle.rotation_degrees = calc * i
		# Spawn Battler in the middle if there's only 1:
		if battlers.size() == 1:
			allyScene.global_position = circle.global_position
		else:
			allyScene.global_position = circle.get_node("SpawnPoint").global_position

func _input(event: InputEvent) -> void:
	# Ignore input if the settings menu is currently open
	if settings_instance != null and settings_instance.visible:
		return

	var btn_clicked: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("left_click")
	if btn_clicked and text_window.visible:
		text_window.hide()
		SignalBus.text_window_closed.emit()

func let_battlers_decide_actions() -> void:
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

func let_battlers_perform_action() -> void:
	for battler: Battler in battlersSortedSpeed:
		if battler.isDefeated: continue
		battler.set_process(true)
		battler.perform_action()
		await battler.performing_action_finished
		battler.set_process(false)
	free_defeated_battlers()
	await get_tree().create_timer(0.01).timeout # Wait till all are freed.
	let_battlers_decide_actions()

func free_defeated_battlers() -> void:
	for battler: Battler in battlers:
		if battler.isDefeated:
			battler.remove_from_group("enemies")
			battler.remove_from_group("allies")
			battler.reparent(self)
			battler.anim.play("fade_out")
	await get_tree().create_timer(0.01).timeout #Wait till all are freed.
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

# --- REWARD CALCULATION ---
func calculate_loot() -> int:
	var total_reward: int = 0
	# Iterate over the enemy stats in the battle data to calculate reward
	for enemy_stats: EnemyStats in battleData.enemies:
		# Formula: 10% of HP + 20% of Strength + 20% of Magic Strength
		# Example: 120 HP, 50 Str = 12 + 10 = 22 coins per enemy
		var coin_value = (enemy_stats.health * 0.1) + (enemy_stats.strength * 0.2) + (enemy_stats.magicStrength * 0.2)
		total_reward += int(coin_value)
	
	# Minimum 10 coins just in case
	return max(10, total_reward)

func on_battle_won() -> void:
	$Cursor/AnimationPlayer.play("fade")
	
	# 1. Calculate Rewards
	var coins_earned = calculate_loot()
	Global.coins += coins_earned
	Global.save_game() # Save immediately
	
	# 2. Display Rewards Pop-up
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
	$Cursor/AnimationPlayer.play("fade")
	SignalBus.display_text.emit("Battle lost...")
	Audio.lost.play()
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
		
		# --- NEW: Connect the End Run signal ---
		settings_instance.end_run_requested.connect(_on_end_run_requested)
	
	# --- NEW: Show the End Run button since we are in battle ---
	settings_instance.enable_battle_mode()
	
	settings_instance.show()
	%SettingsButton.release_focus()

# Define what happens when the player confirms "End Run"
func _on_end_run_requested() -> void:
	on_battle_lost()

func _on_settings_closed() -> void:
		pass

func setup_button_sounds(button: Button) -> void:
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
