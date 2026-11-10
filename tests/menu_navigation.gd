extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(
		ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/BotMenu.tscn",
		"el proyecto arranca en el menú principal"
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
		"Ludo": "res://scenes/Ludo.tscn",
		"Ludo3": "res://scenes/Ludo3.tscn",
		"Ludo4": "res://scenes/Ludo4.tscn",
		"IslandTwo": "res://scenes/IslandTwo.tscn",
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
		var rig := view.get_node("CameraRig") as TabletopCamera3D
		var original := rig._initial_focus
		rig.focus = Vector3(4, 1, 6)
		var reset := nav.get("camera_button") as Button
		_check(not reset.disabled, "recentrar cámara disponible en pausa")
		reset.pressed.emit()
		_check(rig.focus == original, "recentrar cámara funciona en pausa")
		nav.call("_toggle")
		_check(not paused and not nav.get("overlay").visible, "continuar reanuda la partida")
		nav.call("_toggle")
		nav.call("_request_return_to_menu")
		_check(
			(
				paused
				and current_scene.scene_file_path == "res://scenes/GuidedPhysicalCheckers.tscn"
				and nav.get("overlay").find_child("CancelExit", true, false).visible
			),
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
			not paused and current_scene.scene_file_path == "res://scenes/BotMenu.tscn",
			"confirmar salida vuelve al menú y reanuda el árbol"
		)
	_check(change_scene_to_file("res://scenes/Lobby.tscn") == OK, "abrir lobby online")
	await _frames()
	if current_scene != null:
		var create_section := current_scene.find_child("CreateSection", true, false) as Control
		var join_section := current_scene.find_child("JoinSection", true, false) as Control
		var room_section := current_scene.find_child("RoomSection", true, false) as Control
		_check(
			create_section != null
			and join_section != null
			and create_section.visible
			and join_section.visible
			and create_section.get_index() < join_section.get_index(),
			"lobby muestra crear sala y unirse en primer lugar"
		)
		_check(
			room_section != null and not room_section.visible,
			"lobby oculta butacas y chat antes de entrar a sala"
		)
		current_scene.call("_append_chat", "Ana", "Hola")
		current_scene.call("_append_chat", "Luis", "Listo")
		var chat_log := current_scene.find_child("ChatLog", true, false) as TextEdit
		_check(
			chat_log != null and chat_log.text.contains("Ana: Hola") and chat_log.text.contains("Luis: Listo"),
			"chat del lobby inserta mensajes sin error en Godot 4.7"
		)
		_check(
			current_scene.find_child("MenuBackdrop", true, false) != null,
			"lobby monta el fondo ilustrado de mesa"
		)
		var leave_btn := current_scene.find_child("Leave", true, false) as Button
		if leave_btn != null:
			leave_btn.pressed.emit()
			await _frames()
			_check(
				current_scene != null and current_scene.scene_file_path == "res://scenes/ModeSelect.tscn",
				"salir del lobby sin sala vuelve al selector de modos"
			)

	# Verificar filtros del catálogo local y contenedor desplazable en BotSelect
	_check(change_scene_to_file("res://scenes/Menu.tscn") == OK, "reabrir menú local para filtros")
	await _frames()
	if current_scene != null:
		_check(
			current_scene.find_child("MenuBackdrop", true, false) != null,
			"menú local monta el fondo ilustrado"
		)
		var filter_strategy := current_scene.find_child("Filter_strategy", true, false) as Button
		var filter_all := current_scene.find_child("Filter_all", true, false) as Button
		var chess_btn := current_scene.find_child("GuidedChess", true, false) as Button
		var ludo_btn := current_scene.find_child("Ludo", true, false) as Button
		_check(
			filter_strategy != null and filter_all != null and chess_btn != null and ludo_btn != null,
			"controles de filtro por categoría presentes"
		)
		if filter_strategy != null and filter_all != null and chess_btn != null and ludo_btn != null:
			filter_strategy.pressed.emit()
			_check(
				chess_btn.is_visible_in_tree() and not ludo_btn.is_visible_in_tree(),
				"filtro Estrategia muestra Ajedrez y oculta Ludo"
			)
			filter_all.pressed.emit()
			_check(
				chess_btn.is_visible_in_tree() and ludo_btn.is_visible_in_tree(),
				"filtro Todas vuelve a mostrar todas las familias"
			)
		var back_modes := current_scene.find_child("BackToModes", true, false) as Button
		_check(back_modes != null, "menú local incluye botón para volver a modos")

	_check(change_scene_to_file("res://scenes/BotSelect.tscn") == OK, "abrir selección de bots")
	await _frames()
	if current_scene != null:
		_check(
			current_scene.find_child("BotGamesScroll", true, false) is ScrollContainer
			and current_scene.find_child("MenuBackdrop", true, false) != null,
			"selección de bots usa cuadrícula desplazable y fondo ilustrado"
		)

	if failures:
		printerr("Menu navigation: %d errores" % failures)
		quit(1)
	else:
		print("Menu navigation tests OK")
		quit(0)


func _frames() -> void:
	await physics_frame
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
