class_name TableBots
extends RefCounted
## Bots básicos para completar mesas (roadmap, fase 6): ludo, dominó y damas. Son funciones
## puras sobre las reglas de cada juego, así que se pueden probar sin escena. Juegan con
## sentido común, no buscan ganar siempre: la idea es que no falten jugadores.
##
## Tres niveles de dificultad (menú «Jugar contra bots»): FACIL se equivoca a propósito,
## NORMAL juega con sentido común y DIFICIL busca ventaja con más profundidad. La
## dificultad global y el modo solitario se guardan aquí como estáticos: el menú los
## escribe y los juegos los leen al abrirse.

## Niveles de dificultad para los bots.
enum Difficulty { FACIL, NORMAL, DIFICIL }

## Dificultad elegida en el menú de bots; la usan los juegos al decidir.
static var difficulty := Difficulty.NORMAL
## Marcado por el menú de bots: la siguiente mesa que se abre empieza en solitario
## contra bots. Lo consume el juego al abrirse.
static var solo := false

## Pausa antes de cada acción del bot, para que se vea lo que hace.
const THINK_TIME := 0.8


## Pausa antes de cada acción según la dificultad (segundos).
static func think_time(level: Difficulty = Difficulty.NORMAL) -> float:
	match level:
		Difficulty.FACIL:
			return 0.35
		Difficulty.DIFICIL:
			return 1.4
		_:
			return THINK_TIME


## Ludo: devuelve la ficha que mueve el bot (o -1 si no hay jugada).
## FACIL: cualquiera de las legales. NORMAL: prioriza llegar a meta > comer > salir
## de casa > ponerse a salvo > avanzar la más adelantada que no quede expuesta.
## DIFICIL: el mismo criterio con riesgo elevado (rígido ante rivales cercanos) y
## formación de barrera con otra ficha propia.
static func ludo_choice(rules: LudoRules, level: Difficulty = Difficulty.NORMAL) -> int:
	var legal := rules.legal_tokens()
	if legal.is_empty():
		return -1
	if level == Difficulty.FACIL:
		return legal[randi_range(0, legal.size() - 1)]
	var best := legal[0]
	var best_score := -INF
	for token in legal:
		var score := _ludo_score(rules, token, level)
		if score > best_score:
			best_score = score
			best = token
	return best


static func _ludo_score(rules: LudoRules, token: int, level: Difficulty) -> float:
	var current: int = rules.positions[rules.turn][token]
	var dest := rules.destination(token)
	var score := float(dest) * 0.1
	if dest == LudoRules.FINISH:
		score += 100.0
	elif dest >= 52:
		score += 40.0  # Pasillo de meta: ya nadie la puede comer.
	if current == LudoRules.YARD:
		score += 30.0
	if dest >= 0 and dest < 52:
		var square := LudoRules.track_square(rules.turn, dest)
		if square in LudoRules.SAFE:
			score += 15.0
		if level == Difficulty.DIFICIL:
			# Barrera: otra ficha propia en la casilla de destino.
			for other in 4:
				if other == token:
					continue
				var mate: int = rules.positions[rules.turn][other]
				if mate >= 0 and mate < 52 and LudoRules.track_square(rules.turn, mate) == square:
					score += 15.0
					break
		for player in rules.players:
			if player == rules.turn:
				continue
			for other in 4:
				var progress: int = rules.positions[player][other]
				if progress >= 0 and progress < 52:
					var theirs := LudoRules.track_square(player, progress)
					if theirs == square and square not in LudoRules.SAFE:
						score += 60.0  # Comer.
					# Riesgo: un rival justo detrás (a 1–6 casillas) puede comerla.
					var gap := posmod(square - theirs, 52)
					if gap >= 1 and gap <= 6 and square not in LudoRules.SAFE:
						score -= 25.0 if level == Difficulty.DIFICIL else 8.0
	# Sacar del peligro una ficha que estaba expuesta también suma.
	if current >= 0 and current < 52:
		var here := LudoRules.track_square(rules.turn, current)
		if here not in LudoRules.SAFE:
			score += 3.0
	return score


## Dominó: devuelve {"id", "end"} para jugar, {"action": "draw"} o {"action": "pass"}.
## FACIL: cualquier jugada legal. NORMAL: juega la ficha que más puntos suma
## (dobles primero) y prefiere dejar en los extremos números de los que le quedan fichas.
## DIFICIL: el mismo criterio con mirada de una jugada (resta lo que el rival podría
## sumar a continuación).
static func domino_choice(rules: DominoRules, level: Difficulty = Difficulty.NORMAL) -> Dictionary:
	if rules.result != DominoRules.PLAYING:
		return {}
	if level == Difficulty.FACIL:
		var plays: Array[Dictionary] = []
		for id in rules.hands[rules.turn]:
			for end in rules.legal_ends(id):
				plays.append({"id": id, "end": end})
		if not plays.is_empty():
			return plays[randi_range(0, plays.size() - 1)]
		if not rules.stock.is_empty():
			return {"action": "draw"}
		return {"action": "pass"}
	var best := {}
	var best_score := -INF
	for id in rules.hands[rules.turn]:
		for end in rules.legal_ends(id):
			var tile: Vector2i = rules.values[id]
			var score := float(tile.x + tile.y)
			if tile.x == tile.y:
				score += 4.0
			score += _domino_followups(rules, id, end) * 1.5
			if level == Difficulty.DIFICIL:
				score -= _domino_reply_value(rules, id, end) * 0.5
			if score > best_score:
				best_score = score
				best = {"id": id, "end": end}
	if not best.is_empty():
		return best
	if not rules.stock.is_empty():
		return {"action": "draw"}
	return {"action": "pass"}


## Puntos que el rival podría sumar en su siguiente jugada tras colocar id en end.
static func _domino_reply_value(rules: DominoRules, id: int, end: String) -> float:
	var tile: Vector2i = rules.values[id]
	var left_end := tile.x
	var right_end := tile.y
	if not rules.chain.is_empty():
		if end == "left":
			# El extremo libre tras colocar: si x encaja con el front, queda y libre.
			left_end = tile.y if tile.x == int(rules.chain.front()["left"]) else tile.x
		else:
			right_end = tile.x if tile.y == int(rules.chain.back()["right"]) else tile.y
	var opens: Array = []
	if rules.chain.is_empty():
		opens = [left_end, right_end]
	elif end == "left":
		opens = [left_end, rules.chain.back()["right"]]
	else:
		opens = [rules.chain.front()["left"], right_end]
	var best := 0
	for other in rules.players:
		if other == rules.turn:
			continue
		for other_id in rules.hands[other]:
			var value: Vector2i = rules.values[other_id]
			if value.x in opens or value.y in opens:
				best = maxi(best, value.x + value.y)
	return float(best)


## Cuántas fichas de la mano podrían seguir jugando tras colocar id en end.
static func _domino_followups(rules: DominoRules, id: int, end: String) -> int:
	var tile: Vector2i = rules.values[id]
	var open := tile.y
	if not rules.chain.is_empty():
		var touching: int = rules.chain.front()["left"] if end == "left" else rules.chain.back()["right"]
		open = tile.y if tile.x == touching else tile.x
	var count := 0
	for other in rules.hands[rules.turn]:
		if other == id:
			continue
		var value: Vector2i = rules.values[other]
		if value.x == open or value.y == open:
			count += 1
	return count


## Damas: devuelve {"from", "to"} (un paso o salto; las cadenas se piden de una en una).
## FACIL: jugada legal al azar. NORMAL: minimax a 2 medias jugadas. DIFICIL: minimax a
## 3 medias jugadas. Evalúa material, coronas y avance.
static func checkers_choice(rules: CheckersRules, level: Difficulty = Difficulty.NORMAL) -> Dictionary:
	var moves := _checkers_moves(rules)
	if moves.is_empty():
		return {}
	if level == Difficulty.FACIL:
		return moves[randi_range(0, moves.size() - 1)]
	var side := rules.turn
	var best: Dictionary = moves[0]
	var best_score := -INF
	var depth := 3 if level == Difficulty.DIFICIL else 2
	for move in moves:
		var copy := _checkers_copy(rules)
		copy.play(int(move["from"]), int(move["to"]))
		var score := _checkers_reply(copy, side, depth)
		score += randf() * 0.05  # Desempate para no jugar siempre igual.
		if score > best_score:
			best_score = score
			best = move
	return best


static func _checkers_reply(rules: CheckersRules, side: int, depth: int) -> float:
	var moves := _checkers_moves(rules)
	if depth <= 0 or moves.is_empty():
		if moves.is_empty():
			return -1000.0 if rules.turn == side else 1000.0
		return _checkers_eval(rules, side)
	var maximizing := rules.turn == side
	var best := -INF if maximizing else INF
	for move in moves:
		var copy := _checkers_copy(rules)
		copy.play(int(move["from"]), int(move["to"]))
		# Una captura múltiple sigue siendo del mismo jugador: no gasta profundidad.
		var next_depth := depth if copy.turn == rules.turn else depth - 1
		var score := _checkers_reply(copy, side, next_depth)
		best = maxf(best, score) if maximizing else minf(best, score)
	return best


static func _checkers_eval(rules: CheckersRules, side: int) -> float:
	var score := 0.0
	for square in 64:
		var piece := rules.board[square]
		if piece == 0:
			continue
		var mine := (1 if piece > 0 else -1) == side
		var value := 3.0 if absi(piece) == CheckersRules.KING else 1.0
		if absi(piece) == CheckersRules.MAN:
			# Las blancas avanzan hacia la fila 0 y las negras hacia la 7.
			var rank := square / 8
			value += 0.06 * float(7 - rank if piece > 0 else rank)
		score += value if mine else -value
	return score


static func _checkers_moves(rules: CheckersRules) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for square in 64:
		moves.append_array(rules.legal_moves_from(square))
	return moves


static func _checkers_copy(rules: CheckersRules) -> CheckersRules:
	var copy := CheckersRules.new()
	copy.board = rules.board.duplicate()
	copy.turn = rules.turn
	copy.forced_from = rules.forced_from
	return copy


## Isla de recursos: siguiente acción del jugador del turno, como diccionario
## {"kind": "settlement"|"road"|"city"|"roll"|"discard"|"robber"|"steal"|"trade"|"end", ...}.
## FACIL: la primera acción legal. NORMAL: estrategia voraz — ciudades, luego pueblos en
## los mejores cruces, caminos hacia sitios libres y cambios 4:1 (o de puerto) con el
## banco cuando sobra algo. DIFICIL: el mismo criterio evitando vértices que atraerían
## al ladrón y conectando asentamientos propios.
static func island_action(rules: IslandRules, level: Difficulty = Difficulty.NORMAL) -> Dictionary:
	match rules.phase:
		IslandRules.SETUP_SETTLEMENT:
			return {
				"kind": "settlement",
				"id": _island_first_vertex(rules) if level == Difficulty.FACIL else _island_best_vertex(rules, true, level)
			}
		IslandRules.SETUP_ROAD:
			for edge_id in rules.board.vertex_edges[rules.last_setup_vertex]:
				if rules.can_road(edge_id):
					return {"kind": "road", "id": edge_id}
		IslandRules.ROLL:
			return {"kind": "roll"}
		IslandRules.DISCARD:
			var hand: Array = rules.resources[rules.discard_player]
			var most := 0
			for resource in 5:
				if int(hand[resource]) > int(hand[most]):
					most = resource
			return {"kind": "discard", "id": most}
		IslandRules.ROBBER:
			return {"kind": "robber", "id": _island_robber_tile(rules, level)}
		IslandRules.STEAL:
			return {"kind": "steal", "id": rules.eligible_victims[0]}
		IslandRules.ACTION:
			for vertex in rules.building_owner.size():
				if rules.can_city(vertex):
					return {"kind": "city", "id": vertex}
			var spot := _island_first_vertex(rules) if level == Difficulty.FACIL else _island_best_vertex(rules, false, level)
			if spot >= 0:
				return {"kind": "settlement", "id": spot}
			if _island_needs_road(rules):
				var road := _island_first_road(rules) if level == Difficulty.FACIL else _island_best_road(rules, level)
				if road >= 0:
					return {"kind": "road", "id": road}
			var trade := _island_trade(rules)
			if not trade.is_empty():
				return trade
			return {"kind": "end"}
	return {}


static func _island_vertex_value(rules: IslandRules, vertex: int, level: Difficulty) -> float:
	var value := 0.0
	var kinds := {}
	for tile_id in rules.board.vertex_tiles[vertex]:
		var number: int = rules.board.tiles[tile_id]["number"]
		if number > 0:
			value += 6.0 - absf(7.0 - number)
			kinds[rules.board.tiles[tile_id]["terrain"]] = true
	value += kinds.size() * 0.5
	if level == Difficulty.DIFICIL:
		# El ladrón se mueve a la ficha con más edificios rivales: penaliza los vértices
		# que lo atraerían la próxima vez que salga un 7.
		var rivals := 0
		for tile_id in rules.board.vertex_tiles[vertex]:
			for other in rules.board.tiles[tile_id]["vertices"]:
				var owner: int = rules.building_owner[other]
				if owner >= 0 and owner != rules.turn:
					rivals += 1
		if rivals >= 3:
			value -= 2.0
	return value


## Primer vértice donde se puede hacer un pueblo (la isla fácil no piensa).
static func _island_first_vertex(rules: IslandRules) -> int:
	for vertex in rules.building_owner.size():
		if rules.can_settlement(vertex):
			return vertex
	return -1


## Primer camino que se puede construir.
static func _island_first_road(rules: IslandRules) -> int:
	for edge_id in rules.road_owner.size():
		if rules.can_road(edge_id):
			return edge_id
	return -1


static func _island_best_vertex(rules: IslandRules, setup: bool, level: Difficulty) -> int:
	var best := -1
	var best_value := -1.0
	for vertex in rules.building_owner.size():
		if not rules.can_settlement(vertex):
			continue
		var value := _island_vertex_value(rules, vertex, level)
		if value > best_value:
			best_value = value
			best = vertex
	return best if (setup or best >= 0) else -1


static func _island_best_road(rules: IslandRules, level: Difficulty) -> int:
	# Solo construye caminos si le quedan recursos para algo más después o no tiene sitio.
	var best := -1
	var best_value := -1.0
	for edge_id in rules.road_owner.size():
		if not rules.can_road(edge_id):
			continue
		var edge: Vector2i = rules.board.edges[edge_id]
		var value := 0.0
		for vertex in [edge.x, edge.y]:
			if rules.building_owner[vertex] == -1 and rules._clear_neighbors(vertex):
				value = maxf(value, _island_vertex_value(rules, vertex, level))
		if level == Difficulty.DIFICIL:
			# Conectar dos asentamientos propios también vale.
			if rules.building_owner[edge.x] == rules.turn and rules.building_owner[edge.y] == rules.turn:
				value += 1.0
		if value > best_value:
			best_value = value
			best = edge_id
	return best


static func _island_has_open_site(rules: IslandRules, player: int) -> bool:
	if rules._piece_count(player, 1) >= 5:
		return false
	for vertex in rules.building_owner.size():
		if rules.building_owner[vertex] != -1 or not rules._clear_neighbors(vertex):
			continue
		for edge_id in rules.board.vertex_edges[vertex]:
			if rules.road_owner[edge_id] == player:
				return true
	return false


static func _island_needs_road(rules: IslandRules) -> bool:
	var hand: Array = rules.resources[rules.turn]
	if not _island_has_open_site(rules, rules.turn) and rules._piece_count(rules.turn, 1) < 5:
		return true
	return int(hand[0]) >= 2 and int(hand[1]) >= 2


static func _island_trade(rules: IslandRules) -> Dictionary:
	var hand: Array = rules.resources[rules.turn]
	var targets: Array = []
	if rules._piece_count(rules.turn, 1) > 0 and rules._piece_count(rules.turn, 2) < 4:
		targets.append(IslandRules.CITY_COST)
	if _island_has_open_site(rules, rules.turn):
		targets.append(IslandRules.SETTLEMENT_COST)
	elif rules._piece_count(rules.turn, 1) < 5 and rules._road_count(rules.turn) < 15:
		targets.append(IslandRules.ROAD_COST)
	for cost: Array in targets:
		var want := -1
		for resource in 5:
			if int(cost[resource]) > int(hand[resource]) and rules.bank[resource] > 0:
				want = resource
				break
		if want < 0:
			continue
		for give in 5:
			var rate := rules.bank_rate(rules.turn, give)
			if give != want and int(hand[give]) >= int(cost[give]) + rate:
				return {"kind": "trade", "give": give, "take": want}
		return {}
	return {}


static func _island_robber_tile(rules: IslandRules, level: Difficulty) -> int:
	if level == Difficulty.FACIL:
		for tile_id in rules.board.tiles.size():
			if tile_id != rules.robber_tile:
				return tile_id
		return rules.robber_tile
	var best := -1
	var best_value := -INF
	for tile_id in rules.board.tiles.size():
		if tile_id == rules.robber_tile:
			continue
		var value := 0.0
		for vertex in rules.board.tiles[tile_id]["vertices"]:
			var owner: int = rules.building_owner[vertex]
			if owner == rules.turn:
				value -= 3.0
			elif owner >= 0:
				value += 1.0 + float(rules.hand_size(owner) > 0)
		if value > best_value:
			best_value = value
			best = tile_id
	return best


## Brisca: carta que juega el bot.
## Al salir: la carta que menos vale y, a igualdad, la más floja, guardando los triunfos.
## Al responder: si la baza lleva puntos, la gana con lo más barato que pueda; si no, la
## gana con una carta del mismo palo que sume, o tira la carta que menos pierde.
static func brisca_choice(rules: BriscaRules, level: Difficulty = Difficulty.NORMAL) -> String:
	var hand: Array = rules.hands[rules.turn]
	if hand.is_empty():
		return ""
	if level == Difficulty.FACIL:
		return hand[randi_range(0, hand.size() - 1)]
	var on_table := rules.card_to_beat()
	if on_table.is_empty():
		return _brisca_lead(rules, hand, level)
	var winners: Array = hand.filter(func(card: String) -> bool: return rules.beats(card, on_table))
	var at_stake := BriscaRules.card_points(on_table)
	var same_suit_winners := winners.filter(
		func(card: String) -> bool: return BriscaRules.suit_of(card) != rules.trump_suit
	)
	if not same_suit_winners.is_empty():
		# Ganar con el mismo palo no cuesta triunfos: la de más puntos se lleva más.
		var best: String = same_suit_winners[0]
		for card in same_suit_winners:
			if BriscaRules.card_points(card) > BriscaRules.card_points(best):
				best = card
		return best
	if at_stake >= (4 if level == Difficulty.DIFICIL else 10) and not winners.is_empty():
		return _brisca_cheapest(rules, winners, false)
	return _brisca_cheapest(rules, hand, true)


## Carta con la que se sale. Difícil: con tres o más de un palo no triunfo, sale la
## más alta de ese palo para gastar las del rival; el resto, la más barata.
static func _brisca_lead(rules: BriscaRules, hand: Array, level: Difficulty) -> String:
	if level != Difficulty.DIFICIL:
		return _brisca_cheapest(rules, hand, true)
	var best_suit := ""
	var best_count := 0
	for card in hand:
		var suit := BriscaRules.suit_of(card)
		if suit == rules.trump_suit:
			continue
		var count := 0
		for other in hand:
			if BriscaRules.suit_of(other) == suit:
				count += 1
		if count > best_count:
			best_count = count
			best_suit = suit
	if best_count >= 3:
		var best := ""
		for card in hand:
			if BriscaRules.suit_of(card) != best_suit:
				continue
			if best.is_empty() or BriscaRules.card_points(card) > BriscaRules.card_points(best):
				best = card
		if not best.is_empty():
			return best
	return _brisca_cheapest(rules, hand, true)


# La carta que menos pierde: menos puntos, luego menos fuerza; con save_trumps, los triunfos
# solo si no hay otra.
static func _brisca_cheapest(rules: BriscaRules, cards: Array, save_trumps: bool) -> String:
	var best := ""
	var best_cost := INF
	for card in cards:
		var cost: float = BriscaRules.card_points(card) * 100.0 + float(BriscaRules.STRENGTH[BriscaRules.rank_of(card)])
		if save_trumps and BriscaRules.suit_of(card) == rules.trump_suit:
			cost += 10000.0
		if cost < best_cost:
			best_cost = cost
			best = card
	return best
