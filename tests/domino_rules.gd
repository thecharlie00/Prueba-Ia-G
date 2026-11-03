extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rules := DominoRules.new()
	rules.reset(42)
	_check(rules.values.size() == 28, "conjunto doble seis")
	_check(rules.hands[0].size() == 7 and rules.hands[1].size() == 7, "reparto inicial")
	_check(rules.stock.size() == 14 and rules.turn == 0, "pozo y primer turno")
	var first_hand: Array = rules.hands[0].duplicate()
	var first_stock: Array = rules.stock.duplicate()
	rules.reset(42)
	_check(rules.hands[0] == first_hand and rules.stock == first_stock, "semilla reproducible")
	_check(rules.draw() == -1 and not rules.pass_turn(), "no se roba ni pasa si se puede jugar")
	var first: int = rules.hands[0][0]
	_check(not rules.play(first, "arriba") and rules.chain.is_empty(), "rechazar extremo inválido")
	_check(not rules.play(rules.hands[1][0], "left"), "no jugar fichas del oponente")
	_check(rules.play(first, "left") and rules.turn == 1, "apertura y cambio de turno")

	# Una posición reducida permite verificar orientación y rechazo sin azar.
	var two_five := _id(rules, 2, 5)
	var one_two := _id(rules, 1, 2)
	var five_six := _id(rules, 5, 6)
	var zero_zero := _id(rules, 0, 0)
	rules.chain = [{"id": two_five, "left": 2, "right": 5}]
	rules.hands = [[one_two, five_six, zero_zero], [0]]
	rules.turn = 0
	rules.result = DominoRules.PLAYING
	_check(rules.legal_ends(one_two) == ["left"], "coincidencia izquierda")
	_check(rules.legal_ends(five_six) == ["right"], "coincidencia derecha")
	_check(rules.legal_ends(zero_zero).is_empty(), "ficha incompatible")
	_check(not rules.play(one_two, "right"), "rechazar extremo incompatible")
	_check(rules.play(one_two, "left"), "jugar por la izquierda")
	_check(rules.chain[0]["left"] == 1 and rules.chain[0]["right"] == 2, "orientación izquierda")
	rules.turn = 0
	_check(rules.play(five_six, "right"), "jugar por la derecha")
	_check(
		rules.chain.back()["left"] == 5 and rules.chain.back()["right"] == 6, "orientación derecha"
	)

	# Comprobar también las dos orientaciones que requieren invertir la ficha.
	var two_six := _id(rules, 2, 6)
	var one_five := _id(rules, 1, 5)
	rules.chain = [{"id": two_five, "left": 2, "right": 5}]
	rules.hands = [[two_six, one_five, zero_zero], [0]]
	rules.turn = 0
	_check(rules.play(two_six, "left"), "invertir para conectar por izquierda")
	_check(
		rules.chain.front()["left"] == 6 and rules.chain.front()["right"] == 2,
		"valores invertidos a izquierda"
	)
	rules.turn = 0
	_check(rules.play(one_five, "right"), "invertir para conectar por derecha")
	_check(
		rules.chain.back()["left"] == 5 and rules.chain.back()["right"] == 1,
		"valores invertidos a derecha"
	)

	# Robar solo cuando no hay jugadas; el turno no cambia y puede requerir más de un robo.
	rules.chain = [{"id": two_five, "left": 2, "right": 5}]
	rules.hands = [[zero_zero], [1]]
	rules.stock.assign([one_two, _id(rules, 0, 1)])
	rules.turn = 0
	rules.result = DominoRules.PLAYING
	_check(rules.draw() == _id(rules, 0, 1) and rules.turn == 0, "primer robo sin cambiar turno")
	_check(rules.draw() == one_two and rules.turn == 0, "segundo robo hasta conseguir jugada")
	_check(not rules.pass_turn() and rules.draw() == -1, "no pasar ni robar con jugada")

	# Cierre por bloqueo: menor suma o empate. La posición es sintética.
	rules.chain = [{"id": two_five, "left": 2, "right": 5}]
	rules.hands = [[zero_zero], [_id(rules, 1, 1)]]
	rules.stock.clear()
	rules.turn = 0
	rules.passes = 0
	rules.result = DominoRules.PLAYING
	_check(rules.pass_turn() and rules.turn == 1, "primer pase")
	_check(
		rules.pass_turn() and rules.result == DominoRules.PLAYER_1_WINS, "bloqueo por menor suma"
	)
	_check(not rules.pass_turn() and not rules.play(zero_zero, "left"), "resultado es final")
	rules.hands = [[_id(rules, 0, 4)], [_id(rules, 1, 3)]]
	rules.turn = 0
	rules.passes = 0
	rules.result = DominoRules.PLAYING
	_check(
		rules.pass_turn() and rules.pass_turn() and rules.result == DominoRules.DRAW,
		"empate por puntos"
	)

	# Salir de la última ficha gana inmediatamente.
	rules.chain = [{"id": two_five, "left": 2, "right": 5}]
	rules.hands = [[one_two], [zero_zero]]
	rules.turn = 0
	rules.result = DominoRules.PLAYING
	_check(
		rules.play(one_two, "left") and rules.result == DominoRules.PLAYER_1_WINS,
		"victoria al vaciar mano"
	)

	for seed_value in range(50):
		_play_random_game(seed_value)
	if failures:
		printerr("Domino rules: %d errores" % failures)
		quit(1)
	else:
		print("Domino rules tests OK · 50 partidas completas")
		quit(0)


func _play_random_game(seed_value: int) -> void:
	var rules := DominoRules.new()
	rules.reset(seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 200
	var steps := 0
	while rules.result == DominoRules.PLAYING and steps < 150:
		_check_inventory(rules)
		var moves: Array[Dictionary] = []
		for id in rules.hands[rules.turn]:
			for end in rules.legal_ends(id):
				moves.append({"id": id, "end": end})
		if not moves.is_empty():
			var move: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
			_check(rules.play(move["id"], move["end"]), "jugada legal aleatoria")
		elif not rules.stock.is_empty():
			_check(rules.draw() >= 0, "robo legal aleatorio")
		else:
			_check(rules.pass_turn(), "pase legal aleatorio")
		steps += 1
	_check_inventory(rules)
	_check(rules.result != DominoRules.PLAYING and steps < 150, "partida completa sin ciclos")


func _check_inventory(rules: DominoRules) -> void:
	var ids: Array = []
	ids.append_array(rules.stock)
	ids.append_array(rules.hands[0])
	ids.append_array(rules.hands[1])
	for entry in rules.chain:
		ids.append(entry["id"])
	var unique := {}
	for id in ids:
		unique[id] = true
	_check(ids.size() == 28 and unique.size() == 28, "conservación de las 28 fichas")
	for i in range(1, rules.chain.size()):
		_check(rules.chain[i - 1]["right"] == rules.chain[i]["left"], "continuidad de cadena")


func _id(rules: DominoRules, left: int, right: int) -> int:
	return rules.values.find(Vector2i(left, right))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 15:
			printerr("FALLO: " + message)
