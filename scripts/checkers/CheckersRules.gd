class_name CheckersRules
extends RefCounted

## Variante adaptada de damas inglesas: casillas oscuras; blancas empiezan.
## Positivo: blancas. Negativo: negras. 1: ficha; 2: dama.
const WHITE := 1
const BLACK := -1
const MAN := 1
const KING := 2

var board: Array[int] = []
var turn: int = WHITE
# Durante una captura múltiple solo puede mover la ficha que comenzó la secuencia.
var forced_from: int = -1
var history: Array[Dictionary] = []
var move_log: Array[Dictionary] = []


func _init() -> void:
	reset()


func reset() -> void:
	board.resize(64)
	board.fill(0)
	for y in range(8):
		for x in range(8):
			if (x + y) % 2 == 1:
				if y < 3:
					board[y * 8 + x] = BLACK * MAN
				elif y > 4:
					board[y * 8 + x] = WHITE * MAN
	turn = WHITE
	forced_from = -1
	history.clear()
	move_log.clear()


func piece_at(square: int) -> int:
	return board[square] if square >= 0 and square < 64 else 0


# Cada movimiento es un solo salto o paso; la UI debe continuar una cadena obligatoria.
func legal_moves_from(square: int) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	var piece: int = piece_at(square)
	if piece == 0 or _color(piece) != turn:
		return empty
	if forced_from >= 0:
		return _captures_from(square) if square == forced_from else empty
	if has_any_capture():
		return _captures_from(square)
	return _steps_from(square)


func play(from_square: int, to_square: int) -> bool:
	var move: Dictionary = {}
	for candidate in legal_moves_from(from_square):
		if int(candidate["to"]) == to_square:
			move = candidate
			break
	if move.is_empty():
		return false
	history.append({"board": board.duplicate(), "turn": turn, "forced_from": forced_from})
	var piece: int = board[from_square]
	board[from_square] = 0
	board[to_square] = piece
	var captured: int = int(move.get("captured", -1))
	if captured >= 0:
		board[captured] = 0
	var rank: int = to_square / 8
	var promoted: bool = absi(piece) == MAN and (rank == 0 or rank == 7)
	if promoted:
		board[to_square] = turn * KING
	move_log.append({"from": from_square, "to": to_square})
	# En damas inglesas, coronar durante un salto termina el turno inmediatamente.
	if captured >= 0 and not promoted and not _captures_from(to_square).is_empty():
		forced_from = to_square
	else:
		forced_from = -1
		turn = -turn
	return true


# Revierte un paso o salto individual, incluso durante una captura múltiple.
func undo() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	board = previous["board"]
	turn = previous["turn"]
	forced_from = previous["forced_from"]
	if not move_log.is_empty():
		move_log.pop_back()
	return true


# Gana el contrario cuando el jugador del turno no tiene piezas o movimientos.
func status() -> String:
	for square in range(64):
		if _color(board[square]) == turn and not legal_moves_from(square).is_empty():
			return "playing"
	return "black_wins" if turn == WHITE else "white_wins"


func export_record() -> Dictionary:
	return {"game": "english_checkers", "version": 1, "moves": move_log.duplicate(true)}


# Reconstrucción en un estado temporal: un archivo inválido no cambia la partida actual.
func import_record(data: Variant) -> bool:
	if not data is Dictionary or data.get("game") != "english_checkers":
		return false
	if not _whole_number(data.get("version"), 1, 1):
		return false
	var moves: Variant = data.get("moves")
	if not moves is Array or moves.size() > 1024:
		return false
	var candidate := CheckersRules.new()
	for move in moves:
		if not _valid_record_move(move):
			return false
		if not candidate.play(int(move["from"]), int(move["to"])):
			return false
	board = candidate.board.duplicate()
	turn = candidate.turn
	forced_from = candidate.forced_from
	history = candidate.history.duplicate(true)
	move_log = candidate.move_log.duplicate(true)
	return true


func _valid_record_move(move: Variant) -> bool:
	return (
		move is Dictionary
		and _whole_number(move.get("from"), 0, 63)
		and _whole_number(move.get("to"), 0, 63)
	)


func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return (
		is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
	)


func has_any_capture() -> bool:
	for square in range(64):
		if _color(board[square]) == turn and not _captures_from(square).is_empty():
			return true
	return false


func _captures_from(square: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece: int = piece_at(square)
	if piece == 0:
		return moves
	var x: int = square % 8
	var y: int = square / 8
	for dy in _directions(piece):
		for dx in [-1, 1]:
			var middle: int = _index(x + dx, y + dy)
			var target: int = _index(x + dx * 2, y + dy * 2)
			if middle >= 0 and target >= 0:
				if _color(board[middle]) == -_color(piece) and board[target] == 0:
					moves.append({"from": square, "to": target, "captured": middle})
	return moves


func _steps_from(square: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece: int = piece_at(square)
	if piece == 0:
		return moves
	var x: int = square % 8
	var y: int = square / 8
	for dy in _directions(piece):
		for dx in [-1, 1]:
			var target: int = _index(x + dx, y + dy)
			if target >= 0 and board[target] == 0:
				moves.append({"from": square, "to": target})
	return moves


func _directions(piece: int) -> Array[int]:
	if absi(piece) == KING:
		return [-1, 1]
	return [-_color(piece)]


func _index(x: int, y: int) -> int:
	return y * 8 + x if x >= 0 and x < 8 and y >= 0 and y < 8 else -1


func _color(piece: int) -> int:
	return 1 if piece > 0 else (-1 if piece < 0 else 0)
