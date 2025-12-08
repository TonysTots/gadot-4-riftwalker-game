class_name MapNode extends Resource

enum Type {
	BATTLE,
	ELITE,
	SHOP,
	EVENT,
	BOSS,
	REST
}

@export var type: Type
@export var grid_position: Vector2 # X = Layer/Floor, Y = Lane
@export var next_nodes: Array[Vector2] = [] # Positions of connected nodes in next layer
@export var is_visited: bool = false
@export var is_locked: bool = true # Helper for UI
