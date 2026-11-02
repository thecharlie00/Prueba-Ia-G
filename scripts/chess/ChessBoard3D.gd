class_name ChessBoard3D
extends Node3D

const CELL := 0.46
const BOARD_HEIGHT := 0.83
const MAX_SAVE_BYTES := 262144
const SYMBOLS := {1: "P", 2: "C", 3: "A", 4: "T", 5: "D", 6: "R"}

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
		var origin: Vector3 = camera.project_ray_origin(event.position)
		var direction: Vector3 = camera.project_ray_normal(event.position)
		if absf(direction.y) < 0.0001:
			return
		var distance: float = (BOARD_HEIGHT - origin.y) / direction.y
		if distance < 0.0:
			return
		var point: Vector3 = origin + direction * distance
		var x: int = floori(point.x / CELL + 4.0)
		var y: int = floori(point.z / CELL + 4.0)
		if x >= 0 and x < 8 and y >= 0 and y < 8:
			_select_square(y * 8 + x)


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
	light_material = _material(Color("dfd1ad"))
	dark_material = _material(Color("405f50"))
	selected_material = _material(Color("d8af5d"))
	legal_material = _material(Color("80bc8e"))
	white_piece = _material(Color("f5ead5"))
	black_piece = _material(Color("202d29"))


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


func _make_board() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL, 0.035, CELL)
	for y in range(8):
		for x in range(8):
			var tile := MeshInstance3D.new()
			tile.mesh = mesh
			tile.position = Vector3((x - 3.5) * CELL, BOARD_HEIGHT - 0.0175, (y - 3.5) * CELL)
			tiles_root.add_child(tile)
			squares.append(tile)
	for index in range(8):
		_add_coordinate(
			"abcdefgh".substr(index, 1),
			Vector3((index - 3.5) * CELL, BOARD_HEIGHT + 0.01, 4.35 * CELL)
		)
		_add_coordinate(
			str(8 - index), Vector3(-4.35 * CELL, BOARD_HEIGHT + 0.01, (index - 3.5) * CELL)
		)


func _add_coordinate(text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.003
	label.modulate = Color("f5ead5")
	label.rotation_degrees.x = -90.0
	label.position = point
	tiles_root.add_child(label)


func _refresh() -> void:
	for i in range(64):
		var square_color: int = (i % 8 + i / 8) % 2
		squares[i].material_override = light_material if square_color == 0 else dark_material
		if i == selected:
			squares[i].material_override = selected_material
		elif i in legal_destinations:
			squares[i].material_override = legal_material
	for child in pieces_root.get_children():
		child.queue_free()
	for i in range(64):
		var piece: int = rules.piece_at(i)
		if piece != 0:
			_make_piece(i, piece)
	_update_status()


func _make_piece(square: int, piece: int) -> void:
	var holder := Node3D.new()
	holder.position = Vector3((square % 8 - 3.5) * CELL, BOARD_HEIGHT, (square / 8 - 3.5) * CELL)
	pieces_root.add_child(holder)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.145
	mesh.bottom_radius = 0.17
	mesh.height = 0.16
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = 0.08
	body.material_override = white_piece if piece > 0 else black_piece
	holder.add_child(body)
	var label := Label3D.new()
	label.text = SYMBOLS[absi(piece)]
	label.font_size = 64
	label.pixel_size = 0.0035
	label.rotation_degrees.x = -90.0
	label.position.y = 0.165
	label.modulate = Color("26382f") if piece > 0 else Color("f5ead5")
	holder.add_child(label)


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
	var json: String = JSON.stringify(rules.export_record())
	if rules.move_log.size() > 1024 or json.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		help_label.text = "La partida supera el límite de guardado."
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		help_label.text = "No se pudo abrir el archivo para guardar."
		return
	file.store_string(json)
	file.flush()
	if file.get_error() != OK:
		help_label.text = "No se pudo guardar la partida."
	else:
		help_label.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		help_label.text = "No hay una partida guardada disponible."
		return
	if file.get_length() > MAX_SAVE_BYTES:
		help_label.text = "Archivo de partida demasiado grande."
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		help_label.text = "Archivo inválido o partida incompatible."
		return
	var record: Variant = parser.data
	if not rules.import_record(record):
		help_label.text = "Archivo inválido o partida incompatible."
		return
	selected = -1
	legal_destinations.clear()
	_refresh()
	help_label.text = "Partida cargada desde este dispositivo."


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
