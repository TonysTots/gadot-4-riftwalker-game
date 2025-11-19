extends CharacterBody2D

# -----------------------------------------------------------------------------
# SECTION 1: PROPERTIES
# -----------------------------------------------------------------------------
const SPEED = 180.0
const JUMP_VELOCITY = -300.0

@onready var player: AnimatedSprite2D = $AnimatedSprite2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- STATE MACHINE VARIABLES ---

# Machine 1: Movement
enum MovementState { IDLE, RUN, JUMP, GLIDE, DOUBLE_JUMP }
var current_move_state = MovementState.IDLE

# Machine 2: Attack (A simple boolean two-state machine)
var is_attacking: bool = false

# Flag for double jump
var can_double_jump: bool = false

# -----------------------------------------------------------------------------
# SECTION 2: THE MAIN LOOP
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	
	# --- PART 1: CALCULATE VELOCITY (PHYSICS) ---
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# If we're on the ground, reset our double jump
		can_double_jump = true

	# Handle Jump / Double Jump Input
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			# --- Normal Jump ---
			velocity.y = JUMP_VELOCITY
			current_move_state = MovementState.JUMP
			player.play("jump")
		elif can_double_jump:
			# --- Double Jump ---
			can_double_jump = false # Use it up
			velocity.y = JUMP_VELOCITY # You could use a different value here
			current_move_state = MovementState.DOUBLE_JUMP
			player.play("flip") # Use "flip" as the double jump anim

	# Handle Attack Input (Ground Only)
	if Input.is_action_just_pressed("punch") and not is_attacking:
		if is_on_floor():
			is_attacking = true
	
	# Handle Horizontal Movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# --- PART 2: MOVE THE PLAYER ---
	# This applies all calculated velocity and updates 'is_on_floor()'
	move_and_slide()

	# --- PART 3: UPDATE STATES & ANIMATIONS ---
	# After moving, we run our state logic using the fresh physics data
	_update_movement_state()
	_update_animations(direction)

# -----------------------------------------------------------------------------
# SECTION 3: STATE MACHINE LOGIC
# -----------------------------------------------------------------------------

# This function's ONLY job is to check for state *transitions*.
func _update_movement_state() -> void:
	match current_move_state:
		
		MovementState.IDLE:
			if not is_on_floor():
				current_move_state = MovementState.GLIDE # We fell
			elif velocity.x != 0:
				current_move_state = MovementState.RUN
		
		MovementState.RUN:
			if not is_on_floor():
				current_move_state = MovementState.GLIDE # We ran off a ledge
			elif velocity.x == 0:
				current_move_state = MovementState.IDLE
		
		MovementState.JUMP:
			# The "jump" anim is our transition timer.
			if not player.is_playing():
				current_move_state = MovementState.GLIDE
			elif is_on_floor():
				current_move_state = MovementState.IDLE # Landed early
		
		MovementState.GLIDE:
			if is_on_floor():
				if velocity.x == 0:
					current_move_state = MovementState.IDLE
				else:
					current_move_state = MovementState.RUN
		
		MovementState.DOUBLE_JUMP:
			# When the 'flip' animation finishes, go to 'glide'
			if not player.is_playing():
				current_move_state = MovementState.GLIDE
			# Or if we land before it's done
			elif is_on_floor():
				current_move_state = MovementState.IDLE

# This function's ONLY job is to play the right animation
# based on our *current* states.
func _update_animations(direction: float) -> void:
	
	# --- Part A: Handle Animations ---
	match current_move_state:
		
		MovementState.IDLE:
			if is_attacking:
				if player.animation != "punch": player.play("punch")
			else:
				# Re-play "idle" if it's finished (i.e., not looping)
				if player.animation != "idle" or not player.is_playing(): 
					player.play("idle")
		
		MovementState.RUN:
			if is_attacking:
				if player.animation != "run_punch": player.play("run_punch")
			else:
				# Re-play "run" if it's finished (i.e., not looping)
				if player.animation != "run" or not player.is_playing(): 
					player.play("run")
		
		MovementState.JUMP:
			# 'jump' is already playing. We don't need to do anything.
			pass
		
		MovementState.GLIDE:
			# Air attacks are gone.
			if player.animation != "glide" or not player.is_playing():
				player.play("glide")

		MovementState.DOUBLE_JUMP:
			# 'flip' is already playing. We don't need to do anything.
			pass

	# --- Part B: Handle Visuals (like flipping) ---
	if direction != 0:
		player.flip_h = (direction < 0)

# -----------------------------------------------------------------------------
# SECTION 4: SIGNAL CALLBACKS
# -----------------------------------------------------------------------------

func _on_animated_sprite_2d_animation_finished() -> void:
	# This function's ONLY job is to reset the 'Attack' state machine.
	var anim = player.animation
	
	# 'flip' is no longer an attack, so it's removed from this list.
	if anim == "punch" or anim == "run_punch":
		is_attacking = false
