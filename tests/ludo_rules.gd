extends SceneTree

var failures := 0


func _initialize() -> void:
	var game := LudoRules.new(4)
	_check(
		game.apply_roll(3) and game.turn == 1 and game.phase == LudoRules.ROLL,
		"sin seis pasa turno"
	)
	_check(game.apply_roll(6) and game.legal_tokens() == [0, 1, 2, 3], "seis habilita salida")
	_check(game.move(0) and game.turn == 1 and game.positions[1][0] == 0, "salida y turno extra")
	_check(game.apply_roll(6) and 1 not in game.legal_tokens(), "salida ocupada por ficha propia")
	_check(game.move(0) and game.positions[1][0] == 6 and game.turn == 1, "avanza seis")
	game = LudoRules.new(2)
	game.positions[0][0] = 4
	game.positions[1][0] = 44
	_check(game.apply_roll(1) and game.move(0), "mover a casilla ocupada")
	_check(game.positions[1][0] == -1, "captura devuelve ficha a casa")
	game = LudoRules.new(2)
	game.positions[0][0] = 7
	game.positions[1][0] = 47
	_check(game.apply_roll(1) and game.turn == 1, "seguro ocupado bloquea llegada")
	game = LudoRules.new(2)
	game.positions[0] = [51, 53, 57, 57]
	_check(game.apply_roll(1) and game.move(0) and game.positions[0][0] == 52, "entrada al pasillo")
	game.turn = 0
	_check(game.apply_roll(1) and 0 not in game.legal_tokens(), "no apilar fichas propias")
	_check(game.move(1) and game.positions[0][1] == 54, "otra ficha puede avanzar")
	game.turn = 0
	game.positions[0] = [57, 57, 57, 56]
	_check(game.apply_roll(2) and game.turn == 1, "meta exige número exacto")
	game.turn = 0
	_check(game.apply_roll(1) and game.move(3) and game.winner == 0, "cuatro fichas ganan")
	_check(not game.apply_roll(6), "no se juega tras victoria")
	_check(
		(
			LudoRules.from_record(
				{
					"game": "ludo_local",
					"version": 1,
					"players": 2,
					"events": [{"type": "move", "token": 0}]
				}
			)
			== null
		),
		"replay ilegal rechazado"
	)
	for count in range(2, 5):
		_simulate(count)
	if failures:
		printerr("Ludo rules: %d errores" % failures)
		quit(1)
	else:
		print("Ludo rules tests OK")
		quit(0)


func _simulate(count: int) -> void:
	var game := LudoRules.new(count)
	var random := RandomNumberGenerator.new()
	random.seed = 9000 + count
	var rolls := 0
	while game.phase != LudoRules.FINISHED and rolls < 4000:
		_check(game.apply_roll(random.randi_range(1, 6)), "tirada válida en simulación")
		rolls += 1
		if game.phase == LudoRules.MOVE:
			var legal := game.legal_tokens()
			_check(not legal.is_empty(), "hay ficha seleccionable")
			if legal.is_empty():
				break
			_check(game.move(legal[random.randi_range(0, legal.size() - 1)]), "movimiento válido")
		_validate_positions(game)
	_check(game.phase == LudoRules.FINISHED, "partida termina %d jugadores" % count)
	var loaded := LudoRules.from_record(JSON.parse_string(JSON.stringify(game.export_record())))
	_check(loaded != null, "replay carga")
	if loaded != null:
		_check(
			loaded.positions == game.positions and loaded.winner == game.winner,
			"replay reproduce resultado"
		)


func _validate_positions(game: LudoRules) -> void:
	var occupied := {}
	for player in range(game.players):
		var lane := {}
		for progress in game.positions[player]:
			_check(progress >= -1 and progress <= LudoRules.FINISH, "progreso válido")
			if progress >= 0 and progress < 52:
				var square := LudoRules.track_square(player, progress)
				_check(not occupied.has(square), "sin fichas apiladas en recorrido")
				occupied[square] = true
			elif progress >= 52 and progress < LudoRules.FINISH:
				_check(not lane.has(progress), "sin fichas apiladas en pasillo")
				lane[progress] = true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
