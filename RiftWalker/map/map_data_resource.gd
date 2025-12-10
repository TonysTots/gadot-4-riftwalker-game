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
