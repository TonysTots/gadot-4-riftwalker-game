extends Control

@export var party_stats: Array[AllyStats]
const BATTLE_SCENE_PATH = "res://battle/battle.tscn"

# Stack to track actions for Undo
var action_history: Array = []

# Track points spent per ally: { ResourceInstanceID : int_count }
var upgrades_spent: Dictionary = {}

# Upgrade Mode: 1 = 1x, 10 = 10x, 0 = Max
var current_mode: int = 1 
var mode_buttons: Array[Button] = []

func _ready() -> void:
	ScreenFade.fade_into_game()
	
	# Setup Global Buttons
	%UndoButton.pressed.connect(_on_undo_pressed)
	%StartButton.pressed.connect(_on_start_battle_pressed)
	
	# Initial UI State
	%UndoButton.disabled = true
	%StartButton.disabled = true
	
	# Initialize point tracking
	for stats in party_stats:
		upgrades_spent[stats.get_instance_id()] = 0
		
	# Button Text Update
	var points_limit = get_points_limit()
	if points_limit > 1:
		%StartButton.text = "Finish"
	else:
		%StartButton.text = "Fight!"

	create_mode_selector()
	
	# Clear old columns
	for child in %HeroContainer.get_children():
		child.queue_free()
	
	# Create new columns
	for stats in party_stats:
		create_hero_column(stats)

func get_points_limit() -> int:
	if "upgrade_points_pending" in Global:
		return Global.upgrade_points_pending
	return 1

func create_mode_selector() -> void:
	var bottom_bar = %UndoButton.get_parent()
	var group = ButtonGroup.new()
	
	var btn_1 = create_mode_btn("1x", 1, group)
	var btn_10 = create_mode_btn("10x", 10, group)
	var btn_max = create_mode_btn("MAX", 0, group)
	
	bottom_bar.add_child(btn_1)
	bottom_bar.add_child(btn_10)
	bottom_bar.add_child(btn_max)
	
	bottom_bar.move_child(btn_1, 1)
	bottom_bar.move_child(btn_10, 2)
	bottom_bar.move_child(btn_max, 3)
	bottom_bar.move_child(%StartButton, 4)

func create_mode_btn(text: String, mode: int, group: ButtonGroup) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(60, 40)
	btn.focus_mode = Control.FOCUS_NONE
	
	if mode == 1: btn.button_pressed = true
	
	btn.pressed.connect(func(): 
		Audio.btn_pressed.play()
		current_mode = mode
	)
	return btn

func create_hero_column(stats: AllyStats) -> void:
	var vbox = VBoxContainer.new()
	%HeroContainer.add_child(vbox)

	# 1. VISUALS
	var sprite_holder = Control.new()
	sprite_holder.custom_minimum_size = Vector2(64, 64)
	sprite_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(sprite_holder)
	
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = stats.spriteFrames
	sprite.play("idle")
	sprite.position = Vector2(32, 40)
	sprite.scale = Vector2(2, 2)
	sprite_holder.add_child(sprite)
	
	# 2. POINTS REMAINING LABEL
	var points_label = Label.new()
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(points_label)
	
	# 3. NAME LABEL
	var name_label = Label.new()
	name_label.text = stats.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# 4. STATS TEXT
	var stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(stats_label)
	
	update_labels(vbox, stats)

	# 5. BUTTONS
	vbox.add_child(HSeparator.new())
	# --- FIXED: Now passing stats_label to the button creator ---
	create_upgrade_button(vbox, stats, "Body", "body", sprite, stats_label)
	create_upgrade_button(vbox, stats, "Mind", "mind", sprite, stats_label)
	create_upgrade_button(vbox, stats, "Spirit", "spirit", sprite, stats_label)

# --- FIXED: Function now accepts label_node ---
func create_upgrade_button(parent: VBoxContainer, stats: AllyStats, label_text: String, stat_name: String, sprite: AnimatedSprite2D, label_node: RichTextLabel) -> void:
	var btn = Button.new()
	btn.text = label_text 
	parent.add_child(btn)
	
	# Sounds
	btn.mouse_entered.connect(btn.grab_focus)
	btn.focus_entered.connect(Audio.btn_mov.play)
	
	# --- FIXED: Re-added Preview Logic ---
	# Preview on Hover
	btn.mouse_entered.connect(func(): show_preview(label_node, stats, stat_name))
	btn.focus_entered.connect(func(): show_preview(label_node, stats, stat_name))
	
	# Reset on Leave
	btn.mouse_exited.connect(func(): update_labels(parent, stats))
	btn.focus_exited.connect(func(): update_labels(parent, stats))
	
	# Logic
	btn.pressed.connect(_on_upgrade_clicked.bind(stats, stat_name, parent, sprite))

func _on_upgrade_clicked(stats: AllyStats, stat_name: String, column: VBoxContainer, sprite: AnimatedSprite2D) -> void:
	Audio.btn_pressed.play()
	
	# Calculate amounts
	var limit = get_points_limit()
	var id = stats.get_instance_id()
	var spent = upgrades_spent[id]
	var available = limit - spent
	
	if available <= 0: return

	# Determine how much to add based on mode
	var amount = 0
	if current_mode == 1: amount = 1
	elif current_mode == 10: amount = 10
	elif current_mode == 0: amount = available # Max
	
	# Clamp to what is actually available
	amount = min(amount, available)
	
	if amount <= 0: return

	# Apply Stats
	if stat_name == "body": stats.body += amount
	elif stat_name == "mind": stats.mind += amount
	elif stat_name == "spirit": stats.spirit += amount
	
	# Visuals
	sprite.play("attack")
	if not sprite.animation_finished.is_connected(_on_sprite_anim_done):
		sprite.animation_finished.connect(_on_sprite_anim_done.bind(sprite), CONNECT_ONE_SHOT)
	
	# Track
	upgrades_spent[id] += amount
	
	# History
	action_history.append({
		"stats": stats,
		"stat": stat_name,
		"amount": amount,
		"column": column
	})
	
	update_ui_state(column, stats)

func _on_undo_pressed() -> void:
	if action_history.is_empty(): return
	Audio.btn_pressed.play()
	
	var action = action_history.pop_back()
	var stats = action["stats"]
	var amount = action["amount"]
	var col = action["column"]
	
	# Revert
	if action["stat"] == "body": stats.body -= amount
	elif action["stat"] == "mind": stats.mind -= amount
	elif action["stat"] == "spirit": stats.spirit -= amount
	
	upgrades_spent[stats.get_instance_id()] -= amount
	
	update_ui_state(col, stats)

func update_ui_state(column: VBoxContainer, stats: AllyStats) -> void:
	update_labels(column, stats)
	
	var limit = get_points_limit()
	var spent = upgrades_spent[stats.get_instance_id()]
	var is_full = spent >= limit
	
	for child in column.get_children():
		if child is Button:
			child.disabled = is_full

	check_start_condition()
	%UndoButton.disabled = action_history.is_empty()

func update_labels(column: VBoxContainer, stats: AllyStats) -> void:
	# Points Label is Index 1
	var pts_label = column.get_child(1) as Label
	var limit = get_points_limit()
	var remaining = limit - upgrades_spent[stats.get_instance_id()]
	pts_label.text = "Points: " + str(remaining)
	
	# Stats RichTextLabel is Index 3
	var stats_label = column.get_child(3) as RichTextLabel
	var derived = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	stats_label.text = format_stats_text(derived, derived)

# --- FIXED: Show Preview Calculation ---
func show_preview(label: RichTextLabel, stats: AllyStats, buff_stat: String) -> void:
	var current = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	
	# Calculate potential increase based on mode
	var id = stats.get_instance_id()
	var limit = get_points_limit()
	var available = limit - upgrades_spent[id]
	var amount = 0
	
	if current_mode == 1: amount = 1
	elif current_mode == 10: amount = 10
	elif current_mode == 0: amount = available
	
	amount = min(amount, available)
	
	if amount <= 0:
		# No increase possible, just show current
		label.text = format_stats_text(current, current)
		return

	# Calculate hypothetical stats
	var b = stats.body + (amount if buff_stat == "body" else 0)
	var m = stats.mind + (amount if buff_stat == "mind" else 0)
	var s = stats.spirit + (amount if buff_stat == "spirit" else 0)
	
	var future = calculate_derived_stats(b, m, s)
	label.text = format_stats_text(current, future)

func check_start_condition() -> void:
	var limit = get_points_limit()
	var total_needed = party_stats.size() * limit
	var total_spent = 0
	for k in upgrades_spent:
		total_spent += upgrades_spent[k]
		
	if total_spent >= total_needed:
		%StartButton.disabled = false
		%StartButton.grab_focus()
	else:
		%StartButton.disabled = true

func _on_start_battle_pressed() -> void:
	Audio.btn_pressed.play()
	if "upgrade_points_pending" in Global:
		Global.upgrade_points_pending = 1
		
	Global.pick_new_battle()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _on_sprite_anim_done(sprite: AnimatedSprite2D) -> void:
	sprite.play("idle")

func calculate_derived_stats(b: int, m: int, s: int) -> Dictionary:
	return {
		"hp": (b + s) * 5,
		"mp": (m + s) * 2,
		"atk": (b + m) * 2,
		"mag": (m + s) * 2, # --- NEW: Magic Strength Calculation ---
		"def": b + s,
		"spd": b + m
	}

func format_stats_text(curr: Dictionary, fut: Dictionary) -> String:
	var txt = "[center][font_size=10]"
	txt += "HP: %s\n" % get_diff_string(curr.hp, fut.hp)
	txt += "MP: %s\n" % get_diff_string(curr.mp, fut.mp)
	txt += "ATK: %s\n" % get_diff_string(curr.atk, fut.atk)
	
	# --- NEW: Magic Strength Display ---
	txt += "MAG: %s\n" % get_diff_string(curr.mag, fut.mag)
	
	txt += "DEF: %s\n" % get_diff_string(curr.def, fut.def)
	txt += "SPD: %s" % get_diff_string(curr.spd, fut.spd)
	txt += "[/font_size][/center]"
	return txt

func get_diff_string(old: int, new_val: int) -> String:
	if new_val > old:
		return "%d [color=#00ff00]-> %d[/color]" % [old, new_val]
	else:
		return str(old)
