class_name LudoRules
extends RefCounted

# Variante local concreta, no pretende reproducir todas las reglas de parchís.
const ROLL := "roll"
const MOVE := "move"
const FINISHED := "finished"
const YARD := -1
const FINISH := 57
const SAFE := [0, 8, 13, 21, 26, 34, 39, 47]
const MAX_EVENTS := 10000

var players := 2
var turn := 0
var phase := ROLL
var die := 0
var winner := -1
var positions: Array = []
var events: Array[Dictionary] = []


func _init(player_count: int = 2) -> void:
	players = clampi(player_count, 2, 4)
	for player in range(players):
		positions.append([YARD, YARD, YARD, YARD])


static func track_square(player: int, progress: int) -> int:
	return (player * 13 + progress) % 52


func destination(token: int) -> int:
	if phase != MOVE or token < 0 or token >= 4:
		return -2
	var current: int = positions[turn][token]
	var dest := 0 if current == YARD and die == 6 else current + die
	if current == FINISH or (current == YARD and die != 6) or dest > FINISH:
		return -2
	if dest >= 52:
		if dest < FINISH:
			for other in range(4):
				if other != token and positions[turn][other] == dest:
					return -2
		return dest
	var square := track_square(turn, dest)
	for player in range(players):
		for other in range(4):
			var progress: int = positions[player][other]
			if player == turn and other == token:
				continue
			if progress >= 0 and progress < 52 and track_square(player, progress) == square:
				if player == turn or square in SAFE:
					return -2
	return dest


func legal_tokens() -> Array[int]:
	var legal: Array[int] = []
	for token in range(4):
		if destination(token) >= 0:
			legal.append(token)
	return legal


func apply_roll(value: int) -> bool:
	if phase != ROLL or value < 1 or value > 6:
		return false
	die = value
	phase = MOVE
	events.append({"type": "roll", "value": value})
	if legal_tokens().is_empty():
		_next_turn()
	return true


func move(token: int) -> bool:
	var dest := destination(token)
	if dest < 0:
		return false
	if dest < 52:
		var square := track_square(turn, dest)
		if square not in SAFE:
			for player in range(players):
				if player == turn:
					continue
				for other in range(4):
					var progress: int = positions[player][other]
					if progress >= 0 and progress < 52 and track_square(player, progress) == square:
						positions[player][other] = YARD
	positions[turn][token] = dest
	events.append({"type": "move", "token": token})
	if positions[turn].count(FINISH) == 4:
		winner = turn
		phase = FINISHED
	else:
		_next_turn()
	return true


func _next_turn() -> void:
	if die != 6:
		turn = (turn + 1) % players
	die = 0
	phase = ROLL


func export_record() -> Dictionary:
	return {
		"game": "ludo_local", "version": 1, "players": players, "events": events.duplicate(true)
	}


static func from_record(data: Variant) -> LudoRules:
	if not data is Dictionary or data.get("game") != "ludo_local":
		return null
	if not _integer(data.get("version"), 1, 1):
		return null
	if not _integer(data.get("players"), 2, 4):
		return null
	var list: Variant = data.get("events")
	if not list is Array or list.size() > MAX_EVENTS:
		return null
	var result := LudoRules.new(int(data["players"]))
	for event in list:
		if not event is Dictionary:
			return null
		if event.get("type") == "roll" and _integer(event.get("value"), 1, 6):
			if not result.apply_roll(int(event["value"])):
				return null
		elif event.get("type") == "move" and _integer(event.get("token"), 0, 3):
			if not result.move(int(event["token"])):
				return null
		else:
			return null
	return result


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT)
		and is_finite(float(value))
		and float(value) == floorf(float(value))
		and value >= minimum
		and value <= maximum
	)
