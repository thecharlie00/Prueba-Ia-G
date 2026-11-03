class_name ChessBoard3D
extends Node3D

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")
const CELL := 0.46
const BOARD_HEIGHT := 0.83
const MAX_SAVE_BYTES := 262144

@export var save_path := "user://diceon_chess.json"

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

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var tiles_root: Node3D = $Board/Tiles
@onready var pieces_root: Node3D = $Board/Pieces
@onready var status_label: Label = $UI/Panel/Margin/Content/Status
@onready var help_label: Label = $UI/Panel/Margin/Content/Help
@onready var promotion_choice: OptionButton = $UI/Panel/Margin/Content/Promotion
@onready var undo_button: Button = $UI/Panel/Margin/Content/Undo
@onready var claim_button: Button = $UI/Panel/Margin/Content/Claim


func _ready() -> void:
	_make_materials()
	_make_board()
	promotion_choice.add_item("Dama", ChessRules.QUEEN)
	promotion_choice.add_item("Torre", ChessRules.ROOK)
	promotion_choice.add_item("Alfil", ChessRules.BISHOP)
	promotion_choice.add_item("Caballo", ChessRules.KNIGHT)
	$UI/Panel/Margin/Content/Reset.pressed.connect(_reset)
	undo_button.pressed.connect(_undo)
	claim_button.pressed.connect(_claim)
	$UI/Panel/Margin/Content/Save.pressed.connect(_save_game)
	$UI/Panel/Margin/Content/Load.pressed.connect(_load_game)
	$UI/Panel/Margin/Content/Sandbox.pressed.connect(_open_sandbox)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var square: int = BoardGeometry.square_from_mouse(
			camera, event.position, CELL, BOARD_HEIGHT
		)
		if square >= 0:
			_select_square(square)


func _select_square(square: int) -> void:
	if rules.status() not in ["playing", "check"]:
		return
	var piece: int = rules.piece_at(square)
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
	light_material = BoardGeometry.make_material(Color("dfd1ad"))
	dark_material = BoardGeometry.make_material(Color("405f50"))
	selected_material = BoardGeometry.make_material(Color("d8af5d"))
	legal_material = BoardGeometry.make_material(Color("80bc8e"))
	white_piece = BoardGeometry.make_material(Color("f5ead5"))
	black_piece = BoardGeometry.make_material(Color("202d29"))


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
	claim_button.disabled = (
		not active
		or not (
			rules.halfmove_clock >= 100
			or int(rules.repetition_counts.get(rules._position_key(), 0)) >= 3
		)
	)


func _reset() -> void:
	rules.reset()
	selected = -1
	legal_destinations.clear()
	_refresh()


func _undo() -> void:
	if rules.undo():
		selected = -1
		legal_destinations.clear()
		_refresh()


func _claim() -> void:
	if rules.claim_draw():
		selected = -1
		legal_destinations.clear()
		_refresh()


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
	legal_destinations.clear()
	_refresh()
	help_label.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
