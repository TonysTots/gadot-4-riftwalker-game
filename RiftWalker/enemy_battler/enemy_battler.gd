## Class for every enemy battler.
class_name EnemyBattler extends Battler

# --- DATA ---
## Most important variable, conatins all the enemy's data.
@export var stats: EnemyStats

# --- LOGICAL PROPERTIES ---
## All the [EnemyAction] that this enemy can possibly perform.
@onready var actions: Array[EnemyAction] = stats.actions
## Weights for random action selection.
var actionChances: Array[float] = []

## Random Generator.
var random: RandomNumberGenerator

## The chosen action for this turn.
var actionToPerform: EnemyAction
## The target(s) for the action.
var targetBattlers: Array[Battler] = []

# --- UI NODES ---
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var health_label: Label = %HealthLabel
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# --- STATE ---
var isDefending: bool = false
var defendAmount: int = 0

# --- STAT PROXIES ---
## Current Health (Logic + UI Update)
@onready var health: int = stats.health:
	set(val):
		health = clamp(val, 0, max_health)
		if health_label: health_label.text = "HP: " + str(health)
		if health_bar: health_bar.value = health

var max_health: int:
	get: return stats.health
var strength: int:
	get: return stats.strength
var magicStrength: int:
	get: return stats.magicStrength
var defense: int:
	get: return stats.defense
var speed: int:
	get: return stats.speed
@onready var defeatedText: String = stats.defeatedText

func _ready() -> void:
	super._ready()
	
	random = RandomNumberGenerator.new()
	random.randomize()
	
	name_ = stats.name_
	opponents = "allies"
	
	_setup_visuals()
	_setup_actions()
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.show_percentage = false
		
	# Trigger setter
	health = health

func _setup_visuals() -> void:
	if animated_sprite_2d:
		animated_sprite_2d.scale *= stats.texture_scale
		animated_sprite_2d.sprite_frames = stats.spriteFrames
		animated_sprite_2d.play("idle")
		animated_sprite_2d.offset += stats.offset

func _setup_actions() -> void:
	for action: EnemyAction in actions:
		actionChances.append(action.enemyActionChance)
		
	# Check for abstract classes (Debug safety)
	for action: EnemyAction in actions:
		if not (action is EnemyAttack or action is EnemyDefend):
			push_error("Enemy Action %s is abstract! Use distinct subclasses." % action.resource_path)

# --- TURN LOGIC ---

## Decision Phase
func decide_action() -> void:
	handle_defense() # Reset defense from previous turn
	
	# Status Check
	if isDisabled:
		actionToPerform = null
		targetBattlers.clear()
		await get_tree().process_frame
		deciding_finished.emit()
		return

	# Logic: Pick Weighted Random Action
	var chosen_idx: int = random.rand_weighted(actionChances)
	if chosen_idx == -1: chosen_idx = 0 # Fallback
	
	actionToPerform = actions[chosen_idx]
	
	targetBattlers.clear()
	
	if actionToPerform is EnemyAttack:
		var targets: Array[Node] = get_tree().get_nodes_in_group("allies")
		if targets.is_empty():
			# Everyone dead? Should have ended.
			targets = [self] # Fallback to prevent crash
			
		if actionToPerform.actionTargetType == EnemyAttack.ActionTargetType.SINGLE_ALLY:
			# Pick one random ally
			targetBattlers.append(targets.pick_random() as Battler)
		elif actionToPerform.actionTargetType == EnemyAttack.ActionTargetType.ALL_ALLIES:
			for t in targets:
				if t is Battler: targetBattlers.append(t)
				
	elif actionToPerform is EnemyDefend:
		targetBattlers.append(self)
		
	await get_tree().process_frame
	deciding_finished.emit()

## Execution Phase
func perform_action() -> void:
	SignalBus.cursor_come_to_me.emit(self.global_position, false)
	process_immunities()

	# 1. Handle Status Effects (Sleep, Paralysis, etc.)
	# If this returns true, the turn is over (either stunned or just woke up)
	if await _handle_status_effects():
		return

	# 2. Announce Action
	if actionToPerform:
		SignalBus.display_text.emit(name_ + " " + actionToPerform.actionText)
		Audio.action.stream = actionToPerform.sound
	await SignalBus.text_window_closed

	# 3. Perform Action on all targets
	for battler in targetBattlers:
		# Skip if target is already dead (unless it's a multi-target attack, but usually hitting corpses is bad UX)
		if battler.isDefeated:
			SignalBus.display_text.emit(battler.name_ + " has already been defeated!")
			await SignalBus.text_window_closed
			continue

		if actionToPerform is EnemyAttack:
			await _perform_attack(battler)
			if check_if_we_won(): return # If we killed last ally, end immediately
		
		elif actionToPerform is EnemyDefend:
			await _perform_defend(battler)

	# 4. Clean up
	targetBattlers.clear()
	performing_action_finished.emit()

# --- ACTION HANDLERS ---

func _perform_attack(target: Battler) -> void:
	play_anim("attack")
	if Audio.action.stream: Audio.action.play()
	
	# Calculate Damage
	var damage: int = (actionToPerform.damageAmount + strength)
	var is_crit: bool = (randf() <= 0.1) # 10% Chance
	
	if is_crit: damage *= 2
	
	# Apply Mitigation (Consistency: Subtract Defense)
	var final_damage: int = damage
	if "defense" in target:
		final_damage = clampi(damage - target.get("defense"), 0, 9999999)
	
	# Apply
	target.take_damage(final_damage, is_crit)
	
	if is_crit:
		SignalBus.display_text.emit("CRITICAL HIT!")
		await SignalBus.text_window_closed
	else:
		await wait_with_skip(0.5)
	
	await get_tree().create_timer(0.1).timeout
	
	# Check Death
	await _check_target_defeat(target)

func _perform_defend(target: Battler) -> void:
	play_anim("defend")
	if Audio.action.stream: Audio.action.play()
	
	var defenseAmount: int = actionToPerform.defenseAmount
	self.defense += defenseAmount
	defendAmount = defenseAmount # Store for removal next turn
	isDefending = true
	
	SignalBus.display_text.emit(target.name_ + "'s defense increased by " + str(defenseAmount) + " !")
	Audio.play_action_sound("defend")
	target.play_anim("defend")
	
	await SignalBus.text_window_closed

# --- STATE MANAGEMENT ---

## Reset defense buff from previous turn.
func handle_defense() -> void:
	if isDefending:
		defense -= defendAmount
		isDefending = false
		defendAmount = 0 # Reset amount too

## Handles status duration, removal, immunity, and skipping turns.
## Returns true if the battler cannot act this turn.
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
		
		# Cleanup
		disablingStatusEffect = null
		if status_effect_sprite: status_effect_sprite.texture = null
		
		# Turn consumed by waking up (Design choice: Waking up takes the turn?)
		# Original code returned true here. I'll preserve it.
		performing_action_finished.emit()
		return true 
	
	# Case B: Status still active
	SignalBus.display_text.emit(name_ + " " + disablingStatusEffect.text)
	Audio.status_effect.stream = disablingStatusEffect.sound
	Audio.status_effect.play()
	await SignalBus.text_window_closed
	
	performing_action_finished.emit()
	return true # Turn skipped

## Checks and handles target death.
func _check_target_defeat(target: Battler) -> void:
	var hp: int = 1
	if "health" in target: hp = target.get("health")
	
	if hp <= 0 and not target.isDefeated:
		target.isDefeated = true
		Audio.down.play()
		target.play_anim("defeated")
		await get_tree().create_timer(1.0).timeout
		
		var d_text: String = "Defeated!"
		if "defeatedText" in target: d_text = target.get("defeatedText")
		
		SignalBus.display_text.emit(d_text)
		await SignalBus.text_window_closed
		
		if check_if_we_won():
			SignalBus.battle_lost.emit() # Logic inversion: Enemies Check Win = Players Lost

# Override set_name to update label
func _set_name(value: String) -> void:
	super._set_name(value)
	if has_node("%NameLabel"):
		%NameLabel.text = value
