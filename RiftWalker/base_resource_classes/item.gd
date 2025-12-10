## Class for ally healing items.

class_name Item extends AllyAction

@export_category("Item data")
enum ActionTargetType {
	SINGLE_ALLY, ## This action targets 1 singular ally battler in this battle.
	ALL_ALLIES, ## This action targets all the ally battlers in this battle.
	}
## The number of allies this item can be used on.
@export var actionTargetType: ActionTargetType = ActionTargetType.SINGLE_ALLY
## How much health this item will recover.
## How much health this item will recover.
@export_range(0, 9999999, 5) var healthAmount: int = 50
## How much magic points this item will recover.
@export_range(0, 9999999, 5) var magicAmount: int = 0
## If true, this item restores all magic points.
@export var restoreAllMagic: bool = false
## If true, this item restores all health.
@export var restoreAllHealth: bool = false

@export_category("Visuals")
@export var icon: Texture2D ## Drag your image file here in the Inspector!

@export var price: int = 50
@export_multiline var description: String = "Restores health."
