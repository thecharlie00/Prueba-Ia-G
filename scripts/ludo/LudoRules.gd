class_name LudoRules
extends RefCounted

## Ludo local (52 casillas) y, con variant = PARCHIS, el parchís español clásico de 68 casillas:
## - tablero tradicional numerado del 1 al 68 (salidas en 5, 22, 39 y 56; 12 seguros, pasillo
##   de 7 casillas de color y meta central);
## - se sale de casa con un 5 (obligatorio si se puede) y, al salir, se come al rival que esté
##   en la casilla de salida aunque sea seguro;
## - dos fichas en una casilla forman una barrera que nadie puede pasar; en los seguros pueden
##   estar dos fichas de jugadores distintos;
## - comer da 20 casillas de premio y llegar a meta 10, con una ficha cualquiera;
## - con un 6 se vuelve a tirar; sin fichas en casa el 6 cuenta 7;
## - el tercer 6 seguido devuelve a casa la última ficha movida (si no está en el pasillo).
const ROLL := "roll"
const MOVE := "move"
const FINISHED := "finished"
const YARD := -1
const FINISH := 57
const SAFE := [0, 8, 13, 21, 26, 34, 39, 47]
const MAX_EVENTS := 10000
const LUDO := "ludo"
const PARCHIS := "parchis"
const PARCHIS_TRACK := 68
const PARCHIS_CORRIDOR := 64
const PARCHIS_FINISH := 71
## Casillas seguras clásicas del parchís español (0-indexadas: casillas 5, 12, 17, 22, 29, 34,
## 39, 46, 51, 56, 63 y 68).
const PARCHIS_SAFE := [4, 11, 16, 21, 28, 33, 38, 45, 50, 55, 62, 67]
const PARCHIS_EXIT := 5
const CAPTURE_BONUS := 20
const HOME_BONUS := 10

var variant := LUDO
var players := 2
var turn := 0
var phase := ROLL
var die := 0
var winner := -1
var positions: Array = []
var events: Array[Dictionary] = []
## Parchís: premio pendiente (20 o 10 casillas) que se mueve antes de pasar el turno.
var bonus := 0
## Parchís: seises seguidos en este turno y última ficha movida (para el castigo del tercero).
var sixes := 0
var last_moved := -1


func _init(player_count: int = 2, variant_name: String = LUDO) -> void:
	players = clampi(player_count, 2, 4)
	variant = PARCHIS if variant_name == PARCHIS else LUDO
	for player in range(players):
		positions.append([YARD, YARD, YARD, YARD])


static func track_square(player: int, progress: int) -> int:
	return (player * 13 + progress) % 52


func is_parchis() -> bool:
	return variant == PARCHIS


func track_length() -> int:
	return PARCHIS_TRACK if is_parchis() else 52


func corridor_start() -> int:
	return PARCHIS_CORRIDOR if is_parchis() else 52


func finish_progress() -> int:
	return PARCHIS_FINISH if is_parchis() else FINISH


func player_house(player: int) -> int:
	if is_parchis() and players == 2:
		return 0 if player == 0 else 2
	return player


func player_square(player: int, progress: int) -> int:
	if is_parchis():
		return (4 + player_house(player) * 17 + progress) % PARCHIS_TRACK
	return track_square(player, progress)


func is_safe_square(square: int) -> bool:
	return square in (PARCHIS_SAFE if is_parchis() else SAFE)


## Casillas que avanza la ficha ahora: el premio pendiente o el dado (en parchís, el 6 vale 7
## si no queda ninguna ficha en casa).
func steps() -> int:
	if bonus > 0:
		return bonus
	if is_parchis() and die == 6 and not YARD in positions[turn]:
		return 7
	return die


func destination(token: int) -> int:
	if phase != MOVE or token < 0 or token >= 4:
		return -2
	if is_parchis():
		return _parchis_destination(token)
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


## Fichas en una casilla del recorrido común (sin contar la que se mueve).
func tokens_on(square: int, skip_player := -1, skip_token := -1) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var lane_start := corridor_start()
	for player in range(players):
		for other in range(4):
			if player == skip_player and other == skip_token:
				continue
			var progress: int = positions[player][other]
			if progress >= 0 and progress < lane_start and player_square(player, progress) == square:
				found.append(Vector2i(player, other))
	return found


func _parchis_destination(token: int) -> int:
	var current: int = positions[turn][token]
	if current == PARCHIS_FINISH:
		return -2
	if current == YARD:
		if bonus > 0 or die != PARCHIS_EXIT:
			return -2
		var exit := tokens_on(player_square(turn, 0), turn, token)
		var own := exit.filter(func(item: Vector2i) -> bool: return item.x == turn).size()
		# Dos fichas propias en la salida la cierran; un rival se come al salir.
		if own >= 2:
			return -2
		return 0
	var dest := current + steps()
	if dest > PARCHIS_FINISH:
		return -2
	# Barreras: ninguna casilla del camino (ni la de llegada) puede tener ya dos fichas.
	for progress in range(current + 1, dest + 1):
		if progress < PARCHIS_CORRIDOR:
			if tokens_on(player_square(turn, progress), turn, token).size() >= 2:
				return -2
		elif progress < PARCHIS_FINISH:
			var own_lane := 0
			for other in range(4):
				if other != token and positions[turn][other] == progress:
					own_lane += 1
			if own_lane >= 2:
				return -2
	return dest


func legal_tokens() -> Array[int]:
	var legal: Array[int] = []
	for token in range(4):
		if destination(token) >= 0:
			legal.append(token)
	# Parchís: con un 5 hay que sacar ficha si se puede.
	if is_parchis() and bonus == 0 and die == PARCHIS_EXIT:
		var exits := legal.filter(func(token: int) -> bool: return positions[turn][token] == YARD)
		if not exits.is_empty():
			legal.assign(exits)
	return legal


func apply_roll(value: int) -> bool:
	if phase != ROLL or value < 1 or value > 6:
		return false
	die = value
	phase = MOVE
	events.append({"type": "roll", "value": value})
	if is_parchis() and value == 6:
		sixes += 1
		if sixes >= 3:
			# Tercer 6 seguido: la última ficha movida vuelve a casa y pasa el turno.
			if last_moved >= 0:
				var progress: int = positions[turn][last_moved]
				if progress >= 0 and progress < PARCHIS_CORRIDOR:
					positions[turn][last_moved] = YARD
			die = 0
			_pass_turn()
			return true
	if legal_tokens().is_empty():
		_next_turn()
	return true


func move(token: int) -> bool:
	var dest := destination(token)
	if dest < 0 or token not in legal_tokens():
		return false
	if is_parchis():
		return _parchis_move(token, dest)
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


func _parchis_move(token: int, dest: int) -> bool:
	var exiting: bool = positions[turn][token] == YARD
	var gained := 0
	if dest < PARCHIS_CORRIDOR:
		var square := player_square(turn, dest)
		if exiting or not is_safe_square(square):
			for item in tokens_on(square, turn, token):
				if item.x != turn:
					positions[item.x][item.y] = YARD
					gained = CAPTURE_BONUS
					break
	positions[turn][token] = dest
	last_moved = token
	events.append({"type": "move", "token": token})
	if dest == PARCHIS_FINISH:
		gained = HOME_BONUS
	if positions[turn].count(PARCHIS_FINISH) == 4:
		winner = turn
		phase = FINISHED
		bonus = 0
		return true
	bonus = gained
	if bonus > 0 and not legal_tokens().is_empty():
		return true  # Sigue en MOVE: toca mover el premio.
	bonus = 0
	_next_turn()
	return true


func _next_turn() -> void:
	if die != 6:
		_pass_turn()
		return
	die = 0
	bonus = 0
	phase = ROLL


func _pass_turn() -> void:
	turn = (turn + 1) % players
	die = 0
	bonus = 0
	sixes = 0
	last_moved = -1
	phase = ROLL


func export_record() -> Dictionary:
	var record := {
		"game": "ludo_local", "version": 1, "players": players, "events": events.duplicate(true)
	}
	if is_parchis():
		record["version"] = 2
		record["variant"] = PARCHIS
	return record


static func from_record(data: Variant) -> LudoRules:
	if not data is Dictionary or data.get("game") != "ludo_local":
		return null
	if not _integer(data.get("version"), 1, 2):
		return null
	var variant_name := LUDO
	if int(data["version"]) == 2:
		if data.get("variant") != PARCHIS:
			return null
		variant_name = PARCHIS
	if not _integer(data.get("players"), 2, 4):
		return null
	var list: Variant = data.get("events")
	if not list is Array or list.size() > MAX_EVENTS:
		return null
	var result := LudoRules.new(int(data["players"]), variant_name)
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
