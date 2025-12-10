## Abstract class that [AllyBattler] and [EnemyBattler] inherit from.
class_name Battler extends Node2D

# --- NODES ---
@onready var status_effect_sprite: Sprite2D = $StatusEffectSprite
@onready var anim: AnimationPlayer = $AnimationPlayer

# --- STATE ---
var isDefeated: bool = false
var isDisabled: bool = false
var disablingStatusEffect: StatusEffect
## Group name of opposing team ("enemies" or "allies").
var opponents: StringName

## Battler Name (Getter/Setter to update Label).
var name_: String : set = _set_name

# --- IMMUNITIES ---
## Tracks immunity durations. Key: StatusName, Value: Turns Remaining.
var status_immunities: Dictionary = {}

# --- SIGNALS ---
@warning_ignore("unused_signal")
signal deciding_finished
@warning_ignore("unused_signal")
signal performing_action_finished

func _ready() -> void:
	set_process(false)
	
	# Game Speed Logic
	if SignalBus.has_signal("game_speed_changed"):
		SignalBus.game_speed_changed.connect(_on_game_speed_changed)
	
	_apply_speed(Global.game_speed)

func _set_name(value: String) -> void:
	name_ = value

## Abstract Method: Logic to decide next move.
func decide_action() -> void:
	pass

## Abstract Method: Logic to execute chosen move.
func perform_action() -> void:
	pass

## Dynamic Animation Player helper (Supports explicit anim name or SpriteFrame).
func play_anim(animationName: String) -> void:
	var animPlayerAnims: Array[String] = ["heal", "cursed", "fade_out", "hurt"] # Added hurt/fade_out
	
	if animationName in animPlayerAnims:
		if has_node("AnimationPlayer") and $AnimationPlayer.has_animation(animationName):
			$AnimationPlayer.play(animationName)
		elif has_node("AnimatedSprite2D"):
			# Fallback: If AnimationPlayer doesn't have it (e.g. "hurt"), try Sprite
			$AnimatedSprite2D.play(animationName)
	else:
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.play(animationName)

# --- EVENTS ---

func _on_animated_sprite_2d_animation_finished() -> void:
	if has_node("AnimatedSprite2D") and $AnimatedSprite2D.animation != "defeated":
		$AnimatedSprite2D.play("idle")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fade_out":
		queue_free()

## Checks if all opponents are defeated defined by the [opponents] group.
func check_if_we_won() -> bool:
	var is_defeated_pred: Callable = func(b: Battler) -> bool: return b.isDefeated
	var battlers: Array[Node] = get_tree().get_nodes_in_group(opponents)
	
	# Filter only Battlers (Safety)
	var valid_battlers: Array[Battler] = []
	for node in battlers:
		if node is Battler: valid_battlers.append(node)
		
	return valid_battlers.all(is_defeated_pred)

## Handles taking damage, clamping Health, Visuals, and Juice.
func take_damage(amount: int, is_critical: bool = false) -> void:
	var actual_damage: int = amount
	
	# 'health' is defined in child classes via dynamic getters/setters or properties.
	# We access it via self property which accesses the child implementation.
	if "health" in self:
		self.health -= actual_damage
		if self.health < 0: self.health = 0
	
	play_anim("hurt")
	
	# Play Hurting Sound
	Audio.play_action_sound("hurt")
	
	# Floating Text
	var indicator = load("res://UI/damage_indicator.tscn").instantiate()
	add_child(indicator)
	if indicator.has_method("setup"):
		indicator.setup(actual_damage, is_critical)
	
	# Instant Juice
	if is_critical:
		SignalBus.request_camera_shake.emit(5.0, 0.2)
		SignalBus.request_hit_stop.emit(0.05, 0.15)

# --- SPEED MANAGEMENT ---

func _on_game_speed_changed(new_speed: float) -> void:
	_apply_speed(new_speed)

func _apply_speed(value: float) -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.speed_scale = value
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.speed_scale = value

# --- IMMUNITY SYSTEM ---

func process_immunities() -> void:
	var keys_to_remove: Array = []
	
	for status_name in status_immunities.keys():
		status_immunities[status_name] -= 1
		if status_immunities[status_name] <= 0:
			keys_to_remove.append(status_name)
	
	for k in keys_to_remove:
		status_immunities.erase(k)

func add_immunity(status_name: String, duration: int) -> void:
	status_immunities[status_name] = duration

func is_immune(status_name: String) -> bool:
	return status_immunities.has(status_name)

# --- UTILS ---

## Async helper: Waits for 'duration', skippable by input.
func wait_with_skip(duration: float) -> void:
	# Enforce a small non-skippable window to prevent input bleed
	var safe_time: float = 0.15
	if duration <= safe_time: safe_time = duration
	
	await get_tree().create_timer(safe_time).timeout
	
	var remaining: float = duration - safe_time
	if remaining <= 0: return

	var t: SceneTreeTimer = get_tree().create_timer(remaining)
	while t.time_left > 0:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("left_click"):
			return # Skip
		await get_tree().process_frame
