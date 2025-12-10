extends Control

# --- DATA ---
@export var party_stats: Array[AllyStats]
const MAP_SCENE_PATH: String = "res://UI/map_screen.tscn"

# --- STATE ---
# Stack to track actions for Undo: Array[Dictionary]
var action_history: Array[Dictionary] = []

# Track points spent per ally: { int (InstanceID) : int (Count) }
var upgrades_spent: Dictionary = {}

# Upgrade Mode: 1 = 1x, 10 = 10x, 0 = Max
var current_mode: int = 1 
var mode_buttons: Array[Button] = []

# --- NODES ---
@onready var bgm_player: AudioStreamPlayer = $BGM
@onready var hero_container: HBoxContainer = %HeroContainer
@onready var undo_button: Button = %UndoButton
@onready var start_button: Button = %StartButton

func _ready() -> void:
	ScreenFade.fade_into_game()
	
	_setup_audio()
	_setup_ui()
	_initialize_points_tracking()
	_setup_start_button_text()
	
	create_mode_selector()
	_refresh_hero_columns()
	check_start_condition()

func _setup_audio() -> void:
	if bgm_player:
		var stream: AudioStreamMP3 = bgm_player.stream as AudioStreamMP3
		if stream:
			stream.loop = true
			stream.loop_offset = 2.5 # Skip 2.5s of silence on loop
		
		# Play from 2.5s to skip initial silence (Overrides Autoplay)
		bgm_player.play(2.5)

func _setup_ui() -> void:
	undo_button.pressed.connect(_on_undo_pressed)
	start_button.pressed.connect(_on_start_battle_pressed)
	
	undo_button.disabled = true
	start_button.disabled = true

func _initialize_points_tracking() -> void:
	for stats in party_stats:
		upgrades_spent[stats.get_instance_id()] = 0

func _setup_start_button_text() -> void:
	var any_points: bool = false
	for stats in party_stats:
		if get_points_limit(stats.name) > 0:
			any_points = true
			break
			
	if any_points:
		start_button.text = "Finish"
	else:
		start_button.text = "Fight!"

func _refresh_hero_columns() -> void:
	for child in hero_container.get_children():
		child.queue_free()
	
	for stats in party_stats:
		create_hero_column(stats)

# --- LOGIC ---

func get_points_limit(char_name: String) -> int:
	if char_name in Global.party_points:
		return Global.party_points[char_name]
	return 0

func create_mode_selector() -> void:
	var bottom_bar: Node = undo_button.get_parent()
	var group: ButtonGroup = ButtonGroup.new()
	
	var btn_1: Button = create_mode_btn("1x", 1, group)
	var btn_10: Button = create_mode_btn("10x", 10, group)
	var btn_max: Button = create_mode_btn("MAX", 0, group)
	
	bottom_bar.add_child(btn_1)
	bottom_bar.add_child(btn_10)
	bottom_bar.add_child(btn_max)
	
	bottom_bar.move_child(btn_1, 1)
	bottom_bar.move_child(btn_10, 2)
	bottom_bar.move_child(btn_max, 3)
	bottom_bar.move_child(start_button, 4)

func create_mode_btn(text: String, mode: int, group: ButtonGroup) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(60, 40)
	btn.focus_mode = Control.FOCUS_NONE
	
	if mode == 1: btn.button_pressed = true
	
	btn.pressed.connect(func() -> void: 
		Audio.btn_pressed.play()
		current_mode = mode
	)
	return btn

func create_hero_column(stats: AllyStats) -> void:
	# Simplified VBox (Pre-Makeover style)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_container.add_child(vbox)

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
	points_label.add_theme_font_size_override("font_size", 10) # Smaller
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
	create_upgrade_button(vbox, stats, "Body", "body", sprite, stats_label)
	create_upgrade_button(vbox, stats, "Mind", "mind", sprite, stats_label)
	create_upgrade_button(vbox, stats, "Spirit", "spirit", sprite, stats_label)

func create_upgrade_button(parent: VBoxContainer, stats: AllyStats, label_text: String, stat_name: String, sprite: AnimatedSprite2D, label_node: RichTextLabel) -> void:
	var btn = Button.new()
	btn.text = label_text 
	parent.add_child(btn)
	
	# Sounds
	btn.mouse_entered.connect(btn.grab_focus)
	btn.focus_entered.connect(Audio.btn_mov.play)
	
	# Preview on Hover
	btn.mouse_entered.connect(func() -> void: show_preview(label_node, stats, stat_name))
	btn.focus_entered.connect(func() -> void: show_preview(label_node, stats, stat_name))
	
	# Reset on Leave
	btn.mouse_exited.connect(func() -> void: update_labels(parent, stats))
	btn.focus_exited.connect(func() -> void: update_labels(parent, stats))
	
	# Logic
	btn.pressed.connect(_on_upgrade_clicked.bind(stats, stat_name, parent, sprite))

func _on_upgrade_clicked(stats: AllyStats, stat_name: String, column: VBoxContainer, sprite: AnimatedSprite2D) -> void:
	Audio.btn_pressed.play()
	
	# Calculate amounts
	var limit: int = get_points_limit(stats.name)
	var id: int = stats.get_instance_id()
	var available: int = limit
	
	if available <= 0: return

	# Determine how much to add based on mode
	var amount: int = 0
	if current_mode == 1: amount = 1
	elif current_mode == 10: amount = 10
	elif current_mode == 0: amount = available # Max
	
	# Clamp to what is actually available
	amount = mini(amount, available)
	
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
	if not upgrades_spent.has(id): upgrades_spent[id] = 0
	upgrades_spent[id] += amount
	
	if stats.name in Global.party_points:
		Global.party_points[stats.name] -= amount
		Global.save_game()
	
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
	
	var action: Dictionary = action_history.pop_back()
	var stats: AllyStats = action["stats"]
	var amount: int = action["amount"]
	var col: VBoxContainer = action["column"]
	
	# Revert
	if action["stat"] == "body": stats.body -= amount
	elif action["stat"] == "mind": stats.mind -= amount
	elif action["stat"] == "spirit": stats.spirit -= amount
	
	var id: int = stats.get_instance_id()
	upgrades_spent[id] -= amount
	
	if stats.name in Global.party_points:
		Global.party_points[stats.name] += amount
		Global.save_game()
	
	update_ui_state(col, stats)

func update_ui_state(column: VBoxContainer, stats: AllyStats) -> void:
	update_labels(column, stats)
	
	var limit: int = get_points_limit(stats.name)
	var is_full: bool = (limit <= 0)
	
	for child in column.get_children():
		if child is Button:
			child.disabled = is_full

	check_start_condition()
	undo_button.disabled = action_history.is_empty()

func update_labels(column: VBoxContainer, stats: AllyStats) -> void:
	# Points Label is Index 1
	var pts_label: Label = column.get_child(1) as Label

	var available: int = get_points_limit(stats.name)
	pts_label.text = "Points: " + str(available)
	
	# Stats RichTextLabel is Index 3
	var stats_label: RichTextLabel = column.get_child(3) as RichTextLabel
	var derived: Dictionary = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	stats_label.text = format_stats_text(derived, derived)

func show_preview(label: RichTextLabel, stats: AllyStats, buff_stat: String) -> void:
	var current: Dictionary = calculate_derived_stats(stats.body, stats.mind, stats.spirit)
	
	var available: int = get_points_limit(stats.name)
	var amount: int = 0
	
	if current_mode == 1: amount = 1
	elif current_mode == 10: amount = 10
	elif current_mode == 0: amount = available
	
	amount = mini(amount, available)
	
	if amount <= 0:
		label.text = format_stats_text(current, current)
		return

	# Calculate hypothetical stats
	var b: int = stats.body + (amount if buff_stat == "body" else 0)
	var m: int = stats.mind + (amount if buff_stat == "mind" else 0)
	var s: int = stats.spirit + (amount if buff_stat == "spirit" else 0)
	
	var future: Dictionary = calculate_derived_stats(b, m, s)
	label.text = format_stats_text(current, future)

func check_start_condition() -> void:
	# Start is enabled always (save points logic)
	start_button.disabled = false

func _on_start_battle_pressed() -> void:
	Audio.btn_pressed.play()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_sprite_anim_done(sprite: AnimatedSprite2D) -> void:
	sprite.play("idle")

func calculate_derived_stats(b: int, m: int, s: int) -> Dictionary:
	return {
		"hp": (b + s) * 20,
		"mp": (m + s) * 5,
		"atk": (b + m) * 2,
		"mag": (m + s) * 2,
		"def": (b + s) * 2,
		"spd": (b + m) * 5
	}

func format_stats_text(curr: Dictionary, fut: Dictionary) -> String:
	var txt: String = "[center][font_size=10]"
	txt += "HP: %s\n" % get_diff_string(curr.hp, fut.hp)
	txt += "MP: %s\n" % get_diff_string(curr.mp, fut.mp)
	txt += "ATK: %s\n" % get_diff_string(curr.atk, fut.atk)
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
