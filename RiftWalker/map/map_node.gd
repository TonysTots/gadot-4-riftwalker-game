class_name MapNode extends Resource

## Defines the possible encounter types for a map node.
enum Type {
	BATTLE,
	ELITE,
	SHOP,
	EVENT,
	BOSS,
	REST
}

# --- PROPERTIES ---
## The encounter type of this node.
@export var type: Type
## Grid coordinates: X = Layer/Depth, Y = Lane/Index.
@export var grid_position: Vector2
## List of grid positions (Vector2) that this node connects TO in the next layer.
@export var next_nodes: Array[Vector2] = []
## Tracks if the player has successfully visited/cleared this node.
@export var is_visited: bool = false

# --- UI STATES (Runtime Only) ---
## Used by MapScreen to visualize accessibility. Not saved.
@export var is_locked: bool = true
