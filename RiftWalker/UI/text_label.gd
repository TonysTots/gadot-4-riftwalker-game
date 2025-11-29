extends Label

func _on_mouse_entered() -> void:
	if self.modulate.a < 1:
		Audio.btn_mov.play()
		var index: int = get_parent().get_children().find(self)
		SignalBus.label_index_changed.emit(index)

func _on_mouse_exited() -> void:
	var index: int = get_parent().get_children().find(self)
	SignalBus.label_index_changed.emit(index)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_action_pressed("left_click"):
			SignalBus.selected_label.emit()
