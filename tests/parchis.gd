extends SceneTree
## Parchís español clásico (68 casillas numeradas, 4 casas en esquina, 12 seguros, pasillos de
## 7 casillas y meta central de 4 triángulos): reglas y tablero 3D.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_classic_board_numbers()
	_exit_rules()
	_barriers()
	_bonuses()
	_sixes()
	_save_and_bots()
	await _view()
	if _failed:
		quit(1)
	else:
		print("parchis: ok")
		quit(0)


func _game(count := 4) -> LudoRules:
	return LudoRules.new(count, LudoRules.PARCHIS)


func _classic_board_numbers() -> void:
	var game4 := _game(4)
	_check(
		game4.track_length() == 68 and game4.corridor_start() == 64 and game4.finish_progress() == 71,
		"recorrido clásico de 68 casillas, 7 de pasillo y meta en 71"
	)
	var exits: Array[int] = []
	var bridges: Array[int] = []
	for p in range(4):
		exits.append(game4.player_square(p, 0) + 1)
		bridges.append(game4.player_square(p, 63) + 1)
	_check(exits == [5, 22, 39, 56], "salidas clásicas en las casillas 5, 22, 39 y 56")
	_check(bridges == [68, 17, 34, 51], "entradas de pasillo en las casillas 68, 17, 34 y 51")
	var safe_labels: Array[int] = []
	for sq in LudoRules.PARCHIS_SAFE:
		safe_labels.append(int(sq) + 1)
	_check(
		safe_labels == [5, 12, 17, 22, 29, 34, 39, 46, 51, 56, 63, 68],
		"los 12 seguros clásicos del parchís español"
	)
	var game2 := _game(2)
	_check(
		game2.player_square(0, 0) + 1 == 5 and game2.player_square(1, 0) + 1 == 39,
		"a 2 jugadores se usan casas opuestas (5 amarillo y 39 rojo)"
	)


func _exit_rules() -> void:
	var game := _game()
	game.apply_roll(6)
	_check(
		game.turn == 0 and game.phase == LudoRules.ROLL,
		"con un 6 y todo en casa no se sale, pero se vuelve a tirar"
	)
	game.apply_roll(3)
	_check(game.turn == 1, "sin 5 ni 6 pasa el turno")
	game = _game()
	game.apply_roll(5)
	_check(game.legal_tokens() == [0, 1, 2, 3], "con un 5 se puede sacar cualquier ficha")
	_check(
		game.move(2) and game.positions[0][2] == 0 and game.turn == 1,
		"sale a su casilla de salida"
	)
	# Con un 5 es obligatorio sacar si se puede.
	game = _game(2)
	game.positions[0] = [10, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(5)
	_check(game.legal_tokens() == [1, 2, 3], "con un 5 hay que sacar ficha")
	# Al salir se come al rival que está en la salida, aunque sea seguro.
	game = _game(2)
	var exit_j1 := game.player_square(0, 0)
	var j2_start := game.player_square(1, 0)
	game.positions[1][0] = posmod(exit_j1 - j2_start, LudoRules.PARCHIS_TRACK)
	_check(
		game.player_square(1, game.positions[1][0]) == exit_j1,
		"la ficha de J2 está en la salida de J1"
	)
	game.apply_roll(5)
	game.move(0)
	_check(game.bonus == 20 and game.turn == 0, "comer al salir también da 20")
	_check(game.positions[1][0] == LudoRules.YARD, "la ficha comida vuelve a casa")


func _barriers() -> void:
	var game := _game(2)
	# Barrera de J2 en la casilla 5 del recorrido de J1.
	var square := game.player_square(0, 5)
	var progress_j2 := posmod(square - game.player_square(1, 0), LudoRules.PARCHIS_TRACK)
	game.positions[1] = [progress_j2, progress_j2, LudoRules.YARD, LudoRules.YARD]
	game.positions[0] = [2, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(4)
	_check(game.destination(0) == -2 and game.turn == 1, "una barrera no se puede pasar")
	game = _game(2)
	game.positions[0] = [3, 7, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(4)
	_check(game.destination(0) == 7 and game.move(0), "dos fichas propias pueden juntarse")
	_check(game.tokens_on(game.player_square(0, 7)).size() == 2, "forman barrera")
	# Seguro compartido: dos colores en un seguro (casilla 12 -> progreso 7 de J1), sin comer.
	game = _game(2)
	var safe := int(LudoRules.PARCHIS_SAFE[1])
	var j1_prog := posmod(safe - game.player_square(0, 0), LudoRules.PARCHIS_TRACK)
	var j2_prog := posmod(safe - game.player_square(1, 0), LudoRules.PARCHIS_TRACK)
	game.positions[1] = [j2_prog, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	game.positions[0] = [j1_prog - 3, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(3)
	_check(game.move(0) and game.positions[1][0] != LudoRules.YARD, "en el seguro no se come")


func _bonuses() -> void:
	var game := _game(2)
	var target := game.player_square(0, 10)
	var j2_prog := posmod(target - game.player_square(1, 0), LudoRules.PARCHIS_TRACK)
	game.positions[1] = [j2_prog, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	game.positions[0] = [6, 20, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(4)
	_check(game.move(0) and game.positions[1][0] == LudoRules.YARD, "se come fuera del seguro")
	_check(
		game.bonus == 20 and game.turn == 0 and game.phase == LudoRules.MOVE,
		"comer da 20 de premio"
	)
	_check(game.move(1) and game.positions[0][1] == 40, "el premio mueve 20 casillas")
	_check(game.turn == 1 and game.bonus == 0, "después del premio pasa el turno")
	# Meta: 10 de premio.
	game = _game(2)
	game.positions[0] = [LudoRules.PARCHIS_FINISH - 3, 4, LudoRules.YARD, LudoRules.YARD]
	game.apply_roll(3)
	_check(game.move(0) and game.bonus == 10, "llegar a meta da 10")
	_check(game.move(1) and game.positions[0][1] == 14, "el premio de meta mueve 10")


func _sixes() -> void:
	var game := _game(2)
	game.positions[0] = [4, 20, 30, 40]
	game.apply_roll(6)
	_check(game.steps() == 7, "sin fichas en casa el 6 cuenta 7")
	game.move(0)
	_check(game.turn == 0 and game.phase == LudoRules.ROLL, "con un 6 se repite")
	game.apply_roll(6)
	game.move(1)
	game.apply_roll(6)
	_check(
		game.positions[0][1] == LudoRules.YARD and game.turn == 1,
		"el tercer 6 manda a casa la última movida"
	)
	# Si la última ficha movida ya entró al pasillo de meta, el tercer 6 no la devuelve a casa.
	game = _game(2)
	game.positions[0] = [65, 10, LudoRules.YARD, LudoRules.YARD]
	game.sixes = 2
	game.last_moved = 0
	game.apply_roll(6)
	_check(
		game.positions[0][0] == 65 and game.turn == 1,
		"ficha dentro del pasillo no vuelve a casa con el tercer 6"
	)


func _save_and_bots() -> void:
	var game := _game(4)
	random_play(game, 600)
	var copy := LudoRules.from_record(JSON.parse_string(JSON.stringify(game.export_record())))
	_check(
		copy != null and copy.is_parchis() and copy.positions == game.positions and copy.turn == game.turn,
		"la partida de parchís se reconstruye"
	)
	_check(
		LudoRules.from_record(LudoRules.new(2).export_record()).variant == LudoRules.LUDO,
		"el ludo guardado sigue siendo ludo"
	)
	# Partidas completas con el bot en 68 casillas.
	for seed_value in 6:
		seed(seed_value)
		game = _game(4 if seed_value % 2 == 0 else 2)
		random_play(game, 8000)
		_check(
			game.phase == LudoRules.FINISHED,
			"partida de parchís con bots termina (semilla %d)" % seed_value
		)


func random_play(game: LudoRules, limit: int) -> void:
	var actions := 0
	while game.phase != LudoRules.FINISHED and actions < limit:
		if game.phase == LudoRules.ROLL:
			game.apply_roll(randi_range(1, 6))
		else:
			var token := TableBots.ludo_choice(game)
			if not game.move(token):
				_check(false, "el bot elige una ficha válida")
				return
		actions += 1


func _view() -> void:
	var view: LudoView = (load("res://scenes/Parchis2.tscn") as PackedScene).instantiate()
	root.add_child(view)
	for i in 10:
		await physics_frame
	_check(
		view.rules.is_parchis() and view.rules.players == 2,
		"la escena de parchís usa sus reglas"
	)
	var tiles := view.get_node("Board/Tiles")
	_check(
		tiles.get_node_or_null("House0") != null
		and tiles.get_node_or_null("House3") != null
		and tiles.get_node_or_null("Square1") != null
		and tiles.get_node_or_null("Square68") != null
		and tiles.get_node_or_null("Num68") != null
		and tiles.get_node_or_null("Lane0_7") != null
		and tiles.get_node_or_null("MetaTriangle0") != null
		and tiles.get_node_or_null("MetaTriangle3") != null,
		"tablero clásico 3D construye 4 casas, 68 casillas numeradas, pasillos de 7 y meta de 4 triángulos"
	)
	_check(
		view._player_name(0) == "amarillo" and view._player_name(1) == "rojo",
		"Parchis2 asigna casas opuestas amarillo y rojo"
	)
	view.rules.positions[0] = [7, 7, LudoRules.YARD, LudoRules.YARD]
	var a := view._token_position(0, 0, 7)
	var b := view._token_position(0, 1, 7)
	_check(a.distance_to(b) > 0.12, "dos fichas en una casilla se ponen una al lado de otra")
	var meta_pos := view._finished_position(0, 0)
	_check(
		Vector2(meta_pos.x - LudoView.CENTER.x, meta_pos.z - LudoView.CENTER.z).length()
		< LudoView.PARCHIS_META_HALF,
		"las fichas terminadas se colocan dentro del triángulo central de meta"
	)
	view.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
