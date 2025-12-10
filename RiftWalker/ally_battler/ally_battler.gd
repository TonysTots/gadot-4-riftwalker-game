class_name AllyBattler extends Battler

# --- UI NODES ---
@onready var control: Control = %Control
@onready var selection_window: NinePatchRect = $UI/Control/SelectionWindow
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var button_container: HBoxContainer = %ButtonContainer
@onready var attack_button: Button = %AttackButton
@onready var magic_button: Button = %MagicButton
@onready var item_button: Button = %ItemButton
@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar
@onready var magic_bar: ProgressBar = $VBoxContainer/MagicBar
@onready var health_label: Label = %HealthLabel
@onready var magic_points_label: Label = %MagicPointsLabel
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# --- LOGIC NODES ---
@onready var defending_manager: Node = $DefendingDecider_Manager

# --- DATA ---
@export var stats: AllyStats

## Current Health (Logic + UI Update)
@onready var health: int = stats.health - stats.damage_taken:
	set(value):
		health = clamp(value, 0, max_health)
		stats.damage_taken = max_health - health # SYNC DAMAGE
		if health_label: health_label.text = "HP: " + str(health)
		if health_bar: health_bar.value = health

## Current Mana (Logic + UI Update)
@onready var magicPoints: int = stats.magicPoints - stats.mana_used:
	set(value):
		magicPoints = value
		stats.mana_used = stats.magicPoints - magicPoints # SYNC USAGE
		if magic_points_label: magic_points_label.text = "MP: " + str(magicPoints)
		if magic_bar: magic_bar.value = value

# --- STAT PROXIES ---
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

# --- ACTIONS ---
@onready var attackActions: Array[Attack] = stats.attackActions
@onready var defendAction: Defend = stats.defendAction
@onready var magicActions: Array[Spell] = stats.magicActions
@onready var items: Array[Item] = stats.items # Direct reference for persistence

## The specific action intended to be performed this turn.
var actionToPerform: AllyAction
## The target(s) for the action.
var targetBattlers: Array[Battler] = []

const TEXT_LABEL: PackedScene = preload("uid://cotypm82phjd3") # Verify path or remove if unused

func _ready() -> void:
	super._ready()
	
	name_ = stats.name
	opponents = "enemies"
	
	_setup_ui()
	_load_visuals()
	
	SignalBus.battle_lost.connect(on_battle_lost)
	
	# Connect UI Signals
	for button: Button in button_container.get_children():
		if button is Button:
			if not button.mouse_entered.is_connected(button.grab_focus):
				button.mouse_entered.connect(button.grab_focus)
			if not button.focus_entered.is_connected(on_button_focus_changed):
				button.focus_entered.connect(on_button_focus_changed)

func _setup_ui() -> void:
	$UI.show()
	if has_node("%NameLabel"): %NameLabel.text = stats.name
	
	selection_window.hide()
	button_container.hide()
	
	health_bar.max_value = max_health
	magic_bar.max_value = stats.magicPoints
	
	# Trigger setters to update text
	health = health 
	magicPoints = magicPoints
	
	if control: control.theme = stats.ui_theme

func _load_visuals() -> void:
	if animated_sprite_2d:
		animated_sprite_2d.scale *= stats.texture_scale
		animated_sprite_2d.flip_h = true
		animated_sprite_2d.offset.y -= 40
		animated_sprite_2d.sprite_frames = stats.spriteFrames
		animated_sprite_2d.play("idle")
		animated_sprite_2d.offset += stats.offset
		
	if not stats.can_use_magic:
		if magic_button: magic_button.queue_free()
		if magic_bar: magic_bar.hide()
		if magic_points_label: magic_points_label.hide()

# --- TURN LOGIC ---

## Player Input Phase
func decide_action() -> void:
	# Clean up previous UI
	for child in options_container.get_children():
		child.queue_free()
		
	SignalBus.cursor_come_to_me.emit(self.global_position, true)
	
	if items.size() <= 0 and item_button:
		item_button.hide()
		
	if defending_manager:
		defending_manager.manage_defense_stat()
		
	targetBattlers.clear()
	button_container.show()
	
	# Wait for UI to be ready
	await get_tree().process_frame
	if attack_button: attack_button.grab_focus()

## Execution Phase
func perform_action() -> void:
	# Safety Cleanup: Ensure UI is hidden when action starts
	if button_container: button_container.hide()
	if selection_window: selection_window.hide()
	
	# 1. Announce
	SignalBus.cursor_come_to_me.emit(self.global_position, true)
	if actionToPerform:
		SignalBus.display_text.emit(name_ + " " + actionToPerform.actionText)
		Audio.action.stream = actionToPerform.sound
	await SignalBus.text_window_closed

	# 2. Iterate Targets
	
	# Consume MP Once (if applicable)
	if "magicPointsCost" in actionToPerform:
		magicPoints -= actionToPerform.magicPointsCost
	
	for i in range(targetBattlers.size()):
		var target: Battler = targetBattlers[i]
		
		# Retarget if dead
		if target.isDefeated:
			target = _get_new_target_if_dead(target)
			if target.isDefeated: continue # No valid target found
			
		# Execute Action Logic
		if actionToPerform is Attack:
			await _perform_attack(target)
		elif actionToPerform is Defend:
			await _perform_defend(target)
		elif actionToPerform is Spell:
			await _perform_spell(target)
		elif actionToPerform is Item:
			await _perform_item(target)
			
		# Win Check
		if check_if_we_won(): 
			return

	# 3. Cleanup
	targetBattlers.clear()
	performing_action_finished.emit()

# --- ACTION HANDLERS ---

func _perform_attack(target: Battler) -> void:
	play_anim("attack")
	if Audio.action.stream: Audio.action.play()
	
	# Wait for animation to finish (Unskippable)
	if animated_sprite_2d and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
	
	var damage: int = actionToPerform.damageAmount + strength
	var is_crit: bool = (randf() <= 0.1)
	
	if is_crit: damage *= 2
	
	# Apply final damage
	var final_damage: int = clampi(damage - target.defense, 0, 9999999) # Using defense property if it exists?
	# Dynamic access required or Cast.
	if "defense" in target:
		final_damage = clampi(damage - target.get("defense"), 0, 9999999)
	
	target.take_damage(final_damage, is_crit)
	
	if is_crit:
		SignalBus.display_text.emit("CRITICAL HIT!")
		await SignalBus.text_window_closed
	else:
		await wait_with_skip(0.5)
	
	await _check_target_defeat(target)

func _perform_defend(target: Battler) -> void:
	play_anim("defend")
	if Audio.action.stream: Audio.action.play()
	
	if animated_sprite_2d and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
	
	var defenseAmount: int = actionToPerform.defenseAmount
	self.defense += defenseAmount
	
	SignalBus.display_text.emit(target.name_ + " raised defense by " + str(defenseAmount) + "!")
	Audio.play_action_sound("defend")
	target.play_anim("defend")
	
	await SignalBus.text_window_closed

func _perform_spell(target: Battler) -> void:
	if actionToPerform is OffensiveSpell:
		play_anim("offensive_magic")
		if Audio.action.stream: Audio.action.play()
		
		if animated_sprite_2d and animated_sprite_2d.is_playing():
			await animated_sprite_2d.animation_finished
		
		var damage: int = actionToPerform.damageAmount + magicStrength
		var is_crit: bool = (randf() <= 0.1)
		if is_crit: damage *= 2
		
		# Defense check for magic? Usually Magic Defense, but using Defense for simplicity if needed.
		var final_damage: int = damage
		if "defense" in target:
			final_damage = clampi(damage - target.get("defense"), 0, 9999999)
			
		target.take_damage(final_damage, is_crit)
		
		if is_crit:
			SignalBus.display_text.emit("CRITICAL HIT!")
			await SignalBus.text_window_closed
			
		await _check_target_defeat(target)
		
	elif actionToPerform is HealingSpell:
		play_anim("heal_magic")
		if Audio.action.stream: Audio.action.play()
		
		# Healing animation might be short/instant, but consistency is good
		if animated_sprite_2d and animated_sprite_2d.is_playing():
			await animated_sprite_2d.animation_finished
		
		@warning_ignore("integer_division")
		var heal_amount: int = actionToPerform.healingAmount + (magicStrength / 2)
		if "health" in target:
			target.health += heal_amount
			
		SignalBus.display_text.emit(target.name_ + " recovered " + str(heal_amount) + " HP!")
		Audio.play_action_sound("heal")
		target.play_anim("heal")
		await SignalBus.text_window_closed

	elif actionToPerform is CurseSpell:
		await _perform_curse(target)

func _perform_curse(target: Battler) -> void:
	play_anim("offensive_magic")
	if Audio.action.stream: Audio.action.play()
	
	if animated_sprite_2d and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
	
	var effect: StatusEffect = actionToPerform.statusEffect
	
	# Immunities
	if target.is_immune(effect.name_):
		SignalBus.display_text.emit(target.name_ + " resisted " + effect.name_ + "!")
		await SignalBus.text_window_closed
		return

	# Already Active
	if target.disablingStatusEffect != null:
		SignalBus.display_text.emit(target.name_ + " is already disabled!")
		await SignalBus.text_window_closed
		return

	# Apply
	target.disablingStatusEffect = effect.duplicate()
	target.isDisabled = true
	if target.status_effect_sprite:
		target.status_effect_sprite.texture = effect.sprite
		target.status_effect_sprite.scale = Vector2(effect.scale, effect.scale)
	
	SignalBus.display_text.emit(target.name_ + " inflicted with " + effect.name_ + "!")
	Audio.play_action_sound("cursed")
	target.play_anim("cursed")
	await SignalBus.text_window_closed

func _perform_item(target: Battler) -> void:
	# Consume Item
	if actionToPerform in items:
		items.erase(actionToPerform)
		# Update UI button if needed (hide if empty)
		if items.is_empty() and item_button:
			item_button.hide()
			
	# 3. Apply Effects
	
	# Health
	if "health" in target:
		if actionToPerform.restoreAllHealth:
			target.health = target.max_health # Uses setter, handles clamping
		else:
			target.health += actionToPerform.healthAmount
		
	# Magic
	if "magicPoints" in target:
		if actionToPerform.restoreAllMagic:
			if target.stats: target.magicPoints = target.stats.magicPoints
			else: target.magicPoints += 9999
		else:
			target.magicPoints = clampi(target.magicPoints + actionToPerform.magicAmount, 0, target.stats.magicPoints if target.stats else 9999)
		
	SignalBus.display_text.emit(target.name_ + " used " + actionToPerform.actionName + "!")
	Audio.play_action_sound("heal")
	target.play_anim("heal")
	await SignalBus.text_window_closed

# --- HELPERS ---

func _check_target_defeat(target: Battler) -> void:
	# Assume Target logic handles death animation transition?
	# In previous code, `perform_action` called `_handle_target_defeat`.
	# But `Battler.take_damage` does NOT handle death.
	# So we must check here.
	
	# Access property safely
	var hp: int = 1
	if "health" in target: hp = target.get("health")
	
	if hp <= 0 and not target.isDefeated:
		target.isDefeated = true
		Audio.down.play()
		target.play_anim("defeated")
		
		# Use wait_with_skip so players can speed through death animations
		await wait_with_skip(1.0)
		
		# Get defeated text safely
		var d_text: String = "Defeated!"
		if "defeatedText" in target: d_text = target.get("defeatedText")
		
		SignalBus.display_text.emit(d_text)
		await SignalBus.text_window_closed
		
		if check_if_we_won():
			SignalBus.battle_won.emit()

func _get_new_target_if_dead(dead_target: Battler) -> Battler:
	var target_group_name: String = "enemies" 
	if dead_target is AllyBattler: target_group_name = "allies" # Should be rare for self-target?
	
	var candidates: Array[Node] = get_tree().get_nodes_in_group(target_group_name)
	for c in candidates:
		if c is Battler and not c.isDefeated:
			return c
	return dead_target

func _process(_delta: float) -> void:
	# UI Updates handled in setters now, but just in case of external changes
	pass

# --- UI EVENTS ---

func _on_cancel_button_pressed() -> void:
	Audio.btn_pressed.play()
	
	# Clear options
	for child in options_container.get_children():
		child.queue_free()
	
	selection_window.hide()
	button_container.show()
	attack_button.grab_focus()

func on_button_focus_changed() -> void:
	Audio.btn_mov.play()

func on_battle_lost() -> void:
	if control: control.hide()
	set_process_input(false)
	set_process_unhandled_input(false)
