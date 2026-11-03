class_name DominoRules
extends RefCounted

# Doble seis para dos jugadores: siete fichas, jugador 1 comienza con cualquier ficha.
const PLAYING := "playing"
const PLAYER_1_WINS := "player_1_wins"
const PLAYER_2_WINS := "player_2_wins"
const DRAW := "draw"

var values: Array[Vector2i] = []
var hands: Array = [[], []]
var stock: Array[int] = []
# Cada entrada contiene id y sus valores orientados de izquierda a derecha.
var chain: Array[Dictionary] = []
var turn := 0
var passes := 0
var result := PLAYING
var initial_hands: Array = [[], []]
var initial_stock: Array[int] = []
var events: Array[Dictionary] = []


func _init() -> void:
	for left in range(7):
		for right in range(left, 7):
			values.append(Vector2i(left, right))
	reset()


# Un valor negativo elige una semilla aleatoria; en pruebas se usa una fija.
func reset(seed_value: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var bag: Array[int] = []
	for id in range(28):
		bag.append(id)
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: int = bag[i]
		bag[i] = bag[j]
		bag[j] = temp
	hands = [[], []]
	for i in range(7):
		hands[0].append(bag.pop_back())
		hands[1].append(bag.pop_back())
	stock = bag
	initial_hands = hands.duplicate(true)
	initial_stock = stock.duplicate()
	events.clear()
	chain.clear()
	turn = 0
	passes = 0
	result = PLAYING


func legal_ends(id: int) -> Array[String]:
	var ends: Array[String] = []
	if result != PLAYING or id < 0 or id >= values.size() or id not in hands[turn]:
		return ends
	if chain.is_empty():
		ends.append("left")
		ends.append("right")
		return ends
	var tile: Vector2i = values[id]
	var left: int = chain.front()["left"]
	var right: int = chain.back()["right"]
	if tile.x == left or tile.y == left:
		ends.append("left")
	if tile.x == right or tile.y == right:
		ends.append("right")
	return ends


func has_play() -> bool:
	for id in hands[turn]:
		if not legal_ends(id).is_empty():
			return true
	return false


func play(id: int, end: String) -> bool:
	if end not in legal_ends(id):
		return false
	var tile: Vector2i = values[id]
	var oriented := {"id": id, "left": tile.x, "right": tile.y}
	if not chain.is_empty():
		if end == "left" and tile.x == int(chain.front()["left"]):
			oriented["left"] = tile.y
			oriented["right"] = tile.x
		elif end == "right" and tile.y == int(chain.back()["right"]):
			oriented["left"] = tile.y
			oriented["right"] = tile.x
	hands[turn].erase(id)
	events.append({"type": "play", "id": id, "end": end})
	if end == "left":
		chain.push_front(oriented)
	else:
		chain.push_back(oriented)
	passes = 0
	if hands[turn].is_empty():
		result = PLAYER_1_WINS if turn == 0 else PLAYER_2_WINS
	else:
		turn = 1 - turn
	return true


# Solo se roba cuando no hay jugadas; se mantiene el turno hasta poder jugar o agotar el pozo.
func draw() -> int:
	if result != PLAYING or stock.is_empty() or has_play():
		return -1
	var id: int = stock.pop_back()
	hands[turn].append(id)
	events.append({"type": "draw"})
	passes = 0
	return id


# Dos pases consecutivos con el pozo vacío cierran la partida por suma de puntos.
func pass_turn() -> bool:
	if result != PLAYING or not stock.is_empty() or has_play():
		return false
	passes += 1
	events.append({"type": "pass"})
	if passes >= 2:
		var first := hand_points(0)
		var second := hand_points(1)
		if first == second:
			result = DRAW
		else:
			result = PLAYER_1_WINS if first < second else PLAYER_2_WINS
	else:
		turn = 1 - turn
	return true


func hand_points(player: int) -> int:
	if player < 0 or player >= 2:
		return -1
	var total := 0
	for id in hands[player]:
		var tile: Vector2i = values[id]
		total += tile.x + tile.y
	return total


# Guarda el reparto real, no depende de que el generador aleatorio sea igual en otra versión.
func export_record() -> Dictionary:
	return {
		"game": "domino_double_six",
		"version": 1,
		"hands": initial_hands.duplicate(true),
		"stock": initial_stock.duplicate(),
		"events": events.duplicate(true)
	}


# Se reconstruye en un candidato temporal. Ningún archivo puede saltarse las reglas.
func import_record(data: Variant) -> bool:
	if not data is Dictionary or data.get("game") != "domino_double_six":
		return false
	if not _whole_number(data.get("version"), 1, 1):
		return false
	var saved_hands: Variant = data.get("hands")
	var saved_stock: Variant = data.get("stock")
	var saved_events: Variant = data.get("events")
	if not _valid_deal(saved_hands, saved_stock) or not saved_events is Array:
		return false
	if saved_events.size() > 128:
		return false
	var candidate := DominoRules.new()
	candidate.hands = [[], []]
	candidate.stock.clear()
	for player in range(2):
		for value in saved_hands[player]:
			candidate.hands[player].append(int(value))
	for value in saved_stock:
		candidate.stock.append(int(value))
	candidate.initial_hands = candidate.hands.duplicate(true)
	candidate.initial_stock = candidate.stock.duplicate()
	candidate.chain.clear()
	candidate.turn = 0
	candidate.passes = 0
	candidate.result = PLAYING
	candidate.events.clear()
	if not _replay_events(candidate, saved_events):
		return false
	hands = candidate.hands.duplicate(true)
	stock = candidate.stock.duplicate()
	chain = candidate.chain.duplicate(true)
	turn = candidate.turn
	passes = candidate.passes
	result = candidate.result
	initial_hands = candidate.initial_hands.duplicate(true)
	initial_stock = candidate.initial_stock.duplicate()
	events = candidate.events.duplicate(true)
	return true


func _valid_deal(saved_hands: Variant, saved_stock: Variant) -> bool:
	if not saved_hands is Array or saved_hands.size() != 2 or not saved_stock is Array:
		return false
	if not saved_hands[0] is Array or not saved_hands[1] is Array:
		return false
	if saved_hands[0].size() != 7 or saved_hands[1].size() != 7 or saved_stock.size() != 14:
		return false
	var ids := {}
	for group in [saved_hands[0], saved_hands[1], saved_stock]:
		for value in group:
			if not _whole_number(value, 0, 27) or ids.has(int(value)):
				return false
			ids[int(value)] = true
	return ids.size() == 28


func _replay_events(candidate: DominoRules, saved_events: Array) -> bool:
	for event in saved_events:
		if not _replay_event(candidate, event):
			return false
	return true


func _replay_event(candidate: DominoRules, event: Variant) -> bool:
	if not event is Dictionary or not event.get("type") is String:
		return false
	match event["type"]:
		"play":
			if not _whole_number(event.get("id"), 0, 27) or not event.get("end") is String:
				return false
			return candidate.play(int(event["id"]), event["end"])
		"draw":
			return candidate.draw() >= 0
		"pass":
			return candidate.pass_turn()
	return false


func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return (
		is_finite(number) and floorf(number) == number and number >= minimum and number <= maximum
	)
