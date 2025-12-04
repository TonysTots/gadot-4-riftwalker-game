extends Control

# Drag your 3 character files (Blake, Michael, Mitchell) into this list!
@export var party_stats: Array[AllyStats]

const BATTLE_SCENE_PATH = "res://battle/battle.tscn"

# Stack to track actions for Undo: [{ "stats": resource, "stat": "body", "btn_column": vbox }]
var action_history: Array = []

func _ready() -> void:
	ScreenFade.fade_into_game()
	
	# Connect global buttons
	%UndoButton.pressed.connect(_on_undo_pressed)
	%StartButton.pressed.connect(_on_start_battle_pressed)
	
	# Initial UI State
	%UndoButton.disabled = true
	%StartButton.disabled = true
	
	# Clear placeholders
	for child in %HeroContainer.get_children():
		child.queue_free()
	
	# Create columns
	for stats in party_stats:
		create_hero_column(stats)

func create_hero_column(stats: AllyStats) -> void:
	var vbox = VBoxContainer.new()
	%HeroContainer.add_child(vbox)

	# 1. VISUALS (Sprite)
	# We use a Control node to reserve space, then put the sprite inside
	var sprite_holder = Control.new()
	sprite_holder.custom_minimum_size = Vector2(64, 64) # Adjust based on your sprite size
	sprite_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(sprite_holder)
	
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = stats.spriteFrames
	sprite.play("idle")
	# Center the sprite in the holder
	sprite.position = Vector2(32, 40) 
	sprite.scale = Vector2(2, 2) # Adjust scale if needed
	sprite_holder.add_child(sprite)
	
	# 2. LABELS
	var name_label = Label.new()
	name_label.text = stats.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# We use RichTextLabel to allow colored text (e.g. green numbers)
	var stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(stats_label)
	
	# Render the initial stats text
	update_stats_label(stats_label, stats)

	# 3. BUTTONS
	vbox.add_child(HSeparator.new())
	
	# Pass all necessary info to the buttons
	create_upgrade_button(vbox, stats, "Body", "body", stats_label, sprite)
	create_upgrade_button(vbox, stats, "Mind", "mind", stats_label, sprite)
	create_upgrade_button(vbox, stats, "Spirit", "spirit", stats_label, sprite)

func create_upgrade_button(parent: Node, stats: AllyStats, label: String, stat_name: String, label_node: RichTextLabel, sprite: AnimatedSprite2D) -> void:
	var btn = Button.new()
	btn.text = "+1 " + label
	parent.add_child(btn)
	
	# SOUNDS
	btn.mouse_entered.connect(btn.grab_focus)
	btn.focus_entered.connect(Audio.btn_mov.play)
	
	# PREVIEW LOGIC (Hover)
	btn.mouse_entered.connect(func(): show_preview(label_node, stats, stat_name))
	btn.focus_entered.connect(func(): show_preview(label_node, stats, stat_name))
	
	# RESET PREVIEW (Mouse Leave)
	btn.mouse_exited.connect(func(): update_stats_label(label_node, stats))
	btn.focus_exited.connect(func(): update_stats_label(label_node, stats))
	
	# CLICK LOGIC
	btn.pressed.connect(_on_upgrade_clicked.bind(stats, stat_name, parent, sprite))

# -------------------------------------------------------------------------
# LOGIC & CALCULATIONS
# -------------------------------------------------------------------------

func _on_upgrade_clicked(stats: AllyStats, stat_name: String, column_vbox: VBoxContainer, sprite: AnimatedSprite2D) -> void:
	Audio.btn_pressed.play()
	
	# 1. Apply Upgrade
	if stat_name == "body": stats.body += 1
	elif stat_name == "mind": stats.mind += 1
	elif stat_name == "spirit": stats.spirit += 1
	
	# 2. Visual Feedback
	sprite.play("attack")
	# Reset to idle after animation finishes
	await sprite.animation_finished
	sprite.play("idle")
	
	# 3. Lock this column
	for child in column_vbox.get_children():
		if child is Button: child.disabled = true
	
	# 4. Record Action for Undo
	action_history.append({
		"stats": stats,
		"stat": stat_name,
		"column": column_vbox
	})
	
	# 5. Update UI State
	%UndoButton.disabled = false
	check_if_ready()
	
	# Force update the label to show the NEW permanent stats (no green preview)
	# Find the RichTextLabel in the column (it's at index 2 based on creation order)
	var label = column_vbox.get_child(2) 
	update_stats_label(label, stats)

func _on_undo_pressed() -> void:
	if action_history.size() == 0: return
	
	Audio.btn_pressed.play()
	
	# Pop the last action
	var last_action = action_history.pop_back()
	var stats = last_action["stats"]
	var stat_name = last_action["stat"]
	var column = last_action["column"]
	
	# Revert Value
	if stat_name == "body": stats.body -= 1
	elif stat_name == "mind": stats.mind -= 1
	elif stat_name == "spirit": stats.spirit -= 1
	
	# Re-enable buttons
	for child in column.get_children():
		if child is Button: child.disabled = false
	
	# Update label
	var label = column.get_child(2)
	update_stats_label(label, stats)
	
	# Reset "Fight" button
	%StartButton.disabled = true
	if action_history.size() == 0:
		%UndoButton.disabled = true

func check_if_ready() -> void:
	# If we have performed as many actions as there are party members
	if action_history.size() >= party_stats.size():
		%StartButton.disabled = false
		%StartButton.grab_focus()

func _on_start_battle_pressed() -> void:
	Global.pick_new_battle()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

# -------------------------------------------------------------------------
# STAT PREVIEW HELPERS
# -------------------------------------------------------------------------

# Display current stats normally
func update_stats_label(label: RichTextLabel, stats: AllyStats) -> void:
	var derived = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	label.text = format_stats_text(derived, derived) # No difference, so no green text

# Display stats with a "Preview" (green arrows)
func show_preview(label: RichTextLabel, stats: AllyStats, buff_stat: String) -> void:
	var current = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	
	# Calculate hypothetical stats
	var b = stats.body + (1 if buff_stat == "body" else 0)
	var m = stats.mind + (1 if buff_stat == "mind" else 0)
	var s = stats.spirit + (1 if buff_stat == "spirit" else 0)
	
	var future = calculate_derived_stats(b, m, s)
	label.text = format_stats_text(current, future)

# Calculate stats manually (mirroring AllyStats.gd logic)
func calculate_derived_stats(b: int, m: int, s: int) -> Dictionary:
	return {
		"hp": (b + s) * 5,
		"mp": (m + s) * 2,
		"atk": (b + m) * 2,
		"def": b + s,
		"spd": b + m
	}

# Format the text. If future > current, color it green!
func format_stats_text(curr: Dictionary, fut: Dictionary) -> String:
	var txt = "[center][font_size=10]"
	txt += "HP: %s\n" % get_diff_string(curr.hp, fut.hp)
	txt += "MP: %s\n" % get_diff_string(curr.mp, fut.mp)
	txt += "ATK: %s\n" % get_diff_string(curr.atk, fut.atk)
	txt += "DEF: %s\n" % get_diff_string(curr.def, fut.def)
	txt += "SPD: %s" % get_diff_string(curr.spd, fut.spd)
	txt += "[/font_size][/center]"
	return txt

# Helper to generate "20" or "20 -> [color=green]25[/color]"
func get_diff_string(old: int, new_val: int) -> String:
	if new_val > old:
		return "%d [color=#00ff00]-> %d[/color]" % [old, new_val]
	else:
		return str(old)
