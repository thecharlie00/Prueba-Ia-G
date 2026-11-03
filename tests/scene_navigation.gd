extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(change_scene_to_file("res://scenes/Main.tscn") == OK, "abrir la mesa libre")
	await _frames()
	await _click("UI/Margin/Panel/Content/Checkers", "res://scenes/Checkers.tscn")
	await _click("UI/Panel/Margin/Content/Physical", "res://scenes/PhysicalCheckers.tscn")
	await _click("UI/Panel/Margin/Content/Rules", "res://scenes/Checkers.tscn")
	await _click("UI/Panel/Margin/Content/Sandbox", "res://scenes/Main.tscn")
	await _click("UI/Margin/Panel/Content/PhysicalCheckers", "res://scenes/PhysicalCheckers.tscn")
	await _click("UI/Panel/Margin/Content/Guided", "res://scenes/GuidedPhysicalCheckers.tscn")
	await _click("UI/Panel/Margin/Content/Free", "res://scenes/PhysicalCheckers.tscn")
	await _click("UI/Panel/Margin/Content/Sandbox", "res://scenes/Main.tscn")
	await _click(
		"UI/Margin/Panel/Content/GuidedPhysicalCheckers", "res://scenes/GuidedPhysicalCheckers.tscn"
	)
	await _click("UI/Panel/Margin/Content/Sandbox", "res://scenes/Main.tscn")
	_check(change_scene_to_file("res://scenes/PhysicalChess.tscn") == OK, "abrir ajedrez físico")
	await _frames()
	await _click("UI/Panel/Margin/Content/Guided", "res://scenes/GuidedPhysicalChess.tscn")
	await _click("UI/Panel/Margin/Content/Free", "res://scenes/PhysicalChess.tscn")
	await _click("UI/Panel/Margin/Content/Sandbox", "res://scenes/Main.tscn")
	await _click("UI/Margin/Panel/Content/PhysicalDomino", "res://scenes/PhysicalDomino.tscn")
	await _click("UI/Panel/Margin/Content/Guided", "res://scenes/GuidedDomino.tscn")
	await _click("UI/Panel/Margin/Content/Rules", "res://scenes/PhysicalDomino.tscn")
	await _click("UI/Panel/Margin/Content/Sandbox", "res://scenes/Main.tscn")
	if failures > 0:
		printerr("Scene navigation tests: %d errores" % failures)
		quit(1)
	else:
		print("Scene navigation tests OK")
		quit(0)


func _click(path: String, expected: String) -> void:
	if current_scene == null:
		_check(false, "no hay escena para abrir " + expected)
		return
	var button := current_scene.get_node_or_null(path) as Button
	if button == null:
		_check(false, "falta el botón " + path)
		return
	button.pressed.emit()
	await _frames()
	_check(
		current_scene != null and current_scene.scene_file_path == expected, "navegar a " + expected
	)


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
