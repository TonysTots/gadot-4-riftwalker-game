extends CanvasLayer

signal closed
signal end_run_requested ## New signal to tell Battle to quit

@onready var volume_slider: HSlider = $PanelContainer/VBoxContainer/Volume/VolumeSlider
@onready var fullscreen_check: CheckButton = $PanelContainer/VBoxContainer/FullScreenCheck

# --- NEW NODES ---
# Make sure these paths match your scene exactly!
@onready var end_run_btn: Button = $PanelContainer/VBoxContainer/EndRunButton
@onready var confirm_popup: PanelContainer = $ConfirmationPopup
@onready var yes_btn: Button = $ConfirmationPopup/VBoxContainer/HBoxContainer/YesButton
@onready var no_btn: Button = $ConfirmationPopup/VBoxContainer/HBoxContainer/NoButton

var master_bus_index: int

func _ready() -> void:
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# Initial State
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	# --- CONNECTIONS ---
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	$PanelContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
	setup_hover_sounds($PanelContainer/VBoxContainer/BackButton)
	
	# End Run Logic
	end_run_btn.pressed.connect(_on_end_run_pressed)
	yes_btn.pressed.connect(_on_confirm_end_run)
	no_btn.pressed.connect(func(): 
		Audio.btn_pressed.play()
		confirm_popup.hide()
	)
	
	setup_hover_sounds(end_run_btn)
	setup_hover_sounds(yes_btn)
	setup_hover_sounds(no_btn)

# Call this function when opening settings from Battle to show the button
func enable_battle_mode() -> void:
	end_run_btn.show()

func _on_end_run_pressed() -> void:
	Audio.btn_pressed.play()
	confirm_popup.show()
	# Focus the 'No' button by default to prevent accidents
	no_btn.grab_focus()

func _on_confirm_end_run() -> void:
	Audio.btn_pressed.play()
	confirm_popup.hide()
	hide() # Hide settings menu
	end_run_requested.emit() # Tell Battle.gd to finish the run

# ... (Keep your existing volume/fullscreen functions here) ...
func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
	AudioServer.set_bus_mute(master_bus_index, value < 0.05)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	Audio.btn_pressed.play()
	hide()
	closed.emit()

func setup_hover_sounds(btn: Button) -> void:
	btn.mouse_entered.connect(func(): Audio.btn_mov.play())
	btn.focus_entered.connect(func(): Audio.btn_mov.play())
