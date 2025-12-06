## Class for every enemy battler.
##
## This class takes an [EnemyStats] resource that contains all of the enemy's data, 
## If you're trying to create an enemy then create an [EnemyStats] resoruce and then fill
##  in everything and finaly add it into a battle [BattleData] resource.


class_name EnemyBattler extends Battler

## Most important variable, conatins all the enemy's data.
@export var stats: EnemyStats
## 2nd most important variable, contains all the [EnemyAction] that this enemy
## can possibly perform.
@onready var actions: Array[EnemyAction] = stats.actions

## This variable is related to how the enemy can randomaly choose [EnemyAction]s
## from [member EnemyBattler.actions] based on specific weights, 
## look into [method RandomNumberGenerator.rand_weighted] to learn more.
var actionChances: Array = []
## [RandomNumberGenerator] object.
var random: RandomNumberGenerator
## The action that this enemy will perfom when [method EnemyBattler.perform_action] is called.
var actionToPerform: EnemyAction
var targetBattlers: Array[Battler]

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var health_label: Label = %HealthLabel

# Defending stuff:
var isDefending: bool = false
var defendAmount: int

@onready var health: int = stats.health:
	set(val):
		health = val
		
		# Update UI whenever health changes
		if health_label:
			health_label.text = "HP: " + str(health)
		if health_bar:
			health_bar.value = health
@onready var strength: int = stats.strength
@onready var magicStrength: int = stats.magicStrength
@onready var defense: int = stats.defense
@onready var speed: int = stats.speed
@onready var defeatedText: String = stats.defeatedText
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	super._ready()
	check_abstract_classes()
	randomize()
	
	name_ = stats.name_
	
	animated_sprite_2d.scale *= stats.texture_scale
	random = RandomNumberGenerator.new()
	for action: EnemyAction in actions:
		actionChances.append(action.enemyActionChance)
	
	if health_bar:
		health_bar.max_value = health
		health_bar.value = health
		health_bar.show_percentage = false
	self.health = stats.health
	
	# Load SpriteFrames:
	animated_sprite_2d.sprite_frames = stats.spriteFrames
	animated_sprite_2d.play("idle")
	animated_sprite_2d.offset += stats.offset
	# init other stuff:
	opponents = "allies"

func decide_action() -> void:
	handle_defense()
	# Battler can't decide since it's disabled (asleep, paralyzed, etc...).
	if isDisabled:
		actionToPerform = null
		targetBattlers.clear()
		await get_tree().create_timer(0.01).timeout
		self.deciding_finished.emit()
		return
	actionToPerform = actions[random.rand_weighted(actionChances)]
	if actionToPerform is EnemyAttack:
		if actionToPerform.actionTargetType == EnemyAttack.ActionTargetType.SINGLE_ALLY:
			targetBattlers.append(get_tree().get_nodes_in_group("allies").pick_random())
		elif actionToPerform.actionTargetType == EnemyAttack.ActionTargetType.ALL_ALLIES:
			targetBattlers.assign(get_tree().get_nodes_in_group("allies").duplicate())
	elif actionToPerform is EnemyDefend:
		targetBattlers.append(self)
	await get_tree().create_timer(0.01).timeout
	self.deciding_finished.emit()

func perform_action() -> void:
	SignalBus.cursor_come_to_me.emit(self.global_position, false)
	process_immunities()

	# 1. Handle Status Effects (Sleep, Paralysis, etc.)
	# If this returns true, the turn is over (either stunned or just woke up)
	if await _handle_status_effects():
		return

	# 2. Announce Action
	SignalBus.display_text.emit(name_ + " " + actionToPerform.actionText)
	Audio.action.stream = actionToPerform.sound
	await SignalBus.text_window_closed

	# 3. Perform Action on all targets
	for battler in targetBattlers:
		# Skip if target is already dead (unless it's a multi-target attack, logic handled below)
		if battler.isDefeated:
			SignalBus.display_text.emit(battler.name_ + " has already been defeated!")
			await SignalBus.text_window_closed
			continue

		if actionToPerform is EnemyAttack:
			# _perform_attack returns true if the battle ends (Player lost)
			if await _perform_attack(battler):
				return 
		
		elif actionToPerform is EnemyDefend:
			await _perform_defend(battler)

	# 4. Clean up
	targetBattlers.clear()
	performing_action_finished.emit()

func check_abstract_classes() -> void:
	for action: EnemyAction in actions:
		if action is EnemyAttack or action is EnemyDefend:
			pass
		# This is an abstract class; Throw error:
		else:
			var class_ = action.get_script().get_global_name()
			var path_ := action.resource_path
			var error := "The action at: \"%s\" is an instance of the abstract class \"%s\"."
			error += "\nMake the action inherit \"EnemyAttack\" or \"EnemyDefend\"."
			var formated := error % [path_, class_]
			assert(false, formated)

# Override the parent setter to also update the UI Label
func _set_name(value: String) -> void:
	super._set_name(value) # Call the parent function to store the string
	
	# Update the visual label if it exists
	if %NameLabel:
		%NameLabel.text = value

## Handles the defense stat.
func handle_defense() -> void:
	if isDefending:
		defense -= defendAmount
		isDefending = false

# Handles status duration, removal, immunity, and skipping turns.
# Returns true if the battler cannot act this turn.
func _handle_status_effects() -> bool:
	if disablingStatusEffect == null:
		return false # No status, proceed with turn
		
	disablingStatusEffect.effectDuration -= 1
	
	# Case A: Status wore off
	if disablingStatusEffect.effectDuration <= 0:
		isDisabled = false
		SignalBus.display_text.emit(name_ + " " + disablingStatusEffect.removalText)
		await SignalBus.text_window_closed
		
		# Grant Immunity
		add_immunity(disablingStatusEffect.name_, 2)
		SignalBus.display_text.emit(name_ + " is now resistant to " + disablingStatusEffect.name_)
		await SignalBus.text_window_closed
		
		disablingStatusEffect = null
		status_effect_sprite.texture = null
		performing_action_finished.emit()
		return true # Turn consumed by waking up
	
	# Case B: Status still active
	SignalBus.display_text.emit(name_ + " " + disablingStatusEffect.text)
	Audio.status_effect.stream = disablingStatusEffect.sound
	Audio.status_effect.play()
	await SignalBus.text_window_closed
	performing_action_finished.emit()
	return true # Turn skipped

# Handles damage calculation, animation, and death checks.
# Returns true if the game ended.
func _perform_attack(target: Battler) -> bool:
	play_anim("attack")
	Audio.action.play()
	
	# Calculate Damage
	var damage: int = (actionToPerform.damageAmount + strength) - target.defense
	
	if randf() <= 0.1: # 10% Chance
		damage *= 2
		SignalBus.display_text.emit("CRITICAL HIT!")
		await SignalBus.text_window_closed
	
	damage = clamp(damage, 0, 9999999)
	
	# Apply Damage
	target.health -= damage
	SignalBus.display_text.emit(target.name_ + " took " + str(damage) + " !")
	
	Audio.play_action_sound("hurt")
	target.play_anim("hurt")
	
	await SignalBus.text_window_closed
	await get_tree().create_timer(0.1).timeout
	
	# Check for Death
	if target.health <= 0:
		if await _handle_target_death(target):
			return true # Battle Lost
			
	return false

# Handles defense buffs and animations.
func _perform_defend(target: Battler) -> void:
	play_anim("defend")
	Audio.action.play()
	
	var defenseAmount: int = actionToPerform.defenseAmount
	self.defense += defenseAmount
	defendAmount = defenseAmount # Store for removal next turn
	isDefending = true
	
	SignalBus.display_text.emit(target.name_ + "'s defense increased by " + str(defenseAmount) + " !")
	Audio.play_action_sound("defend")
	target.play_anim("defend")
	
	await SignalBus.text_window_closed
	await get_tree().create_timer(0.1).timeout

# Handles the death sequence (animation, text, win condition).
# Returns true if the enemies won (Player lost).
func _handle_target_death(target: Battler) -> bool:
	target.isDefeated = true
	Audio.down.play()
	target.play_anim("defeated")
	await get_tree().create_timer(1.0).timeout
	
	SignalBus.display_text.emit(target.defeatedText)
	await SignalBus.text_window_closed
	
	if check_if_we_won():
		SignalBus.battle_lost.emit()
		return true
		
	return false
