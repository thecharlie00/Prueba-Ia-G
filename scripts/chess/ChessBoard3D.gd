class_name ChessBoard3D
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")
const AtomicSave = preload("res://scripts/AtomicSaveFile.gd")
const ChessAI = preload("res://scripts/chess/ChessAI.gd")
const CELL := 0.46
const BOARD_HEIGHT := 0.83
const MAX_SAVE_BYTES := 262144

@export var save_path := "user://diceon_chess.json"

var confirm_action: ConfirmAction
var rules := ChessRules.new()
var selected: int = -1
var legal_destinations: Array[int] = []
var squares: Array[MeshInstance3D] = []
var light_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var legal_material: StandardMaterial3D
var white_piece: StandardMaterial3D
var black_piece: StandardMaterial3D
var _claim_mode := false
var _ai_thinking := false
var _ai_failed := false
var _ai_request_id := 0
var _random := RandomNumberGenerator.new()

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var tiles_root: Node3D = $Board/Tiles
@onready var pieces_root: Node3D = $Board/Pieces
@onready var status_label: Label = $UI/Panel/Margin/Content/Status
@onready var help_label: Label = $UI/Panel/Margin/Content/Help
@onready var promotion_choice: OptionButton = $UI/Panel/Margin/Content/Promotion
@onready var undo_button: Button = $UI/Panel/Margin/Content/Undo
@onready var claim_button: Button = $UI/Panel/Margin/Content/Claim
@onready var opponent_choice: OptionButton = $UI/Panel/Margin/Content/Opponent


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	_make_materials()
	_make_board()
	promotion_choice.add_item("Dama", ChessRules.QUEEN)
	promotion_choice.add_item("Torre", ChessRules.ROOK)
	promotion_choice.add_item("Alfil", ChessRules.BISHOP)
	promotion_choice.add_item("Caballo", ChessRules.KNIGHT)
	opponent_choice.add_item("Dos personas", ChessRules.OPPONENT_LOCAL)
	opponent_choice.add_item("IA casual", ChessRules.OPPONENT_AI_CASUAL)
	opponent_choice.add_item("IA táctica", ChessRules.OPPONENT_AI_TACTICAL)
	opponent_choice.item_selected.connect(_on_opponent_selected)
	_random.randomize()
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Reset as Button,
		"Nueva partida",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_reset
	)
	undo_button.pressed.connect(_undo)
	claim_button.pressed.connect(_claim)
	$UI/Panel/Margin/Content/Save.pressed.connect(_save_game)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Load as Button,
		"Cargar partida",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Sandbox as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_sandbox
	)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _ai_thinking
		and not _is_ai_turn()
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var square: int = BoardGeometry.square_from_mouse(
			camera, event.position, CELL, BOARD_HEIGHT
		)
		if square >= 0:
			_select_square(square)


func _select_square(square: int) -> void:
	if _ai_thinking or _is_ai_turn() or rules.status() not in ["playing", "check"]:
		return
	var piece: int = rules.piece_at(square)
	if _claim_mode:
		if selected >= 0 and square in legal_destinations:
			if rules.claim_draw(selected, square, promotion_choice.get_selected_id()):
				_claim_mode = false
				selected = -1
				legal_destinations.clear()
				_refresh()
				help_label.text = "Tablas reclamadas anunciando esa jugada."
			else:
				selected = -1
				legal_destinations.clear()
				_refresh()
				help_label.text = "Esa jugada no permite reclamar tablas."
			return
		if (
			(piece > 0 and rules.turn == ChessRules.WHITE)
			or (piece < 0 and rules.turn == ChessRules.BLACK)
		):
			selected = square
			legal_destinations.clear()
			for move in rules.legal_moves_from(square):
				legal_destinations.append(int(move["to"]))
		else:
			selected = -1
			legal_destinations.clear()
		_refresh()
		help_label.text = "Elige la jugada que quieres anunciar para reclamar tablas."
		return
	if selected >= 0 and square in legal_destinations:
		var promotion: int = promotion_choice.get_selected_id()
		if rules.play(selected, square, promotion):
			selected = -1
			legal_destinations.clear()
			_refresh()
			return
	if (
		(piece > 0 and rules.turn == ChessRules.WHITE)
		or (piece < 0 and rules.turn == ChessRules.BLACK)
	):
		selected = square
		legal_destinations.clear()
		for move in rules.legal_moves_from(square):
			legal_destinations.append(int(move["to"]))
	else:
		selected = -1
		legal_destinations.clear()
	_refresh()


func _make_materials() -> void:
	light_material = BoardGeometry.make_material(Palette.BOARD_LIGHT)
	dark_material = BoardGeometry.make_material(Palette.BOARD_DARK)
	selected_material = BoardGeometry.make_material(Palette.SELECTED)
	legal_material = BoardGeometry.make_material(Palette.LEGAL)
	white_piece = BoardGeometry.make_material(Palette.PIECE_LIGHT)
	black_piece = BoardGeometry.make_material(Palette.PIECE_DARK)


func _make_board() -> void:
	squares = BoardGeometry.make_tiles(tiles_root, CELL, BOARD_HEIGHT)


func _refresh() -> void:
	BoardGeometry.update_tiles(
		squares,
		selected,
		legal_destinations,
		light_material,
		dark_material,
		selected_material,
		legal_material
	)
	for child in pieces_root.get_children():
		pieces_root.remove_child(child)
		child.queue_free()
	for i in range(64):
		var piece: int = rules.piece_at(i)
		if piece != 0:
			_make_piece(i, piece)
	_update_status()


func _make_piece(square: int, piece: int) -> void:
	var model := ChessPieceModel.create(
		absi(piece), piece > 0, white_piece if piece > 0 else black_piece
	)
	model.position = BoardGeometry.square_position(square, CELL, BOARD_HEIGHT)
	model.set_meta("square", square)
	pieces_root.add_child(model)


func _update_status() -> void:
	var side: String = "Blancas" if rules.turn == ChessRules.WHITE else "Negras"
	if _is_ai_turn():
		side = "IA"
	var state: String = rules.status()
	match state:
		"checkmate":
			status_label.text = "Jaque mate · ganan " + ("negras" if rules.turn == 1 else "blancas")
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
		"check":
			status_label.text = "Turno: " + side + " · JAQUE"
		_:
			status_label.text = "Turno: " + side
	var active: bool = state in ["playing", "check"]
	if not active:
		selected = -1
		legal_destinations.clear()
	help_label.text = (
		"Selecciona una pieza y luego un destino."
		if active
		else "Partida terminada. Deshaz o inicia una nueva."
	)
	undo_button.disabled = rules.history.is_empty()
	claim_button.disabled = not active or _is_ai_turn() or _ai_thinking
	claim_button.text = "Cancelar anuncio" if _claim_mode else "Reclamar tablas"
	opponent_choice.select(opponent_choice.get_item_index(rules.opponent_mode))
	opponent_choice.disabled = _ai_thinking
	claim_button.tooltip_text = (
		(
			"Selecciona una pieza y una jugada legal que produciría 50 movimientos "
			+ "o una tercera repetición."
		)
		if _claim_mode
		else "Reclama tablas ahora si corresponde o anuncia una jugada legal que las produciría."
	)
	if active and _is_ai_turn():
		_schedule_ai_turn()


func _reset() -> void:
	var opponent_mode: int = rules.opponent_mode
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	rules.reset()
	rules.opponent_mode = opponent_mode
	_claim_mode = false
	selected = -1
	legal_destinations.clear()
	_refresh()


func _undo() -> void:
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	var undo_count := 1
	if (
		rules.opponent_mode != ChessRules.OPPONENT_LOCAL
		and rules.turn == ChessRules.WHITE
		and rules.history.size() >= 2
	):
		undo_count = 2
	var changed := false
	for _i in range(undo_count):
		if rules.undo():
			changed = true
	if changed:
		_claim_mode = false
		selected = -1
		legal_destinations.clear()
		_refresh()


func _claim() -> void:
	if _is_ai_turn() or _ai_thinking:
		return
	if rules.can_claim_draw():
		rules.claim_draw()
		_claim_mode = false
		selected = -1
		legal_destinations.clear()
		_refresh()
		help_label.text = "Tablas reclamadas."
	elif rules.status() in ["playing", "check"]:
		_claim_mode = not _claim_mode
		selected = -1
		legal_destinations.clear()
		_refresh()
		help_label.text = (
			"Selecciona una pieza y una jugada legal para anunciar."
			if _claim_mode
			else "Anuncio de reclamación cancelado."
		)


func _save_game() -> void:
	if rules.move_log.size() > 1024:
		help_label.text = "La partida supera el límite; se conserva el guardado anterior."
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.chess):
		help_label.text = "No se pudo guardar; comprueba el espacio e inténtalo de nuevo."
		return
	help_label.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.chess)
	if loaded.is_empty():
		help_label.text = "Guardado ausente o inválido; se conserva la partida actual."
		return
	rules = loaded["value"] as ChessRules
	selected = -1
	_ai_request_id += 1
	_ai_thinking = false
	_ai_failed = false
	_claim_mode = false
	legal_destinations.clear()
	_refresh()
	help_label.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


func _on_opponent_selected(index: int) -> void:
	rules.opponent_mode = opponent_choice.get_item_id(index)
	_ai_failed = false
	selected = -1
	legal_destinations.clear()
	_claim_mode = false
	_refresh()


func _is_ai_turn() -> bool:
	return rules.opponent_mode != ChessRules.OPPONENT_LOCAL and rules.turn == ChessRules.BLACK


func _schedule_ai_turn() -> void:
	if _ai_thinking or _ai_failed or not _is_ai_turn():
		return
	_ai_thinking = true
	_ai_request_id += 1
	status_label.text = "Turno de la IA · pensando…"
	help_label.text = "La IA elegirá una jugada legal."
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
	_ai_thinking = false
	if move.is_empty() or not rules.play(int(move["from"]), int(move["to"])):
		_ai_failed = true
		help_label.text = "La IA no pudo completar una jugada legal."
		_refresh()
		return
	_refresh()
	help_label.text = "La IA ha movido."


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# --- Interfaz integrada en la mesa (TableHud) ---


func hud_seats() -> Array:
	var bot: bool = rules.opponent_mode != ChessRules.OPPONENT_LOCAL
	var rival := "Negras"
	if rules.opponent_mode == ChessRules.OPPONENT_AI_CASUAL:
		rival = "IA casual"
	elif rules.opponent_mode == ChessRules.OPPONENT_AI_TACTICAL:
		rival = "IA táctica"
	return [
		{"name": "Blancas", "color": Palette.PIECE_LIGHT, "bot": false, "side": "east"},
		{"name": rival, "color": Palette.PIECE_DARK, "bot": bot, "side": "north"},
	]


func hud_active_seat() -> int:
	return 0 if rules.turn == ChessRules.WHITE else 1


func hud_seat_status(index: int) -> String:
	if index == 1 and bool(get("_ai_thinking")):
		return "Pensando…"
	return ""
