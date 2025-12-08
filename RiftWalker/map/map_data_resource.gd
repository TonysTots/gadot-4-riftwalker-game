class_name MapData extends Resource

# Key: Vector2 (Layer, Lane), Value: MapNode
@export var nodes: Dictionary = {}
@export var current_node_grid_pos: Vector2 = Vector2(-1, -1) # -1 means haven't started
@export var max_reached_layer: int = 0

func get_node(grid_pos: Vector2) -> MapNode:
	return nodes.get(grid_pos)
