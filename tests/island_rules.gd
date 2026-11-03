extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for seed_value in range(30):
		_check_board(seed_value)
	_test_setup()
	_test_production_and_robber()
	_test_build_and_trade()
	_test_shortage_and_victory()
	if failures:
		printerr("Island rules: %d errores" % failures)
		quit(1)
	else:
		print("Island rules tests OK · 30 tableros")
		quit(0)


func _check_board(seed_value: int) -> void:
	var board := IslandBoard.new(seed_value)
	_check(
		board.tiles.size() == 19 and board.vertices.size() == 54 and board.edges.size() == 72,
		"geometría 19/54/72"
	)
	var terrain := [0, 0, 0, 0, 0, 0]
	var numbers: Array[int] = []
	var red: Array[int] = []
	for i in range(board.tiles.size()):
		var tile: Dictionary = board.tiles[i]
		_check(tile["vertices"].size() == 6 and tile["edges"].size() == 6, "seis esquinas y lados")
		var resource: int = tile["terrain"]
		terrain[resource if resource >= 0 else 5] += 1
		if resource != IslandBoard.DESERT:
			numbers.append(tile["number"])
			if tile["number"] in [6, 8]:
				red.append(i)
	_check(terrain == [4, 3, 4, 4, 3, 1], "distribución de terrenos")
	numbers.sort()
	_check(
		numbers == [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12], "fichas de números"
	)
	for i in range(red.size()):
		for j in range(i):
			_check(not board.are_neighbors(red[i], red[j]), "números rojos no adyacentes")
	var again := IslandBoard.new(seed_value)
	_check(board.tiles == again.tiles, "tablero reproducible")


func _test_setup() -> void:
	var game := IslandRules.new(7)
	var order: Array[int] = []
	for step in range(6):
		_check(game.phase == IslandRules.SETUP_SETTLEMENT, "preparar pueblo")
		order.append(game.turn)
		var vertex := -1
		for i in range(game.board.vertices.size()):
			if game.can_settlement(i):
				vertex = i
				break
		_check(vertex >= 0 and game.place_settlement(vertex), "colocar pueblo inicial")
		_check(not game.place_settlement(vertex), "no colocar dos pueblos seguidos")
		var edge_id: int = game.board.vertex_edges[vertex][0]
		_check(
			game.can_road(edge_id) and game.place_road(edge_id), "camino inicial junto al pueblo"
		)
	_check(order == [0, 1, 2, 2, 1, 0], "orden inicial de ida y vuelta")
	_check(game.phase == IslandRules.ROLL and game.turn == 0, "empieza primera tirada")
	_check(not game.end_turn() and not game.trade_bank(0, 1), "no actuar antes de tirar")
	_check(not game.roll(0, 6) and game.phase == IslandRules.ROLL, "tirada inválida rechazada")
	_check(game.roll(1, 1) and game.phase == IslandRules.ACTION, "tirada normal")
	_check(game.end_turn() and game.turn == 1 and game.phase == IslandRules.ROLL, "fin de turno")
	_conservation(game)


func _test_production_and_robber() -> void:
	var game := IslandRules.new(13)
	var tile_id := -1
	for i in range(game.board.tiles.size()):
		if game.board.tiles[i]["number"] == 8:
			tile_id = i
			break
	var tile: Dictionary = game.board.tiles[tile_id]
	var resource: int = tile["terrain"]
	var vertex: int = tile["vertices"][0]
	game.building_owner[vertex] = 0
	game.building_level[vertex] = 2
	game.robber_tile = -1
	game.phase = IslandRules.ROLL
	_check(game.roll(4, 4), "tirada de producción")
	_check(game.resources[0][resource] >= 2, "ciudad produce dos recursos")
	_conservation(game)
	var before: int = game.resources[0][resource]
	game.phase = IslandRules.ROLL
	game.robber_tile = tile_id
	game.roll(4, 4)
	_check(game.resources[0][resource] == before, "ladrón bloquea producción")
	# Siete obliga a descartar la mitad, a elegir recurso, y luego mover ladrón.
	game.phase = IslandRules.ROLL
	for i in range(5):
		var add: int = 10 if i == 0 else 0
		game.resources[1][i] += add
		game.bank[i] -= add
	_check(game.roll(3, 4) and game.phase == IslandRules.DISCARD, "siete requiere descarte")
	_check(game.discard_player == 1 and game.discard_due[1] == 5, "descarta mitad de diez")
	for i in range(5):
		_check(game.discard(0), "descarte elegido")
	_check(game.phase == IslandRules.ROBBER, "después del descarte se mueve ladrón")
	_check(not game.move_robber(tile_id), "no dejar ladrón en el mismo hexágono")
	var next := (tile_id + 1) % 19
	var victim_vertex: int = game.board.tiles[next]["vertices"][0]
	game.building_owner[victim_vertex] = 1
	game.building_level[victim_vertex] = 1
	game.turn = 0
	_check(game.move_robber(next) and game.phase == IslandRules.STEAL, "elegir víctima adyacente")
	var victim_before := game.hand_size(1)
	_check(
		(
			game.steal(1)
			and game.hand_size(1) == victim_before - 1
			and game.phase == IslandRules.ACTION
		),
		"robo transfiere un recurso"
	)
	_conservation(game)


func _test_build_and_trade() -> void:
	var game := IslandRules.new(29)
	game.phase = IslandRules.ACTION
	for i in range(5):
		game.resources[0][i] = 10
		game.bank[i] = 9
	game.building_owner[0] = 0
	game.building_level[0] = 1
	var edge_id: int = game.board.vertex_edges[0][0]
	_check(game.place_road(edge_id), "camino conectado al pueblo")
	_check(not game.place_road(edge_id), "camino ocupado rechazado")
	var edge: Vector2i = game.board.edges[edge_id]
	var neighbor := edge.y if edge.x == 0 else edge.x
	_check(not game.place_settlement(neighbor), "distancia entre pueblos obligatoria")
	_check(game.upgrade_city(0) and game.building_level[0] == 2, "mejorar ciudad")
	_check(not game.upgrade_city(0), "no mejorar ciudad de nuevo")
	var old: int = game.resources[0][0]
	_check(game.trade_bank(0, 1) and game.resources[0][0] == old - 4, "comercio con banco 4:1")
	_check(not game.trade_bank(0, 0), "no intercambiar recurso por sí mismo")
	_conservation(game)
	# Una pieza rival bloquea prolongar un camino a través de ese vértice.
	var blocked := IslandRules.new(30)
	blocked.phase = IslandRules.ACTION
	blocked.resources[0] = [5, 5, 5, 5, 5]
	var first: Vector2i = blocked.board.edges[0]
	blocked.road_owner[0] = 0
	blocked.building_owner[first.y] = 1
	blocked.building_level[first.y] = 1
	var continuation := -1
	for candidate in blocked.board.vertex_edges[first.y]:
		if candidate != 0:
			continuation = candidate
			break
	_check(
		continuation >= 0 and not blocked.can_road(continuation), "pueblo rival bloquea conexión"
	)
	blocked.building_owner[first.y] = -1
	blocked.building_level[first.y] = 0
	_check(blocked.can_road(continuation), "camino conecta sin bloqueo")


func _test_shortage_and_victory() -> void:
	var game := IslandRules.new(39)
	var tile_id := -1
	for i in range(game.board.tiles.size()):
		if game.board.tiles[i]["number"] == 8:
			tile_id = i
			break
	var tile: Dictionary = game.board.tiles[tile_id]
	var resource: int = tile["terrain"]
	var vertex: int = tile["vertices"][0]
	game.building_owner[vertex] = 0
	game.building_level[vertex] = 2
	game.resources[1][resource] = 18
	game.bank[resource] = 1
	game.robber_tile = -1
	game.phase = IslandRules.ROLL
	game.roll(4, 4)
	_check(game.resources[0][resource] == 1, "un solo beneficiario recibe lo disponible")
	_conservation(game)
	var shortage := IslandRules.new(39)
	shortage.robber_tile = -1
	shortage.phase = IslandRules.ROLL
	shortage.bank[resource] = 1
	shortage.resources[2][resource] = 18
	for owner in range(2):
		var corner: int = tile["vertices"][owner]
		shortage.building_owner[corner] = owner
		shortage.building_level[corner] = 1
	shortage.roll(4, 4)
	_check(
		shortage.resources[0][resource] == 0 and shortage.resources[1][resource] == 0,
		"escasez con varios beneficiarios no reparte"
	)
	_conservation(shortage)
	var winner := IslandRules.new(40)
	winner.phase = IslandRules.ACTION
	for i in range(4):
		winner.building_owner[i] = 0
		winner.building_level[i] = 2
	winner.building_owner[4] = 0
	winner.building_level[4] = 1
	winner.resources[0] = [0, 0, 0, 2, 3]
	winner.bank[3] -= 2
	winner.bank[4] -= 3
	# Una ciudad se ha retirado para dejar una pieza disponible.
	winner.building_level[3] = 1
	winner.building_owner[5] = 0
	winner.building_level[5] = 1
	_check(winner.score(0) == 9, "nueve puntos antes de mejorar")
	_check(winner.upgrade_city(4), "mejora final")
	_check(winner.winner == 0 and winner.phase == IslandRules.FINISHED, "victoria a diez")
	_check(not winner.end_turn(), "no continuar después de victoria")
	_conservation(winner)


func _conservation(game: IslandRules) -> void:
	for resource in range(5):
		var total: int = game.bank[resource]
		for player in range(3):
			total += int(game.resources[player][resource])
		_check(total == 19, "conservación de recursos del banco")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 15:
			printerr("FALLO: " + message)
