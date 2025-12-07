extends CanvasLayer

var battles: Array[BattleData] 
# UPDATED PATHS based on your renaming:
@onready var ChooseBattle: NinePatchRect = $ChooseBattle 
@onready var BattleList: VBoxContainer = $ChooseBattle/BattleList

var index: int = 0:
	set(val):
		if val < 0 or val >= battles.size(): return
		var labelToUnfocus: Label = BattleList.get_child(index)
		labelToUnfocus.modulate.a = 0.5
		index = val
		var labelToFocus: Label = BattleList.get_child(index)
		labelToFocus.modulate.a = 1
		
var isSelecting: bool = false

const SETTINGS_SCENE = preload("res://UI/settings_menu.tscn")
var settings_instance: CanvasLayer = null

func _ready() -> void:
	$ChooseBattle.hide() # Updated path
	
	SignalBus.label_index_changed.connect(
		func(newIndex: int) -> void:
			index = newIndex
	)
	SignalBus.selected_label.connect(begin_battle)
	
	setup_button_sounds(%StartGameButton)
	setup_button_sounds(%ShopButton)
	setup_button_sounds(%SettingsButton)
	setup_button_sounds(%LoginButton)
	setup_button_sounds(%QuitButton)
	
	# SETUP THE BACK BUTTON
	# Ensure you have a Button named "BackButton" inside the ChooseBattle node
	if %BackButton: 
		setup_button_sounds(%BackButton)
		%BackButton.pressed.connect(_on_back_button_pressed)
	
	ScreenFade.fade_into_game()
	%StartGameButton.grab_focus()
	
	# Load battles from disk:
	var battlePaths: PackedStringArray = DirAccess.get_files_at("res://battle_data/")
	for battlePath: String in battlePaths:
		if battlePath.ends_with(".remap"):
			battlePath = battlePath.replace(".remap", "")
		var battle: BattleData = load("res://battle_data/" + battlePath)
		battles.append(battle)
	
	#Creating labels for the battles:
	for battle: BattleData in battles:
		var label: Label = preload("uid://cotypm82phjd3").instantiate()
		label.text = battle.battleName
		BattleList.add_child(label)
	
	#Begin selecting battle:
	index = 0
	
	%StartGameButton.pressed.connect(_on_start_game_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%ShopButton.pressed.connect(_on_shop_button_pressed)

func begin_battle() -> void:
	Audio.btn_pressed.play()
	
	# Initialize round
	Global.current_round = Global.starting_round
	Global.battle = battles[index]
	
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	
	# Check for Starting Round Bonus
	if Global.starting_round > 1:
		# Give points equal to skipped rounds
		Global.upgrade_points_pending = Global.starting_round - 1
		
		# Go to Upgrade Menu first!
		get_tree().change_scene_to_file("res://UI/upgrade_menu.tscn")
	else:
		# Standard Start (Round 1)
		Global.upgrade_points_pending = 1
		get_tree().change_scene_to_file("uid://p86u62q8dtxq")

func _input(event: InputEvent) -> void:
	if isSelecting:
		if event.is_action_pressed("ui_down"):
			index += 1
		elif event.is_action_pressed("ui_up"):
			index -= 1
		elif event.is_action_pressed("ui_accept"):
			begin_battle()
		# ADDED BACK BUTTON LOGIC (Escape Key / Controller B)
		elif event.is_action_pressed("ui_cancel"):
			_on_back_button_pressed()

func _on_start_game_button_pressed() -> void:
	Audio.btn_pressed.play()
	ChooseBattle.show()
	isSelecting = true
	# We release focus so the keyboard 'ui_up/down' controls the custom label logic
	# instead of moving actual UI focus around.
	%StartGameButton.release_focus()

# NEW FUNCTION TO HANDLE GOING BACK
func _on_back_button_pressed() -> void:
	Audio.btn_pressed.play()
	ChooseBattle.hide()
	isSelecting = false
	%StartGameButton.grab_focus()

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
	%StartGameButton.release_focus()

func _on_settings_closed() -> void:
	%StartGameButton.grab_focus()

func _on_login_button_pressed() -> void:
	Audio.btn_pressed.play() 
	$LoginMenu.show()  

func _on_quit_button_pressed() -> void:
	Audio.btn_pressed.play()
	get_tree().quit()

func setup_button_sounds(button: Button) -> void:
	if not button: return
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
	# Play sound when selected via Keyboard/Controller
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	# Play sound when hovered via Mouse
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
	 
