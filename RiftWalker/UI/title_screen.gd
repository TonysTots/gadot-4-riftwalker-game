extends CanvasLayer

# --- SCENES ---
const SETTINGS_SCENE: PackedScene = preload("res://UI/settings_menu.tscn")
const LEADERBOARD_SCENE: PackedScene = preload("res://UI/leaderboard_menu.tscn")
const BATTLE_LABEL_SCENE: PackedScene = preload("uid://cotypm82phjd3")
const UPGRADE_MENU_SCENE: String = "res://UI/upgrade_menu.tscn"
const MAP_SCREEN_SCENE: String = "res://UI/map_screen.tscn"
const MAP_SCREEN_UID: String = "uid://p86u62q8dtxq"
const TITLE_SCREEN_UID: String = "uid://0xc8hpp1566k"

# --- NODES ---
@onready var choose_battle_panel: NinePatchRect = $ChooseBattle 
@onready var battle_list_container: VBoxContainer = $ChooseBattle/BattleList
@onready var start_game_button: Button = %StartGameButton
@onready var shop_button: Button = %ShopButton
@onready var settings_button: Button = %SettingsButton
@onready var login_button: Button = %LoginButton
@onready var quit_button: Button = %QuitButton
@onready var back_button: Button = %BackButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var login_menu: Control = $LoginMenu

# --- DATA ---
var battles: Array[BattleData] = []
var index: int = 0:
	set(val):
		if val < 0 or val >= battles.size(): return
		
		# Visual Update
		if battle_list_container.get_child_count() > index:
			var labelToUnfocus: Label = battle_list_container.get_child(index) as Label
			labelToUnfocus.modulate.a = 0.5
			
		index = val
		
		if battle_list_container.get_child_count() > index:
			var labelToFocus: Label = battle_list_container.get_child(index) as Label
			labelToFocus.modulate.a = 1.0

var is_selecting_battle: bool = false
var settings_instance: CanvasLayer = null
var leaderboard_instance: Control = null

func _ready() -> void:
	choose_battle_panel.hide() 
	Global.map_data = null # Ensure we are not "in a run" logic-wise
	
	_connect_signals()
	_setup_buttons()
	_load_battles()
	_create_battle_list()
	
	ScreenFade.fade_into_game()
	start_game_button.grab_focus()
	
	# Check for Resume
	if Global.run_in_progress:
		start_game_button.text = "Continue Run"
	else:
		start_game_button.text = "Start Game"
	
	_handle_auto_login()

func _connect_signals() -> void:
	SignalBus.label_index_changed.connect(
		func(newIndex: int) -> void: sorted_index_changed(newIndex)
	)
	SignalBus.selected_label.connect(begin_battle)
	AuthManager.login_success.connect(_on_login_success)

func sorted_index_changed(newIndex: int) -> void:
	index = newIndex

func _setup_buttons() -> void:
	setup_button_sounds(start_game_button)
	setup_button_sounds(shop_button)
	setup_button_sounds(settings_button)
	setup_button_sounds(login_button)
	setup_button_sounds(quit_button)
	if leaderboard_button:
		setup_button_sounds(leaderboard_button)
	
	if not start_game_button.pressed.is_connected(_on_start_game_button_pressed):
		start_game_button.pressed.connect(_on_start_game_button_pressed)
	if not settings_button.pressed.is_connected(_on_settings_button_pressed):
		settings_button.pressed.connect(_on_settings_button_pressed)
	if not shop_button.pressed.is_connected(_on_shop_button_pressed):
		shop_button.pressed.connect(_on_shop_button_pressed)
	if not login_button.pressed.is_connected(_on_login_button_pressed):
		login_button.pressed.connect(_on_login_button_pressed)
	if not quit_button.pressed.is_connected(_on_quit_button_pressed):
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	if leaderboard_button and not leaderboard_button.pressed.is_connected(_on_leaderboard_button_pressed):
		leaderboard_button.pressed.connect(_on_leaderboard_button_pressed)

	if back_button: 
		setup_button_sounds(back_button)
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)

func _load_battles() -> void:
	var dir = DirAccess.open("res://battle_data/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
				# Trim .remap for exported builds
				var resource_path = "res://battle_data/" + file_name.replace(".remap", "")
				var battle: BattleData = load(resource_path)
				if battle:
					battles.append(battle)
			file_name = dir.get_next()
	else:
		push_error("Could not access res://battle_data/")

func _create_battle_list() -> void:
	for battle in battles:
		var label: Label = BATTLE_LABEL_SCENE.instantiate()
		label.text = battle.battleName
		label.modulate.a = 0.5 # Default dim
		battle_list_container.add_child(label)
	
	# Focus first if exists
	if not battles.is_empty():
		index = 0

func _handle_auto_login() -> void:
	if Global.current_username != "":
		login_button.text = "Logging in..."
		AuthManager.login(Global.current_username)

func _on_login_success(user_data: Dictionary) -> void:
	if user_data.has("username"):
		login_button.text = "Profile: " + user_data["username"]
		login_button.disabled = false 

# --- BATTLE SELECTION LOGIC ---

func begin_battle() -> void:
	Audio.btn_pressed.play()
	
	# Initialize round
	Global.current_round = Global.starting_round
	if index < battles.size():
		Global.battle = battles[index]
	
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	
	# Check for Starting Round Bonus
	if Global.starting_round > 1:
		Global.upgrade_points_pending = Global.starting_round - 1
		get_tree().change_scene_to_file(UPGRADE_MENU_SCENE)
	else:
		Global.upgrade_points_pending = 1
		get_tree().change_scene_to_file(MAP_SCREEN_UID)

# --- INPUT ---

func _input(event: InputEvent) -> void:
	if is_selecting_battle:
		if event.is_action_pressed("ui_down"):
			index += 1
		elif event.is_action_pressed("ui_up"):
			index -= 1
		elif event.is_action_pressed("ui_accept"):
			begin_battle()
		elif event.is_action_pressed("ui_cancel"):
			_on_back_button_pressed()

# --- UI EVENTS ---

func _on_start_game_button_pressed() -> void:
	Audio.btn_pressed.play()
	
	# CONTINUE LOGIC
	if Global.run_in_progress:
		ScreenFade.fade_into_black()
		await get_tree().create_timer(0.5).timeout
		
		# Resume directly to map or upgrade
		if Global.upgrade_points_pending > 0:
			get_tree().change_scene_to_file(UPGRADE_MENU_SCENE)
		else:
			get_tree().change_scene_to_file(MAP_SCREEN_SCENE)
		return

	# NEW GAME LOGIC
	Global.run_in_progress = true # Start Run
	Global.pending_allies_data.clear() # Discard old save data
	
	# Reset map data for a new run
	Global.map_data = null 
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	
	# Run Initialization
	Global.map_base_difficulty = Global.starting_round
	Global.current_round = Global.starting_round
	
	var initial_points: int = 1
	if Global.starting_round > 1:
		initial_points = Global.starting_round
		
	# Reset Party Points
	# TODO: Hardcoded names are brittle. Ideally load from starter roster resource.
	Global.party_points = {
		"Blake": initial_points,
		"Michael": initial_points,
		"Mitchell": initial_points
	}
	
	# Reset Character Stats to Base
	var party_paths: Array[String] = [
		"res://stats/ally_stats/blake.tres",
		"res://stats/ally_stats/michael.tres",
		"res://stats/ally_stats/mitchell.tres"
	]
	
	for path in party_paths:
		var ally_stats: AllyStats = load(path)
		if ally_stats:
			ally_stats.reset_to_base()
	
	Global.save_game() # Save initial state
	
	if Global.starting_round > 1:
		get_tree().change_scene_to_file(UPGRADE_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(MAP_SCREEN_SCENE)

func _on_back_button_pressed() -> void:
	Audio.btn_pressed.play()
	choose_battle_panel.hide()
	is_selecting_battle = false
	start_game_button.grab_focus()

func _on_shop_button_pressed() -> void:
	Audio.btn_pressed.play()
	get_tree().change_scene_to_file("res://UI/shop_menu.tscn")

func _on_settings_button_pressed() -> void:
	Audio.btn_pressed.play()
	if settings_instance == null:
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		settings_instance.closed.connect(_on_settings_closed)
	
	settings_instance.show()
	start_game_button.release_focus()

func _on_settings_closed() -> void:
	start_game_button.grab_focus()

func _on_login_button_pressed() -> void:
	Audio.btn_pressed.play() 
	login_menu.show()  

func _on_quit_button_pressed() -> void:
	Audio.btn_pressed.play()
	get_tree().quit()

func _on_leaderboard_button_pressed() -> void:
	Audio.btn_pressed.play()
	if leaderboard_instance == null:
		leaderboard_instance = LEADERBOARD_SCENE.instantiate()
		add_child(leaderboard_instance)
	
	leaderboard_instance.show()

# --- UTILS ---

func setup_button_sounds(button: Button) -> void:
	if not button: return
	button.focus_entered.connect(func() -> void: Audio.btn_mov.play())
	button.mouse_entered.connect(func() -> void: Audio.btn_mov.play())
