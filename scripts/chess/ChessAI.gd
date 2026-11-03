extends RefCounted

const MATERIAL_VALUES := {
	ChessRules.PAWN: 100,
	ChessRules.KNIGHT: 320,
	ChessRules.BISHOP: 330,
	ChessRules.ROOK: 500,
	ChessRules.QUEEN: 900,
	ChessRules.KING: 0
}
const MATE_SCORE := 100000


static func choose_move(
	game: ChessRules, opponent_mode: int, random: RandomNumberGenerator
) -> Dictionary:
	var moves := _legal_moves(game)
	if moves.is_empty():
		return {}
	if opponent_mode == ChessRules.OPPONENT_AI_CASUAL:
		return moves[random.randi_range(0, moves.size() - 1)]
	if opponent_mode != ChessRules.OPPONENT_AI_TACTICAL:
		return {}

	var ai_side: int = game.turn
	var best_score := -INF
	var best_moves: Array[Dictionary] = []
	for move in moves:
		if not game.play(int(move["from"]), int(move["to"])):
			continue
		var score := _search(game, 1, ai_side, -INF, INF, 1)
		_undo_search_move(game)
		if score > best_score:
			best_score = score
			best_moves.clear()
			best_moves.append(move)
		elif is_equal_approx(score, best_score):
			best_moves.append(move)
	if best_moves.is_empty():
		return {}
	return best_moves[random.randi_range(0, best_moves.size() - 1)]


static func _search(
	game: ChessRules, depth: int, ai_side: int, alpha: float, beta: float, ply: int
) -> float:
	var moves := _legal_moves(game)
	if moves.is_empty():
		if game._in_check(game.board, game.turn):
			return -MATE_SCORE + ply if game.turn == ai_side else MATE_SCORE - ply
		return 0.0
	if (
		game.halfmove_clock >= 150
		or int(game.repetition_counts.get(game._position_key(), 0)) >= 5
		or game._insufficient_material()
	):
		return 0.0
	if depth <= 0:
		return _evaluate(game, ai_side)

	var maximizing: bool = game.turn == ai_side
	var best_score: float = -INF if maximizing else INF
	for move in moves:
		if not game.play(int(move["from"]), int(move["to"])):
			continue
		var score := _search(game, depth - 1, ai_side, alpha, beta, ply + 1)
		_undo_search_move(game)
		if maximizing:
			best_score = maxf(best_score, score)
			alpha = maxf(alpha, best_score)
		else:
			best_score = minf(best_score, score)
			beta = minf(beta, best_score)
		if beta <= alpha:
			break
	return best_score


static func _evaluate(game: ChessRules, perspective: int) -> float:
	var score := 0.0
	for square in range(64):
		var piece: int = game.piece_at(square)
		if piece == 0:
			continue
		var side := 1 if piece > 0 else -1
		var kind: int = absi(piece)
		score += side * float(MATERIAL_VALUES[kind])
		if kind in [ChessRules.PAWN, ChessRules.KNIGHT, ChessRules.BISHOP]:
			var file_distance: float = absf(float(square % 8) - 3.5)
			var rank_distance: float = absf(float(square / 8) - 3.5)
			score += side * maxf(0.0, 3.5 - file_distance) * 2.0
			score += side * maxf(0.0, 3.5 - rank_distance) * 2.0
	if game._in_check(game.board, ChessRules.WHITE):
		score -= 25.0
	if game._in_check(game.board, ChessRules.BLACK):
		score += 25.0
	return score * perspective


static func _legal_moves(game: ChessRules) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for square in range(64):
		result.append_array(game.legal_moves_from(square))
	return result


static func _undo_search_move(game: ChessRules) -> void:
	var position_key: String = game._position_key()
	game.undo()
	if int(game.repetition_counts.get(position_key, 0)) == 0:
		game.repetition_counts.erase(position_key)
