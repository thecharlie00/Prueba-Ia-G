class_name GuidedPhysicalChess
extends PhysicalChess

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const MAX_SAVE_BYTES := 262144
const SPRING := 28.0
const DAMPING := 9.0
const MAX_ACCELERATION := 20.0

@export var save_path := "user://diceon_chess.json"

var rules := ChessRules.new()
var piece_squares: Dictionary = {}
var initial_squares: Dictionary = {}
var homes: Dictionary = {}
# Índices 0 y 1: blancas y negras capturadas.
var capture_counts: Array[int] = [0, 0]
var _snapshots: Array[Dictionary] = []
var _dragged: PhysicalChessPiece
var _drag_from := -1
var _destinations: Array[int] = []
var _claim_mode := false
var _ai_thinking := false
var _ai_failed := false
var _ai_request_id := 0
var _random := RandomNumberGenerator.new()
var _squares: Array[MeshInstance3D] = []
var _light: Material
var _dark: Material
var _selected: Material
var _legal: Material


func _ready() -> void:
	super._ready()
	_light = BoardGeometry3D.make_material(Color("dfd1ad"))
	_dark = BoardGeometry3D.make_material(Color("405f50"))
	_selected = BoardGeometry3D.make_material(Color("d8af5d"))
	_legal = BoardGeometry3D.make_material(Color("80bc8e"))
	for node in $Board/Tiles.get_children():
		if node is MeshInstance3D and _squares.size() < 64:
			_squares.append(node)
	for child in objects.get_children():
		var piece := child as PhysicalChessPiece
		if piece == null:
			continue
		var square := _square_from_position(piece.global_position)
		piece_squares[piece] = square
		homes[piece] = _square_center(square)
	initial_squares = piece_squares.duplicate()
	var promotion: OptionButton = $UI/Panel/Margin/Content/Promotion
	promotion.add_item("Dama", ChessRules.QUEEN)
	promotion.add_item("Torre", ChessRules.ROOK)
	promotion.add_item("Alfil", ChessRules.BISHOP)
	promotion.add_item("Caballo", ChessRules.KNIGHT)
	var opponent: OptionButton = $UI/Panel/Margin/Content/Opponent
	opponent.add_item("Dos personas", ChessRules.OPPONENT_LOCAL)
	opponent.add_item("IA casual", ChessRules.OPPONENT_AI_CASUAL)
	opponent.add_item("IA táctica", ChessRules.OPPONENT_AI_TACTICAL)
	opponent.item_selected.connect(_on_opponent_selected)
	_random.randomize()
	grabber.grab_started.connect(_on_grab_started)
	grabber.grab_finished.connect(_on_grab_finished)
	$UI/Panel/Margin/Content/Actions/Undo.pressed.connect(_undo)
	$UI/Panel/Margin/Content/Actions/Claim.pressed.connect(_claim)
	$UI/Panel/Margin/Content/SaveRow/Save.pressed.connect(_save_game)
	$UI/Panel/Margin/Content/SaveRow/Load.pressed.connect(_load_game)
	$UI/Panel/Margin/Content/Free.pressed.connect(_open_free)
	_refresh()


func _physics_process(_delta: float) -> void:
	for key in homes:
		var piece := key as PhysicalChessPiece
		if not is_instance_valid(piece) or piece == grabber.held or piece.freeze:
			continue
		var home: Vector3 = homes[piece]
		var displacement := Vector3(
			home.x - piece.global_position.x, 0, home.z - piece.global_position.z
		)
		var velocity := Vector3(piece.linear_velocity.x, 0, piece.linear_velocity.z)
		if displacement.length() < 0.015 and velocity.length() < 0.03:
			continue
		var acceleration := displacement * SPRING - velocity * DAMPING
		if piece.sleeping:
			piece.sleeping = false
		piece.apply_central_force(acceleration.limit_length(MAX_ACCELERATION) * piece.mass)


func _on_grab_started(object: InteractiveTableObject) -> void:
	_dragged = object as PhysicalChessPiece
	_drag_from = int(piece_squares.get(_dragged, -1))
	_destinations.clear()
	if _ai_thinking or _is_ai_turn():
		grabber.call_deferred("_release", "cancelled")
		_refresh()
		_help("Espera a que termine el turno de la IA.")
		return
	if (
		_drag_from >= 0 and rules.status() in ["playing", "check"]
	):
		for move in rules.legal_moves_from(_drag_from):
			_destinations.append(int(move["to"]))
	_refresh()
	if _destinations.is_empty():
		_help("Esa pieza no tiene jugadas legales en este turno.")
	else:
		_help("Lleva la pieza a una casilla iluminada; suelta cuando llegue.")


func _on_grab_finished(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if not is_instance_valid(_dragged) or object != _dragged:
		return
	var accepted := false
	var announced_claim := false
	var destination := _square_from_position(target)
	if reason == "released" and destination in _destinations:
		var center := _square_center(destination)
		var offset := Vector2(
			_dragged.global_position.x - center.x, _dragged.global_position.z - center.z
		)
		if offset.length() <= CELL * 0.55:
			var promotion: int = $UI/Panel/Margin/Content/Promotion.get_selected_id()
			if _claim_mode:
				announced_claim = rules.claim_draw(_drag_from, destination, promotion)
			else:
				var snapshot := _move_with_mapping(
					rules, piece_squares, homes, capture_counts, _drag_from, destination, promotion
				)
				if not snapshot.is_empty():
					_snapshots.append(snapshot)
					_update_models()
					accepted = true
	_dragged = null
	_drag_from = -1
	_destinations.clear()
	if announced_claim:
		_claim_mode = false
	_refresh()
	if announced_claim:
		_help("Tablas reclamadas anunciando la jugada; la pieza vuelve a su casilla.")
	elif _claim_mode and reason == "released":
		_help("Esa jugada no permite reclamar tablas; la pieza vuelve a su casilla.")
	elif accepted:
		_help("Jugada aceptada; las piezas se estabilizan mediante fuerzas.")
	elif reason in ["cancelled", "recovered"]:
		_help("Jugada cancelada; la pieza volverá a su posición.")
	elif reason == "released":
		_help("Jugada rechazada; la pieza volverá a su posición.")


# Comparte la misma reconstrucción para jugadas y carga, incluidos enroque y captura al paso.
func _move_with_mapping(
	game: ChessRules,
	squares: Dictionary,
	positions: Dictionary,
	counts: Array[int],
	from_square: int,
	to_square: int,
	promotion: int
) -> Dictionary:
	var chosen: Dictionary = {}
	for move in game.legal_moves_from(from_square):
		if int(move["to"]) == to_square:
			chosen = move
			break
	if chosen.is_empty():
		return {}
	var moving := _find_piece(squares, from_square)
	if not is_instance_valid(moving):
		return {}
	var moving_value: int = game.piece_at(from_square)
	var victim_square := to_square
	if chosen.get("ep", false):
		victim_square = to_square + 8 * (1 if moving_value > 0 else -1)
	var victim_value: int = game.piece_at(victim_square)
	var victim := _find_piece(squares, victim_square) if victim_value != 0 else null
	if victim_value != 0 and not is_instance_valid(victim):
		return {}
	var rook: PhysicalChessPiece = null
	var rook_to := -1
	if chosen.get("castle", false):
		var rook_from := from_square + 3 if to_square > from_square else from_square - 4
		rook_to = from_square + 1 if to_square > from_square else from_square - 1
		rook = _find_piece(squares, rook_from)
		if not is_instance_valid(rook):
			return {}
	var snapshot := {
		"squares": squares.duplicate(), "homes": positions.duplicate(), "counts": counts.duplicate()
	}
	if not game.play(from_square, to_square, promotion):
		return {}
	squares[moving] = to_square
	positions[moving] = _square_center(to_square)
	if is_instance_valid(victim):
		squares[victim] = -1
		var side := 0 if victim_value > 0 else 1
		positions[victim] = _capture_position(side, counts[side])
		counts[side] += 1
	if is_instance_valid(rook):
		squares[rook] = rook_to
		positions[rook] = _square_center(rook_to)
	return snapshot


func _capture_position(side: int, index: int) -> Vector3:
	var x := 2.1 + (index / 6) * 0.48
	return Vector3(x if side == 0 else -x, BOARD_HEIGHT, -1.7 + (index % 6) * 0.68)


func _find_piece(squares: Dictionary, square: int) -> PhysicalChessPiece:
	if square < 0:
		return null
	for key in squares:
		if int(squares[key]) == square and is_instance_valid(key):
			return key as PhysicalChessPiece
	return null


func _update_models() -> void:
	for key in piece_squares:
		var piece := key as PhysicalChessPiece
		if not is_instance_valid(piece):
			continue
		var square: int = int(piece_squares[piece])
		if square >= 0:
			piece.set_piece_type(absi(rules.piece_at(square)))


func _reset() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la pieza antes de iniciar una partida nueva.")
		return
	var opponent_mode: int = rules.opponent_mode
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	rules.reset()
	rules.opponent_mode = opponent_mode
	piece_squares = initial_squares.duplicate()
	homes.clear()
	for piece in piece_squares:
		if is_instance_valid(piece):
			homes[piece] = _square_center(int(piece_squares[piece]))
	capture_counts = [0, 0]
	_snapshots.clear()
	_dragged = null
	_drag_from = -1
	_destinations.clear()
	_claim_mode = false
	_update_models()
	_refresh()
	_help("Nueva partida iniciada.")


func _undo() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la pieza antes de deshacer.")
		return
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	var undo_count := 1
	if (
		rules.opponent_mode != ChessRules.OPPONENT_LOCAL
		and rules.turn == ChessRules.WHITE
		and _snapshots.size() >= 2
	):
		undo_count = 2
	if _snapshots.size() < undo_count:
		return
	_claim_mode = false
	for _i in range(undo_count):
		if not rules.undo():
			break
		var snapshot: Dictionary = _snapshots.pop_back()
		piece_squares = snapshot["squares"]
		homes = snapshot["homes"]
		capture_counts.assign(snapshot["counts"])
	_update_models()
	_refresh()
	_help("Jugada deshecha; las piezas vuelven mediante fuerzas.")


func _claim() -> void:
	if _is_ai_turn() or _ai_thinking:
		return
	if rules.can_claim_draw():
		if is_instance_valid(grabber.held):
			_help("Suelta la pieza antes de reclamar tablas en la posición actual.")
			return
		rules.claim_draw()
		_claim_mode = false
		_refresh()
		_help("Tablas reclamadas.")
	elif rules.status() in ["playing", "check"]:
		_claim_mode = not _claim_mode
		_refresh()
		_help(
			"Arrastra una pieza a una jugada legal que produciría tablas y suéltala para anunciarla."
			if _claim_mode
			else "Anuncio de reclamación cancelado."
		)


func _save_game() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la pieza antes de guardar.")
		return
	if rules.move_log.size() > 1024:
		_help("La partida supera el límite; se conserva el guardado anterior.")
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.chess):
		_help("No se pudo guardar; comprueba el espacio e inténtalo de nuevo.")
		return
	_help("Partida guardada en este dispositivo.")


func _load_game() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la pieza antes de cargar.")
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.chess)
	if loaded.is_empty():
		_help("Guardado ausente o inválido; se conserva la partida actual.")
		return
	if not _restore_record(loaded["record"]):
		_help("No se pudieron reconstruir las piezas; se conserva la partida actual.")
		return
	_dragged = null
	_drag_from = -1
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	_claim_mode = false
	_destinations.clear()
	_update_models()
	_refresh()
	_help(
		(
			"Cargada la copia anterior: el guardado principal falta o es inválido."
			if loaded["backup"]
			else "Partida cargada en este dispositivo."
		)
	)


func _restore_record(record: Variant) -> bool:
	var candidate := ChessRules.new()
	if not candidate.import_record(record):
		return false
	var replay := ChessRules.new()
	var squares: Dictionary = initial_squares.duplicate()
	var positions := {}
	for piece in squares:
		if not is_instance_valid(piece):
			return false
		positions[piece] = _square_center(int(squares[piece]))
	var counts: Array[int] = [0, 0]
	var snapshots: Array[Dictionary] = []
	for move in candidate.move_log:
		var snapshot := _move_with_mapping(
			replay,
			squares,
			positions,
			counts,
			int(move["from"]),
			int(move["to"]),
			int(move["promotion"])
		)
		if snapshot.is_empty():
			return false
		snapshots.append(snapshot)
	rules = candidate
	piece_squares = squares
	homes = positions
	capture_counts = counts
	_snapshots = snapshots
	return true


func _refresh() -> void:
	BoardGeometry3D.update_tiles(
		_squares, _drag_from, _destinations, _light, _dark, _selected, _legal
	)
	var state := rules.status()
	var side := "blancas" if rules.turn == ChessRules.WHITE else "negras"
	match state:
		"playing":
			status_label.text = "Turno: " + ("IA (negras)" if _is_ai_turn() else side)
		"check":
			status_label.text = (
				"Turno: IA (negras) · JAQUE" if _is_ai_turn() else "Turno: " + side + " · JAQUE"
			)
		"checkmate":
			status_label.text = (
				"Jaque mate · ganan " + ("negras" if rules.turn == ChessRules.WHITE else "blancas")
			)
		"stalemate":
			status_label.text = "Tablas · rey ahogado"
		"insufficient_material":
			status_label.text = "Tablas · material insuficiente"
		"seventy_five_moves":
			status_label.text = "Tablas · 75 movimientos"
		"fivefold_repetition":
			status_label.text = "Tablas · cinco repeticiones"
		"fifty_moves":
			status_label.text = "Tablas reclamadas · 50 movimientos"
		"threefold_repetition":
			status_label.text = "Tablas reclamadas · tres repeticiones"
	var active := state in ["playing", "check"]
	$UI/Panel/Margin/Content/Actions/Undo.disabled = _snapshots.is_empty()
	var claim_button: Button = $UI/Panel/Margin/Content/Actions/Claim
	claim_button.disabled = not active or _is_ai_turn() or _ai_thinking
	claim_button.text = "Cancelar anuncio" if _claim_mode else "Reclamar tablas"
	var opponent: OptionButton = $UI/Panel/Margin/Content/Opponent
	opponent.select(opponent.get_item_index(rules.opponent_mode))
	opponent.disabled = _ai_thinking or is_instance_valid(grabber.held)
	claim_button.tooltip_text = (
		"Arrastra una pieza a una jugada legal que produciría 50 movimientos o una tercera repetición."
		if _claim_mode
		else "Reclama tablas ahora si corresponde o anuncia una jugada legal que las produciría."
	)
	if active and _is_ai_turn():
		_schedule_ai_turn()


func _on_opponent_selected(index: int) -> void:
	rules.opponent_mode = $UI/Panel/Margin/Content/Opponent.get_item_id(index)
	_ai_failed = false
	_claim_mode = false
	_refresh()


func _is_ai_turn() -> bool:
	return rules.opponent_mode != ChessRules.OPPONENT_LOCAL and rules.turn == ChessRules.BLACK


func _schedule_ai_turn() -> void:
	if _ai_thinking or _ai_failed or not _is_ai_turn():
		return
	_ai_thinking = true
	_ai_request_id += 1
	status_label.text = "Turno de la IA (negras) · pensando…"
	_help("La IA elegirá una jugada legal.")
	_play_ai_turn.call_deferred(_ai_request_id)


func _play_ai_turn(request_id: int) -> void:
	await get_tree().create_timer(0.35).timeout
	if request_id != _ai_request_id:
		return
	if not _is_ai_turn() or rules.status() not in ["playing", "check"]:
		_ai_thinking = false
		_refresh()
		return
	var move := ChessAI.choose_move(rules, rules.opponent_mode, _random)
	if move.is_empty():
		_ai_thinking = false
		_ai_failed = true
		_refresh()
		_help("La IA no encontró una jugada legal.")
		return
	var snapshot := _move_with_mapping(
		rules,
		piece_squares,
		homes,
		capture_counts,
		int(move["from"]),
		int(move["to"]),
		ChessRules.QUEEN
	)
	_ai_thinking = false
	if snapshot.is_empty():
		_ai_failed = true
		_refresh()
		_help("La IA eligió una jugada que no pudo reflejarse en las piezas.")
		return
	_snapshots.append(snapshot)
	_update_models()
	_refresh()
	_help("La IA ha movido.")


func _on_selection_changed(_object: InteractiveTableObject) -> void:
	pass


func _on_placement_message(_message: String) -> void:
	_help("Pieza recuperada; volverá a su posición lógica.")


func _help(message: String) -> void:
	$UI/Panel/Margin/Content/Help.text = message


func _square_from_position(point: Vector3) -> int:
	var x := floori(point.x / CELL + 4.0)
	var y := floori(point.z / CELL + 4.0)
	return y * 8 + x if x >= 0 and x < 8 and y >= 0 and y < 8 else -1


func _square_center(square: int) -> Vector3:
	return BoardGeometry3D.square_position(square, CELL, BOARD_HEIGHT)


func _open_free() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicalChess.tscn")
