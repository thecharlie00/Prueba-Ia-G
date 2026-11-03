extends SceneTree

var failures := 0
var counts := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for seed_value in range(10):
		var game := IslandRules.new(seed_value + 500, 3 + seed_value % 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + 9000
		for step in range(game.players * 2):
			var choices: Array[int] = []
			for i in range(game.board.vertices.size()):
				if game.can_settlement(i):
					choices.append(i)
			if choices.is_empty():
				_check(false, "preparación bloqueada")
				break
			var vertex := choices[rng.randi_range(0, choices.size() - 1)]
			game.place_settlement(vertex)
			for edge in game.board.vertex_edges[vertex]:
				if game.can_road(edge):
					game.place_road(edge)
					break
		for round_index in range(150):
			if game.phase == IslandRules.FINISHED:
				break
			_check(game.phase == IslandRules.ROLL, "comienzo de turno")
			game.roll(rng.randi_range(1, 6), rng.randi_range(1, 6))
			_resolve(game, rng)
			if game.phase == IslandRules.FINISHED:
				break
			for card in [
				IslandRules.KNIGHT,
				IslandRules.ROAD_BUILDING,
				IslandRules.YEAR_OF_PLENTY,
				IslandRules.MONOPOLY_CARD
			]:
				if game.play_development(card):
					_resolve(game, rng)
					break
			if game.phase == IslandRules.FINISHED:
				break
			_actions(game, rng)
			if game.phase == IslandRules.ACTION:
				game.end_turn()
			_check_conservation(game)
		var replay := IslandRules.from_record(
			JSON.parse_string(JSON.stringify(game.export_record()))
		)
		_check(replay != null, "replay de partida simulada")
		if replay != null:
			_check(
				replay.resources == game.resources and replay.bank == game.bank,
				"replay de economía"
			)
			_check(
				(
					replay.building_owner == game.building_owner
					and replay.road_owner == game.road_owner
				),
				"replay de tablero"
			)
			_check(
				replay.dev_ready == game.dev_ready and replay.dev_new == game.dev_new,
				"replay de cartas"
			)
			_check(
				(
					replay.phase == game.phase
					and replay.turn == game.turn
					and replay.winner == game.winner
				),
				"replay de turno"
			)
		for event in game.events:
			counts[event["type"]] = counts.get(event["type"], 0) + 1
	_check(counts.get("buy", 0) > 0 and counts.get("play", 0) > 0, "simulaciones usaron cartas")
	if failures:
		printerr("Island simulation: %d errores" % failures)
		quit(1)
	else:
		print("Island simulation tests OK · 10 partidas · eventos ", counts)
		quit(0)


func _resolve(game: IslandRules, rng: RandomNumberGenerator) -> void:
	var safety := 0
	while (
		game.phase
		in [
			IslandRules.DISCARD,
			IslandRules.ROBBER,
			IslandRules.STEAL,
			IslandRules.FREE_ROADS,
			IslandRules.PLENTY,
			IslandRules.MONOPOLY
		]
	):
		safety += 1
		if safety > 100:
			_check(false, "efecto bloqueado")
			return
		match game.phase:
			IslandRules.DISCARD:
				for resource in range(5):
					if game.discard(resource):
						break
			IslandRules.ROBBER:
				game.move_robber((game.robber_tile + 1 + rng.randi_range(0, 17)) % 19)
			IslandRules.STEAL:
				game.steal(game.eligible_victims[0])
			IslandRules.FREE_ROADS:
				for edge in range(72):
					if game.place_road(edge):
						break
			IslandRules.PLENTY:
				for resource in range(5):
					if game.take_plenty(resource):
						break
			IslandRules.MONOPOLY:
				game.choose_monopoly(rng.randi_range(0, 4))


func _actions(game: IslandRules, rng: RandomNumberGenerator) -> void:
	for vertex in range(54):
		if game.upgrade_city(vertex):
			break
	for vertex in range(54):
		if game.place_settlement(vertex):
			break
	for edge in range(72):
		if game.place_road(edge):
			break
	game.buy_development()
	if game.phase != IslandRules.ACTION:
		return
	for resource in range(5):
		if game.resources[game.turn][resource] >= game.bank_rate(game.turn, resource) + 1:
			var target := (resource + 1 + rng.randi_range(0, 3)) % 5
			game.trade_bank(resource, target)
			break
	# Una oferta real y su respuesta se incluyen en el historial.
	var other := (game.turn + 1) % game.players
	for give in range(5):
		for take in range(5):
			if (
				give != take
				and game.resources[game.turn][give] > 0
				and game.resources[other][take] > 0
			):
				var offered := [0, 0, 0, 0, 0]
				var requested := [0, 0, 0, 0, 0]
				offered[give] = 1
				requested[take] = 1
				if game.propose_trade(other, offered, requested):
					game.respond_trade(other, rng.randi_range(0, 1) == 1)
				return


func _check_conservation(game: IslandRules) -> void:
	for resource in range(5):
		var total: int = game.bank[resource]
		for player in range(game.players):
			total += int(game.resources[player][resource])
		_check(total == 19, "conservación del recurso")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 10:
			printerr("FALLO: " + message)
