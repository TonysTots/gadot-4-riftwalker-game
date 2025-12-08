extends Control

@onready var container = %VBoxContainer

func _ready() -> void:
	# Connect buttons
	%BackButton.pressed.connect(_on_back_pressed)
	setup_button_sounds(%BackButton)
	
	if has_node("%RefreshButton"):
		%RefreshButton.pressed.connect(func(): 
			Audio.btn_pressed.play()
			# Clear list immediately to show loading state if desired, or let callback handle it
			for child in container.get_children(): child.queue_free()
			var loading = Label.new()
			loading.text = "Loading..."
			loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			container.add_child(loading)
			AuthManager.get_leaderboard()
		)
		setup_button_sounds(%RefreshButton)

	# Request data
	AuthManager.leaderboard_received.connect(_on_leaderboard_received)
	AuthManager.get_leaderboard()

func _on_leaderboard_received(data: Array) -> void:
	# Clear previous entries (including 'Loading...')
	for child in container.get_children():
		child.queue_free()

	if data.size() == 0:
		var label = Label.new()
		label.text = "Failed to load leaderboard."
		container.add_child(label)
		return

	var rank = 1
	for entry in data:
		var label = Label.new()
		var username = entry.get("username", "Unknown")
		var round_reached = int(entry.get("highest_round", 0))
		
		label.text = str(rank) + ". " + username + " - Round " + str(round_reached)
		# Add some style if needed
		container.add_child(label)
		rank += 1

func _on_back_pressed() -> void:
	Audio.btn_pressed.play()
	hide()

func setup_button_sounds(button: Button) -> void:
	if not button: return
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
