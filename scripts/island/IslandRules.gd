# gdlint: disable=max-public-methods
class_name IslandRules
extends RefCounted

const SETUP_SETTLEMENT := "setup_settlement"
const SETUP_ROAD := "setup_road"
const ROLL := "roll"
const DISCARD := "discard"
const ROBBER := "robber"
const STEAL := "steal"
const ACTION := "action"
const FINISHED := "finished"
const FREE_ROADS := "free_roads"
const PLENTY := "plenty"
const MONOPOLY := "monopoly"
const TRADE_RESPONSE := "trade_response"
const DEV_NAMES := ["Caballero", "Punto", "Caminos", "Abundancia", "Monopolio"]
const KNIGHT := 0
const VICTORY_POINT := 1
const ROAD_BUILDING := 2
const YEAR_OF_PLENTY := 3
const MONOPOLY_CARD := 4
const DEV_COST := [0, 0, 1, 1, 1]
const ROAD_COST := [1, 1, 0, 0, 0]
const SETTLEMENT_COST := [1, 1, 1, 1, 0]
const CITY_COST := [0, 0, 0, 2, 3]

var board: IslandBoard
var initial_seed: int
var events: Array[Dictionary] = []
var players := 3
var turn := 0
var phase := SETUP_SETTLEMENT
var setup_order: Array[int] = []
var setup_index := 0
var last_setup_vertex := -1
var resources: Array = []
var bank: Array[int] = [19, 19, 19, 19, 19]
# -1 es vacío; niveles 0/1/2 representan vacío, pueblo y ciudad.
var building_owner: Array[int] = []
var building_level: Array[int] = []
var road_owner: Array[int] = []
var robber_tile := -1
var discard_due: Array[int] = []
var discard_player := -1
var eligible_victims: Array[int] = []
var last_dice := Vector2i.ZERO
var winner := -1
var development_deck: Array[int] = []
var dev_ready: Array = []
var dev_new: Array = []
var dev_played := false
var knights_played: Array[int] = []
var largest_army := -1
var longest_road := -1
var road_lengths: Array[int] = []
var resume_phase := ACTION
var free_roads_left := 0
var plenty_left := 0
var trade_offer: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1, player_count: int = 3) -> void:
	players = clampi(player_count, 3, 4)
	for player in range(players):
		setup_order.append(player)
	for player in range(players - 1, -1, -1):
		setup_order.append(player)
	discard_due.resize(players)
	discard_due.fill(0)
	knights_played.resize(players)
	knights_played.fill(0)
	road_lengths.resize(players)
	road_lengths.fill(0)
	if seed_value < 0:
		_rng.randomize()
		seed_value = _rng.randi_range(0, 2147483646)
	initial_seed = seed_value
	board = IslandBoard.new(seed_value)
	_rng.seed = seed_value + 173
	for kind in [KNIGHT, VICTORY_POINT, ROAD_BUILDING, YEAR_OF_PLENTY, MONOPOLY_CARD]:
		var count: int = [14, 5, 2, 2, 2][kind]
		for i in range(count):
			development_deck.append(kind)
	board._shuffle(development_deck, _rng)
	for i in range(players):
		resources.append([0, 0, 0, 0, 0])
		dev_ready.append([0, 0, 0, 0, 0])
		dev_new.append([0, 0, 0, 0, 0])
	building_owner.resize(board.vertices.size())
	building_owner.fill(-1)
	building_level.resize(board.vertices.size())
	building_level.fill(0)
	road_owner.resize(board.edges.size())
	road_owner.fill(-1)
	for i in range(board.tiles.size()):
		if board.tiles[i]["terrain"] == IslandBoard.DESERT:
			robber_tile = i


func can_settlement(vertex: int) -> bool:
	if phase not in [SETUP_SETTLEMENT, ACTION] or vertex < 0 or vertex >= building_owner.size():
		return false
	if building_owner[vertex] != -1 or _piece_count(turn, 1) >= 5 or not _clear_neighbors(vertex):
		return false
	if phase == SETUP_SETTLEMENT:
		return true
	if not _can_pay(turn, SETTLEMENT_COST):
		return false
	for edge_id in board.vertex_edges[vertex]:
		if road_owner[edge_id] == turn:
			return true
	return false


func _clear_neighbors(vertex: int) -> bool:
	for edge_id in board.vertex_edges[vertex]:
		var edge: Vector2i = board.edges[edge_id]
		var neighbor := edge.y if edge.x == vertex else edge.x
		if building_owner[neighbor] != -1:
			return false
	return true


func place_settlement(vertex: int) -> bool:
	if not can_settlement(vertex):
		return false
	if phase == ACTION:
		_pay(turn, SETTLEMENT_COST)
	building_owner[vertex] = turn
	building_level[vertex] = 1
	if phase == SETUP_SETTLEMENT:
		last_setup_vertex = vertex
		if setup_index >= players:
			_grant_setup_resources(vertex, turn)
		phase = SETUP_ROAD
	else:
		_update_longest_road()
		_check_winner()
	events.append({"type": "settlement", "id": vertex})
	return true


func can_road(edge_id: int) -> bool:
	if phase not in [SETUP_ROAD, ACTION, FREE_ROADS] or edge_id < 0 or edge_id >= road_owner.size():
		return false
	if road_owner[edge_id] != -1 or _road_count(turn) >= 15:
		return false
	var edge: Vector2i = board.edges[edge_id]
	if phase == SETUP_ROAD:
		return edge.x == last_setup_vertex or edge.y == last_setup_vertex
	return (phase == FREE_ROADS or _can_pay(turn, ROAD_COST)) and _road_connected(edge)


func _road_connected(edge: Vector2i) -> bool:
	for vertex in [edge.x, edge.y]:
		if building_owner[vertex] == turn:
			return true
		if building_owner[vertex] != -1:
			continue
		for adjacent in board.vertex_edges[vertex]:
			if road_owner[adjacent] == turn:
				return true
	return false


func place_road(edge_id: int) -> bool:
	if not can_road(edge_id):
		return false
	if phase == ACTION:
		_pay(turn, ROAD_COST)
	road_owner[edge_id] = turn
	if phase == SETUP_ROAD:
		setup_index += 1
		last_setup_vertex = -1
		if setup_index == setup_order.size():
			turn = 0
			phase = ROLL
		else:
			turn = setup_order[setup_index]
			phase = SETUP_SETTLEMENT
	_update_longest_road()
	if phase == FREE_ROADS:
		free_roads_left -= 1
		_check_winner()
		if phase == FINISHED:
			free_roads_left = 0
		elif free_roads_left == 0 or not _has_free_road():
			_finish_development()
	elif phase == ACTION:
		_check_winner()
	events.append({"type": "road", "id": edge_id})
	return true


func can_city(vertex: int) -> bool:
	return (
		phase == ACTION
		and vertex >= 0
		and vertex < building_owner.size()
		and building_owner[vertex] == turn
		and building_level[vertex] == 1
		and _piece_count(turn, 2) < 4
		and _can_pay(turn, CITY_COST)
	)


func upgrade_city(vertex: int) -> bool:
	if not can_city(vertex):
		return false
	_pay(turn, CITY_COST)
	building_level[vertex] = 2
	_check_winner()
	events.append({"type": "city", "id": vertex})
	return true


func roll(die_a: int, die_b: int) -> bool:
	if phase != ROLL or die_a < 1 or die_a > 6 or die_b < 1 or die_b > 6:
		return false
	last_dice = Vector2i(die_a, die_b)
	var total := die_a + die_b
	if total == 7:
		resume_phase = ACTION
		for player in range(players):
			var count := hand_size(player)
			discard_due[player] = count / 2 if count > 7 else 0
		_set_next_discard()
	else:
		_produce(total)
		phase = ACTION
	events.append({"type": "roll", "a": die_a, "b": die_b})
	return true


func discard(resource: int) -> bool:
	if (
		phase != DISCARD
		or resource < 0
		or resource >= 5
		or resources[discard_player][resource] <= 0
	):
		return false
	resources[discard_player][resource] -= 1
	bank[resource] += 1
	discard_due[discard_player] -= 1
	_set_next_discard()
	events.append({"type": "discard", "id": resource})
	return true


func _set_next_discard() -> void:
	for player in range(players):
		if discard_due[player] > 0:
			discard_player = player
			phase = DISCARD
			return
	discard_player = -1
	phase = ROBBER


func move_robber(tile_id: int) -> bool:
	if phase != ROBBER or tile_id < 0 or tile_id >= board.tiles.size() or tile_id == robber_tile:
		return false
	robber_tile = tile_id
	eligible_victims.clear()
	for vertex in board.tiles[tile_id]["vertices"]:
		var owner := building_owner[vertex]
		if owner >= 0 and owner != turn and owner not in eligible_victims and hand_size(owner) > 0:
			eligible_victims.append(owner)
	if not eligible_victims.is_empty():
		phase = STEAL
	else:
		_finish_development()
	events.append({"type": "robber", "id": tile_id})
	return true


func steal(player: int) -> bool:
	if phase != STEAL or player not in eligible_victims or hand_size(player) <= 0:
		return false
	var pick := _rng.randi_range(0, hand_size(player) - 1)
	for resource in range(5):
		if pick < resources[player][resource]:
			resources[player][resource] -= 1
			resources[turn][resource] += 1
			break
		pick -= resources[player][resource]
	eligible_victims.clear()
	_finish_development()
	events.append({"type": "steal", "id": player})
	return true


func trade_bank(give: int, take: int) -> bool:
	if phase != ACTION or give < 0 or give >= 5 or take < 0 or take >= 5 or give == take:
		return false
	var rate := bank_rate(turn, give)
	if resources[turn][give] < rate or bank[take] <= 0:
		return false
	resources[turn][give] -= rate
	bank[give] += rate
	resources[turn][take] += 1
	bank[take] -= 1
	events.append({"type": "bank", "give": give, "take": take})
	return true


func end_turn() -> bool:
	if phase != ACTION:
		return false
	for kind in range(5):
		dev_ready[turn][kind] += dev_new[turn][kind]
		dev_new[turn][kind] = 0
	turn = (turn + 1) % players
	dev_played = false
	last_dice = Vector2i.ZERO
	phase = ROLL
	_check_winner()
	events.append({"type": "end"})
	return true


func hand_size(player: int) -> int:
	var total := 0
	for count in resources[player]:
		total += int(count)
	return total


func score(player: int) -> int:
	var points := 0
	for i in range(building_owner.size()):
		if building_owner[i] == player:
			points += building_level[i]
	points += int(dev_ready[player][VICTORY_POINT]) + int(dev_new[player][VICTORY_POINT])
	if longest_road == player:
		points += 2
	if largest_army == player:
		points += 2
	return points


func _check_winner() -> void:
	if score(turn) >= 10:
		winner = turn
		phase = FINISHED


func _produce(number: int) -> void:
	var owed: Array = []
	for player in range(players):
		owed.append([0, 0, 0, 0, 0])
	for tile_id in range(board.tiles.size()):
		var tile: Dictionary = board.tiles[tile_id]
		var resource: int = tile["terrain"]
		if tile_id == robber_tile or resource == IslandBoard.DESERT or tile["number"] != number:
			continue
		for vertex in tile["vertices"]:
			var owner := building_owner[vertex]
			if owner >= 0:
				owed[owner][resource] += building_level[vertex]
	for resource in range(5):
		var total := 0
		for player in range(players):
			total += int(owed[player][resource])
		if total > bank[resource]:
			var recipients: Array[int] = []
			for player in range(players):
				if owed[player][resource] > 0:
					recipients.append(player)
			# Con un solo beneficiario recibe lo disponible; con varios, nadie.
			if recipients.size() == 1:
				resources[recipients[0]][resource] += bank[resource]
				bank[resource] = 0
			continue
		for player in range(players):
			resources[player][resource] += owed[player][resource]
		bank[resource] -= total


func _grant_setup_resources(vertex: int, player: int) -> void:
	for tile_id in board.vertex_tiles[vertex]:
		var resource: int = board.tiles[tile_id]["terrain"]
		if resource != IslandBoard.DESERT and bank[resource] > 0:
			resources[player][resource] += 1
			bank[resource] -= 1


func _can_pay(player: int, cost: Array) -> bool:
	for resource in range(5):
		if resources[player][resource] < cost[resource]:
			return false
	return true


func _pay(player: int, cost: Array) -> void:
	for resource in range(5):
		resources[player][resource] -= cost[resource]
		bank[resource] += cost[resource]


func _piece_count(player: int, level: int) -> int:
	var count := 0
	for i in range(building_owner.size()):
		if building_owner[i] == player and building_level[i] == level:
			count += 1
	return count


func _road_count(player: int) -> int:
	return road_owner.count(player)


func bank_rate(player: int, resource: int) -> int:
	if player < 0 or player >= players or resource < 0 or resource >= 5:
		return 4
	var rate := 4
	for port in board.ports:
		var edge: Vector2i = board.edges[port["edge"]]
		if building_owner[edge.x] != player and building_owner[edge.y] != player:
			continue
		if port["resource"] == resource:
			return 2
		if port["resource"] == -1:
			rate = 3
	return rate


func buy_development() -> bool:
	if phase != ACTION or development_deck.is_empty() or not _can_pay(turn, DEV_COST):
		return false
	_pay(turn, DEV_COST)
	var card: int = development_deck.pop_back()
	dev_new[turn][card] += 1
	_check_winner()
	events.append({"type": "buy"})
	return true


func play_development(card: int) -> bool:
	if (
		phase not in [ROLL, ACTION]
		or card not in [KNIGHT, ROAD_BUILDING, YEAR_OF_PLENTY, MONOPOLY_CARD]
	):
		return false
	if dev_played or dev_ready[turn][card] <= 0:
		return false
	if card == ROAD_BUILDING and not _can_start_free_roads():
		return false
	if card == YEAR_OF_PLENTY and _bank_total() == 0:
		return false
	dev_ready[turn][card] -= 1
	dev_played = true
	resume_phase = phase
	match card:
		KNIGHT:
			knights_played[turn] += 1
			largest_army = _award_holder(knights_played, largest_army, 3)
			phase = ROBBER
		ROAD_BUILDING:
			free_roads_left = 2
			phase = FREE_ROADS
		YEAR_OF_PLENTY:
			plenty_left = mini(2, _bank_total())
			phase = PLENTY
		MONOPOLY_CARD:
			phase = MONOPOLY
	events.append({"type": "play", "id": card})
	return true


func take_plenty(resource: int) -> bool:
	if phase != PLENTY or resource < 0 or resource >= 5 or bank[resource] <= 0:
		return false
	bank[resource] -= 1
	resources[turn][resource] += 1
	plenty_left -= 1
	if plenty_left <= 0 or _bank_total() == 0:
		_finish_development()
	events.append({"type": "plenty", "id": resource})
	return true


func choose_monopoly(resource: int) -> bool:
	if phase != MONOPOLY or resource < 0 or resource >= 5:
		return false
	for player in range(players):
		if player != turn:
			resources[turn][resource] += resources[player][resource]
			resources[player][resource] = 0
	_finish_development()
	events.append({"type": "monopoly", "id": resource})
	return true


func _finish_development() -> void:
	phase = resume_phase
	_check_winner()


func _bank_total() -> int:
	var total := 0
	for amount in bank:
		total += amount
	return total


func _can_start_free_roads() -> bool:
	var old := phase
	phase = FREE_ROADS
	var possible := _has_free_road()
	phase = old
	return possible


func _has_free_road() -> bool:
	for edge in range(road_owner.size()):
		if can_road(edge):
			return true
	return false


func propose_trade(other: int, offered: Array, requested: Array) -> bool:
	if phase != ACTION or other < 0 or other >= players or other == turn:
		return false
	if not _valid_trade_amounts(offered, requested):
		return false
	if not _can_pay(turn, offered):
		return false
	trade_offer = {
		"from": turn, "to": other, "give": offered.duplicate(), "take": requested.duplicate()
	}
	phase = TRADE_RESPONSE
	events.append(
		{
			"type": "offer",
			"other": other,
			"give": offered.duplicate(),
			"take": requested.duplicate()
		}
	)
	return true


func _valid_trade_amounts(offered: Array, requested: Array) -> bool:
	if offered.size() != 5 or requested.size() != 5:
		return false
	var sum_offered := 0
	var sum_requested := 0
	for i in range(5):
		if typeof(offered[i]) != TYPE_INT or typeof(requested[i]) != TYPE_INT:
			return false
		if offered[i] < 0 or requested[i] < 0 or offered[i] > 19 or requested[i] > 19:
			return false
		if offered[i] > 0 and requested[i] > 0:
			return false
		sum_offered += offered[i]
		sum_requested += requested[i]
	return sum_offered > 0 and sum_requested > 0


func respond_trade(player: int, accept: bool) -> bool:
	if phase != TRADE_RESPONSE or trade_offer.get("to", -1) != player:
		return false
	var offered: Array = trade_offer["give"]
	var requested: Array = trade_offer["take"]
	if accept:
		if not _can_pay(turn, offered) or not _can_pay(player, requested):
			return false
		for resource in range(5):
			resources[turn][resource] += requested[resource] - offered[resource]
			resources[player][resource] += offered[resource] - requested[resource]
	trade_offer.clear()
	phase = ACTION
	events.append({"type": "respond", "player": player, "accept": accept})
	return true


func _update_longest_road() -> void:
	for player in range(players):
		road_lengths[player] = _longest_for(player)
	longest_road = _award_holder(road_lengths, longest_road, 5)


func _longest_for(player: int) -> int:
	var best := 0
	for vertex in range(board.vertices.size()):
		best = maxi(best, _road_walk(player, vertex, {}, false))
	return best


func _road_walk(player: int, vertex: int, used: Dictionary, arrived: bool) -> int:
	if arrived and building_owner[vertex] != -1 and building_owner[vertex] != player:
		return 0
	var best := 0
	for edge_id in board.vertex_edges[vertex]:
		if road_owner[edge_id] != player or used.has(edge_id):
			continue
		used[edge_id] = true
		var edge: Vector2i = board.edges[edge_id]
		var next := edge.y if edge.x == vertex else edge.x
		best = maxi(best, 1 + _road_walk(player, next, used, true))
		used.erase(edge_id)
	return best


func _award_holder(values: Array[int], holder: int, minimum: int) -> int:
	var best := minimum - 1
	for value in values:
		best = maxi(best, value)
	if best < minimum:
		return -1
	var tied: Array[int] = []
	for player in range(players):
		if values[player] == best:
			tied.append(player)
	if holder in tied:
		return holder
	return tied[0] if tied.size() == 1 else -1


func export_record() -> Dictionary:
	return {
		"game": "island_resources",
		"version": 1,
		"seed": initial_seed,
		"players": players,
		"events": events.duplicate(true)
	}


static func from_record(data: Variant) -> IslandRules:
	if not data is Dictionary or data.get("game") != "island_resources":
		return null
	if (
		not _valid_integer(data.get("version"), 1, 1)
		or not _valid_integer(data.get("seed"), 0, 2147483646)
	):
		return null
	var saved: Variant = data.get("events")
	if not saved is Array or saved.size() > 10000:
		return null
	var player_count: Variant = data.get("players", 3)
	if not _valid_integer(player_count, 3, 4):
		return null
	var game := IslandRules.new(int(data["seed"]), int(player_count))
	for event in saved:
		if not _apply_saved_event(game, event):
			return null
	return game


static func _apply_saved_event(game: IslandRules, event: Variant) -> bool:
	if not event is Dictionary or not event.get("type") is String:
		return false
	var kind: String = event["type"]
	if (
		kind
		in [
			"settlement", "road", "city", "discard", "robber", "steal", "play", "plenty", "monopoly"
		]
	):
		if not _valid_integer(event.get("id"), 0, 71):
			return false
		var id := int(event["id"])
		match kind:
			"settlement":
				return game.place_settlement(id)
			"road":
				return game.place_road(id)
			"city":
				return game.upgrade_city(id)
			"discard":
				return game.discard(id)
			"robber":
				return game.move_robber(id)
			"steal":
				return game.steal(id)
			"play":
				return game.play_development(id)
			"plenty":
				return game.take_plenty(id)
			"monopoly":
				return game.choose_monopoly(id)
	match kind:
		"roll":
			if not _valid_integer(event.get("a"), 1, 6) or not _valid_integer(event.get("b"), 1, 6):
				return false
			return game.roll(int(event["a"]), int(event["b"]))
		"bank":
			if (
				not _valid_integer(event.get("give"), 0, 4)
				or not _valid_integer(event.get("take"), 0, 4)
			):
				return false
			return game.trade_bank(int(event["give"]), int(event["take"]))
		"offer":
			if not _valid_integer(event.get("other"), 0, game.players - 1):
				return false
			var give := _saved_amounts(event.get("give"))
			var take := _saved_amounts(event.get("take"))
			if give.is_empty() or take.is_empty():
				return false
			return game.propose_trade(int(event["other"]), give, take)
		"respond":
			if (
				not _valid_integer(event.get("player"), 0, game.players - 1)
				or typeof(event.get("accept")) != TYPE_BOOL
			):
				return false
			return game.respond_trade(int(event["player"]), event["accept"])
		"end":
			return game.end_turn()
		"buy":
			return game.buy_development()
	return false


static func _saved_amounts(value: Variant) -> Array:
	if not value is Array or value.size() != 5:
		return []
	var result := []
	for amount in value:
		if not _valid_integer(amount, 0, 19):
			return []
		result.append(int(amount))
	return result


static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return (
		is_finite(number) and floorf(number) == number and number >= minimum and number <= maximum
	)
