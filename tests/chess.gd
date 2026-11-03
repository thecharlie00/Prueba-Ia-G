extends SceneTree

const ChessAI = preload("res://scripts/chess/ChessAI.gd")
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := ChessRules.new()
	_check(_perft(game, 1) == 20, "20 jugadas legales iniciales")
	_check(_perft(game, 2) == 400, "400 posiciones en dos medias jugadas")
	_check(_perft(game, 3) == 8902, "8902 posiciones en tres medias jugadas")
	_check(not game.play(_sq("e2"), _sq("e5")), "no saltar tres casillas")
	_check(game.turn == ChessRules.WHITE, "rechazo no cambia turno")
	for move in [["f2", "f3"], ["e7", "e5"], ["g2", "g4"], ["d8", "h4"]]:
		_check(game.play(_sq(move[0]), _sq(move[1])), "mate del loco: " + str(move))
	_check(game.status() == "checkmate", "jaque mate detectado")
	_check(not game.play(_sq("e2"), _sq("e4")), "no jugar tras jaque mate")
	_check(game.undo() and game.status() == "playing", "deshacer mate")

	# Posición de referencia con enroques y ataques cruzados; cifras cotejadas con python-chess.
	_fixture(
		game,
		{
			"h8": -4,
			"e8": -6,
			"a8": -4,
			"g7": -3,
			"f7": -1,
			"e7": -5,
			"d7": -1,
			"c7": -1,
			"a7": -1,
			"g6": -1,
			"f6": -2,
			"e6": -1,
			"b6": -2,
			"a6": -3,
			"d5": 1,
			"c5": -1,
			"e4": 1,
			"b4": -1,
			"f3": 2,
			"c3": 2,
			"h2": 1,
			"g2": 1,
			"f2": 1,
			"e2": 3,
			"d2": 3,
			"c2": 5,
			"b2": 1,
			"a2": 1,
			"h1": 4,
			"e1": 6,
			"a1": 4
		},
		ChessRules.WHITE
	)
	_check(_perft(game, 1) == 45, "referencia: 45 jugadas legales")
	_check(_perft(game, 2) == 1947, "referencia: 1947 posiciones")

	_fixture(game, {"e1": 6, "h1": 4, "e8": -6}, ChessRules.WHITE)
	_check(game.play(_sq("e1"), _sq("g1")), "enroque corto")
	_check(
		game.piece_at(_sq("f1")) == 4 and game.piece_at(_sq("g1")) == 6, "torre y rey en enroque"
	)
	_check(game.undo() and game.piece_at(_sq("h1")) == 4, "deshacer enroque")
	_fixture(game, {"e1": 6, "h1": 4, "e8": -6, "f8": -4}, ChessRules.WHITE)
	_check(not game.play(_sq("e1"), _sq("g1")), "no enrocar a través de jaque")

	_fixture(game, {"e1": 6, "e8": -6, "e5": 1, "d7": -1}, ChessRules.BLACK)
	_check(game.play(_sq("d7"), _sq("d5")), "avance doble")
	_check(game.play(_sq("e5"), _sq("d6")), "captura al paso")
	_check(
		game.piece_at(_sq("d5")) == 0 and game.piece_at(_sq("d6")) == 1, "víctima al paso retirada"
	)
	_check(game.undo() and game.piece_at(_sq("d5")) == -1, "deshacer captura al paso")
	_fixture(game, {"e1": 6, "a8": -6, "e8": -4, "e5": 1, "d5": -1}, ChessRules.WHITE)
	game.en_passant = _sq("d6")
	_check(not game.play(_sq("e5"), _sq("d6")), "al paso no puede exponer al rey")

	_fixture(game, {"h1": 6, "h8": -6, "a7": 1}, ChessRules.WHITE)
	_check(game.play(_sq("a7"), _sq("a8"), ChessRules.KNIGHT), "promoción a caballo")
	_check(game.piece_at(_sq("a8")) == ChessRules.KNIGHT, "pieza promocionada")
	_check(game.status() == "insufficient_material", "material insuficiente")
	for promotion in [ChessRules.QUEEN, ChessRules.ROOK, ChessRules.BISHOP]:
		_fixture(game, {"h1": 6, "h8": -6, "a7": 1}, ChessRules.WHITE)
		_check(game.play(_sq("a7"), _sq("a8"), promotion), "promoción alternativa")
		_check(game.piece_at(_sq("a8")) == promotion, "tipo de promoción elegido")
	_fixture(game, {"e1": 6, "e8": -6, "e7": 5}, ChessRules.WHITE)
	_check(not game.play(_sq("e7"), _sq("e8")), "el rey contrario no es capturable")
	_fixture(game, {"a8": -6, "c6": 6, "b6": 5}, ChessRules.BLACK)
	_check(game.status() == "stalemate", "rey ahogado")

	game.reset()
	for repetition in range(2):
		for move in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"], ["f6", "g8"]]:
			_check(game.play(_sq(move[0]), _sq(move[1])), "repetición " + str(repetition))
	_check(
		game.claim_draw() and game.status() == "threefold_repetition", "reclamación por repetición"
	)
	_check(not game.play(_sq("e2"), _sq("e4")), "no jugar tras reclamar tablas")
	_check(game.undo() and game.status() == "playing", "deshacer jugada tras tablas")
	game.reset()
	for repetition in range(4):
		for move in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"], ["f6", "g8"]]:
			_check(game.play(_sq(move[0]), _sq(move[1])), "cinco repeticiones " + str(repetition))
	_check(game.status() == "fivefold_repetition", "tablas automáticas por cinco repeticiones")
	_fixture(game, {"e1": 6, "a1": 4, "e8": -6, "e2": 1}, ChessRules.WHITE)
	game.halfmove_clock = 100
	_check(game.claim_draw() and game.status() == "fifty_moves", "reclamación de 50 movimientos")
	game.claimed_draw = ""
	game.halfmove_clock = 150
	_check(game.status() == "seventy_five_moves", "tablas automáticas de 75 movimientos")

	_fixture(game, {"e1": 6, "a1": 4, "e8": -6, "e2": 1}, ChessRules.WHITE)
	game.halfmove_clock = 99
	var board_before_claim: Array[int] = game.board.duplicate()
	_check(not game.can_claim_draw(), "todavía no se puede reclamar la posición actual")
	_check(
		not game.claim_draw(_sq("e2"), _sq("e3")),
		"un avance de peón anunciado no permite reclamar 50 movimientos"
	)
	_check(
		game.board == board_before_claim and game.claimed_draw.is_empty(),
		"reclamo inválido no altera el estado"
	)
	_check(game.claim_draw(_sq("a1"), _sq("a2")), "reclamar 50 movimientos anunciando torre")
	_check(game.status() == "fifty_moves", "anuncio termina la partida en tablas")
	_check(game.board == board_before_claim, "la jugada anunciada no cambia el tablero")
	_check(game.move_log.is_empty() and game.turn == ChessRules.WHITE, "el anuncio no consume turno")
	game.reset()
	for move in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"], ["f6", "g8"]]:
		_check(game.play(_sq(move[0]), _sq(move[1])), "preparar repetición anunciada")
	for move in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"]]:
		_check(game.play(_sq(move[0]), _sq(move[1])), "avanzar a tercera repetición anunciada")
	var position_before_claim: Array[int] = game.board.duplicate()
	_check(game.claim_draw(_sq("f6"), _sq("g8")), "reclamar tercera repetición anunciando caballo")
	_check(game.status() == "threefold_repetition", "repetición anunciada termina en tablas")
	_check(game.board == position_before_claim, "la repetición anunciada no mueve piezas")
	var announced_record: Variant = JSON.parse_string(JSON.stringify(game.export_record()))
	var announced_restored := ChessRules.new()
	_check(announced_restored.import_record(announced_record), "restaurar reclamo anunciado")
	_check(
		announced_restored.claimed_move == {"from": _sq("f6"), "to": _sq("g8"), "promotion": 5},
		"el guardado conserva la jugada anunciada"
	)
	var invalid_announcement: Variant = announced_record.duplicate(true)
	invalid_announcement["claim_move"]["to"] = _sq("f6")
	_check(
		not announced_restored.import_record(invalid_announcement),
		"rechazar reclamo anunciado inválido"
	)

	game.reset()
	game.opponent_mode = ChessRules.OPPONENT_AI_TACTICAL
	_check(game.play(_sq("e2"), _sq("e4")), "guardado: e4")
	_check(game.play(_sq("e7"), _sq("e5")), "guardado: e5")
	var record: Variant = JSON.parse_string(JSON.stringify(game.export_record()))
	var restored := ChessRules.new()
	_check(restored.import_record(record), "importar historial validado")
	_check(
		restored.opponent_mode == ChessRules.OPPONENT_AI_TACTICAL,
		"el guardado conserva el modo de oponente"
	)
	_check(restored.board == game.board and restored.turn == game.turn, "restaurar estado")
	_check(
		restored.undo() and restored.piece_at(_sq("e7")) == -ChessRules.PAWN,
		"deshacer después de cargar"
	)
	var before: Array[int] = restored.board.duplicate()
	record["moves"].append({"from": 999, "to": 0, "promotion": 5})
	_check(not restored.import_record(record), "rechazar movimiento guardado inválido")
	_check(restored.board == before, "importación inválida no modifica partida")

	_fixture(game, {"e1": 6, "e8": -6, "a1": 4, "a8": -5}, ChessRules.WHITE)
	var tactical_random := RandomNumberGenerator.new()
	tactical_random.seed = 7
	var ai_board_before: Array[int] = game.board.duplicate()
	var ai_history_before: Array[Dictionary] = game.history.duplicate(true)
	var ai_log_before: Array[Dictionary] = game.move_log.duplicate(true)
	var ai_repetitions_before: Dictionary = game.repetition_counts.duplicate(true)
	var tactical_move := ChessAI.choose_move(game, ChessRules.OPPONENT_AI_TACTICAL, tactical_random)
	_check(
		tactical_move.get("from", -1) == _sq("a1") and tactical_move.get("to", -1) == _sq("a8"),
		"IA táctica captura una dama disponible"
	)
	_check(
		game.board == ai_board_before
		and game.turn == ChessRules.WHITE
		and game.history == ai_history_before
		and game.move_log == ai_log_before
		and game.repetition_counts == ai_repetitions_before,
		"buscar jugadas no altera el estado de la partida"
	)
	game.reset()
	var casual_random := RandomNumberGenerator.new()
	casual_random.seed = 19
	var casual_move := ChessAI.choose_move(game, ChessRules.OPPONENT_AI_CASUAL, casual_random)
	_check(
		not casual_move.is_empty()
		and casual_move in game.legal_moves_from(int(casual_move.get("from", -1))),
		"IA casual elige una jugada legal"
	)

	var scene: PackedScene = load("res://scenes/Chess.tscn")
	var view := scene.instantiate() as ChessBoard3D
	root.add_child(view)
	await process_frame
	view._select_square(_sq("e2"))
	_check(_sq("e4") in view.legal_destinations, "tablero muestra destino válido")
	view._select_square(_sq("e4"))
	_check(view.rules.piece_at(_sq("e4")) == ChessRules.PAWN, "tablero ejecuta jugada")
	view.save_path = "user://diceon_chess_test.json"
	view._save_game()
	_check(FileAccess.file_exists(view.save_path), "crear archivo de guardado")
	view._select_square(_sq("e7"))
	view._select_square(_sq("e5"))
	view._load_game()
	_check(view.rules.piece_at(_sq("e7")) == -ChessRules.PAWN, "cargar archivo de guardado")
	var bad_file := FileAccess.open(view.save_path, FileAccess.WRITE)
	bad_file.store_string("{malformed json")
	bad_file.close()
	view._load_game()
	_check(view.rules.piece_at(_sq("e4")) == ChessRules.PAWN, "archivo corrupto no cambia partida")
	_fixture(view.rules, {"e1": 6, "a1": 4, "e8": -6}, ChessRules.WHITE)
	view.rules.halfmove_clock = 99
	view._refresh()
	view._claim()
	view._select_square(_sq("a1"))
	view._select_square(_sq("a2"))
	_check(
		view.rules.status() == "fifty_moves",
		"tablero permite anunciar reclamación de 50 movimientos"
	)
	_check(view.rules.move_log.is_empty(), "tablero no ejecuta la jugada anunciada")
	var opponent: OptionButton = view.get_node("UI/Panel/Margin/Content/Opponent")
	var ai_option: int = opponent.get_item_index(ChessRules.OPPONENT_AI_CASUAL)
	opponent.select(ai_option)
	opponent.item_selected.emit(ai_option)
	_check(
		view.rules.opponent_mode == ChessRules.OPPONENT_AI_CASUAL,
		"la vista permite elegir IA casual"
	)
	view._reset()
	view._select_square(_sq("e2"))
	view._select_square(_sq("e4"))
	await create_timer(0.8).timeout
	_check(
		view.rules.move_log.size() == 2 and view.rules.turn == ChessRules.WHITE,
		"la IA responde tras la jugada humana"
	)
	view._undo()
	_check(
		view.rules.move_log.is_empty() and view.rules.piece_at(_sq("e2")) == ChessRules.PAWN,
		"deshacer contra IA revierte la ronda completa"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(view.save_path))
	view.queue_free()
	if failures > 0:
		printerr("Chess tests: %d errores" % failures)
		quit(1)
	else:
		print("Chess tests OK")
		quit(0)


func _perft(game: ChessRules, depth: int) -> int:
	if depth == 0:
		return 1
	var count: int = 0
	for square in range(64):
		for move in game.legal_moves_from(square):
			if game.play(square, int(move["to"])):
				count += _perft(game, depth - 1)
				game.undo()
	return count


func _fixture(game: ChessRules, pieces: Dictionary, side: int) -> void:
	game.reset()
	game.board.fill(0)
	for name in pieces:
		game.board[_sq(name)] = pieces[name]
	game.turn = side
	game.en_passant = -1
	game.halfmove_clock = 0
	game.history.clear()
	game.claimed_draw = ""
	game.repetition_counts.clear()
	game._record_position()


func _sq(name: String) -> int:
	return (8 - int(name.substr(1, 1))) * 8 + "abcdefgh".find(name.substr(0, 1))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
