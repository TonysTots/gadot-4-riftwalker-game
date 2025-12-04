extends CanvasLayer

signal closed

@onready var volume_slider: HSlider = $PanelContainer/VBoxContainer/Volume/VolumeSlider
@onready var fullscreen_check: CheckButton = $PanelContainer/VBoxContainer/FullScreenCheck

# Get the index of the Master audio bus
var master_bus_index: int

func _ready() -> void:
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# Set UI state to match current game settings
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	# Connect signals (or do this via the editor)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	$PanelContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _on_volume_changed(value: float) -> void:
	# Convert linear value (0 to 1) to Decibels
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
	AudioServer.set_bus_mute(master_bus_index, value < 0.05)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	hide()
	closed.emit()
