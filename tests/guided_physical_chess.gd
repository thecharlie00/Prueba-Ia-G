extends SceneTree

const SCENE := preload("res://scenes/GuidedPhysicalChess.tscn")
const SAVE := "user://test_guided_physical_chess.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_real_drag_and_cancel()
	await _test_castle_and_save()
	await _test_en_passant()
	await _test_promotion()
	await _test_promotion_replay()
	await _test_draw_claim()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if failures:
		printerr("Guided physical chess: %d errores" % failures)
		quit(1)
	else:
		print("Guided physical chess tests OK")
		quit(0)


func _new_view() -> GuidedPhysicalChess:
	var view := SCENE.instantiate() as GuidedPhysicalChess
	root.add_child(view)
	view.grabber.set_physics_process(false)
	view.save_path = SAVE
	return view


func _test_real_drag_and_cancel() -> void:
	var view := _new_view()
	await _ticks(70)
	_check(
		view.piece_squares.size() == 32 and view.rules.turn == ChessRules.WHITE, "posición inicial"
	)
	var pawn := view._find_piece(view.piece_squares, _sq("e2"))
	_start_grab(view, pawn)
	_check(_sq("e4") in view._destinations, "destinos legales resaltados")
	var target: Vector3 = view._square_center(_sq("e4")) + Vector3.UP * 0.75
	view.grabber._target = target
	for i in range(150):
		view.grabber._apply_held_force()
		await physics_frame
	var distance := (
		Vector2(pawn.global_position.x - target.x, pawn.global_position.z - target.z).length()
	)
	_check(distance <= view.CELL * 0.55, "el resorte físico alcanza el destino")
	view.grabber._release()
	_check(
		view.rules.piece_at(_sq("e4")) == ChessRules.PAWN and view.rules.turn == ChessRules.BLACK,
		"jugada física y turno"
	)
	var before: Array[int] = view.rules.board.duplicate()
	_simulated_release(view, "d2", "d4", true)
	_check(view.rules.board == before, "pieza contraria no mueve fuera de turno")
	_simulated_release(view, "e7", "e5", false)
	_check(view.rules.board == before, "no aceptar sin alcanzar la casilla")
	_simulated_release(view, "e7", "e5", true, "cancelled")
	_check(view.rules.board == before, "cancelación no confirma")
	_simulated_release(view, "e7", "e5", true, "recovered")
	_check(view.rules.board == before, "recuperación no confirma")
	var black_pawn := view._find_piece(view.piece_squares, _sq("e7"))
	_start_grab(view, black_pawn)
	view.grabber._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	view.grabber._physics_process(1.0 / 60.0)
	_check(view.grabber.held == null and view.rules.board == before, "pérdida de foco cancela")
	_start_grab(view, black_pawn)
	var previous_history := view.rules.history.size()
	view._undo()
	view._load_game()
	_check(view.rules.history.size() == previous_history, "no deshacer ni cargar durante agarre")
	view.grabber._release("cancelled")
	# Un desplazamiento de una pieza no cambia el modelo y se corrige con fuerzas.
	var resting := view._find_piece(view.piece_squares, _sq("a2"))
	var home: Vector3 = view.homes[resting]
	resting.global_position = Vector3(home.x + 0.18, 1.25, home.z)
	resting.linear_velocity = Vector3.ZERO
	resting.sleeping = false
	var distance_before := absf(resting.global_position.x - home.x)
	await _ticks(90)
	_check(view.rules.board == before, "la física no altera el tablero lógico")
	_check(
		absf(resting.global_position.x - home.x) < distance_before,
		"las fuerzas devuelven la pieza desplazada"
	)
	view.queue_free()
	await process_frame


func _test_castle_and_save() -> void:
	var view := _new_view()
	await _ticks(2)
	var moves := [
		["g1", "f3"],
		["a7", "a6"],
		["e2", "e4"],
		["a6", "a5"],
		["f1", "e2"],
		["b7", "b6"],
		["e1", "g1"]
	]
	for move in moves:
		var count := view.rules.history.size()
		_simulated_release(view, move[0], move[1], true)
		_check(view.rules.history.size() == count + 1, "jugada de enroque aceptada")
	_check(
		(
			view.rules.piece_at(_sq("g1")) == ChessRules.KING
			and view.rules.piece_at(_sq("f1")) == ChessRules.ROOK
		),
		"enroque lógico"
	)
	var rook := view._find_piece(view.piece_squares, _sq("f1"))
	_check(
		rook != null and rook.piece_type == ChessRules.ROOK and not rook.freeze,
		"torre física se mueve al enrocar"
	)
	var record := view.rules.export_record()
	view._save_game()
	_check(FileAccess.file_exists(SAVE), "guardar partida física")
	view._undo()
	_check(view._find_piece(view.piece_squares, _sq("h1")) == rook, "deshacer restaura torre")
	view._load_game()
	_check(view.rules.export_record() == record, "carga restaura historial")
	_check(view._find_piece(view.piece_squares, _sq("f1")) == rook, "carga reconstruye el enroque")
	var simple := ChessRules.new()
	_check(
		simple.import_record(record) and simple.board == view.rules.board,
		"registro compatible con vista simple"
	)
	view._undo()
	_check(
		(
			view.rules.piece_at(_sq("e1")) == ChessRules.KING
			and view._find_piece(view.piece_squares, _sq("h1")) == rook
		),
		"deshacer funciona tras cargar"
	)
	var before := view.rules.export_record()
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{mal formado")
	file.close()
	view._load_game()
	_check(view.rules.export_record() == before, "archivo inválido no cambia partida")
	view.queue_free()
	await process_frame


func _test_en_passant() -> void:
	var view := _new_view()
	await _ticks(2)
	for move in [["e2", "e4"], ["a7", "a6"], ["e4", "e5"], ["d7", "d5"]]:
		_simulated_release(view, move[0], move[1], true)
	var victim := view._find_piece(view.piece_squares, _sq("d5"))
	_simulated_release(view, "e5", "d6", true)
	_check(
		view.rules.piece_at(_sq("d5")) == 0 and view.rules.piece_at(_sq("d6")) == ChessRules.PAWN,
		"captura al paso lógica"
	)
	_check(
		int(view.piece_squares[victim]) == -1 and view.capture_counts[1] == 1,
		"capturada al paso enviada al lateral"
	)
	view._save_game()
	view._undo()
	view._load_game()
	_check(
		int(view.piece_squares[victim]) == -1 and view.rules.piece_at(_sq("d6")) == ChessRules.PAWN,
		"carga reconstruye captura al paso"
	)
	view._undo()
	_check(
		view._find_piece(view.piece_squares, _sq("d5")) == victim and view.capture_counts[1] == 0,
		"deshacer restaura captura al paso"
	)
	view.queue_free()
	await process_frame


func _test_promotion() -> void:
	var view := _new_view()
	await _ticks(2)
	var pawn := view._find_piece(view.piece_squares, _sq("a2"))
	var white_king := view._find_piece(view.piece_squares, _sq("e1"))
	var black_king := view._find_piece(view.piece_squares, _sq("e8"))
	for piece in view.piece_squares:
		view.piece_squares[piece] = -1
	view.piece_squares[pawn] = _sq("a7")
	view.piece_squares[white_king] = _sq("e1")
	view.piece_squares[black_king] = _sq("e8")
	view.rules.board.fill(0)
	view.rules.board[_sq("a7")] = ChessRules.PAWN
	view.rules.board[_sq("e1")] = ChessRules.KING
	view.rules.board[_sq("e8")] = -ChessRules.KING
	view.rules.turn = ChessRules.WHITE
	view.rules.castling = {"wk": false, "wq": false, "bk": false, "bq": false}
	view.rules.repetition_counts.clear()
	view.rules._record_position()
	var option: OptionButton = view.get_node("UI/Panel/Margin/Content/Promotion")
	option.select(3)  # Caballo
	_simulated_release(view, "a7", "a8", true)
	_check(
		(
			view.rules.piece_at(_sq("a8")) == ChessRules.KNIGHT
			and pawn.piece_type == ChessRules.KNIGHT
		),
		"promoción cambia reglas y modelo físico"
	)
	_check(
		pawn.has_node("Visual/ChessModel/KnightProfile/Muzzle"), "modelo promocionado es un caballo"
	)
	_check(
		(
			absf(pawn.bottom_offset() - (ChessPieceModel.height(ChessRules.KNIGHT) + 0.01) / 2.0)
			< 0.001
		),
		"colisionador de promoción actualizado"
	)
	view._undo()
	_check(
		view.rules.piece_at(_sq("a7")) == ChessRules.PAWN and pawn.piece_type == ChessRules.PAWN,
		"deshacer promoción restaura peón"
	)
	view.queue_free()
	await process_frame


func _test_promotion_replay() -> void:
	var view := _new_view()
	await _ticks(2)
	var pawn := view._find_piece(view.piece_squares, _sq("a2"))
	var rook := view._find_piece(view.piece_squares, _sq("a8"))
	var moves := [
		["a2", "a4"],
		["h7", "h5"],
		["a4", "a5"],
		["h5", "h4"],
		["a5", "a6"],
		["h4", "h3"],
		["a6", "b7"],
		["h3", "g2"]
	]
	for move in moves:
		var before := view.rules.history.size()
		_simulated_release(view, move[0], move[1], true)
		_check(view.rules.history.size() == before + 1, "secuencia legal de promoción")
	var option: OptionButton = view.get_node("UI/Panel/Margin/Content/Promotion")
	option.select(3)
	_simulated_release(view, "b7", "a8", true)
	_check(
		(
			view._find_piece(view.piece_squares, _sq("a8")) == pawn
			and pawn.piece_type == ChessRules.KNIGHT
		),
		"promoción real con captura"
	)
	_check(int(view.piece_squares[rook]) == -1, "torre capturada en promoción")
	var record := view.rules.export_record()
	view._save_game()
	view._undo()
	_check(
		(
			pawn.piece_type == ChessRules.PAWN
			and view._find_piece(view.piece_squares, _sq("a8")) == rook
		),
		"deshacer promoción y captura"
	)
	view._load_game()
	_check(
		view.rules.export_record() == record and pawn.piece_type == ChessRules.KNIGHT,
		"replay reconstruye promoción"
	)
	_check(int(view.piece_squares[rook]) == -1, "replay reconstruye captura de torre")
	view._undo()
	_check(
		(
			pawn.piece_type == ChessRules.PAWN
			and view._find_piece(view.piece_squares, _sq("a8")) == rook
		),
		"deshacer promoción tras cargar"
	)
	view.queue_free()
	await process_frame


func _test_draw_claim() -> void:
	var view := _new_view()
	await _ticks(2)
	for i in range(2):
		for move in [["g1", "f3"], ["g8", "f6"], ["f3", "g1"], ["f6", "g8"]]:
			_simulated_release(view, move[0], move[1], true)
	var claim: Button = view.get_node("UI/Panel/Margin/Content/Actions/Claim")
	_check(not claim.disabled, "reclamación disponible en tercera repetición")
	claim.pressed.emit()
	_check(view.rules.status() == "threefold_repetition", "reclamar tablas")
	view._save_game()
	view._undo()
	view._load_game()
	_check(view.rules.status() == "threefold_repetition", "carga conserva tablas reclamadas")
	view.queue_free()
	await process_frame


func _start_grab(view: GuidedPhysicalChess, piece: PhysicalChessPiece) -> void:
	if piece == null:
		_check(false, "no hay pieza para agarrar")
		return
	view.grabber.hovered = piece
	var mouse: Vector2 = view.grabber.camera.unproject_position(piece.global_position)
	view.grabber._begin_grab(mouse)


func _simulated_release(
	view: GuidedPhysicalChess,
	from_name: String,
	to_name: String,
	arrive: bool,
	reason := "released"
) -> void:
	var piece := view._find_piece(view.piece_squares, _sq(from_name))
	if piece == null:
		_check(false, "no hay pieza en " + from_name)
		return
	_start_grab(view, piece)
	var target: Vector3 = view._square_center(_sq(to_name)) + Vector3.UP * 0.6
	view.grabber._target = target
	if arrive:
		piece.global_position = target
	else:
		piece.global_position = Vector3(3.0, 1.5, -1.8)
	view.grabber._release(reason)


func _sq(name: String) -> int:
	return (8 - int(name.substr(1, 1))) * 8 + "abcdefgh".find(name.substr(0, 1))


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
