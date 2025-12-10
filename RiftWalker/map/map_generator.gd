class_name MapGenerator extends Node

# --- CONFIGURATION ---
const LAYERS: int = 10
const NODES_PER_LAYER_MIN: int = 3
const NODES_PER_LAYER_MAX: int = 4

const PROBABILITY_ELITE: float = 0.20 # 20% Chance for Elite vs Normal

## Main entry point to generate a new procedural map.
func generate_map() -> MapData:
	var map_data: MapData = MapData.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	# Keep track of nodes in the previous layer to connect them
	var prev_layer_nodes: Array[MapNode] = []
	
	# 1. Generate Grid & Connections
	for layer in range(LAYERS):
		var nodes_in_this_layer: Array[MapNode] = []
		var count: int = rng.randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)
		
		# Boss logic: Layer 9 (Final) should be a single Boss node
		if layer == LAYERS - 1:
			count = 1
		
		for i in range(count):
			var node: MapNode = MapNode.new()
			node.grid_position = Vector2(layer, i)
			node.type = _determine_node_type(layer, rng)
			
			map_data.nodes[node.grid_position] = node
			nodes_in_this_layer.append(node)
			
		# Connect layers (Forward linking)
		if layer > 0:
			_connect_layers(prev_layer_nodes, nodes_in_this_layer, rng)
			
		prev_layer_nodes = nodes_in_this_layer
		
	# 2. Post-Processing: Place Special Nodes (1 Shop, 1 Rest per Map)
	_place_special_node(map_data, MapNode.Type.SHOP, rng)
	_place_special_node(map_data, MapNode.Type.REST, rng)
			
	return map_data

## Helper to decide the initial type of a node based on layer depth.
func _determine_node_type(layer: int, rng: RandomNumberGenerator) -> MapNode.Type:
	if layer == 0:
		return MapNode.Type.BATTLE
	elif layer == LAYERS - 1:
		return MapNode.Type.BOSS
	else:
		if rng.randf() < PROBABILITY_ELITE: 
			return MapNode.Type.ELITE
		return MapNode.Type.BATTLE

## Randomly converts an existing Battle node into a Special type (Shop/Rest).
func _place_special_node(data: MapData, type: MapNode.Type, _rng: RandomNumberGenerator) -> void:
	var valid_layers: Array = range(1, LAYERS - 1) # Exclude Start (0) and Boss (Last)
	if valid_layers.is_empty(): return
	
	var target_layer: int = valid_layers.pick_random()
	var nodes_in_layer: Array[MapNode] = _get_nodes_in_layer(data, target_layer)
	
	if nodes_in_layer.is_empty(): return
	
	# Prefer replacing a BATTLE node to avoid overwriting other specials if we add more later
	var candidates: Array[MapNode] = nodes_in_layer.filter(func(n): return n.type == MapNode.Type.BATTLE)
	
	if not candidates.is_empty():
		candidates.pick_random().type = type
	else:
		# Fallback: Overwrite anything (except Boss/Start effectively due to layer range)
		nodes_in_layer.pick_random().type = type

## Retrieves all nodes belonging to a specific X layer.
func _get_nodes_in_layer(data: MapData, layer: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for pos in data.nodes:
		if int(pos.x) == layer:
			result.append(data.nodes[pos] as MapNode)
	return result

## Logic to connect two layers ensuring navigability (No dead ends, no orphans).
func _connect_layers(prev_nodes: Array[MapNode], current_nodes: Array[MapNode], _rng: RandomNumberGenerator) -> void:
	# Rule A: Every Previous Node must lead to at least one Current Node (No Dead Ends)
	for p_node in prev_nodes:
		var p_idx: int = int(p_node.grid_position.y)
		
		for c_node in current_nodes:
			var c_idx: int = int(c_node.grid_position.y)
			# Connect if physically close (Lane +/- 1)
			if abs(p_idx - c_idx) <= 1: 
				p_node.next_nodes.append(c_node.grid_position)
	
	# Rule B: Every Current Node must have at least one Parent (No Orphans)
	for c_node in current_nodes:
		var has_parent: bool = false
		for p_node in prev_nodes:
			if c_node.grid_position in p_node.next_nodes:
				has_parent = true
				break
		
		# If orphan, force a connection from a nearby parent
		if not has_parent:
			var parent_candidates: Array[MapNode] = []
			for p_node in prev_nodes:
				if abs(p_node.grid_position.y - c_node.grid_position.y) <= 1:
					parent_candidates.append(p_node)
			
			if not parent_candidates.is_empty():
				parent_candidates.pick_random().next_nodes.append(c_node.grid_position)
			else:
				# Emergency link (should rarely happen given generation params)
				prev_nodes.pick_random().next_nodes.append(c_node.grid_position)
