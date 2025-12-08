## Class for all the ally battlers (party member).
##
## This class takes an [AllyStats] resource that contains all of the ally's data, 
## If you're trying to create an ally then create an [AllyStats] resoruce and then fill
##  in everything and finaly add it into a battle [BattleData] resource.

class_name AllyBattler extends Battler

## Parent of UI buttons and selection windows.
@onready var control: Control = %Control
## Menu where action names and battler names appear when selecting.
@onready var selection_window: NinePatchRect = $UI/Control/SelectionWindow
## [VBoxContainer] that contains [Label]s with battler/action names.
@onready var options_container: VBoxContainer = $"%OptionsContainer"
## [HBoxContainer] that contains all the UI buttons (attack button, defend button, ect...).
@onready var button_container: HBoxContainer = %ButtonContainer
## Displays list of possible attacks when clicked.
@onready var attack_button: Button = %AttackButton
## Displays list of possible spells when clicked.
@onready var magic_button: Button = %MagicButton
## Displays list of avalible items when clicked.
@onready var item_button: Button = %ItemButton
## handles the defense stat.
@onready var defending_manager: Node = $DefendingDecider_Manager
## Ally's health bar.
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
## Ally's magic points bar.
@onready var magic_bar: ProgressBar = $VBoxContainer/MagicBar
## [AnimatedSprite2D] that displays all Ally animations.
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
## Displays the Ally's health.
@onready var health_label: Label = %HealthLabel
## Displays the Ally's MP (magic points).
@onready var magic_points_label: Label = %MagicPointsLabel
## Most important variable, 
## contains actions, sprites, UI theme, ect...
@export var stats: AllyStats

## Ally dies when it reaches zero.
@onready var health: int = stats.health:
	set(value):
		if value >= max_health:
			health = max_health
		else:
			health = value
		health_label.text = "HP: " + str(health)
		health_bar.value = health
## Required for casting magic spells.
@onready var magicPoints: int = stats.magicPoints:
	set(value):
		magicPoints = value
		magic_points_label.text = "MP: " + str(magicPoints)
		magic_bar.value = value
## Ally's health can't exceed this.
var max_health: int:
	get: return stats.health
## How much physical damage the Ally can do.
var strength: int:
	get: return stats.strength
## How potent this Ally's spells are.
var magicStrength: int:
	get: return stats.magicStrength
## Reduces damage from enemies.
var defense: int:
	get: return stats.defense
## The battler with the highest speed gets to act first.
var speed: int:
	get: return stats.speed
## Gets displayed when this Ally dies.
@onready var defeatedText: String = stats.defeatedText

## All the possible attacks this Ally can perform.
@onready var attackActions: Array[Attack] = stats.attackActions
## This action is performed when the Ally defends.
@onready var defendAction: Defend = stats.defendAction
## All spells that this Ally can use.
@onready var magicActions: Array[Spell] = stats.magicActions
## All items in this Ally's inventory.
@onready var items: Array[Item] = stats.items.duplicate()

## The [AllyAction] that this Ally will do when it can act.
var actionToPerform: AllyAction
## All the [Battler]s ([AllyBattler]s, [EnemyBattler]s) that this Ally's next action will target.
var targetBattlers: Array[Battler]

const TEXT_LABEL: PackedScene = preload("uid://cotypm82phjd3")

func _ready() -> void:
	super._ready()
	$UI/Control/SelectionWindow.hide()
	check_abstract_classes()
	
	name_ = stats.name
	
	# Show UI:
	$UI.show()
	# Show battler name:
	$"%NameLabel".text = stats.name
	health_bar.max_value = self.health
	magic_bar.max_value = magicPoints
	health += 0; magicPoints += 0 # init the progress bars.
	control.theme = stats.ui_theme
	button_container.hide()
	animated_sprite_2d.scale *= stats.texture_scale
	animated_sprite_2d.flip_h = true
	animated_sprite_2d.offset.y -= 40
	if stats.can_use_magic == false:
		magic_button.queue_free()
		magic_bar.hide()
		magic_points_label.hide()
	# Load SpriteFrames:
	animated_sprite_2d.sprite_frames = stats.spriteFrames
	animated_sprite_2d.play("idle")
	animated_sprite_2d.offset += stats.offset
	#init other stuff:
	opponents = "enemies"
	
	SignalBus.battle_lost.connect(on_battle_lost)
	
	for button: Button in %ButtonContainer.get_children():
		button.mouse_entered.connect(func() -> void:
			button.grab_focus())
		
		if not button.focus_entered.is_connected(on_button_focus_changed):
			button.focus_entered.connect(on_button_focus_changed)

## This method checks if the user has accidentally put an abstract class resource
## into one of the [AllyAction] lists.
func check_abstract_classes() -> void:
	# check all the spell actions:
	for action: AllyAction in magicActions:
		# Do nothing if it's one of the normal inetended child classes:
		if action is HealingSpell or action is OffensiveSpell or action is CurseSpell:
			pass
		# This is an abstract class; Throw error:
		else:
			@warning_ignore("shadowed_variable", "shadowed_variable_base_class")
			var name_ := action.actionName
			var class_ = action.get_script().get_global_name()
			var path_ := action.resource_path
			var error := "The action \"%s\" at: \"%s\" is an instance of the abstract class \"%s\"."
			error += "\nMake the action inherit \"OffensiveSpell\" or \"HealingSpell\" or \"CurseSpell\"."
			var formated := error % [name_, path_, class_]
			assert(false, formated)

## Allows player to choose an [AllyAction] ([Attack], [Defend], [Item], ect...)
## that this [AllyBattler] will perform.
func decide_action() -> void:
	# Clear labels:
	for label: Label in $"%OptionsContainer".get_children():
		if label: label.queue_free()
	SignalBus.cursor_come_to_me.emit(self.global_position, true)
	if items.size() <= 0:
		item_button.hide()
	defending_manager.manage_defense_stat()
	targetBattlers.clear()
	button_container.show()
	await get_tree().create_timer(0.01).timeout
	attack_button.grab_focus()

## Lets the [AllyBattler] perform the [AllyAction] that they chose in
## [method AllyBattler.decide_action]
func perform_action() -> void:
	print("DEBUG: Ally " + name + " starting perform_action")
	# 1. Announce the action
	SignalBus.cursor_come_to_me.emit(self.global_position, true)
	SignalBus.display_text.emit(name_ + " " + actionToPerform.actionText)
	Audio.action.stream = actionToPerform.sound
	await SignalBus.text_window_closed

	# 2. Process all targets
	for i in range(targetBattlers.size()):
		var target = targetBattlers[i]
		
		# Handle Retargeting (if target died before we could hit them)
		if target.isDefeated:
			target = _get_new_target_if_dead(target)
			if target.isDefeated: continue # Could not find a new target
		
		# Execute the specific action logic
		if actionToPerform is Attack:
			await _perform_attack(target)
		elif actionToPerform is Defend:
			await _perform_defend(target)
		elif actionToPerform is Spell:
			await _perform_spell(target)
		elif actionToPerform is Item:
			await _perform_item(target)
			
		# Check if the battle is won after this specific action
		if SignalBus.battle_won.get_connections().size() > 0:
			# If we won, stop everything.
			# (We check victory inside _handle_target_defeat)
			if check_if_we_won(): return

	# 3. Cleanup
	targetBattlers.clear()
	print("DEBUG: Ally " + name + " emitting performing_action_finished")
	performing_action_finished.emit()

## Method that calculates damage done to [EnemyBattler]s by performing
## [Attack]s and [OffensiveSpell]s.
func damage_actions(battler: Battler, isMagic: bool) -> void:
	# 1. Calculate potential damage
	var damage: int
	if not isMagic:
		damage = (actionToPerform.damageAmount + strength)
	else:
		damage = (actionToPerform.damageAmount + magicStrength)
	
	if randf() <= 0.1: # 10% Chance
		damage *= 2
		SignalBus.display_text.emit("CRITICAL HIT!")
		await SignalBus.text_window_closed
	
	damage = damage - battler.defense
	damage = clamp(damage, 0, 9999999)
	
	# 2. Tell the target to take that damage
	battler.take_damage(damage)
	
	# 3. Play the sound (Global audio is fine here, or move to Battler too)
	Audio.play_action_sound("hurt")

## Updates health and magic points labels.
func _process(_delta: float) -> void:
	health_label.text = "HP: " + str(health)
	magic_points_label.text = "MP: " + str(magicPoints)

func _on_cancel_button_pressed() -> void:
	Audio.btn_pressed.play()
	
	# --- NEW: Clear the previous options to prevent duplicates ---
	for child in options_container.get_children():
		child.queue_free()
	
	# 1. Hide the Selection Window (Spells/Items list)
	selection_window.hide()
	
	# 2. Show the Main Action Buttons (Attack/Magic/Item)
	button_container.show()
	
	# 3. Reset focus to the Attack button
	attack_button.grab_focus()

## Plays a UI sound.
func on_button_focus_changed() -> void:
	Audio.btn_mov.play()

func on_battle_lost() -> void:
	# 1. Hide the entire UI container for this character
	if control:
		control.hide()
	
	# 2. Hide specific containers just to be safe
	if button_container:
		button_container.hide()
	if selection_window:
		selection_window.hide()

	# 3. Stop this battler from accepting any more inputs (Prevent clicking)
	set_process_input(false)
	set_process_unhandled_input(false)

# Logic to find a living target if the original one died
func _get_new_target_if_dead(dead_target: Battler) -> Battler:
	var target_group = "enemies" if dead_target is EnemyBattler else "allies"
	var candidates = get_tree().get_nodes_in_group(target_group)
	
	# Try to find the next living battler in the list
	for candidate in candidates:
		if not candidate.isDefeated:
			return candidate
			
	return dead_target # Everyone is dead, return original to fail safely

func _perform_attack(target: Battler) -> void:
	play_anim("attack")
	Audio.action.play()
	
	# Calculate Damage & Critical Hit
	var damage = actionToPerform.damageAmount + strength
	var is_crit = false
	
	if randf() <= 0.1: # 10% Crit Chance
		damage *= 2
		is_crit = true
	
	await _apply_damage(target, damage, is_crit)
	
	if is_crit:
		# Juice is now handled in take_damage so it's instant
		SignalBus.display_text.emit("CRITICAL HIT!")
		await SignalBus.text_window_closed
	else:
		# If no text box, we still need a brief pause so attacks don't feel instant/weightless
		await wait_with_skip(0.5)

func _perform_defend(target: Battler) -> void:
	play_anim("defend")
	Audio.action.play()
	
	var defenseAmount = actionToPerform.defenseAmount
	self.defense += defenseAmount
	
	SignalBus.display_text.emit(target.name_ + "'s defense increased by " + str(defenseAmount) + "!")
	Audio.play_action_sound("defend")
	target.play_anim("defend")
	
	await SignalBus.text_window_closed
	await get_tree().create_timer(0.1).timeout

func _perform_spell(target: Battler) -> void:
	if actionToPerform is OffensiveSpell:
		play_anim("offensive_magic")
		Audio.action.play()
		var damage = actionToPerform.damageAmount + magicStrength
		
		# --- NEW: Spell Critical Hit ---
		var is_crit = false
		if randf() <= 0.1: # 10% Chance
			damage *= 2
			is_crit = true
		# -------------------------------
		
		await _apply_damage(target, damage, is_crit)
		
	elif actionToPerform is HealingSpell:
		play_anim("heal_magic")
		Audio.action.play()
		@warning_ignore("integer_division")
		var heal_amount = actionToPerform.healingAmount + (magicStrength / 2)
		target.health += heal_amount
		
		SignalBus.display_text.emit(target.name_ + " recovered " + str(heal_amount) + " HP!")
		Audio.play_action_sound("heal")
		target.play_anim("heal")
		await SignalBus.text_window_closed
		await get_tree().create_timer(0.1).timeout

	elif actionToPerform is CurseSpell:
		await _perform_curse(target)

func _perform_curse(target: Battler) -> void:
	play_anim("offensive_magic")
	Audio.action.play()
	
	var effect = actionToPerform.statusEffect
	
	# Check Immunity
	if target.is_immune(effect.name_):
		SignalBus.display_text.emit(target.name_ + " resisted " + effect.name_ + "!")
		await SignalBus.text_window_closed
		return

	# Check if already inflicted
	if target.disablingStatusEffect != null:
		SignalBus.display_text.emit(target.name_ + " is already disabled!")
		await SignalBus.text_window_closed
		return

	# Apply Effect
	target.disablingStatusEffect = effect.duplicate()
	target.isDisabled = true
	target.status_effect_sprite.texture = effect.sprite
	target.status_effect_sprite.scale = Vector2(effect.scale, effect.scale) # Fix: Apply scale
	
	SignalBus.display_text.emit(target.name_ + " inflicted with " + effect.name_ + "!")
	Audio.play_action_sound("cursed")
	target.play_anim("cursed")
	await SignalBus.text_window_closed

func _perform_item(target: Battler) -> void:
	# Add item logic here (Healing, etc.)
	target.health += actionToPerform.healthAmount
	SignalBus.display_text.emit(target.name_ + " recovered " + str(actionToPerform.healthAmount) + " HP!")
	Audio.play_action_sound("heal")
	target.play_anim("heal")
	await SignalBus.text_window_closed

# Centralized damage application and death check
func _apply_damage(target: Battler, raw_damage: int, is_critical: bool = false) -> void:
	var final_damage = clampi(raw_damage - target.defense, 0, 9999999)
	target.take_damage(final_damage, is_critical) # Battler class handles the "took damage" text
	
	Audio.play_action_sound("hurt")
	Audio.play_action_sound("hurt")
	# Using 'hurt' anim inside take_damage usually, but we ensure flow here:
	# Removed text logging wait, just wait for anim frame
	await wait_with_skip(0.3)
	await get_tree().create_timer(0.1).timeout
	
	if target.health <= 0:
		await _handle_target_defeat(target)

func _handle_target_defeat(target: Battler) -> void:
	target.isDefeated = true
	Audio.down.play()
	target.play_anim("defeated")
	await get_tree().create_timer(1.0 / Global.game_speed).timeout
	
	if is_instance_valid(target):
		SignalBus.display_text.emit(target.defeatedText)
	else:
		# Fallback if target is gone
		SignalBus.display_text.emit("Enemy defeated!")

	await SignalBus.text_window_closed
	
	if check_if_we_won():
		SignalBus.battle_won.emit()
