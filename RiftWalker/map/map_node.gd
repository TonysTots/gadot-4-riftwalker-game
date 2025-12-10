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
@export var is_locked: bool = true

# --- SERIALIZATION ---

func to_dict() -> Dictionary:
	# Convert next_nodes (Vector2 array) to Array of Dictionaries for JSON safety
	var next_list: Array = []
	for v in next_nodes:
		next_list.append({"x": v.x, "y": v.y})

	return {
		"type": type,
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
		"next_nodes_list": next_list,
		"is_visited": is_visited
	}

static func from_dict(data: Dictionary) -> MapNode:
	var node = MapNode.new()
	node.type = int(data.get("type", 0))
	node.grid_position = Vector2(data.get("grid_x", 0), data.get("grid_y", 0))
	node.is_visited = data.get("is_visited", false)
	
	var typed_next_nodes: Array[Vector2] = []
	var list = data.get("next_nodes_list", [])
	for item in list:
		typed_next_nodes.append(Vector2(item.get("x", 0), item.get("y", 0)))
	
	node.next_nodes = typed_next_nodes
		
	return node
