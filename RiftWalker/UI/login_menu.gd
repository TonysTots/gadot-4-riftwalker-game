extends Control

signal login_finished

@onready var email_input: LineEdit = %UsernameInput
# @onready var password_input: LineEdit = %PasswordInput
@onready var login_button: Button = %LoginButton
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	login_button.pressed.connect(_on_login_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	if has_node("%RecoverButton"):
		%RecoverButton.toggled.connect(func(toggled):
			if has_node("%DeviceIdContainer"):
				%DeviceIdContainer.visible = toggled
				if toggled:
					# Populate with current ID if opening
					var current_id = Global.device_id
					if current_id == "":
						current_id = OS.get_unique_id()
					%DeviceIdInput.text = current_id
		)
	
	# --- NEW: Pre-fill username if known ---
	if Global.current_username != "":
		email_input.text = Global.current_username
	# ---------------------------------------
	
	# --- NEW: Setup Sounds ---
	setup_ui_sounds(login_button)
	setup_ui_sounds(back_button)
	setup_ui_sounds(email_input)
	# setup_ui_sounds(password_input)
	# -------------------------
	
	visibility_changed.connect(_on_visibility_changed)
	email_input.text_changed.connect(_on_email_text_changed)

func _on_email_text_changed(new_text: String) -> void:
	# If text changed, allow trying to connect (switching accounts or fixing typo)
	login_button.disabled = false
	status_label.text = ""
	status_label.modulate = Color.WHITE
	
	# Optional: If typed back to current user, could re-show status, but better to keep simple.

func _on_visibility_changed() -> void:
	if visible:
		# Check if already logged in
		var is_logged_in: bool = Global.access_token != "" and Global.current_username != ""
		login_button.disabled = is_logged_in
		
		if is_logged_in:
			status_label.text = "Already logged in as " + Global.current_username
			status_label.modulate = Color.GREEN
		else:
			status_label.text = ""
			status_label.modulate = Color.WHITE
			login_button.disabled = false
			
		if Global.current_username != "":
			email_input.text = Global.current_username

	if AuthManager:
		if not AuthManager.login_success.is_connected(_on_login_success):
			AuthManager.login_success.connect(_on_login_success)
		if not AuthManager.login_failed.is_connected(_on_login_failed):
			AuthManager.login_failed.connect(_on_login_failed)

# --- NEW: Helper Function ---
func setup_ui_sounds(node: Control) -> void:
	# Plays the "blip" sound when mouse enters or tab key focuses the element
	node.mouse_entered.connect(func(): Audio.btn_mov.play())
	node.focus_entered.connect(func(): Audio.btn_mov.play())

func _on_login_pressed() -> void:
	Audio.btn_pressed.play() # <--- Add Sound
	
	var email = email_input.text.strip_edges()
	# var password = password_input.text.strip_edges()
	
	if email == "":
		status_label.text = "Please enter a username."
		return
	
	login_button.disabled = true
	status_label.modulate = Color.WHITE
	status_label.text = "Connecting..."
	
	# --- NEW: Override ID if manually entered ---
	if has_node("%DeviceIdContainer") and %DeviceIdContainer.visible:
		var manual_id = %DeviceIdInput.text.strip_edges()
		if manual_id != "" and manual_id != Global.device_id:
			Global.device_id = manual_id
			# We should save this change immediately so it persists
			Global.save_game() 
	
	AuthManager.logout() # Ensure clean slate (Clear local tokens)
	AuthManager.login(email)

func _on_back_pressed() -> void:
	Audio.btn_pressed.play() # <--- Add Sound
	hide()
	login_finished.emit()

# ... (Keep existing _on_login_success and _on_login_failed functions) ...
func _on_login_success(_user_data: Dictionary) -> void:
	status_label.text = "Success!"
	status_label.modulate = Color.GREEN
	status_label.show() # Ensure it's visible
	await get_tree().create_timer(2.0).timeout # increased to 2.0s
	hide()
	login_finished.emit()

func _on_login_failed(error_message: String) -> void:
	login_button.disabled = false
	status_label.modulate = Color.RED
	status_label.text = error_message
