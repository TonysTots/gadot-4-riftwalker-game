@tool
## Contains all [AllyBattler] data.
class_name AllyStats extends Resource

@export_category("Main traits")
## The battler's display name in battle.
@export var name: String
## The UI theme for the battler:
@export var ui_theme: Theme
## How much will the texture will be up/down scalled ?
@export var texture_scale: float = 1.0
## Can this battler use magical abilities ? (allies only).
@export var can_use_magic: bool = true

@export_category("Actions")
## The attacks that the battler can perform.
@export var attackActions: Array[Attack]
## The battler's defend action.
@export var defendAction: Defend = load("uid://dtv4tf41ul5p")
## The magic actions of the batller.
@export var magicActions: Array[Spell]
## The items in the battler's inventory.
@export var items: Array[Item]

#####################################
## STAT SYSTEM (Body / Mind / Spirit)
#####################################
@export_category("Base Stats")
## Represents physical power and durability.
@export_range(1, 100) var body: int = 1:
	set(value):
		body = value
		notify_property_list_changed() # Updates the inspector immediately

## Represents intelligence and speed.
@export_range(1, 100) var mind: int = 1:
	set(value):
		mind = value
		notify_property_list_changed()

## Represents magic power and resilience.
@export_range(1, 100) var spirit: int = 1:
	set(value):
		spirit = value
		notify_property_list_changed()

#############################################
# DERIVED STATS (Calculated automatically)
#############################################
# Used standard RPG formulas here. 

## Health = (Body + Spirit) * 5
var health: int:
	get: return (body + spirit) * 20

## Magic Points = (Mind + Spirit) * 2
var magicPoints: int:
	get: return (mind + spirit) * 5

## Strength = Body + Mind
var strength: int:
	get: return (body + mind) * 2

## Defense = Body + Spirit
var defense: int:
	get: return (body + spirit) * 2

## Magic Strength = Mind + Spirit
var magicStrength: int:
	get: return (mind + spirit) * 2

## Speed = (Body + Mind) / 2
var speed: int:
	get: return (body + mind) * 5

@export_category("Text")
## This text will appear when your battler is knocked out.
@export_multiline var defeatedText: String

func create_sprite_frames() -> SpriteFrames:
	var spriteFramesInstance: SpriteFrames = SpriteFrames.new()
	spriteFramesInstance.remove_animation("default")
	spriteFramesInstance.add_animation("attack")
	spriteFramesInstance.add_animation("hurt")
	spriteFramesInstance.add_animation("defend")
	spriteFramesInstance.add_animation("defeated")
	spriteFramesInstance.add_animation("heal_magic")
	spriteFramesInstance.add_animation("offensive_magic")
	for animation: String in spriteFramesInstance.get_animation_names():
		spriteFramesInstance.set_animation_loop(animation, false)
		spriteFramesInstance.set_animation_speed(animation, 8.0)
	spriteFramesInstance.add_animation("idle")
	return spriteFramesInstance

@export_category("Sprites")
@export var createTemplate: bool = false:
	set(value):
		spriteFrames = create_sprite_frames()
## The sprites.
@export var spriteFrames: SpriteFrames
## Offset the sprite from the node's origin point.
@export var offset: Vector2 = Vector2.ZERO
