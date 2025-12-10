class_name MapScreen extends Control

# --- CONFIGURATION ---
const X_SPACING: int = 90
const Y_SPACING: int = 50
const SCROLL_SPEED: float = 600.0
const MAP_PADDING_X: int = 50
const MAP_PADDING_Y_OFFSET: int = 50

# --- NODES ---
@onready var map_container: Control = %MapContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer

var target_scroll_x: float = 0.0
const SMOOTH_SPEED: float = 12.0
const WHEEL_SPEED: float = 100.0 # Per tick

func _ready() -> void:
	# 1. Initialize Map Data if missing
	if Global.map_data == null:
		var generator: MapGenerator = MapGenerator.new()
		Global.map_data = generator.generate_map()
		
	# Connect GUI Input for Scroll override
	scroll_container.gui_input.connect(_on_scroll_container_gui_input)
	
	render_map()
	call_deferred("scroll_to_current")
	
	ScreenFade.fade_into_game()
	
	# 2. Audio Setup (Manual Loop Logic)
	if has_node("MapMusic"):
		var music_player: AudioStreamPlayer = $MapMusic
		var stream: AudioStreamMP3 = music_player.stream as AudioStreamMP3
		
		# Offset logic to skip initial silence
		if stream:
			stream.loop = true
			stream.loop_offset = 2.0 
		
		# Force play from offset (Overrides Autoplay)
		music_player.play(2.0)

func _process(delta: float) -> void:
	# Sync target if dragging (Left Click held usually implies interaction/drag)
	# NOTE: ScrollContainer drag uses LMB. If pressed, we defer to native drag.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_scroll_x = float(scroll_container.scroll_horizontal)
		return

	# Manual Scrolling Input (Keys) - Update Target
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		target_scroll_x += SCROLL_SPEED * delta
	elif Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		target_scroll_x -= SCROLL_SPEED * delta
		
	# Clamp Target
	var max_scroll: float = map_container.custom_minimum_size.x - scroll_container.size.x
	target_scroll_x = clampf(target_scroll_x, 0.0, max_scroll)
	
	# Smooth Interpolation
	if abs(scroll_container.scroll_horizontal - target_scroll_x) > 1.0:
		scroll_container.scroll_horizontal = int(lerp(float(scroll_container.scroll_horizontal), target_scroll_x, SMOOTH_SPEED * delta))
	else:
		scroll_container.scroll_horizontal = int(target_scroll_x)

func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_scroll_x -= WHEEL_SPEED
				scroll_container.accept_event() # Eat event
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_scroll_x += WHEEL_SPEED
				scroll_container.accept_event() # Eat event

## Handles the special "Rift" button that appears after defeating a boss.
func _on_rift_pressed() -> void:
	Audio.play_action_sound("heal") 
	
	# Generate New Map Layer
	var generator: MapGenerator = MapGenerator.new()
	Global.map_data = generator.generate_map()
	
	# Increase Base Difficulty (Jump ahead by 10 layers)
	Global.map_base_difficulty += MapGenerator.LAYERS 
	
	Global.save_game()
	
	# Refresh UI
	render_map()
	call_deferred("scroll_to_current")

## Centers the scroll view on the player's current node.
func scroll_to_current() -> void:
	var data: MapData = Global.map_data
	var target_x: float = 0.0
	
	if data.current_node_grid_pos != Vector2(-1, -1):
		var node: MapNode = data.get_node(data.current_node_grid_pos)
		if node:
			target_x = node.grid_position.x * X_SPACING
	
	var center_offset_x: float = scroll_container.size.x / 2.0
	var final_x: int = int(target_x - center_offset_x + MAP_PADDING_X)
	scroll_container.scroll_horizontal = final_x
	target_scroll_x = float(final_x) # Sync smooth scroll target

## Rebuilds the visual map UI based on MapData.
func render_map() -> void:
	# Clear existing
	for child in map_container.get_children():
		child.queue_free()
		
	var data: MapData = Global.map_data
	var viewport_height: float = get_viewport_rect().size.y
	
	# A. Pre-calculate "Persistent Frontier" logic
	# Identify nodes that should remain open for backtracking
	var persistent_frontier_indices: Dictionary = {}
	for g_pos in data.nodes:
		var n: MapNode = data.nodes[g_pos]
		if n.grid_position.x == data.max_reached_layer and n.is_visited:
			for next_pos in n.next_nodes:
				persistent_frontier_indices[next_pos] = true
	
	# B. Spawn Buttons
	for grid_pos in data.nodes:
		var node: MapNode = data.nodes[grid_pos]
		var btn: Button = Button.new()
		
		# Position Calculation
		var x_pos: float = MAP_PADDING_X + (node.grid_position.x * X_SPACING)
		var map_height_px: float = 4 * Y_SPACING 
		var start_y: float = (viewport_height - map_height_px) / 2.0
		var y_pos: float = start_y + (node.grid_position.y * Y_SPACING)
		btn.position = Vector2(x_pos, y_pos)
		
		btn.text = get_icon_for_type(node.type)
		btn.custom_minimum_size = Vector2(40, 40)
		
		# C. Determine Accessibility (Locked state)
		var is_locked: bool = _calculate_node_locked_state(node, data, persistent_frontier_indices)
		
		# D. Visual Style based on state
		if node.is_visited:
			# Visited Nodes
			if node.type == MapNode.Type.BATTLE or node.type == MapNode.Type.BOSS or node.type == MapNode.Type.ELITE:
				btn.disabled = true
				btn.modulate = Color.DARK_GRAY
			else:
				# Shops/Rest remain active
				btn.disabled = false
				btn.modulate = Color(0.5, 0.5, 1.0) # Light Blue
		elif is_locked:
			# Locked Nodes
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.2)
		else:
			# Available Nodes
			btn.disabled = false
			btn.modulate = Color.GREEN 
			
		# E. Events
		btn.pressed.connect(func(): _on_node_pressed(node))
		setup_button_sounds(btn)
		map_container.add_child(btn)
		
		# F. Rift Button (Boss Defeated)
		if node.type == MapNode.Type.BOSS and node.is_visited:
			_spawn_rift_button(btn.position)
			
	# Update Container Size
	var max_x: float = 0.0
	for grid_pos in data.nodes:
		var x: float = MAP_PADDING_X + (data.nodes[grid_pos].grid_position.x * X_SPACING)
		if x > max_x: max_x = x
	map_container.custom_minimum_size = Vector2(max_x + 300, 0)
	map_container.queue_redraw()

func _spawn_rift_button(boss_pos: Vector2) -> void:
	var rift_btn: Button = Button.new()
	rift_btn.text = "RIFT >"
	rift_btn.modulate = Color.CYAN
	rift_btn.scale = Vector2(0.8, 0.8)
	rift_btn.position = boss_pos + Vector2(50, 0)
	rift_btn.pressed.connect(_on_rift_pressed)
	setup_button_sounds(rift_btn)
	map_container.add_child(rift_btn)

func _calculate_node_locked_state(node: MapNode, data: MapData, persistent_frontier: Dictionary) -> bool:
	# Rule 1: Always accessible if behind max reached layer (Backtracking)
	if node.grid_position.x <= data.max_reached_layer:
		return false
		
	# Rule 2: Lateral Movement in same column (if started)
	if data.current_node_grid_pos != Vector2(-1, -1):
		if int(node.grid_position.x) == int(data.current_node_grid_pos.x):
			return false

	# Rule 3: Forward Connectivity
	if data.current_node_grid_pos != Vector2(-1, -1):
		var curr: MapNode = data.get_node(data.current_node_grid_pos)
		if curr and node.grid_position in curr.next_nodes:
			# Only allow 1 step ahead of max
			if node.grid_position.x <= data.max_reached_layer + 1:
				return false
	elif node.grid_position.x == 0:
		# Start nodes always open
		return false
	
	# Rule 4: Persistent Frontier (Unvisited options from previous cleared node)
	if persistent_frontier.has(node.grid_position):
		return false

	return true

func _on_node_pressed(node: MapNode) -> void:
	Audio.btn_pressed.play()
	Global.map_data.current_node_grid_pos = node.grid_position
	node.is_visited = true
	
	# Update Round Number based on map progression
	Global.current_round = Global.map_base_difficulty + int(node.grid_position.x)
	
	match node.type:
		MapNode.Type.BATTLE, MapNode.Type.ELITE:
			start_battle(0)
		MapNode.Type.BOSS:
			start_battle(10) # Boss Spike (+10 Rounds)
		MapNode.Type.REST:
			# Grant pending point (Legacy logic preserved: Grindable)
			if "upgrade_points_pending" in Global:
				Global.upgrade_points_pending += 1
			get_tree().change_scene_to_file("res://UI/upgrade_menu.tscn")
		MapNode.Type.SHOP:
			get_tree().change_scene_to_file("res://UI/shop_menu.tscn")
		_:
			render_map() 

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
	button.focus_entered.connect(Audio.btn_mov.play)
	button.mouse_entered.connect(Audio.btn_mov.play)
