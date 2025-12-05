extends CanvasLayer

var battles: Array[BattleData] 
@onready var ui_box: NinePatchRect = $UIBox
@onready var label_container: VBoxContainer = $UIBox/LabelContainer

var index: int = 0:
	set(val):
		if val < 0 or val >= battles.size(): return
		var labelToUnfocus: Label = label_container.get_child(index)
		labelToUnfocus.modulate.a = 0.5
		index = val
		var labelToFocus: Label = label_container.get_child(index)
		labelToFocus.modulate.a = 1
var isSelecting: bool = false

const SETTINGS_SCENE = preload("res://UI/settings_menu.tscn")
var settings_instance: CanvasLayer = null

func _ready() -> void:
	$UIBox.hide()
	SignalBus.label_index_changed.connect(
		func(newIndex: int) -> void:
			index = newIndex
	)
	SignalBus.selected_label.connect(begin_battle)
	
	setup_button_sounds(%StartGameButton)
	setup_button_sounds(%SettingsButton)
	setup_button_sounds(%QuitButton)
	
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
		label_container.add_child(label)
	#Begin selecting battle:
	index = 0
	
	%StartGameButton.pressed.connect(_on_start_game_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)

func begin_battle() -> void:
	Global.battle = battles[index]
	ScreenFade.fade_into_black()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("uid://p86u62q8dtxq")

func _input(event: InputEvent) -> void:
	if isSelecting:
		if event.is_action_pressed("ui_down"):
			index += 1
		elif event.is_action_pressed("ui_up"):
			index -= 1
		elif event.is_action_pressed("ui_accept"):
			begin_battle()

func _on_start_game_button_pressed() -> void:
	Audio.btn_pressed.play()
	ui_box.show()
	isSelecting = true
	%StartGameButton.release_focus()

func _on_settings_button_pressed() -> void:
	Audio.btn_pressed.play()
	if settings_instance == null:
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		# Listen for when the menu closes to return focus
		settings_instance.closed.connect(_on_settings_closed)
	
	settings_instance.show()
	%StartGameButton.release_focus()

func _on_settings_closed() -> void:
	%StartGameButton.grab_focus()

func _on_quit_button_pressed() -> void:
	Audio.btn_pressed.play()
	get_tree().quit()

func setup_button_sounds(button: Button) -> void:
	# Play sound when selected via Keyboard/Controller
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	# Play sound when hovered via Mouse
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
