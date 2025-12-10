class_name MapData extends Resource

# --- STORAGE ---
## All nodes in the map. Key: Vector2 (Layer, Lane), Value: MapNode
@export var nodes: Dictionary = {}

# --- PROGRESSION ---
## The player's current position on the grid. (-1, -1) indicates not started.
@export var current_node_grid_pos: Vector2 = Vector2(-1, -1)
## The deepest layer index (X) the player has cleared (for backtracking rules).
@export var max_reached_layer: int = 0

## Helper to retrieve a node safely by grid position.
func get_node(grid_pos: Vector2) -> MapNode:
	return nodes.get(grid_pos) as MapNode

func to_dict() -> Dictionary:
	var nodes_data: Array = []
	for key in nodes:
		var node: MapNode = nodes[key]
		if node:
			nodes_data.append(node.to_dict())
			
	return {
		"current_x": current_node_grid_pos.x,
		"current_y": current_node_grid_pos.y,
		"max_reached": max_reached_layer,
		"nodes_data": nodes_data
	}

static func from_dict(data: Dictionary) -> MapData:
	var map = MapData.new()
	map.current_node_grid_pos = Vector2(data.get("current_x", -1), data.get("current_y", -1))
	map.max_reached_layer = int(data.get("max_reached", 0))
	
	map.nodes = {}
	var list = data.get("nodes_data", [])
	for node_dict in list:
		var node = MapNode.from_dict(node_dict)
		map.nodes[node.grid_position] = node
		
	return map
