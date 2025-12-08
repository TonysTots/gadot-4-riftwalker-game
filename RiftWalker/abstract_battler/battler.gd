## Abstract class that [AllyBattler] and [EnemyBattler] inherit from.
class_name Battler extends Node2D

@onready var status_effect_sprite: Sprite2D = $StatusEffectSprite
@onready var anim: AnimationPlayer = $AnimationPlayer

# Flags:
var isDefeated: bool = false
var isDisabled: bool = false
var disablingStatusEffect: StatusEffect
var opponents: StringName

var name_: String : set = _set_name

# --- NEW: Immunity Tracking ---
var status_immunities: Dictionary = {}

@warning_ignore("unused_signal")
signal deciding_finished
@warning_ignore("unused_signal")
signal performing_action_finished

func _ready() -> void:
	set_process(false)
	
	# --- Game Speed Logic ---
	# Check if signal exists to prevent errors if SignalBus isn't fully loaded
	if SignalBus.has_signal("game_speed_changed"):
		SignalBus.game_speed_changed.connect(_on_game_speed_changed)
	
	# Apply initial speed
	_apply_speed(Global.game_speed)

func _set_name(value: String) -> void:
	name_ = value

func decide_action():
	pass

func perform_action() -> void:
	pass

func play_anim(animationName: String) -> void:
	var animPlayerAnims: Array[String] = ["heal", "cursed"]
	
	if animationName in animPlayerAnims:
		$AnimationPlayer.play(animationName)
	else:
		$AnimatedSprite2D.play(animationName)

func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation != "defeated":
		$AnimatedSprite2D.play("idle")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "fade_out":
		queue_free()

func check_if_we_won() -> bool:
	var is_defated: Callable = func (battler: Battler) -> bool:
		return battler.isDefeated
	var battlers: Array[Battler]
	battlers.assign(get_tree().get_nodes_in_group(opponents))
	if battlers.all(is_defated):
		return true
	return false

func take_damage(amount: int, is_critical: bool = false) -> void:
	var actual_damage = amount
	
	# Note: 'health' is defined in child classes, so this relies on dynamic access
	self.health -= actual_damage
	if self.health < 0: self.health = 0
	
	# Visuals
	play_anim("hurt")
	
	# --- NEW: Floating Damage Text ---
	var indicator = load("res://UI/damage_indicator.tscn").instantiate()
	add_child(indicator)
	indicator.setup(actual_damage, is_critical) # Now using real crit flag
	# ---------------------------------
	
	# --- NEW: Instant Juice ---
	if is_critical:
		SignalBus.request_camera_shake.emit(5.0, 0.2)
		SignalBus.request_hit_stop.emit(0.05, 0.15)
	# ------------------------
	
	# Removed text logging as per request

# --- SPEED UPDATE FUNCTIONS ---
func _on_game_speed_changed(new_speed: float) -> void:
	_apply_speed(new_speed)

func _apply_speed(value: float) -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.speed_scale = value
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.speed_scale = value

# --- IMMUNITY FUNCTIONS ---
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

# --- NEW: Skippable Wait Helper ---
# waits for 'duration' seconds, OR until the user clicks/presses action
func wait_with_skip(duration: float) -> void:
	var t = get_tree().create_timer(duration)
	while t.time_left > 0:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("left_click"):
			return # Skip
		await get_tree().process_frame
# ----------------------------------
