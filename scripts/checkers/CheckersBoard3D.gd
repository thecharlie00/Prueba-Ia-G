class_name CheckersBoard3D
extends Node3D

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")
const AtomicSave = preload("res://scripts/AtomicSaveFile.gd")
const CELL := 0.46
const BOARD_HEIGHT := 0.83
const MAX_SAVE_BYTES := 262144

@export var save_path := "user://diceon_checkers.json"

var rules := CheckersRules.new()
var selected: int = -1
var legal_destinations: Array[int] = []
var squares: Array[MeshInstance3D] = []
var light_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var legal_material: StandardMaterial3D
var white_piece: StandardMaterial3D
var black_piece: StandardMaterial3D
var crown_material: StandardMaterial3D

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var tiles_root: Node3D = $Board/Tiles
@onready var pieces_root: Node3D = $Board/Pieces
@onready var status_label: Label = $UI/Panel/Margin/Content/Status
@onready var help_label: Label = $UI/Panel/Margin/Content/Help
@onready var undo_button: Button = $UI/Panel/Margin/Content/Undo


func _ready() -> void:
	_make_materials()
	_make_board()
	$UI/Panel/Margin/Content/Reset.pressed.connect(_reset)
	undo_button.pressed.connect(_undo)
	$UI/Panel/Margin/Content/Save.pressed.connect(_save_game)
	$UI/Panel/Margin/Content/Load.pressed.connect(_load_game)
	$UI/Panel/Margin/Content/Sandbox.pressed.connect(_open_sandbox)
	$UI/Panel/Margin/Content/Physical.pressed.connect(_open_physical)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var square: int = BoardGeometry.square_from_mouse(
			camera, event.position, CELL, BOARD_HEIGHT
		)
		if square >= 0:
			_select_square(square)


func _select_square(square: int) -> void:
	if rules.status() != "playing":
		return
	if selected >= 0 and square in legal_destinations:
		if rules.play(selected, square):
			_select_forced_piece()
			_refresh()
			return
	if rules.forced_from >= 0:
		return
	var piece: int = rules.piece_at(square)
	if (
		(piece > 0 and rules.turn == CheckersRules.WHITE)
		or (piece < 0 and rules.turn == CheckersRules.BLACK)
	):
		selected = square
		_update_destinations()
	else:
		selected = -1
		legal_destinations.clear()
	_refresh()


func _select_forced_piece() -> void:
	selected = rules.forced_from
	_update_destinations()


func _update_destinations() -> void:
	legal_destinations.clear()
	if selected >= 0:
		for move in rules.legal_moves_from(selected):
			legal_destinations.append(int(move["to"]))


func _make_materials() -> void:
	light_material = BoardGeometry.make_material(Color("dfd1ad"))
	dark_material = BoardGeometry.make_material(Color("405f50"))
	selected_material = BoardGeometry.make_material(Color("d8af5d"))
	legal_material = BoardGeometry.make_material(Color("80bc8e"))
	white_piece = BoardGeometry.make_material(Color("f5ead5"))
	black_piece = BoardGeometry.make_material(Color("202d29"))
	crown_material = BoardGeometry.make_material(Color("d8af5d"))


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
		child.queue_free()
	for square in range(64):
		var piece: int = rules.piece_at(square)
		if piece != 0:
			_make_piece(square, piece)
	_update_status()


func _make_piece(square: int, piece: int) -> void:
	var holder := Node3D.new()
	holder.position = BoardGeometry.square_position(square, CELL, BOARD_HEIGHT)
	pieces_root.add_child(holder)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.165
	mesh.bottom_radius = 0.17
	mesh.height = 0.09
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = 0.045
	body.material_override = white_piece if piece > 0 else black_piece
	holder.add_child(body)
	if absi(piece) == CheckersRules.KING:
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.115
		crown_mesh.bottom_radius = 0.12
		crown_mesh.height = 0.035
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.position.y = 0.108
		crown.material_override = crown_material
		holder.add_child(crown)
		var label := Label3D.new()
		label.text = "D"
		label.font_size = 56
		label.pixel_size = 0.003
		label.rotation_degrees.x = -90.0
		label.position.y = 0.128
		label.modulate = Color("202d29")
		holder.add_child(label)


func _update_status() -> void:
	var state: String = rules.status()
	match state:
		"white_wins":
			status_label.text = "Ganan las blancas"
		"black_wins":
			status_label.text = "Ganan las negras"
		_:
			status_label.text = (
				"Turno: " + ("Blancas" if rules.turn == CheckersRules.WHITE else "Negras")
			)
	if state != "playing":
		help_label.text = "Partida terminada. Deshaz o inicia una nueva."
	elif rules.forced_from >= 0:
		help_label.text = "Captura múltiple: continúa con la misma ficha."
	elif rules.has_any_capture():
		help_label.text = "Captura obligatoria. Elige una ficha que pueda saltar."
	else:
		help_label.text = "Selecciona una ficha y después un destino."
	undo_button.disabled = rules.history.is_empty()


func _reset() -> void:
	rules.reset()
	selected = -1
	legal_destinations.clear()
	_refresh()


func _undo() -> void:
	if rules.undo():
		_select_forced_piece()
		_refresh()


func _save_game() -> void:
	if rules.move_log.size() > 1024:
		help_label.text = "La partida supera el límite; se conserva el guardado anterior."
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.checkers):
		help_label.text = "No se pudo guardar; comprueba el espacio e inténtalo de nuevo."
		return
	help_label.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.checkers)
	if loaded.is_empty():
		help_label.text = "Guardado ausente o inválido; se conserva la partida actual."
		return
	rules = loaded["value"] as CheckersRules
	_select_forced_piece()
	_refresh()
	help_label.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_physical() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicalCheckers.tscn")
