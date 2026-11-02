extends SceneTree


func _initialize() -> void:
	var file := FileAccess.open("res://tests/fixtures/chess_reference.json", FileAccess.READ)
	if file == null:
		push_error("No se pudo cargar el conjunto de posiciones de referencia.")
		quit(1)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Array:
		push_error("El conjunto de posiciones de referencia es inválido.")
		quit(1)
		return
	var cases: Array = parser.data
	var game := ChessRules.new()
	var failures: int = 0
	for item in cases:
		game.board.assign(item.board)
		game.turn = int(item.turn)
		game.castling = item.castling
		game.en_passant = int(item.ep)
		var actual: Array[String] = []
		for square in range(64):
			for move in game.legal_moves_from(square):
				actual.append("%d-%d" % [square, move.to])
		actual.sort()
		var expected: Array[String] = []
		expected.assign(item.legal)
		if actual != expected:
			printerr("Desacuerdo en posición ", item.fen)
			failures += 1
	if failures:
		printerr("Posiciones con desacuerdo: ", failures)
		quit(1)
	else:
		print("Chess reference OK: %d posiciones" % cases.size())
		quit(0)
