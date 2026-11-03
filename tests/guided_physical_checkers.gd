extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/GuidedPhysicalCheckers.tscn")
	var view := packed.instantiate() as GuidedPhysicalCheckers
	root.add_child(view)
	await _ticks(60)
	view.grabber.set_physics_process(false)
	_check(view.token_squares.size() == 24, "cada ficha física tiene una casilla lógica")
	_check(view.rules.turn == CheckersRules.WHITE, "comienzan blancas")

	# Una ficha física realmente sigue el resorte hasta una casilla legal.
	var first: Token3D = view._token_at_square(44)  # e3
	_start_grab(view, first)
	_check(35 in view._legal_destinations, "se resaltan destinos legales")
	var target: Vector3 = view._square_center(35) + Vector3.UP * 0.4
	view.grabber._target = target
	for i in range(80):
		view.grabber._apply_held_force()
		await physics_frame
	var distance := (
		Vector2(first.global_position.x - target.x, first.global_position.z - target.z).length()
	)
	_check(distance <= view.CELL * 0.55, "el cuerpo físico llega al destino")
	view.grabber._release()
	_check(view.rules.board[35] == CheckersRules.MAN, "se confirma la jugada legal")
	_check(view.rules.turn == CheckersRules.BLACK, "cambia el turno")
	_check(int(view.token_squares[first]) == 35, "ficha y estado quedan asociados")

	var board_before: Array[int] = view.rules.board.duplicate()
	_simulated_release(view, 46, 37, true)  # blanca fuera de turno
	_check(view.rules.board == board_before, "una ficha fuera de turno no altera el estado")
	_simulated_release(view, 21, 28, false)  # legal pero el cuerpo no llegó
	_check(view.rules.board == board_before, "no confirmar si el cuerpo no llegó al destino")
	_simulated_release(view, 21, 28, true, "cancelled")
	_check(view.rules.board == board_before, "perder foco cancela la jugada")
	_simulated_release(view, 21, 28, true, "recovered")
	_check(view.rules.board == board_before, "recuperar la ficha no confirma una jugada")
	_start_grab(view, view._token_at_square(21))
	view.grabber._target = view._square_center(28)
	view.grabber._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	view.grabber._physics_process(1.0 / 60.0)
	_check(view.grabber.held == null, "perder foco libera la ficha")
	_check(view.rules.board == board_before, "el evento de pérdida de foco cancela la jugada")

	var victim: Token3D = view._token_at_square(21)
	_simulated_release(view, 21, 28, true)
	_check(view.rules.board[28] == -CheckersRules.MAN, "movimiento negro aceptado")
	_simulated_release(view, 35, 21, true)
	_check(
		view.rules.board[21] == CheckersRules.MAN and view.rules.board[28] == 0, "captura aplicada"
	)
	_check(
		int(view.token_squares[victim]) == -1 and not victim.freeze,
		"la capturada sigue siendo física"
	)
	_check(view.black_captured == 1, "captura asignada a su zona lateral")
	view._undo()
	_check(view.rules.board[35] == 1 and view.rules.board[28] == -1, "deshacer captura lógica")
	_check(
		int(view.token_squares[victim]) == 28 and view.black_captured == 0,
		"deshacer restaura ficha capturada"
	)

	# El estado no cambia si una colisión o un empujón mueve físicamente una ficha.
	var stable_before: Array[int] = view.rules.board.duplicate()
	var displaced: Token3D = view._token_at_square(40)
	var home: Vector3 = view.home_positions[displaced]
	displaced.global_position = Vector3(home.x + 0.2, 1.1, home.z)
	displaced.linear_velocity = Vector3.ZERO
	displaced.sleeping = false
	var before_distance: float = absf(displaced.global_position.x - home.x)
	await _ticks(90)
	_check(view.rules.board == stable_before, "la física no modifica el estado lógico")
	_check(
		absf(displaced.global_position.x - home.x) < before_distance,
		"las fuerzas devuelven la ficha"
	)

	# Deshacer no debe operar mientras se está agarrando una ficha.
	_start_grab(view, view._token_at_square(35))
	var history_size: int = view.rules.history.size()
	view._undo()
	_check(view.rules.history.size() == history_size, "no deshacer con una ficha agarrada")
	view._load_game()
	_check(view.rules.history.size() == history_size, "no cargar con una ficha agarrada")
	view.grabber._release("cancelled")
	view.queue_free()
	await process_frame
	await _test_forced_chain_and_promotion(packed)
	if failures:
		printerr("Guided physical checkers: %d errores" % failures)
		quit(1)
	else:
		print("Guided physical checkers tests OK")
		quit(0)


func _test_forced_chain_and_promotion(packed: PackedScene) -> void:
	var view := packed.instantiate() as GuidedPhysicalCheckers
	root.add_child(view)
	await _ticks(2)
	view.grabber.set_physics_process(false)
	view.save_path = "user://test_guided_physical_checkers.json"
	var chain_path := [
		[44, 35],
		[21, 28],
		[35, 21],
		[12, 30],
		[46, 37],
		[30, 44],
		[53, 35],
		[3, 12],
		[42, 33],
		[12, 21],
		[62, 53],
		[5, 12],
		[33, 26],
		[19, 33],
		[40, 26],
		[23, 30],
		[53, 44],
		[21, 28],
		[35, 21]
	]
	for move in chain_path:
		var history_before: int = view.rules.history.size()
		_simulated_release(view, move[0], move[1], true)
		_check(view.rules.history.size() == history_before + 1, "jugada de cadena aceptada")
	_check(view.rules.forced_from == 21, "cadena obliga a continuar con la misma ficha")
	var board_before: Array[int] = view.rules.board.duplicate()
	_simulated_release(view, 26, 19, true)
	_check(view.rules.board == board_before, "no se cambia de ficha durante la captura")
	# Guardar a mitad de una cadena y restaurar también los cuerpos e historial de deshacer.
	view._save_game()
	var saved_record: Dictionary = view.rules.export_record()
	var captured_before: int = view.black_captured + view.white_captured
	var moves: Array[Dictionary] = view.rules.legal_moves_from(21)
	_check(not moves.is_empty(), "existe continuación de captura")
	if not moves.is_empty():
		var destination: int = moves[0]["to"]
		_simulated_release(view, 21, destination, true)
		_check(view.rules.forced_from == -1, "la cadena termina tras el último salto")
		view._load_game()
		_check(view.rules.export_record() == saved_record, "carga recupera el historial lógico")
		_check(view.rules.forced_from == 21, "carga recupera la continuación obligatoria")
		_check(view._snapshots.size() == chain_path.size(), "carga reconstruye historial físico")
		_check(
			view.black_captured + view.white_captured == captured_before, "carga restaura capturas"
		)
		_check(int(view.token_squares[view._token_at_square(21)]) == 21, "carga asocia la ficha")
		var loaded_token: Token3D = view._token_at_square(21)
		_check(
			view.home_positions[loaded_token] == view._square_center(21),
			"carga restaura destino físico"
		)
		# El mismo registro es compatible con la vista de damas no física.
		var simple_rules := CheckersRules.new()
		_check(simple_rules.import_record(saved_record), "registro compatible con vista simple")
		_check(simple_rules.board == view.rules.board, "ambos modos comparten la posición")
		# Un archivo inválido no debe alterar la partida ni las asociaciones.
		var bad := FileAccess.open(view.save_path, FileAccess.WRITE)
		bad.store_string("{mal formado")
		bad.close()
		view._load_game()
		_check(view.rules.export_record() == saved_record, "carga inválida no altera partida")
		_check(view._snapshots.size() == chain_path.size(), "carga inválida conserva deshacer")
		view._undo()
		_check(view.rules.history.size() == chain_path.size() - 1, "deshacer funciona tras cargar")
		_check(
			view.rules.board[35] == 1 and view.rules.board[28] == -1,
			"deshacer recupera la captura tras cargar"
		)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(view.save_path))

	# Montar una posición reducida para verificar coronación y deshacer.
	var white: Token3D
	var black_a: Token3D
	var black_b: Token3D
	for key in view.token_squares:
		var token := key as Token3D
		if token.display_name == "Ficha blanca" and white == null:
			white = token
		elif token.display_name == "Ficha oscura":
			if black_a == null:
				black_a = token
			elif black_b == null:
				black_b = token
		view.token_squares[token] = -1
	view.rules.reset()
	view.rules.board.fill(0)
	view.rules.board[17] = 1  # b6
	view.rules.board[10] = -1  # c7
	view.rules.board[12] = -1  # e7
	view.token_squares[white] = 17
	view.token_squares[black_a] = 10
	view.token_squares[black_b] = 12
	view.home_positions[white] = view._square_center(17)
	view.home_positions[black_a] = view._square_center(10)
	view.home_positions[black_b] = view._square_center(12)
	view._snapshots.clear()
	_simulated_release(view, 17, 3, true)  # b6 × d8
	_check(view.rules.board[3] == CheckersRules.KING and white.is_king, "coronación física visible")
	_check(view.rules.turn == CheckersRules.BLACK, "coronar termina el turno")
	view._undo()
	_check(
		view.rules.board[17] == CheckersRules.MAN and not white.is_king, "deshacer retira corona"
	)
	_check(
		view.rules.board[10] == -1 and int(view.token_squares[black_a]) == 10,
		"deshacer recupera captura"
	)
	view.queue_free()


func _start_grab(view: GuidedPhysicalCheckers, token: Token3D) -> void:
	view.grabber.hovered = token
	var mouse: Vector2 = view.grabber.camera.unproject_position(token.global_position)
	view.grabber._begin_grab(mouse)


func _simulated_release(
	view: GuidedPhysicalCheckers,
	from_square: int,
	to_square: int,
	arrive: bool,
	reason: String = "released"
) -> void:
	var token: Token3D = view._token_at_square(from_square)
	if token == null:
		_check(false, "no hay ficha en " + str(from_square))
		return
	_start_grab(view, token)
	var target: Vector3 = view._square_center(to_square) + Vector3.UP * 0.3
	view.grabber._target = target
	if arrive:
		# Simula el cuerpo que ya ha llegado; la prueba anterior comprueba el arrastre real.
		token.global_position = target
	view.grabber._release(reason)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
