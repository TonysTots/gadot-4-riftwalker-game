class_name MapScreen extends Control

@onready var map_container: Control = %MapContainer

const X_SPACING = 90 # Wider X to space out layers
const Y_SPACING = 50 # Tighter Y to fit screen
# START_OFFSET will be calculated dynamically for Y

func _ready() -> void:
	# 1. Check if map exists
	if Global.map_data == null:
		var generator = MapGenerator.new()
		Global.map_data = generator.generate_map()
		
	render_map()
	call_deferred("scroll_to_current")
	ScreenFade.fade_into_game()
	
	# Check for Rift (Boss Defeated)
	# Handled in render_map now
	
	# Explicitly play music to prevent delays
	if has_node("MapMusic"):
		var music = $MapMusic
		var stream = music.stream as AudioStreamMP3
		if stream:
			stream.loop = true
			stream.loop = true
			stream.loop_offset = 2.0 # Skip 2s of silence on loop
		
		# Play from 2.0s to skip initial silence (Overrides Autoplay)
		music.play(2.0)

func _process(delta: float) -> void:
	var scroll_speed = 600.0 * delta
	var scroll = $ScrollContainer
	
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		scroll.scroll_horizontal += int(scroll_speed)
	elif Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		scroll.scroll_horizontal -= int(scroll_speed)


func _on_rift_pressed() -> void:
	Audio.play_action_sound("heal") # Sound needed
	
	# Generate NEW MAP
	var generator = MapGenerator.new()
	Global.map_data = generator.generate_map()
	
	# Increase Base Difficulty for next map
	# Assuming 10 layers per map, we jump ahead
	Global.map_base_difficulty += MapGenerator.LAYERS 
	
	Global.save_game()
	
	# Reload UI
	render_map()
	call_deferred("scroll_to_current")

func scroll_to_current() -> void:
	# Keep existing clean logic
	var scroll = $ScrollContainer
	var data = Global.map_data
	var target_x = 0.0
	if data.current_node_grid_pos != Vector2(-1, -1):
		var node = data.get_node(data.current_node_grid_pos)
		target_x = node.grid_position.x * X_SPACING
	
	var center_offset_x = scroll.size.x / 2
	scroll.scroll_horizontal = int(target_x - center_offset_x + 50)

func render_map() -> void:
	for child in map_container.get_children():
		child.queue_free()
		
	var data = Global.map_data
	var viewport_height = get_viewport_rect().size.y
	
	# 0. Pre-calculate "Persistent Frontier"
	# These are nodes in (Max + 1) that are connected to a VISITED node in (Max).
	# They should remain visible/accessible even if we backtrack.
	var persistent_frontier_indices: Dictionary = {}
	for g_pos in data.nodes:
		var n = data.nodes[g_pos]
		if n.grid_position.x == data.max_reached_layer and n.is_visited:
			for next_pos in n.next_nodes:
				persistent_frontier_indices[next_pos] = true
	
	for grid_pos in data.nodes:
		var node: MapNode = data.nodes[grid_pos]
		var btn = Button.new()
		
		# Position Logic
		var x_pos = 50 + (node.grid_position.x * X_SPACING)
		var map_height = 4 * Y_SPACING 
		var start_y = (viewport_height - map_height) / 2
		var y_pos = start_y + (node.grid_position.y * Y_SPACING)
		btn.position = Vector2(x_pos, y_pos)
		
		btn.text = get_icon_for_type(node.type)
		# REMOVED TOOLTIP as requested
		
		btn.custom_minimum_size = Vector2(40, 40)
		
	# --- NEW ACCESSIBILITY LOGIC ---
		var is_locked = true
		
		# Rule 1: Always accessible if "Cleared" (Backtracking)
		if node.grid_position.x <= data.max_reached_layer:
			is_locked = false
			
		# Rule 2: Lateral Movement (Switching lanes in current layer)
		if data.current_node_grid_pos != Vector2(-1, -1):
			if int(node.grid_position.x) == int(data.current_node_grid_pos.x):
				is_locked = false

		# Rule 3: Forward Connectivity (Immediate)
		# If connected to current node, AND not exceeding max reach + 1
		if data.current_node_grid_pos != Vector2(-1, -1):
			var curr = data.get_node(data.current_node_grid_pos)
			if node.grid_position in curr.next_nodes:
				if node.grid_position.x <= data.max_reached_layer + 1:
					is_locked = false
		elif node.grid_position.x == 0:
			# Start node is always open
			is_locked = false
		
		# Rule 4: Persistent Frontier
		# If this node is a valid "Next Step" from a cleared node, keep it open.
		if persistent_frontier_indices.has(node.grid_position):
			is_locked = false

		# 3. Visited Rule
		if node.is_visited:
			# Battles become inactive (Grey), Shops/Rest stay active
			if node.type == MapNode.Type.BATTLE or node.type == MapNode.Type.BOSS or node.type == MapNode.Type.ELITE:
				btn.disabled = true
				btn.modulate = Color.DARK_GRAY
			else:
				btn.disabled = false
				btn.modulate = Color(0.5, 0.5, 1.0) # Light Blue
		elif is_locked:
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.2) # Dimmed
		else:
			btn.disabled = false
			btn.modulate = Color.GREEN # Available
			
		btn.pressed.connect(func(): _on_node_pressed(node))
		setup_button_sounds(btn)
		map_container.add_child(btn)
		
		# --- RIFT BUTTON LOGIC ---
		# If this is the Boss and it's defeated, show the Rift Button next to it
		if node.type == MapNode.Type.BOSS and node.is_visited:
			var rift_btn = Button.new()
			rift_btn.text = "RIFT >"
			rift_btn.modulate = Color.CYAN
			rift_btn.scale = Vector2(0.8, 0.8) # Keep it relatively small
			
			# Position to the right of the boss
			rift_btn.position = btn.position + Vector2(50, 0)
			
			rift_btn.pressed.connect(_on_rift_pressed)
			setup_button_sounds(rift_btn)
			map_container.add_child(rift_btn)
			
	# Size update
	var max_x = 0.0
	for grid_pos in data.nodes:
		var x = 50 + (data.nodes[grid_pos].grid_position.x * X_SPACING)
		if x > max_x: max_x = x
	map_container.custom_minimum_size = Vector2(max_x + 300, 0)
	map_container.queue_redraw()
	
func _draw() -> void:
	pass

func _on_node_pressed(node: MapNode) -> void:
	Audio.btn_pressed.play()
	Global.map_data.current_node_grid_pos = node.grid_position
	# Update Max Layer is now handled in Battle Victory (for battles)

	# Shops/Rest do NOT advance the "Max Reached Layer"
		
	node.is_visited = true
	# Determine Difficulty based on Column + Base Round
	# Layer 0 = Base Round, Layer 1 = Base + 1, etc.
	Global.current_round = Global.map_base_difficulty + int(node.grid_position.x)
	
	match node.type:
		MapNode.Type.BATTLE, MapNode.Type.ELITE:
			start_battle(0)
		MapNode.Type.BOSS:
			start_battle(10) # Boss is 10 rounds harder!
		MapNode.Type.REST:
			# Don't increment pending points if just revisiting?
			# User: "accessible... even after being visited"
			# Let's grant point only once? Or every time? "Grind" implies repetition. 
			# But "CAMPFIRE" usually is a one-time rest.
			# Let's grant point ONCE per node visit if we tracked specific visits, but is_visited is true.
			# If I revisit, is_visited is true. 
			# For now, let's allow unlimited points (Grind!). User can exploit if they want.
			if "upgrade_points_pending" in Global:
				Global.upgrade_points_pending += 1
			get_tree().change_scene_to_file("res://UI/upgrade_menu.tscn")
		MapNode.Type.SHOP:
			get_tree().change_scene_to_file("res://UI/shop_menu.tscn")
		_:
			render_map() # Event?

func start_battle(difficulty_offset: int) -> void:
	Global.battle_round_offset = difficulty_offset
	Global.pick_new_battle()
	get_tree().change_scene_to_file("res://battle/battle.tscn")

func get_icon_for_type(type: int) -> String:
	match type:
		MapNode.Type.BATTLE: return "⚔️"
		MapNode.Type.ELITE: return "💀"
		MapNode.Type.EVENT: return "?"
		MapNode.Type.SHOP: return "💰"
		MapNode.Type.BOSS: return "👹"
		MapNode.Type.REST: return "🔥"
	return "X"

func setup_button_sounds(button: Button) -> void:
	button.focus_entered.connect(func(): Audio.btn_mov.play())
	button.mouse_entered.connect(func(): Audio.btn_mov.play())
