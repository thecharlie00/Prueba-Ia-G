extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Menu.tscn",
		"el proyecto arranca en el menú"
	)
	var nav := root.get_node_or_null("SessionNavigation")
	_check(nav != null, "el navegador global está registrado")
	var routes := {
		"Sandbox": "res://scenes/Main.tscn",
		"Chess": "res://scenes/Chess.tscn",
		"GuidedChess": "res://scenes/GuidedPhysicalChess.tscn",
		"PhysicalChess": "res://scenes/PhysicalChess.tscn",
		"GuidedCheckers": "res://scenes/GuidedPhysicalCheckers.tscn",
		"FreeCheckers": "res://scenes/PhysicalCheckers.tscn",
		"SimpleCheckers": "res://scenes/Checkers.tscn",
		"GuidedDomino": "res://scenes/GuidedDomino.tscn",
		"FreeDomino": "res://scenes/PhysicalDomino.tscn",
		"Cards": "res://scenes/CardTable.tscn",
		"Island": "res://scenes/Island.tscn",
		"IslandFour": "res://scenes/IslandFour.tscn"
	}
	for id in routes:
		_check(change_scene_to_file("res://scenes/Menu.tscn") == OK, "abrir menú")
		await _frames()
		var button := current_scene.find_child(id, true, false) as Button
		_check(button != null, "opción visible " + id)
		if button == null:
			continue
		button.pressed.emit()
		await _frames()
		_check(
			current_scene != null and current_scene.scene_file_path == routes[id], "navegar a " + id
		)
	if nav != null:
		# Pausar mientras se agarra una ficha debe cancelar el movimiento antes de detener físicas.
		change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
		await _frames()
		var view := current_scene as GuidedPhysicalCheckers
		var tile: Token3D = view._token_at_square(44)
		view.grabber.hovered = tile
		var mouse: Vector2 = view.grabber.camera.unproject_position(tile.global_position)
		view.grabber._begin_grab(mouse)
		var before: Array[int] = view.rules.board.duplicate()
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		nav.call("_unhandled_input", escape)
		_check(paused and view.grabber.held == null and not tile.is_grabbed, "pausa cancela agarre")
		_check(view.rules.board == before, "pausa no confirma jugada")
		_check(nav.get("overlay").visible, "pausa muestra menú")
		nav.call("_toggle")
		_check(not paused and not nav.get("overlay").visible, "continuar reanuda la partida")
		nav.call("_toggle")
		nav.call("_request_return_to_menu")
		_check(
			paused
			and current_scene.scene_file_path == "res://scenes/GuidedPhysicalCheckers.tscn"
			and nav.get("overlay").find_child("CancelExit", true, false).visible,
			"salir pide confirmar antes de descartar el estado"
		)
		nav.call("_cancel_return_to_menu")
		_check(
			paused and not nav.get("overlay").find_child("CancelExit", true, false).visible,
			"cancelar salida conserva la partida en pausa"
		)
		nav.call("_request_return_to_menu")
		nav.call("_request_return_to_menu")
		await _frames()
		_check(
			not paused and current_scene.scene_file_path == "res://scenes/Menu.tscn",
			"confirmar salida vuelve al menú y reanuda el árbol"
		)
	if failures:
		printerr("Menu navigation: %d errores" % failures)
		quit(1)
	else:
		print("Menu navigation tests OK")
		quit(0)


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
