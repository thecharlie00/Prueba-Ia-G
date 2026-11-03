extends SceneTree

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := CheckersRules.new()
	var count: int = 0
	for square in range(64):
		count += game.legal_moves_from(square).size()
	_check(count == 7, "posición inicial: siete movimientos")
	_check(game.turn == CheckersRules.WHITE, "comienzan blancas")
	_check(not game.play(_sq("b6"), _sq("a5")), "no mueve quien no tiene el turno")
	_check(not game.play(_sq("a3"), _sq("a4")), "no se mueve ortogonalmente")
	_check(game.play(_sq("a3"), _sq("b4")), "movimiento inicial blanco")
	_check(game.turn == CheckersRules.BLACK, "cambia el turno")
	_check(game.undo() and game.piece_at(_sq("a3")) == CheckersRules.MAN, "deshacer paso")

	_fixture(game, {"c3": 1, "g3": 1, "d4": -1, "h6": -1}, CheckersRules.WHITE)
	_check(game.legal_moves_from(_sq("g3")).is_empty(), "captura obligatoria para todo el bando")
	_check(not game.play(_sq("g3"), _sq("f4")), "impide paso si otra pieza debe capturar")
	_check(game.play(_sq("c3"), _sq("e5")), "captura diagonal")
	_check(game.piece_at(_sq("d4")) == 0, "retira ficha capturada")
	_check(game.turn == CheckersRules.BLACK, "termina turno sin más saltos")
	_check(game.undo() and game.piece_at(_sq("d4")) == -1, "deshacer captura")

	_fixture(game, {"c3": 1, "b2": 1, "d4": -1, "f6": -1, "h8": -1}, CheckersRules.WHITE)
	_check(game.play(_sq("c3"), _sq("e5")), "primer salto de cadena")
	_check(
		game.turn == CheckersRules.WHITE and game.forced_from == _sq("e5"),
		"continuación obligatoria"
	)
	_check(not game.play(_sq("b2"), _sq("a3")), "no cambiar de ficha durante la cadena")
	_check(game.play(_sq("e5"), _sq("g7")), "segundo salto de cadena")
	_check(game.piece_at(_sq("f6")) == 0 and game.turn == CheckersRules.BLACK, "fin de cadena")
	_check(game.undo() and game.forced_from == _sq("e5"), "deshacer salto recupera continuación")
	_check(game.undo() and game.piece_at(_sq("c3")) == 1, "deshacer primer salto")

	_fixture(game, {"b6": 1, "c7": -1, "e7": -1}, CheckersRules.WHITE)
	_check(game.play(_sq("b6"), _sq("d8")), "coronación por captura")
	_check(game.piece_at(_sq("d8")) == CheckersRules.KING, "ficha coronada")
	_check(game.turn == CheckersRules.BLACK and game.forced_from == -1, "coronar termina el turno")
	_fixture(game, {"e5": 2, "d4": -1, "h8": -1}, CheckersRules.WHITE)
	_check(game.play(_sq("e5"), _sq("c3")), "dama captura hacia atrás")
	_fixture(game, {"e5": 1, "d4": -1, "h8": -1}, CheckersRules.WHITE)
	_check(not game.play(_sq("e5"), _sq("c3")), "ficha simple no captura hacia atrás")
	_fixture(game, {"b2": -1, "a1": 1, "c1": 1}, CheckersRules.BLACK)
	_check(game.status() == "white_wins", "gana quien bloquea al contrario")

	game.reset()
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
		_check(game.play(move[0], move[1]), "partida con captura múltiple")
	_check(game.forced_from == 21, "se debe continuar la captura")
	var partial_record: Variant = JSON.parse_string(JSON.stringify(game.export_record()))
	var partial := CheckersRules.new()
	_check(partial.import_record(partial_record), "cargar durante captura múltiple")
	_check(partial.board == game.board and partial.forced_from == 21, "reconstruir continuación")
	_check(partial.undo() and partial.forced_from == -1, "deshacer al cargar una secuencia")

	game.reset()
	_check(game.play(_sq("a3"), _sq("b4")), "guardado: primer paso")
	_check(game.play(_sq("b6"), _sq("a5")), "guardado: respuesta")
	var record: Variant = JSON.parse_string(JSON.stringify(game.export_record()))
	var restored := CheckersRules.new()
	_check(restored.import_record(record), "reconstruir partida")
	_check(restored.board == game.board and restored.turn == game.turn, "restaurar tablero y turno")
	_check(restored.undo() and restored.piece_at(_sq("b6")) == -1, "deshacer después de cargar")
	var before: Array[int] = restored.board.duplicate()
	record["moves"].append({"from": 999, "to": 0})
	_check(not restored.import_record(record), "rechazar movimiento inválido")
	_check(restored.board == before, "importación inválida no cambia la partida")
	_check(
		not restored.import_record({"game": "chess", "version": 1, "moves": []}),
		"rechazar otro juego"
	)

	var scene: PackedScene = load("res://scenes/Checkers.tscn")
	var view := scene.instantiate() as CheckersBoard3D
	root.add_child(view)
	await process_frame
	var point: Vector3 = BoardGeometry.square_position(
		_sq("a3"), CheckersBoard3D.CELL, CheckersBoard3D.BOARD_HEIGHT
	)
	var mouse: Vector2 = view.camera.unproject_position(point)
	_check(
		(
			BoardGeometry.square_from_mouse(
				view.camera, mouse, CheckersBoard3D.CELL, CheckersBoard3D.BOARD_HEIGHT
			)
			== _sq("a3")
		),
		"proyectar un clic sobre el tablero"
	)
	view._select_square(_sq("a3"))
	_check(_sq("b4") in view.legal_destinations, "tablero muestra destino legal")
	view._select_square(_sq("b4"))
	_check(view.rules.piece_at(_sq("b4")) == CheckersRules.MAN, "tablero mueve la ficha")
	view.save_path = "user://diceon_checkers_test.json"
	view._save_game()
	_check(FileAccess.file_exists(view.save_path), "crear guardado de damas")
	view._select_square(_sq("b6"))
	view._select_square(_sq("a5"))
	view._load_game()
	_check(view.rules.piece_at(_sq("b6")) == -CheckersRules.MAN, "cargar guardado de damas")
	var bad_file := FileAccess.open(view.save_path, FileAccess.WRITE)
	bad_file.store_string("{malformed json")
	bad_file.close()
	view._load_game()
	_check(view.rules.piece_at(_sq("b4")) == CheckersRules.MAN, "no cargar JSON corrupto")
	view._reset()
	for move in chain_path:
		_check(view.rules.play(move[0], move[1]), "preparar guardado de captura múltiple")
	view._save_game()
	view._reset()
	view._load_game()
	_check(
		view.selected == 21 and not view.legal_destinations.is_empty(),
		"cargar selecciona la ficha obligatoria"
	)
	view._select_square(_sq("b2"))
	_check(view.selected == 21, "la interfaz impide abandonar la captura")
	view._undo()
	_check(view.rules.forced_from == -1, "deshacer continuación tras cargar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(view.save_path))
	view.queue_free()
	if failures > 0:
		printerr("Checkers tests: %d errores" % failures)
		quit(1)
	else:
		print("Checkers tests OK")
		quit(0)


func _fixture(game: CheckersRules, pieces: Dictionary, side: int) -> void:
	game.reset()
	game.board.fill(0)
	for name in pieces:
		game.board[_sq(name)] = pieces[name]
	game.turn = side
	game.forced_from = -1
	game.history.clear()
	game.move_log.clear()


func _sq(name: String) -> int:
	return (8 - int(name.substr(1, 1))) * 8 + "abcdefgh".find(name.substr(0, 1))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
