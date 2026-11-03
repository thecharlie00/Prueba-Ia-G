extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_ports()
	_test_trade()
	_test_development()
	_test_longest_road()
	_test_replay()
	if failures:
		printerr("Island extended: %d errores" % failures)
		quit(1)
	else:
		print("Island extended tests OK")
		quit(0)


func _test_ports() -> void:
	for seed_value in range(30):
		var game := IslandRules.new(seed_value)
		var types := [0, 0, 0, 0, 0, 0]
		var used := {}
		var counts := []
		counts.resize(72)
		counts.fill(0)
		for tile in game.board.tiles:
			for edge in tile["edges"]:
				counts[edge] += 1
		for port in game.board.ports:
			var id: int = port["edge"]
			var resource: int = port["resource"]
			types[resource + 1] += 1
			var edge: Vector2i = game.board.edges[id]
			_check(counts[id] == 1, "puerto en la costa")
			_check(not used.has(edge.x) and not used.has(edge.y), "puertos no comparten extremos")
			used[edge.x] = true
			used[edge.y] = true
			game.building_owner[edge.x] = 0
			_check(
				(
					game.bank_rate(0, 0 if resource == -1 else resource)
					<= (3 if resource == -1 else 2)
				),
				"tarifa por puerto"
			)
			game.building_owner[edge.x] = -1
		_check(types == [4, 1, 1, 1, 1, 1], "nueve puertos y distribución")
		_check(game.board.ports == IslandRules.new(seed_value).board.ports, "puertos reproducibles")


func _test_trade() -> void:
	var game := IslandRules.new(1)
	game.phase = IslandRules.ACTION
	game.resources[0] = [4, 2, 0, 0, 0]
	game.resources[1] = [0, 0, 3, 1, 0]
	var give := [2, 1, 0, 0, 0]
	var take := [0, 0, 2, 1, 0]
	_check(not game.propose_trade(0, give, take), "no comerciar consigo mismo")
	_check(
		not game.propose_trade(1, [2, 0, 0, 0, 0], [1, 0, 0, 0, 0]), "no intercambiar mismo recurso"
	)
	_check(game.propose_trade(1, give, take), "proponer varios recursos")
	_check(
		not game.end_turn() and not game.respond_trade(2, true),
		"esperar respuesta del destinatario"
	)
	_check(game.respond_trade(1, false) and game.resources[0][0] == 4, "rechazo no transfiere")
	_check(game.propose_trade(1, give, take), "repetir oferta")
	_check(game.respond_trade(1, true), "aceptar oferta")
	_check(
		game.resources[0] == [2, 1, 2, 1, 0] and game.resources[1] == [2, 1, 1, 0, 0],
		"transferencia exacta"
	)
	_check(game.propose_trade(1, give, [0, 0, 10, 0, 0]), "puede proponerse lo que no posee")
	_check(
		not game.respond_trade(1, true) and game.respond_trade(1, false),
		"rechaza aceptar sin fondos"
	)


func _test_development() -> void:
	var game := IslandRules.new(2)
	var counts := [0, 0, 0, 0, 0]
	for card in game.development_deck:
		counts[card] += 1
	_check(counts == [14, 5, 2, 2, 2], "distribución de 25 cartas")
	game.phase = IslandRules.ACTION
	game.resources[0] = [0, 0, 4, 4, 4]
	game.development_deck.clear()
	game.development_deck.append(IslandRules.KNIGHT)
	_check(game.buy_development(), "comprar desarrollo")
	_check(not game.play_development(IslandRules.KNIGHT), "no jugar carta comprada este turno")
	game.end_turn()
	game.phase = IslandRules.ACTION
	game.end_turn()
	game.phase = IslandRules.ACTION
	game.end_turn()
	_check(game.turn == 0 and game.phase == IslandRules.ROLL, "carta madura en el siguiente turno")
	_check(game.play_development(IslandRules.KNIGHT), "caballero antes de dados")
	_check(game.phase == IslandRules.ROBBER, "caballero mueve ladrón")
	var target := (game.robber_tile + 1) % 19
	game.move_robber(target)
	_check(game.phase == IslandRules.ROLL and game.knights_played[0] == 1, "regresa a tirada")
	_check(not game.play_development(IslandRules.KNIGHT), "solo una carta por turno")
	game.phase = IslandRules.ACTION
	game.dev_played = false
	game.dev_ready[0][IslandRules.YEAR_OF_PLENTY] = 1
	_check(game.play_development(IslandRules.YEAR_OF_PLENTY), "abundancia")
	var previous: int = game.resources[0][0]
	_check(game.take_plenty(0) and game.take_plenty(0), "elige mismo recurso dos veces")
	_check(
		game.resources[0][0] == previous + 2 and game.phase == IslandRules.ACTION,
		"abundancia se resuelve"
	)
	game.dev_played = false
	game.dev_ready[0][IslandRules.MONOPOLY_CARD] = 1
	game.resources[1][1] = 3
	game.resources[2][1] = 2
	_check(
		game.play_development(IslandRules.MONOPOLY_CARD) and game.choose_monopoly(1), "monopolio"
	)
	_check(
		game.resources[0][1] == 5 and game.resources[1][1] == 0 and game.resources[2][1] == 0,
		"monopolio transfiere"
	)
	game.dev_played = false
	game.dev_ready[0][IslandRules.ROAD_BUILDING] = 1
	game.building_owner[0] = 0
	game.building_level[0] = 1
	_check(game.play_development(IslandRules.ROAD_BUILDING), "construcción de caminos")
	var before: Array = game.resources[0].duplicate()
	for step in range(2):
		var edge := -1
		for i in range(game.road_owner.size()):
			if game.can_road(i):
				edge = i
				break
		_check(edge >= 0 and game.place_road(edge), "camino gratuito conectado")
	_check(
		game.phase == IslandRules.ACTION and game.resources[0] == before, "dos caminos sin pagar"
	)
	game.knights_played = [3, 3, 2]
	_check(game._award_holder(game.knights_played, 0, 3) == 0, "empate conserva ejército")
	_check(game._award_holder(game.knights_played, -1, 3) == -1, "empate sin dueño")
	game.knights_played = [3, 4, 2]
	_check(game._award_holder(game.knights_played, 0, 3) == 1, "ejército supera al dueño")
	game.dev_new[0][IslandRules.VICTORY_POINT] = 1
	_check(game.score(0) >= 2, "punto de victoria recién comprado cuenta")


func _test_longest_road() -> void:
	var game := IslandRules.new(3)
	var tile: Dictionary = game.board.tiles[8]
	for edge in tile["edges"]:
		game.road_owner[edge] = 0
	game._update_longest_road()
	_check(
		game.road_lengths[0] == 6 and game.longest_road == 0, "ruta en ciclo cuenta aristas una vez"
	)
	var junction: int = tile["vertices"][0]
	var extension := -1
	for edge in game.board.vertex_edges[junction]:
		if edge not in tile["edges"]:
			extension = edge
	_check(extension >= 0, "rama disponible")
	if extension >= 0:
		game.road_owner[extension] = 0
		game._update_longest_road()
		_check(game.road_lengths[0] == 7, "ruta con ciclo y rama")
		game.building_owner[junction] = 1
		game._update_longest_road()
		_check(game.road_lengths[0] == 6, "pueblo rival corta ruta a través del vértice")
	var other: int = tile["vertices"][3]
	game.building_owner[other] = 2
	game._update_longest_road()
	_check(game.road_lengths[0] < 5 and game.longest_road == -1, "dos bloqueos quitan título")
	_check(game._award_holder([5, 5, 3], 0, 5) == 0, "empate conserva ruta")
	_check(game._award_holder([5, 6, 3], 0, 5) == 1, "ruta mayor cambia titular")
	var winning := IslandRules.new(9)
	winning.phase = IslandRules.ACTION
	for vertex in range(6):
		winning.building_owner[vertex] = 0
		winning.building_level[vertex] = 2 if vertex < 3 else 1
	var loop: Array = winning.board.tiles[8]["edges"]
	for i in range(4):
		winning.road_owner[loop[i]] = 0
	winning._update_longest_road()
	winning.dev_ready[0][IslandRules.ROAD_BUILDING] = 1
	_check(
		winning.score(0) == 9 and winning.play_development(IslandRules.ROAD_BUILDING),
		"preparar victoria por caminos"
	)
	_check(
		winning.place_road(loop[4]) and winning.phase == IslandRules.FINISHED,
		"victoria al construir primer camino gratis"
	)


func _test_replay() -> void:
	var game := IslandRules.new(71)
	for step in range(6):
		var vertex := -1
		for i in range(54):
			if game.can_settlement(i):
				vertex = i
				break
		if vertex < 0:
			_check(false, "preparación para replay")
			return
		game.place_settlement(vertex)
		for edge in game.board.vertex_edges[vertex]:
			if game.place_road(edge):
				break
	game.roll(3, 4)
	if game.phase == IslandRules.ROBBER:
		game.move_robber((game.robber_tile + 1) % 19)
	if game.phase == IslandRules.STEAL:
		game.steal(game.eligible_victims[0])
	var record: Variant = JSON.parse_string(JSON.stringify(game.export_record()))
	var loaded := IslandRules.from_record(record)
	_check(loaded != null, "replay JSON válido")
	if loaded != null:
		_check(
			loaded.resources == game.resources and loaded.phase == game.phase,
			"replay restaura reglas"
		)
		_check(
			loaded.board.ports == game.board.ports and loaded.road_owner == game.road_owner,
			"replay restaura tablero"
		)
		_check(loaded.development_deck == game.development_deck, "replay restaura mazo")
	record["events"].append({"type": "road", "id": 999})
	_check(IslandRules.from_record(record) == null, "replay inválido rechazado")
	_check(
		(
			IslandRules.from_record(
				{
					"game": "island_resources",
					"version": 1,
					"seed": 0,
					"events": [{"type": "offer", "other": 1, "give": null, "take": []}]
				}
			)
			== null
		),
		"datos malformados rechazados"
	)


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		printerr("FALLO: " + message)
