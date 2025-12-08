class_name MapGenerator extends Node

const LAYERS = 10
const NODES_PER_LAYER_MIN = 3
const NODES_PER_LAYER_MAX = 4

func generate_map() -> MapData:
	var map_data = MapData.new()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Keep track of nodes in the previous layer to connect them
	var prev_layer_nodes: Array[MapNode] = []
	
	for layer in range(LAYERS):
		var nodes_in_this_layer: Array[MapNode] = []
		var count = rng.randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)
		
		# Boss logic: Layer 9 (Final) should be a single Boss node
		if layer == LAYERS - 1:
			count = 1
		
		for i in range(count):
			var node = MapNode.new()
			node.grid_position = Vector2(layer, i)
			
			# Determine Type (Default to Battle, we replace later)
			if layer == 0:
				node.type = MapNode.Type.BATTLE
			elif layer == LAYERS - 1:
				node.type = MapNode.Type.BOSS
			else:
				# Default to Battle
				node.type = MapNode.Type.BATTLE
				
				# User requested REMOVAL of Event nodes ("Question Marks").
				# Probability: 20% Elite, 80% Battle
				var roll = rng.randf()
				if roll < 0.20: 
					node.type = MapNode.Type.ELITE
				else:
					node.type = MapNode.Type.BATTLE
			
			map_data.nodes[node.grid_position] = node
			nodes_in_this_layer.append(node)
			
		# Connect layers
		if layer > 0:
			_connect_layers(prev_layer_nodes, nodes_in_this_layer, rng)
			
		prev_layer_nodes = nodes_in_this_layer
		
	# Post-Processing: Place Special Nodes (1 Shop, 1 Rest per Map)
	var valid_layers = range(1, LAYERS - 1) # Exclude Start (0) and Boss (Last)
	
	# Place Shop
	if valid_layers.size() > 0:
		var shop_layer = valid_layers.pick_random()
		var nodes = _get_nodes_in_layer(map_data, shop_layer)
		if nodes.size() > 0:
			# Prefer replacing a Battle node
			var candidates = nodes.filter(func(n): return n.type == MapNode.Type.BATTLE)
			if candidates.size() > 0:
				candidates.pick_random().type = MapNode.Type.SHOP
			else:
				nodes.pick_random().type = MapNode.Type.SHOP
			
	# Place Rest (Campfire)
	if valid_layers.size() > 0:
		var rest_layer = valid_layers.pick_random()
		var nodes = _get_nodes_in_layer(map_data, rest_layer)
		# Ensure we don't pick a node that is already a shop (unlikely unless same layer)
		var valid_nodes = nodes.filter(func(n): return n.type == MapNode.Type.BATTLE)
		
		if valid_nodes.size() > 0:
			valid_nodes.pick_random().type = MapNode.Type.REST
		elif nodes.size() > 0:
			# Fallback, try to find non-shop
			var non_shop = nodes.filter(func(n): return n.type != MapNode.Type.SHOP)
			if non_shop.size() > 0:
				non_shop.pick_random().type = MapNode.Type.REST
			
	return map_data

func _get_nodes_in_layer(data: MapData, layer: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for pos in data.nodes:
		if pos.x == layer:
			result.append(data.nodes[pos])
	return result

func _connect_layers(prev_nodes: Array[MapNode], current_nodes: Array[MapNode], _rng: RandomNumberGenerator) -> void:
	# 1. Ensure every Next Node has at least one parent
	# 2. Ensure every Prev Node has at least one child
	
	for p_node in prev_nodes:
		var p_idx = int(p_node.grid_position.y)
		
		for c_node in current_nodes:
			var c_idx = int(c_node.grid_position.y)
			if abs(p_idx - c_idx) <= 1: 
				p_node.next_nodes.append(c_node.grid_position)
	
	# Validation: Ensure every current node has a parent.
	for c_node in current_nodes:
		var has_parent = false
		for p_node in prev_nodes:
			if c_node.grid_position in p_node.next_nodes:
				has_parent = true
				break
		
		if not has_parent:
			var parent_candidates = []
			for p_node in prev_nodes:
				if abs(p_node.grid_position.y - c_node.grid_position.y) <= 1:
					parent_candidates.append(p_node)
			
			if parent_candidates.size() > 0:
				parent_candidates.pick_random().next_nodes.append(c_node.grid_position)
			else:
				prev_nodes.pick_random().next_nodes.append(c_node.grid_position)
