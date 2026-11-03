extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := (load("res://scenes/Chess.tscn") as PackedScene).instantiate() as ChessBoard3D
	root.add_child(view)
	await process_frame
	_check(view.pieces_root.get_child_count() == 32, "tablero muestra las 32 piezas modeladas")
	view._select_square(52)
	_check(view.pieces_root.get_child_count() == 32, "refrescar selección no duplica piezas")
	view._select_square(36)
	_check(view.pieces_root.get_child_count() == 32, "mover no duplica piezas")
	for model in view.pieces_root.get_children():
		var kind: int = int(model.get_meta("kind"))
		_check(kind >= 1 and kind <= 6, "tipo del modelo reconocible")
		_check(
			model.get_node("PieceLetter").text == ChessPieceModel.SYMBOLS[kind],
			"letra accesible coincide con modelo"
		)
	view.rules.board.fill(0)
	view.rules.board[60] = ChessRules.KING
	view.rules.board[4] = -ChessRules.KING
	view.rules.board[0] = ChessRules.QUEEN
	view._refresh()
	_check(view.pieces_root.get_child_count() == 3, "posición actualizada sin geometría anterior")
	var found_queen := false
	for model in view.pieces_root.get_children():
		if int(model.get_meta("square")) == 0:
			found_queen = (
				int(model.get_meta("kind")) == ChessRules.QUEEN and model.has_node("Jewel0")
			)
	_check(found_queen, "dama se modela al actualizar posición")
	view.queue_free()
	await process_frame
	var token := (load("res://scenes/Token3D.tscn") as PackedScene).instantiate() as Token3D
	root.add_child(token)
	_check(
		token.has_node("Visual/InlayRim") and token.has_node("Visual/InlayFace"),
		"ficha de damas tiene moldura"
	)
	_check(
		token.get_node("CollisionShape3D") is CollisionShape3D, "moldura no sustituye colisionador"
	)
	token.set_king(true)
	_check(token.get_node("Crown").visible, "corona visual de dama")
	token.queue_free()
	await process_frame
	var card := (load("res://scenes/Card3D.tscn") as PackedScene).instantiate() as Card3D
	root.add_child(card)
	card.set_card_label("10 ♠")
	_check(card.get_node("Visual/FaceLabel").text == "10 ♠", "carta actualiza valor central")
	_check(
		(
			card.get_node("Visual/Corner0").text == "10 ♠"
			and card.get_node("Visual/Corner1").text == "10 ♠"
		),
		"carta actualiza esquinas"
	)
	card.queue_free()
	await process_frame
	if failures:
		printerr("Piece models: %d errores" % failures)
		quit(1)
	else:
		print("Piece model tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
