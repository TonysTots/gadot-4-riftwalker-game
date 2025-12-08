extends Node

@export var parent: AllyBattler

var actionIndex: int:
	set(value):
		if value < 0 or value >= parent.attackActions.size(): return
		
		if actionIndex < parent.options_container.get_child_count():
			var labelToUnfocus: Label = parent.options_container.get_child(actionIndex)
			if labelToUnfocus: labelToUnfocus.modulate.a = 0.5
			
		actionIndex = value
		
		if actionIndex < parent.options_container.get_child_count():
			var labelToFocus: Label = parent.options_container.get_child(actionIndex)
			if labelToFocus: labelToFocus.modulate.a = 1

var enemyIndex: int:
	set(value):
		if value < 0 or value >= get_tree().get_nodes_in_group("enemies").size(): return
		
		if enemyIndex < parent.options_container.get_child_count():
			var labelToUnfocus: Label = parent.options_container.get_child(enemyIndex)
			if labelToUnfocus: labelToUnfocus.modulate.a = 0.5
			
		enemyIndex = value
		
		if enemyIndex < parent.options_container.get_child_count():
			var labelToFocus: Label = parent.options_container.get_child(enemyIndex)
			if labelToFocus: labelToFocus.modulate.a = 1

#Selection states:
enum {NOT_SELECTING, SELECTING_ATTACK, SELECTING_ENEMIES}
var currentSelectionType = NOT_SELECTING
var isSelecting: bool = false

func _ready() -> void:
	SignalBus.label_index_changed.connect(func(newIndex: int) -> void:
		if currentSelectionType == SELECTING_ATTACK:
			actionIndex = newIndex
		elif currentSelectionType == SELECTING_ENEMIES:
			enemyIndex = newIndex)
	SignalBus.selected_label.connect(pressed_ui_accept)

func _on_attack_button_pressed() -> void:
	#Populate the selection window with attacks:
	parent.selection_window.show()
	parent.button_container.hide()
	for attackingAction: AllyAction in parent.attackActions:
		var label: Label = parent.TEXT_LABEL.instantiate()
		label.text = attackingAction.actionName
		label.modulate.a = 0.5
		parent.options_container.add_child(label)
	#Begin selection:
	actionIndex = 0
	isSelecting = true
	currentSelectionType = SELECTING_ATTACK

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") and isSelecting:
		Audio.btn_mov.play()
		if currentSelectionType == SELECTING_ATTACK: actionIndex += 1
		if currentSelectionType == SELECTING_ENEMIES: enemyIndex += 1
	if event.is_action_pressed("ui_up") and isSelecting:
		Audio.btn_mov.play()
		if currentSelectionType == SELECTING_ATTACK: actionIndex -= 1
		if currentSelectionType == SELECTING_ENEMIES: enemyIndex -= 1
	if event.is_action_pressed("ui_accept") and isSelecting:
		pressed_ui_accept()
	if Input.is_action_pressed("ui_cancel") and isSelecting:
		Input.action_release("ui_cancel")
		cancel_action()

func pressed_ui_accept() -> void:
	match currentSelectionType:
		SELECTING_ATTACK:
			parent.actionToPerform = parent.attackActions[actionIndex]
			currentSelectionType = SELECTING_ENEMIES
			match parent.attackActions[actionIndex].actionTargetType:
				Attack.ActionTargetType.SINGLE_ENEMY: start_selecting_single_enemy()
				Attack.ActionTargetType.ALL_ENEMIES: select_all_enemies_and_finish()
		SELECTING_ENEMIES:
			finish_selecting()

func cancel_action() -> void:
	for label: Label in parent.options_container.get_children():
		if label: label.queue_free()
	isSelecting = false
	currentSelectionType = null
	parent.selection_window.hide()
	parent.button_container.show()
	parent.attack_button.grab_focus()

func start_selecting_single_enemy() -> void:
	for label: Label in parent.options_container.get_children():
		if label: label.queue_free()
	#Wait until all labels are freed:
	await get_tree().create_timer(0.1).timeout
	for enemyBattler: EnemyBattler in get_tree().get_nodes_in_group("enemies"):
		var label: Label = parent.TEXT_LABEL.instantiate()
		label.text = enemyBattler.name_
		label.modulate.a = 0.5
		parent.options_container.add_child(label)
	enemyIndex = 0

func select_all_enemies_and_finish() -> void:
	for battler: Battler in get_tree().get_nodes_in_group("enemies"):
		parent.targetBattlers.append(battler)
	isSelecting = false
	currentSelectionType = NOT_SELECTING
	for label: Label in parent.options_container.get_children():
		if label: label.queue_free()
	parent.selection_window.hide()
	parent.deciding_finished.emit()

func finish_selecting():
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		cancel_action()
		return

	parent.targetBattlers.append(enemies[enemyIndex])
	isSelecting = false
	currentSelectionType = NOT_SELECTING
	for label: Label in parent.options_container.get_children():
		if label: label.queue_free()
	parent.selection_window.hide()
	parent.deciding_finished.emit()
