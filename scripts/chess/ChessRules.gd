# gdlint: disable=max-returns
class_name ChessRules
extends RefCounted

# Casilla 0 = a8, 63 = h1; blancas positivas, negras negativas.
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const WHITE := 1
const BLACK := -1
const OPPONENT_LOCAL := 0
const OPPONENT_AI_CASUAL := 1
const OPPONENT_AI_TACTICAL := 2

var board: Array[int] = []
var turn: int = WHITE
var castling: Dictionary = {}
var en_passant: int = -1
var halfmove_clock: int = 0
var fullmove_number: int = 1
var history: Array[Dictionary] = []
var move_log: Array[Dictionary] = []
var repetition_counts: Dictionary = {}
var claimed_draw: String = ""
var claimed_move: Dictionary = {}
var opponent_mode := OPPONENT_LOCAL


func _init() -> void:
	reset()


func reset() -> void:
	board.resize(64)
	board.fill(0)
	var back: Array[int] = [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for x in range(8):
		board[x] = -back[x]
		board[8 + x] = -PAWN
		board[48 + x] = PAWN
		board[56 + x] = back[x]
	turn = WHITE
	castling = {"wk": true, "wq": true, "bk": true, "bq": true}
	en_passant = -1
	halfmove_clock = 0
	fullmove_number = 1
	history.clear()
	move_log.clear()
	claimed_draw = ""
	claimed_move.clear()
	opponent_mode = OPPONENT_LOCAL
	repetition_counts.clear()
	_record_position()


func piece_at(square: int) -> int:
	return board[square] if square >= 0 and square < 64 else 0


func legal_moves_from(square: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var piece: int = piece_at(square)
	if piece == 0 or _color(piece) != turn:
		return result
	for move in _pseudo_moves(square):
		var copy: Array[int] = board.duplicate()
		_apply_to_board(copy, move, QUEEN)
		if not _in_check(copy, turn):
			result.append(move)
	return result


func play(from_square: int, to_square: int, promotion: int = QUEEN) -> bool:
	if status() not in ["playing", "check"]:
		return false
	if promotion not in [QUEEN, ROOK, BISHOP, KNIGHT]:
		return false
	var move: Dictionary = {}
	for candidate in legal_moves_from(from_square):
		if int(candidate["to"]) == to_square:
			move = candidate
			break
	if move.is_empty():
		return false
	history.append(
		{
			"board": board.duplicate(),
			"turn": turn,
			"castling": castling.duplicate(),
			"en_passant": en_passant,
			"halfmove_clock": halfmove_clock,
			"fullmove_number": fullmove_number
		}
	)
	var piece: int = board[from_square]
	var captured: int = board[to_square]
	_update_castling(from_square, to_square, piece, captured)
	_apply_to_board(board, move, promotion)
	en_passant = -1
	if absi(piece) == PAWN and absi(to_square - from_square) == 16:
		en_passant = (from_square + to_square) / 2
	if absi(piece) == PAWN or captured != 0 or move.get("ep", false):
		halfmove_clock = 0
	else:
		halfmove_clock += 1
	if turn == BLACK:
		fullmove_number += 1
	move_log.append({"from": from_square, "to": to_square, "promotion": promotion})
	turn = -turn
	_record_position()
	return true


func undo() -> bool:
	if history.is_empty():
		return false
	var key: String = _position_key()
	repetition_counts[key] = int(repetition_counts.get(key, 0)) - 1
	var previous: Dictionary = history.pop_back()
	if not move_log.is_empty():
		move_log.pop_back()
	claimed_draw = ""
	claimed_move.clear()
	board = previous["board"]
	turn = previous["turn"]
	castling = previous["castling"]
	en_passant = previous["en_passant"]
	halfmove_clock = previous["halfmove_clock"]
	fullmove_number = previous["fullmove_number"]
	return true


# El guardado contiene solo jugadas validadas; el estado se reconstruye por replay.
func export_record() -> Dictionary:
	return {
		"version": 1,
		"moves": move_log.duplicate(true),
		"claimed_draw": claimed_draw,
		"claim_move": claimed_move.duplicate(true),
		"opponent_mode": opponent_mode
	}


func import_record(data: Variant) -> bool:
	if not data is Dictionary or not _whole_number(data.get("version"), 1, 1):
		return false
	var moves: Variant = data.get("moves")
	if not moves is Array or moves.size() > 1024:
		return false
	var candidate := ChessRules.new()
	for move in moves:
		if not _valid_record_move(move):
			return false
		if not candidate.play(int(move["from"]), int(move["to"]), int(move["promotion"])):
			return false
	var claim: Variant = data.get("claimed_draw", "")
	var claim_move: Variant = data.get("claim_move", {})
	var saved_opponent: Variant = data.get("opponent_mode", OPPONENT_LOCAL)
	if (
		not claim is String
		or not claim_move is Dictionary
		or not _whole_number(saved_opponent, OPPONENT_LOCAL, OPPONENT_AI_TACTICAL)
	):
		return false
	candidate.opponent_mode = int(saved_opponent)
	if claim == "":
		if not claim_move.is_empty():
			return false
	elif claim_move.is_empty():
		if not candidate.claim_draw() or candidate.claimed_draw != claim:
			return false
	elif (
		not _valid_record_move(claim_move)
		or not candidate.claim_draw(
			int(claim_move["from"]), int(claim_move["to"]), int(claim_move["promotion"])
		)
		or candidate.claimed_draw != claim
	):
		return false
	board = candidate.board.duplicate()
	turn = candidate.turn
	castling = candidate.castling.duplicate()
	en_passant = candidate.en_passant
	halfmove_clock = candidate.halfmove_clock
	fullmove_number = candidate.fullmove_number
	history = candidate.history.duplicate(true)
	move_log = candidate.move_log.duplicate(true)
	repetition_counts = candidate.repetition_counts.duplicate()
	claimed_draw = candidate.claimed_draw
	claimed_move = candidate.claimed_move.duplicate(true)
	opponent_mode = candidate.opponent_mode
	return true


func _valid_record_move(move: Variant) -> bool:
	return (
		move is Dictionary
		and _whole_number(move.get("from"), 0, 63)
		and _whole_number(move.get("to"), 0, 63)
		and _whole_number(move.get("promotion"), KNIGHT, QUEEN)
	)


func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return (
		is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum
	)


func status() -> String:
	if claimed_draw != "":
		return claimed_draw
	var checked: bool = _in_check(board, turn)
	var has_moves := false
	for square in range(64):
		if _color(board[square]) == turn and not legal_moves_from(square).is_empty():
			has_moves = true
			break
	if not has_moves:
		return "checkmate" if checked else "stalemate"
	if _insufficient_material():
		return "insufficient_material"
	if halfmove_clock >= 150:
		return "seventy_five_moves"
	if int(repetition_counts.get(_position_key(), 0)) >= 5:
		return "fivefold_repetition"
	return "check" if checked else "playing"


func can_claim_draw() -> bool:
	if status() not in ["playing", "check"]:
		return false
	return not _draw_claim_reason(halfmove_clock, repetition_counts, _position_key()).is_empty()


func claim_draw(from_square: int = -1, to_square: int = -1, promotion: int = QUEEN) -> bool:
	if status() not in ["playing", "check"]:
		return false
	var reason := ""
	if from_square < 0 and to_square < 0:
		reason = _draw_claim_reason(halfmove_clock, repetition_counts, _position_key())
	elif from_square >= 0 and to_square >= 0:
		reason = _announced_move_claim_reason(from_square, to_square, promotion)
	if reason.is_empty():
		return false
	claimed_draw = reason
	claimed_move = (
		{"from": from_square, "to": to_square, "promotion": promotion}
		if from_square >= 0 and to_square >= 0
		else {}
	)
	return true


func _announced_move_claim_reason(from_square: int, to_square: int, promotion: int) -> String:
	if promotion not in [QUEEN, ROOK, BISHOP, KNIGHT]:
		return ""
	var legal := false
	for move in legal_moves_from(from_square):
		if int(move["to"]) == to_square:
			legal = true
			break
	if not legal:
		return ""
	var candidate := ChessRules.new()
	candidate.board = board.duplicate()
	candidate.turn = turn
	candidate.castling = castling.duplicate()
	candidate.en_passant = en_passant
	candidate.halfmove_clock = halfmove_clock
	candidate.fullmove_number = fullmove_number
	candidate.repetition_counts = repetition_counts.duplicate()
	if not candidate.play(from_square, to_square, promotion):
		return ""
	return _draw_claim_reason(
		candidate.halfmove_clock, candidate.repetition_counts, candidate._position_key()
	)


func _draw_claim_reason(halfmove_count: int, counts: Dictionary, position_key: String) -> String:
	if halfmove_count >= 100:
		return "fifty_moves"
	if int(counts.get(position_key, 0)) >= 3:
		return "threefold_repetition"
	return ""


func _record_position() -> void:
	var key: String = _position_key()
	repetition_counts[key] = int(repetition_counts.get(key, 0)) + 1


func _position_key() -> String:
	var parts := PackedStringArray()
	for piece in board:
		parts.append(str(piece))
	parts.append(str(turn))
	for key in ["wk", "wq", "bk", "bq"]:
		parts.append("1" if castling.get(key, false) else "0")
	# El derecho al paso cuenta solo si existe realmente una captura legal.
	var legal_ep: int = -1
	if en_passant >= 0:
		for square in range(64):
			if board[square] == turn * PAWN:
				for move in legal_moves_from(square):
					if move.get("ep", false):
						legal_ep = en_passant
	parts.append(str(legal_ep))
	return ",".join(parts)


func _pseudo_moves(square: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var piece: int = board[square]
	var side: int = _color(piece)
	var x: int = square % 8
	var y: int = square / 8
	match absi(piece):
		PAWN:
			var dy: int = -side
			var forward: int = _index(x, y + dy)
			if forward >= 0 and board[forward] == 0:
				_add(moves, square, forward)
				var start_rank: int = 6 if side == WHITE else 1
				var double: int = _index(x, y + 2 * dy)
				if y == start_rank and board[double] == 0:
					_add(moves, square, double)
			for dx in [-1, 1]:
				var target: int = _index(x + dx, y + dy)
				if target < 0:
					continue
				if _color(board[target]) == -side and absi(board[target]) != KING:
					_add(moves, square, target)
				elif target == en_passant and board[target] == 0:
					var victim: int = _index(x + dx, y)
					if victim >= 0 and board[victim] == -side * PAWN:
						moves.append({"from": square, "to": target, "ep": true})
		KNIGHT:
			for delta in [
				Vector2i(1, 2),
				Vector2i(2, 1),
				Vector2i(-1, 2),
				Vector2i(-2, 1),
				Vector2i(1, -2),
				Vector2i(2, -1),
				Vector2i(-1, -2),
				Vector2i(-2, -1)
			]:
				_add_if_available(moves, square, x + delta.x, y + delta.y, side)
		KING:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx != 0 or dy != 0:
						_add_if_available(moves, square, x + dx, y + dy, side)
			_add_castles(moves, square, side)
		BISHOP, ROOK, QUEEN:
			var directions: Array[Vector2i] = []
			if absi(piece) in [BISHOP, QUEEN]:
				directions.append_array(
					[Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
				)
			if absi(piece) in [ROOK, QUEEN]:
				directions.append_array(
					[Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				)
			for direction in directions:
				var nx: int = x + direction.x
				var ny: int = y + direction.y
				while _index(nx, ny) >= 0:
					var target: int = _index(nx, ny)
					if board[target] == 0:
						_add(moves, square, target)
					else:
						if _color(board[target]) == -side and absi(board[target]) != KING:
							_add(moves, square, target)
						break
					nx += direction.x
					ny += direction.y
	return moves


func _add_castles(moves: Array[Dictionary], square: int, side: int) -> void:
	var home: int = 60 if side == WHITE else 4
	if square != home or _in_check(board, side):
		return
	var king_key: String = "wk" if side == WHITE else "bk"
	var queen_key: String = "wq" if side == WHITE else "bq"
	if castling.get(king_key, false) and board[home + 3] == side * ROOK:
		if board[home + 1] == 0 and board[home + 2] == 0:
			if not _attacked(board, home + 1, -side) and not _attacked(board, home + 2, -side):
				moves.append({"from": square, "to": home + 2, "castle": true})
	if castling.get(queen_key, false) and board[home - 4] == side * ROOK:
		if board[home - 1] == 0 and board[home - 2] == 0 and board[home - 3] == 0:
			if not _attacked(board, home - 1, -side) and not _attacked(board, home - 2, -side):
				moves.append({"from": square, "to": home - 2, "castle": true})


func _update_castling(from_square: int, to_square: int, piece: int, captured: int) -> void:
	if piece == KING:
		castling["wk"] = false
		castling["wq"] = false
	elif piece == -KING:
		castling["bk"] = false
		castling["bq"] = false
	for corner in [0, 7, 56, 63]:
		if (
			(from_square == corner and absi(piece) == ROOK)
			or (to_square == corner and absi(captured) == ROOK)
		):
			var key: String = {0: "bq", 7: "bk", 56: "wq", 63: "wk"}[corner]
			castling[key] = false


func _apply_to_board(target: Array[int], move: Dictionary, promotion: int) -> void:
	var from_square: int = move["from"]
	var to_square: int = move["to"]
	var piece: int = target[from_square]
	target[from_square] = 0
	if move.get("ep", false):
		target[to_square + 8 * _color(piece)] = 0
	if move.get("castle", false):
		var rook_from: int = from_square + 3 if to_square > from_square else from_square - 4
		var rook_to: int = from_square + 1 if to_square > from_square else from_square - 1
		target[rook_to] = target[rook_from]
		target[rook_from] = 0
	if absi(piece) == PAWN and (to_square / 8 == 0 or to_square / 8 == 7):
		piece = _color(piece) * promotion
	target[to_square] = piece


func _in_check(position: Array[int], side: int) -> bool:
	var king: int = position.find(side * KING)
	return king < 0 or _attacked(position, king, -side)


func _attacked(position: Array[int], square: int, attacker: int) -> bool:
	var x: int = square % 8
	var y: int = square / 8
	for dx in [-1, 1]:
		var pawn: int = _index(x + dx, y + attacker)
		if pawn >= 0 and position[pawn] == attacker * PAWN:
			return true
	for delta in [
		Vector2i(1, 2),
		Vector2i(2, 1),
		Vector2i(-1, 2),
		Vector2i(-2, 1),
		Vector2i(1, -2),
		Vector2i(2, -1),
		Vector2i(-1, -2),
		Vector2i(-2, -1)
	]:
		var knight: int = _index(x + delta.x, y + delta.y)
		if knight >= 0 and position[knight] == attacker * KNIGHT:
			return true
	for direction in [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(-1, -1)
	]:
		var nx: int = x + direction.x
		var ny: int = y + direction.y
		var distance: int = 1
		while _index(nx, ny) >= 0:
			var piece: int = position[_index(nx, ny)]
			if piece != 0:
				if _color(piece) == attacker:
					var kind: int = absi(piece)
					var diagonal: bool = direction.x != 0 and direction.y != 0
					if (
						kind == QUEEN
						or (diagonal and kind == BISHOP)
						or (not diagonal and kind == ROOK)
						or (distance == 1 and kind == KING)
					):
						return true
				break
			nx += direction.x
			ny += direction.y
			distance += 1
	return false


func _insufficient_material() -> bool:
	var minors: Array[int] = []
	for square in range(64):
		var kind: int = absi(board[square])
		if kind in [PAWN, ROOK, QUEEN]:
			return false
		if kind in [BISHOP, KNIGHT]:
			minors.append(square)
	if minors.size() <= 1:
		return true
	var square_color: int = (minors[0] % 8 + minors[0] / 8) % 2
	for square in minors:
		if absi(board[square]) != BISHOP or (square % 8 + square / 8) % 2 != square_color:
			return false
	return true


func _add_if_available(
	moves: Array[Dictionary], from_square: int, x: int, y: int, side: int
) -> void:
	var to_square: int = _index(x, y)
	if to_square >= 0 and _color(board[to_square]) != side and absi(board[to_square]) != KING:
		_add(moves, from_square, to_square)


func _add(moves: Array[Dictionary], from_square: int, to_square: int) -> void:
	moves.append({"from": from_square, "to": to_square})


func _index(x: int, y: int) -> int:
	return y * 8 + x if x >= 0 and x < 8 and y >= 0 and y < 8 else -1


func _color(piece: int) -> int:
	return 1 if piece > 0 else (-1 if piece < 0 else 0)
