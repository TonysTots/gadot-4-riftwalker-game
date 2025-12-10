class_name TurnManager extends Node

signal turn_phase_finished

var battlers: Array[Battler] = []
var battlers_sorted: Array[Battler] = []
var current_battler_index: int = 0
var battle_ended: bool = false

## Main entry point for a new turn.
func start_turn(new_battlers: Array[Node]) -> void:
	if battle_ended: return
	
	battlers.clear()
	# Safe cast
	for b in new_battlers:
		if b is Battler: battlers.append(b)
		
	_let_battlers_decide()

func _let_battlers_decide() -> void:
	if battle_ended: return
	
	# 1. Trigger Decision Phase (Parallel)
	for battler in battlers:
		if battler.isDefeated: continue
		battler.set_process(true)
		battler.decide_action()
		
		await battler.deciding_finished
		battler.set_process(false)
		
	# 2. Sort by Speed
	battlers_sorted = battlers.duplicate()
	battlers_sorted.sort_custom(_sort_by_speed)
	
	# 3. Start Action Phase (Sequential)
	current_battler_index = 0
	_process_next_battler()

func _process_next_battler() -> void:
	if battle_ended: return
	
	# End of Turn Check
	if current_battler_index >= battlers_sorted.size():
		turn_phase_finished.emit()
		return
		
	var battler: Battler = battlers_sorted[current_battler_index]
	
	# Skip Dead
	if battler.isDefeated:
		current_battler_index += 1
		_process_next_battler() # Recursion
		return
		
	# Perform Action
	battler.set_process(true)
	battler.perform_action()
	
	await battler.performing_action_finished
	battler.set_process(false)
	
	# Next
	current_battler_index += 1
	_process_next_battler() # Recursion

func _sort_by_speed(a: Battler, b: Battler) -> bool:
	return a.speed > b.speed

func set_battle_ended(ended: bool) -> void:
	battle_ended = ended
