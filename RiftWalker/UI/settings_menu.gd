extends CanvasLayer

signal closed
signal end_run_requested ## New signal to tell Battle to quit

@onready var volume_slider: HSlider = %VolumeSlider
@onready var fullscreen_check: CheckButton = %FullScreenCheck
@onready var speed_slider: HSlider = %GameSpeedSlider
@onready var speed_label: Label = %GameSpeedLabel
@onready var starting_round_slider: HSlider = %StartingRoundSlider
@onready var starting_round_label: Label = %StartingRoundLabel
@onready var end_run_btn: Button = %EndRunButton
@onready var confirm_popup: PanelContainer = $ConfirmationPopup
@onready var yes_btn: Button = %YesButton
@onready var no_btn: Button = %NoButton

var master_bus_index: int

func _ready() -> void:
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# --- INITIAL STATE ---
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	speed_slider.value = Global.game_speed
	update_speed_label(Global.game_speed)
	
	starting_round_slider.value = Global.starting_round
	update_starting_round_label(Global.starting_round)
	
	# --- LOGIC CONNECTIONS ---
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	starting_round_slider.value_changed.connect(_on_starting_round_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	
	# Back Button
	$PanelContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	
	# End Run Logic
	end_run_btn.pressed.connect(_on_end_run_pressed)
	yes_btn.pressed.connect(_on_confirm_end_run)
	no_btn.pressed.connect(func(): 
		Audio.btn_pressed.play()
		confirm_popup.hide()
	)
	
	# --- AUDIO CONNECTIONS (HOVER SOUNDS) ---
	# We apply this to every interactive element
	setup_hover_sounds(volume_slider)
	setup_hover_sounds(fullscreen_check)
	setup_hover_sounds(speed_slider)
	setup_hover_sounds(starting_round_slider)
	setup_hover_sounds($PanelContainer/VBoxContainer/BackButton)
	setup_hover_sounds(end_run_btn)
	setup_hover_sounds(yes_btn)
	setup_hover_sounds(no_btn)

# Generalized to accept any Control node (Buttons, Sliders, CheckBoxes)
func setup_hover_sounds(node: Control) -> void:
	if node:
		node.mouse_entered.connect(func(): Audio.btn_mov.play())
		node.focus_entered.connect(func(): Audio.btn_mov.play())

# Helper to play slider tick sound (prevents "machine gun" noise)
func play_slider_sound() -> void:
	if not Audio.btn_mov.playing: 
		Audio.btn_mov.play()

# Call this function when opening settings from Battle to show the button
func enable_battle_mode() -> void:
	end_run_btn.show()
	if starting_round_slider:
		starting_round_slider.hide()
	if starting_round_label:
		starting_round_label.hide()

func _on_end_run_pressed() -> void:
	Audio.btn_pressed.play()
	confirm_popup.show()
	no_btn.grab_focus()

func _on_confirm_end_run() -> void:
	Audio.btn_pressed.play()
	confirm_popup.hide()
	hide() # Hide settings menu
	end_run_requested.emit() # Tell Battle.gd to finish the run

# --- CHANGED CALLBACKS ---

func _on_volume_changed(value: float) -> void:
	play_slider_sound() # <--- Sound
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
	AudioServer.set_bus_mute(master_bus_index, value < 0.05)

func _on_speed_changed(value: float) -> void:
	play_slider_sound() # <--- Sound
	Global.game_speed = value
	update_speed_label(value)
	Global.save_game()

func _on_starting_round_changed(value: float) -> void:
	play_slider_sound() # <--- Sound
	Global.starting_round = int(value)
	update_starting_round_label(Global.starting_round)
	Global.save_game()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	Audio.btn_pressed.play() # <--- Sound
	if toggled_on: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# --- UTILITIES ---

func update_speed_label(value: float) -> void:
	speed_label.text = "Game Speed: " + str(value) + "x"

func update_starting_round_label(value: int) -> void:
	starting_round_label.text = "Starting Round: " + str(value)

func _on_back_pressed() -> void:
	Audio.btn_pressed.play()
	await get_tree().process_frame
	hide()
	closed.emit()
