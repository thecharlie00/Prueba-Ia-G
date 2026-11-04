# gdlint: disable=max-file-lines
class_name IslandView
extends Node3D

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const PIECE := preload("res://scenes/IslandPiece3D.tscn")
const DICE := preload("res://scenes/Dice3D.tscn")
const RESOURCE_ART := [
	preload("res://assets/island/wood.jpg"),
	preload("res://assets/island/brick.jpg"),
	preload("res://assets/island/wool.jpg"),
	preload("res://assets/island/grain.jpg"),
	preload("res://assets/island/ore.jpg"),
]
const RADIUS := 0.4
const HEIGHT := 0.83
const MAX_SAVE_BYTES := 2000000
const PLAYER_COLORS := [Color("d99552"), Color("5a94bf"), Color("d05b55"), Color("deddd2")]
const PORT_NAMES := ["Mad", "Lad", "Lan", "Tri", "Min"]

@export_range(3, 4) var player_count := 3

var rules := IslandRules.new()
var save_path := "user://diceon_island.json"
var dice: Array[Dice3D] = []
var roll_results: Array[int] = [0, 0]
var waiting_roll := false
var manual_roll := false
var manually_thrown: Array[bool] = [false, false]
var settled_time := 0.0
var stuck_times: Array[float] = [0.0, 0.0]
var nudge_counts: Array[int] = [0, 0]
var selection_mode := ""
var homes: Dictionary = {}
var road_rotations: Dictionary = {}
var building_nodes: Dictionary = {}
var road_nodes: Dictionary = {}
var robber_node: IslandPiece3D
var markers_vertex: Array[MeshInstance3D] = []
var markers_edge: Array[MeshInstance3D] = []
var markers_tile: Array[MeshInstance3D] = []
var marker_legal: Material
var game_title: Label
var status: Label
var hands: Label
var help: Label
var give: OptionButton
var take: OptionButton
var victim: OptionButton
var dev_choice: OptionButton
var trade_partner: OptionButton
var trade_give: Array[SpinBox] = []
var trade_take: Array[SpinBox] = []
var trade_description: Label
var dev_status: Label
var buttons: Dictionary = {}
var tabs: TabContainer
var hand_heading: Label
var resource_buttons: Array[Button] = []
var resource_counts: Array[Label] = []
var turn_controls: Dictionary = {}
var previous_phase := ""
var bank_status: Label
var new_game_confirmation: ConfirmationDialog
var privacy_enabled := false
var privacy_locked := false
var privacy_owner := -1
var privacy_overlay: Control
var privacy_message: Label
var privacy_ready: Button

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var objects: Node3D = $Objects


func _ready() -> void:
	rules = IslandRules.new(-1, player_count)
	_make_board()
	_make_ports()
	_make_markers()
	_make_dice()
	var desert := _tile_position(rules.robber_tile)
	robber_node = _spawn_piece("robber", Color("262b2a"), desert + Vector3.UP * 0.12)
	homes[robber_node] = desert
	_build_ui()
	grabber.dice_shortcuts_enabled = false
	grabber.grab_finished.connect(_on_physical_release)
	grabber.placement_message.connect(_placement_message)
	_refresh()


func _physics_process(delta: float) -> void:
	if waiting_roll and dice.size() == 2:
		var stable := true
		for index in range(dice.size()):
			var die := dice[index]
			if (
				die.global_position.x < -3.4
				or die.global_position.x > 4.0
				or absf(die.global_position.z) > 2.3
				or die.global_position.y < 0.75
			):
				stable = false
				_help("Un dado está fuera de la mesa. Usa Recolocar dados y vuelve a tirar.")
			var basis := die.global_basis.orthonormalized()
			var upright := maxf(absf(basis.x.dot(Vector3.UP)), absf(basis.y.dot(Vector3.UP)))
			upright = maxf(upright, absf(basis.z.dot(Vector3.UP)))
			_unstick_die(die, index, upright, delta)
			if (
				die.is_grabbed
				or die.linear_velocity.length() > 0.07
				or die.angular_velocity.length() > 0.16
				or upright < 0.96
			):
				stable = false
		settled_time = settled_time + delta if stable else 0.0
		if settled_time >= 1.0:
			_finish_roll()

	for key in homes:
		var piece := key as IslandPiece3D
		if not is_instance_valid(piece) or piece == grabber.held or piece.freeze:
			continue
		var home: Vector3 = homes[piece]
		var displacement := Vector3(
			home.x - piece.global_position.x, 0, home.z - piece.global_position.z
		)
		var velocity := Vector3(piece.linear_velocity.x, 0, piece.linear_velocity.z)
		if displacement.length() >= 0.012 or velocity.length() >= 0.03:
			var acceleration := displacement * 28.0 - velocity * 9.0
			if piece.sleeping:
				piece.sleeping = false
			piece.apply_central_force(acceleration.limit_length(20.0) * piece.mass)
		if road_rotations.has(piece):
			_steer_road(piece, road_rotations[piece])


func _unstick_die(die: Dice3D, index: int, upright: float, delta: float) -> void:
	var slow := die.linear_velocity.length() < 0.07 and die.angular_velocity.length() < 0.16
	if (
		die.is_grabbed
		or upright >= 0.96
		or not slow
		or die.global_position.y < 0.75
		or die.global_position.x < -3.4
		or die.global_position.x > 4.0
		or absf(die.global_position.z) > 2.3
	):
		stuck_times[index] = 0.0
		return
	stuck_times[index] += delta
	if stuck_times[index] < 1.2 or nudge_counts[index] >= 3:
		return
	stuck_times[index] = 0.0
	nudge_counts[index] += 1
	var inward := Vector3(2.97 - die.global_position.x, 0, -die.global_position.z).normalized()
	die.sleeping = false
	die.apply_central_impulse((Vector3.UP * 1.1 + inward * 0.35) * die.mass)
	die.apply_torque_impulse(
		Vector3(randf_range(-0.7, 0.7), 0.25, randf_range(-0.7, 0.7)) * die.mass
	)
	_help("Un dado estaba inclinado; se le ha aplicado un pequeño impulso físico.")


func _steer_road(piece: IslandPiece3D, target: Quaternion) -> void:
	var error := (target * piece.global_basis.get_rotation_quaternion().inverse()).normalized()
	if error.w < 0:
		error = Quaternion(-error.x, -error.y, -error.z, -error.w)
	var vector := Vector3(error.x, error.y, error.z)
	var length := vector.length()
	if length < 0.01 and piece.angular_velocity.length() < 0.05:
		return
	var angular_error := Vector3.ZERO
	if length > 0.0001:
		angular_error = vector / length * (2.0 * atan2(length, error.w))
	var torque := (angular_error * 4.0 - piece.angular_velocity * 1.4) * (piece.mass * 0.8)
	if angular_error.length() > 0.06 and piece.angular_velocity.length() < 0.2:
		torque += angular_error.normalized() * piece.mass * 0.8
	if piece.sleeping:
		piece.sleeping = false
	piece.apply_torque(torque.limit_length(piece.mass * 3.0))


func _make_board() -> void:
	var mesh := _hex_mesh()
	for i in range(rules.board.tiles.size()):
		var tile: Dictionary = rules.board.tiles[i]
		var hex := MeshInstance3D.new()
		hex.mesh = mesh
		hex.position = _tile_position(i)
		var material := StandardMaterial3D.new()
		var terrain: int = tile["terrain"]
		material.albedo_color = Color("c3ab78") if terrain == IslandBoard.DESERT else Color.WHITE
		if terrain != IslandBoard.DESERT:
			material.albedo_texture = RESOURCE_ART[terrain]
		material.roughness = 0.9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		hex.material_override = material
		$Board/Tiles.add_child(hex)
		if terrain == IslandBoard.DESERT:
			continue
		var badge := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.095
		disc.bottom_radius = 0.095
		disc.height = 0.015
		badge.mesh = disc
		badge.position = hex.position + Vector3.UP * 0.016
		badge.material_override = BoardGeometry3D.make_material(Color("f3e5bc"))
		$Board/Tiles.add_child(badge)
		var label := Label3D.new()
		label.text = str(tile["number"])
		label.font_size = 50
		label.pixel_size = 0.0018
		label.position = hex.position + Vector3.UP * 0.027
		label.rotation_degrees.x = -90
		label.modulate = Color("9d352b") if tile["number"] in [6, 8] else Color("293b30")
		$Board/Tiles.add_child(label)


func _make_ports() -> void:
	for port in rules.board.ports:
		var edge_id: int = port["edge"]
		var position := _edge_position(edge_id)
		var outward := Vector3(position.x, 0, position.z).normalized()
		var label := Label3D.new()
		var resource: int = port["resource"]
		label.text = "3:1" if resource == -1 else "%s 2:1" % PORT_NAMES[resource]
		label.font_size = 38
		label.pixel_size = 0.0021
		label.position = position + outward * 0.16 + Vector3.UP * 0.035
		label.rotation_degrees.x = -90
		label.modulate = Color("fff3bc")
		$Board/Tiles.add_child(label)


func _hex_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var a := deg_to_rad(30.0 + i * 60.0)
		var b := deg_to_rad(30.0 + (i + 1) * 60.0)
		for vertex in [
			Vector3.ZERO,
			Vector3(cos(a) * RADIUS, 0, sin(a) * RADIUS),
			Vector3(cos(b) * RADIUS, 0, sin(b) * RADIUS)
		]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(
				Vector2(vertex.x / (RADIUS * 2.0) + 0.5, vertex.z / (RADIUS * 2.0) + 0.5)
			)
			surface.add_vertex(vertex)
	return surface.commit()


func _tile_position(id: int) -> Vector3:
	var coord: Vector2i = rules.board.tiles[id]["coord"]
	return Vector3(
		sqrt(3.0) * RADIUS * (coord.x + coord.y * 0.5), HEIGHT + 0.004, 1.5 * RADIUS * coord.y
	)


func _vertex_position(id: int) -> Vector3:
	var point: Vector2i = rules.board.vertices[id]
	return Vector3(point.x * sqrt(3.0) * RADIUS * 0.5, HEIGHT + 0.01, point.y * RADIUS * 0.5)


func _edge_position(id: int) -> Vector3:
	var edge: Vector2i = rules.board.edges[id]
	return (_vertex_position(edge.x) + _vertex_position(edge.y)) * 0.5


func _make_markers() -> void:
	marker_legal = BoardGeometry3D.make_material(Color("9ee9aa"))
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	for id in range(rules.board.vertices.size()):
		markers_vertex.append(_marker(mesh, _vertex_position(id)))
	for id in range(rules.board.edges.size()):
		markers_edge.append(_marker(mesh, _edge_position(id)))
	for id in range(rules.board.tiles.size()):
		markers_tile.append(_marker(mesh, _tile_position(id) + Vector3.UP * 0.04))


func _marker(mesh: SphereMesh, position: Vector3) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.position = position + Vector3.UP * 0.04
	marker.visible = false
	$Board/Tiles.add_child(marker)
	return marker


func _make_dice() -> void:
	_make_dice_tray()
	for i in range(2):
		var die := DICE.instantiate() as Dice3D
		die.position = Vector3(2.97, 1.2, -0.8 + i * 1.6)
		die.collision_mask |= 4
		objects.add_child(die)
		die.result_ready.connect(_on_die_result.bind(i))
		dice.append(die)


func _make_dice_tray() -> void:
	# La mesa se amplía solo en este modo para que la bandeja tenga espacio real.
	var table_mesh := $Table/Visual.mesh.duplicate() as BoxMesh
	table_mesh.size = Vector3(7.4, 0.24, 4.6)
	$Table/Visual.mesh = table_mesh
	var table_shape := $Table/CollisionShape3D.shape.duplicate() as BoxShape3D
	table_shape.size = Vector3(7.4, 0.24, 4.6)
	$Table/CollisionShape3D.shape = table_shape
	$Table.position.x = 0.3
	# Bordes físicos, no invisibles: contienen los dados sin sustituir su movimiento.
	var body := StaticBody3D.new()
	body.name = "DiceTray"
	# Capa exclusiva para la bandeja: los dados chocan, el rayo puede seleccionarlos.
	body.collision_layer = 4
	body.collision_mask = 0
	$Board.add_child(body)
	var material := BoardGeometry3D.make_material(Color(0.57, 0.76, 0.66, 0.28))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var walls := [
		[Vector3(2.02, HEIGHT + 0.39, 0), Vector3(0.08, 0.78, 2.9)],
		[Vector3(3.92, HEIGHT + 0.39, 0), Vector3(0.08, 0.78, 2.9)],
		[Vector3(2.97, HEIGHT + 0.39, -1.45), Vector3(1.98, 0.78, 0.08)],
		[Vector3(2.97, HEIGHT + 0.39, 1.45), Vector3(1.98, 0.78, 0.08)],
	]
	for wall in walls:
		var shape := BoxShape3D.new()
		shape.size = wall[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = wall[0]
		body.add_child(collision)
		var mesh := BoxMesh.new()
		mesh.size = wall[1]
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = wall[0]
		visual.material_override = material
		body.add_child(visual)


func _spawn_piece(kind: String, color: Color, position: Vector3) -> IslandPiece3D:
	var piece := PIECE.instantiate() as IslandPiece3D
	piece.kind = kind
	piece.piece_color = color
	piece.position = position
	objects.add_child(piece)
	return piece


func _set_mode(mode: String) -> void:
	selection_mode = mode
	grabber.set_process_unhandled_input(mode.is_empty() and not privacy_locked)
	_update_markers()


func _unhandled_input(event: InputEvent) -> void:
	if not privacy_locked and event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if (focus is LineEdit or focus is TextEdit) and focus.is_visible_in_tree():
			return
		if event.keycode in [KEY_R, KEY_T] and rules.phase == IslandRules.ROLL:
			_roll()
			get_viewport().set_input_as_handled()
			return
	if privacy_locked or selection_mode.is_empty() or not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var origin := camera.project_ray_origin(event.position)
	var direction := camera.project_ray_normal(event.position)
	if absf(direction.y) < 0.0001:
		return
	var distance := (HEIGHT - origin.y) / direction.y
	if distance < 0:
		return
	var point: Vector3 = origin + direction * distance
	_select_board(point)
	get_viewport().set_input_as_handled()


func _select_board(point: Vector3) -> void:
	var id := _nearest(point, selection_mode)
	if id < 0:
		_help("Selecciona una marca en el tablero.")
		return
	var ok := false
	match selection_mode:
		"settlement":
			ok = rules.place_settlement(id)
			if ok:
				var piece := _spawn_piece(
					"settlement",
					PLAYER_COLORS[rules.building_owner[id]],
					_vertex_position(id) + Vector3.UP * 0.15
				)
				piece.display_name += " J%d" % (rules.building_owner[id] + 1)
				building_nodes[id] = piece
				homes[piece] = _vertex_position(id)
		"city":
			ok = rules.upgrade_city(id)
			if ok:
				var piece: IslandPiece3D = building_nodes[id]
				piece.set_kind("city")
				piece.display_name += " J%d" % (rules.building_owner[id] + 1)
		"road":
			ok = rules.place_road(id)
			if ok:
				var piece := _spawn_piece(
					"road",
					PLAYER_COLORS[rules.road_owner[id]],
					_edge_position(id) + Vector3.UP * 0.12
				)
				var edge: Vector2i = rules.board.edges[id]
				var direction := _vertex_position(edge.y) - _vertex_position(edge.x)
				piece.rotation.y = atan2(-direction.z, direction.x)
				road_rotations[piece] = Quaternion(Vector3.UP, piece.rotation.y)
				piece.display_name += " J%d" % (rules.road_owner[id] + 1)
				road_nodes[id] = piece
				homes[piece] = _edge_position(id)
		"robber":
			ok = rules.move_robber(id)
			if ok:
				homes[robber_node] = _tile_position(id)
	if ok:
		_set_mode("")
		_refresh()
		_help(_phase_guidance())
	else:
		_help("Acción no permitida: revisa conexión, distancia, recursos y turno.")


func _nearest(point: Vector3, mode: String) -> int:
	var count := (
		rules.board.vertices.size()
		if mode in ["settlement", "city"]
		else (rules.board.edges.size() if mode == "road" else rules.board.tiles.size())
	)
	var best := -1
	var threshold := (
		0.14 if mode in ["settlement", "city"] else (0.12 if mode == "road" else RADIUS * 1.02)
	)
	for i in range(count):
		var position := (
			_vertex_position(i)
			if mode in ["settlement", "city"]
			else (_edge_position(i) if mode == "road" else _tile_position(i))
		)
		var distance := Vector2(point.x - position.x, point.z - position.z).length()
		if distance < threshold:
			threshold = distance
			best = i
	return best


func _update_markers() -> void:
	for i in range(markers_vertex.size()):
		var visible_now := selection_mode in ["settlement", "city"]
		if visible_now:
			var legal := (
				rules.can_settlement(i) if selection_mode == "settlement" else rules.can_city(i)
			)
			markers_vertex[i].visible = legal
			markers_vertex[i].material_override = marker_legal
		else:
			markers_vertex[i].visible = false
	for i in range(markers_edge.size()):
		markers_edge[i].visible = selection_mode == "road" and rules.can_road(i)
		markers_edge[i].material_override = marker_legal
	for i in range(markers_tile.size()):
		markers_tile[i].visible = selection_mode == "robber" and i != rules.robber_tile
		markers_tile[i].material_override = marker_legal


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IslandUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 350
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", _panel_style(Color("142b25")))
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	game_title = _label(column, "ISLA DE RECURSOS")
	game_title.add_theme_font_size_override("font_size", 16)
	game_title.add_theme_color_override("font_color", Color("f5e9ca"))
	status = _label(column, "")
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("a9dfbd"))
	hands = _label(column, "")
	hands.add_theme_font_size_override("font_size", 12)
	hands.add_theme_color_override("font_color", Color("cbd6c6"))
	help = _label(column, "Prepara tu primer pueblo en una marca verde.")
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("e6d8b7"))
	tabs = TabContainer.new()
	tabs.name = "Actions"
	tabs.add_theme_font_size_override("font_size", 12)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_build_turn_tab(_tab_page("Turno"))
	_build_trade_tab(_tab_page("Comercio"))
	_build_development_tab(_tab_page("Cartas"))
	_build_options_tab(_tab_page("Partida"))
	_build_hand(layer)
	_build_privacy_overlay(layer)
	new_game_confirmation = ConfirmationDialog.new()
	new_game_confirmation.title = "Nueva isla"
	new_game_confirmation.dialog_text = "¿Descartar la partida actual y crear una isla nueva?"
	new_game_confirmation.ok_button_text = "Crear nueva isla"
	new_game_confirmation.confirmed.connect(_confirm_new_game)
	layer.add_child(new_game_confirmation)


func _tab_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column


func _build_turn_tab(column: VBoxContainer) -> void:
	var roll_box := VBoxContainer.new()
	column.add_child(roll_box)
	turn_controls["roll"] = roll_box
	_label(roll_box, "Tira con R o arrastra y suelta ambos dados.")
	_button(roll_box, "roll", "Lanzar dados  ·  R", _roll)
	_button(roll_box, "cancel_roll", "Cancelar tirada", _cancel_roll)
	_button(roll_box, "reset_dice", "Recolocar dados", _reset_dice)
	var build_box := VBoxContainer.new()
	column.add_child(build_box)
	turn_controls["build"] = build_box
	_label(build_box, "CONSTRUIR · elige una opción y toca el tablero")
	_button(build_box, "road", "Camino", _begin_selection.bind("road"))
	_button(build_box, "settlement", "Pueblo", _begin_selection.bind("settlement"))
	_button(build_box, "city", "Ciudad", _begin_selection.bind("city"))
	buttons["road"].tooltip_text = "Requiere recursos y una conexión libre."
	buttons["settlement"].tooltip_text = "Requiere recursos, conexión y distancia libre."
	buttons["city"].tooltip_text = "Requiere recursos y un pueblo propio."
	var costs := _label(
		build_box,
		"Camino: madera + ladrillo\nPueblo: madera + ladrillo + lana + trigo\nCiudad: 2 trigo + 3 mineral"
	)
	costs.add_theme_font_size_override("font_size", 12)
	_button(build_box, "cancel_selection", "Cancelar selección", _cancel_selection)
	_button(build_box, "end", "Terminar turno", _end_turn)
	var resource_box := VBoxContainer.new()
	column.add_child(resource_box)
	turn_controls["resource"] = resource_box
	_label(resource_box, "Elige un recurso tocando una carta de la mano inferior.")
	var steal_box := VBoxContainer.new()
	column.add_child(steal_box)
	turn_controls["steal"] = steal_box
	_label(steal_box, "Elige a quién robar:")
	var row := _row(steal_box)
	victim = OptionButton.new()
	victim.name = "Victim"
	victim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(victim)
	_button(row, "steal", "Robar", _steal)
	var hints := _label(
		column,
		"Las marcas verdes señalan las ubicaciones válidas\nDerecho: orbitar · Rueda: zoom · H: recuperar"
	)
	hints.add_theme_font_size_override("font_size", 12)


func _build_trade_tab(column: VBoxContainer) -> void:
	var bank_box := VBoxContainer.new()
	column.add_child(bank_box)
	turn_controls["bank"] = bank_box
	_label(bank_box, "BANCO · 4:1, o 3:1 / 2:1 con puerto")
	bank_status = _label(bank_box, "")
	var row := _row(bank_box)
	var give_box := VBoxContainer.new()
	give_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(give_box)
	_label(give_box, "Entrego")
	give = OptionButton.new()
	give.name = "Give"
	give_box.add_child(give)
	var take_box := VBoxContainer.new()
	take_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(take_box)
	_label(take_box, "Recibo")
	take = OptionButton.new()
	take.name = "Take"
	take_box.add_child(take)
	for i in range(5):
		give.add_item(IslandBoard.RESOURCE_NAMES[i], i)
		take.add_item(IslandBoard.RESOURCE_NAMES[i], i)
	take.select(1)
	give.item_selected.connect(_bank_selection_changed)
	_button(bank_box, "trade", "Cambiar con el banco", _trade)
	var offer_box := VBoxContainer.new()
	column.add_child(offer_box)
	turn_controls["offer"] = offer_box
	_label(offer_box, "ENTRE JUGADORES · acuerda una oferta")
	trade_partner = OptionButton.new()
	for player in range(4):
		trade_partner.add_item("Proponer a J%d" % (player + 1), player)
	offer_box.add_child(trade_partner)
	_label(offer_box, "Recurso · ofrezco / pido")
	_trade_inputs(offer_box)
	_button(offer_box, "offer", "Proponer intercambio", _offer_trade)
	var response := VBoxContainer.new()
	column.add_child(response)
	turn_controls["response"] = response
	_label(response, "OFERTA RECIBIDA")
	trade_description = _label(response, "Sin oferta pendiente.")
	row = _row(response)
	_button(row, "accept", "Aceptar", _respond_trade.bind(true))
	_button(row, "reject", "Rechazar", _respond_trade.bind(false))


func _build_development_tab(column: VBoxContainer) -> void:
	_label(column, "DESARROLLO · cuesta lana + trigo + mineral")
	dev_status = _label(column, "")
	_button(column, "buy_dev", "Comprar carta", _buy_development)
	_label(column, "Juega una carta de un turno anterior:")
	dev_choice = OptionButton.new()
	for card in [
		IslandRules.KNIGHT,
		IslandRules.ROAD_BUILDING,
		IslandRules.YEAR_OF_PLENTY,
		IslandRules.MONOPOLY_CARD
	]:
		dev_choice.add_item(IslandRules.DEV_NAMES[card], card)
	column.add_child(dev_choice)
	_button(column, "play_dev", "Jugar carta", _play_development)
	_label(column, "Una carta jugable por turno. Los puntos de victoria cuentan al comprarlos.")


func _build_options_tab(column: VBoxContainer) -> void:
	_label(column, "PARTIDA LOCAL")
	_button(column, "save", "Guardar partida", _save_game)
	_button(column, "load", "Cargar partida guardada", _load_game)
	_button(column, "new", "Nueva isla (descarta la partida)", _new_game)
	_button(column, "privacy", "Manos privadas: desactivadas", _toggle_privacy)
	_label(
		column,
		(
			"Opcional: oculta la pantalla al pasar el equipo. No impide que alguien mire "
			+ "ni protege el guardado. Se guarda el estado lógico, no las poses físicas."
		)
	)


func _build_hand(layer: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.name = "ResourceHand"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 366
	panel.offset_right = -18
	panel.offset_top = -164
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", _panel_style(Color("142b25")))
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	hand_heading = _label(column, "RECURSOS")
	hand_heading.add_theme_font_size_override("font_size", 12)
	hand_heading.add_theme_color_override("font_color", Color("cbd6c6"))
	var row := _row(column)
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for resource in range(5):
		var card := Button.new()
		card.name = "Resource%d" % resource
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.tooltip_text = IslandBoard.RESOURCE_NAMES[resource]
		card.pressed.connect(_resource_pressed.bind(resource))
		card.add_theme_stylebox_override("normal", _card_style(Color("eadcb9")))
		card.add_theme_stylebox_override("hover", _card_style(Color("ffffff")))
		card.add_theme_stylebox_override("pressed", _card_style(Color("b5d4b4")))
		card.add_theme_stylebox_override("disabled", _card_style(Color("eadcb9")))
		row.add_child(card)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 2)
		card.add_child(content)
		var art := TextureRect.new()
		art.texture = RESOURCE_ART[resource]
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
		var count := Label.new()
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_font_size_override("font_size", 14)
		count.add_theme_color_override("font_color", Color("263a2d"))
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(count)
		resource_buttons.append(card)
		resource_counts.append(count)


func _build_privacy_overlay(layer: CanvasLayer) -> void:
	privacy_overlay = Control.new()
	privacy_overlay.name = "PassDevice"
	privacy_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	privacy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	privacy_overlay.visible = false
	layer.add_child(privacy_overlay)
	var background := ColorRect.new()
	background.color = Color("10241e")
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	privacy_overlay.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	privacy_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("203d31")))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	privacy_message = _label(column, "")
	privacy_message.add_theme_font_size_override("font_size", 22)
	_label(column, "Entrega el equipo sin mirar las cartas de la otra persona.")
	privacy_ready = Button.new()
	privacy_ready.name = "Ready"
	privacy_ready.text = "Ya estoy listo · mostrar mi mano"
	privacy_ready.pressed.connect(_unlock_privacy)
	column.add_child(privacy_ready)


func _active_hand_player() -> int:
	if rules.phase == IslandRules.DISCARD:
		return rules.discard_player
	if rules.phase == IslandRules.TRADE_RESPONSE:
		return int(rules.trade_offer.get("to", rules.turn))
	return rules.turn


func _toggle_privacy() -> void:
	if waiting_roll or manual_roll or grabber.held != null:
		_help("Termina la tirada y suelta los objetos antes de cambiar la privacidad.")
		return
	privacy_enabled = not privacy_enabled
	privacy_owner = -1
	privacy_locked = false
	_refresh()


func _unlock_privacy() -> void:
	privacy_locked = false
	privacy_overlay.visible = false
	_set_mode(selection_mode)
	_refresh()


func _update_privacy(player: int) -> void:
	var just_locked := false
	if privacy_enabled and privacy_owner != player:
		privacy_owner = player
		privacy_locked = true
		just_locked = true
	$IslandUI/Panel.visible = not privacy_locked
	$IslandUI/ResourceHand.visible = not privacy_locked
	privacy_overlay.visible = privacy_locked
	if just_locked:
		privacy_ready.grab_focus()
	privacy_message.text = "Pasa el equipo a J%d" % (player + 1)
	buttons["privacy"].text = (
		"Manos privadas: activadas" if privacy_enabled else "Manos privadas: desactivadas"
	)
	if privacy_locked:
		grabber.set_process_unhandled_input(false)


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("456455")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row


func _button(parent: Node, id: String, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = id
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("eff5e8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _card_style(Color("315245")))
	button.add_theme_stylebox_override("hover", _card_style(Color("426d58")))
	button.add_theme_stylebox_override("pressed", _card_style(Color("66876d")))
	button.add_theme_stylebox_override("disabled", _card_style(Color("233a31")))
	button.pressed.connect(callback)
	parent.add_child(button)
	buttons[id] = button


func _refresh() -> void:
	match rules.phase:
		IslandRules.SETUP_SETTLEMENT:
			_set_mode("settlement")
		IslandRules.SETUP_ROAD:
			_set_mode("road")
		IslandRules.ROBBER:
			_set_mode("robber")
		IslandRules.FREE_ROADS:
			_set_mode("road")
		_:
			if rules.phase != IslandRules.ACTION:
				_set_mode("")
	var phases := {
		IslandRules.SETUP_SETTLEMENT: "Preparación: pueblo",
		IslandRules.SETUP_ROAD: "Preparación: camino adyacente",
		IslandRules.ROLL: "Lanza los dos dados",
		IslandRules.DISCARD:
		(
			"J%d descarta: faltan %d"
			% [rules.discard_player + 1, rules.discard_due[maxi(0, rules.discard_player)]]
		),
		IslandRules.ROBBER: "Mueve el ladrón a otra casilla",
		IslandRules.STEAL: "Elige a quién robar",
		IslandRules.ACTION: "Construye, comercia o termina",
		IslandRules.FREE_ROADS: "Coloca caminos gratis: %d" % rules.free_roads_left,
		IslandRules.PLENTY: "Abundancia: faltan %d recursos" % rules.plenty_left,
		IslandRules.MONOPOLY: "Monopolio: elige un recurso",
		IslandRules.TRADE_RESPONSE:
		"J%d responde a la oferta" % int(rules.trade_offer.get("to", 0) + 1),
		IslandRules.FINISHED: "Victoria de J%d" % (rules.winner + 1),
	}
	var last := (
		""
		if rules.last_dice == Vector2i.ZERO
		else " · dados %d + %d" % [rules.last_dice.x, rules.last_dice.y]
	)
	status.text = "Turno J%d · %s%s" % [rules.turn + 1, phases[rules.phase], last]
	if waiting_roll:
		status.text += "\nEsperando a que ambos dados se detengan…"
	game_title.text = "ISLA DE RECURSOS · %d jugadores" % rules.players
	trade_partner.set_item_disabled(3, rules.players < 4)
	if trade_partner.get_selected_id() >= rules.players:
		trade_partner.select(0)
	var scores: Array[String] = []
	var names := ["naranja", "azul", "rojo", "blanco"]
	for player in range(rules.players):
		var points := (
			rules.score(player)
			if rules.phase == IslandRules.FINISHED
			else rules.public_score(player)
		)
		scores.append("J%d %s · %d puntos" % [player + 1, names[player], points])
	hands.text = "  |  ".join(scores)
	var active_hand := _active_hand_player()
	_update_privacy(active_hand)
	hand_heading.text = "RECURSOS · J%d" % (active_hand + 1)
	if rules.phase == IslandRules.DISCARD:
		hand_heading.text += " · toca una carta para descartar"
	elif rules.phase in [IslandRules.PLENTY, IslandRules.MONOPOLY]:
		hand_heading.text += " · toca el recurso que eliges"
	for resource in range(5):
		resource_counts[resource].text = (
			"%s  × %d"
			% [IslandBoard.RESOURCE_NAMES[resource], rules.resources[active_hand][resource]]
		)
		resource_buttons[resource].disabled = (
			rules.phase not in [IslandRules.DISCARD, IslandRules.PLENTY, IslandRules.MONOPOLY]
		)
		if rules.phase == IslandRules.DISCARD and rules.resources[active_hand][resource] == 0:
			resource_buttons[resource].disabled = true
		if rules.phase == IslandRules.PLENTY and rules.bank[resource] == 0:
			resource_buttons[resource].disabled = true
	bank_status.text = "Banco: " + _resource_summary(rules.bank)
	var cards: Array = rules.dev_ready[active_hand]
	var fresh: Array = rules.dev_new[active_hand]
	dev_status.text = (
		(
			"J%d · Disponibles: Caballeros %d · Caminos %d\n"
			+ "Abundancia %d · Monopolio %d · Puntos %d\n"
			+ "Nuevas (próximo turno): Caballeros %d · Caminos %d\n"
			+ "Abundancia %d · Monopolio %d · Puntos %d\n"
			+ "Mazo %d · Ruta: %s · Ejército: %s"
		)
		% [
			active_hand + 1,
			cards[0],
			cards[2],
			cards[3],
			cards[4],
			cards[1],
			fresh[0],
			fresh[2],
			fresh[3],
			fresh[4],
			fresh[1],
			rules.development_deck.size(),
			_award_text(rules.longest_road),
			_award_text(rules.largest_army)
		]
	)
	if rules.phase == IslandRules.TRADE_RESPONSE:
		trade_description.text = (
			"J%d ofrece %s; pide %s a J%d."
			% [
				rules.turn + 1,
				_resource_summary(rules.trade_offer["give"]),
				_resource_summary(rules.trade_offer["take"]),
				int(rules.trade_offer["to"]) + 1
			]
		)
	else:
		trade_description.text = "Sin oferta pendiente."
	buttons["trade"].text = "Cambiar %d por 1" % rules.bank_rate(rules.turn, give.get_selected_id())
	buttons["roll"].disabled = rules.phase != IslandRules.ROLL or waiting_roll
	buttons["cancel_roll"].visible = waiting_roll or manual_roll
	buttons["cancel_roll"].disabled = not waiting_roll and not manual_roll
	var action := rules.phase == IslandRules.ACTION and not waiting_roll
	for id in ["road", "settlement", "city", "trade", "end", "offer", "buy_dev"]:
		buttons[id].disabled = not action
	if action:
		for kind in ["road", "settlement", "city"]:
			buttons[kind].disabled = not _has_build_option(kind)
		buttons["buy_dev"].disabled = (
			rules.development_deck.is_empty()
			or not rules._can_pay(rules.turn, IslandRules.DEV_COST)
		)
	buttons["cancel_selection"].visible = action and not selection_mode.is_empty()
	buttons["cancel_selection"].disabled = not action or selection_mode.is_empty()
	buttons["steal"].disabled = rules.phase != IslandRules.STEAL
	var playable := -1
	for index in range(dev_choice.item_count):
		var card := dev_choice.get_item_id(index)
		var amount: int = rules.dev_ready[active_hand][card]
		dev_choice.set_item_text(index, "%s · %d" % [IslandRules.DEV_NAMES[card], amount])
		dev_choice.set_item_disabled(index, amount == 0)
		if amount > 0 and playable < 0:
			playable = index
	if (
		playable >= 0
		and (dev_choice.selected < 0 or dev_choice.is_item_disabled(dev_choice.selected))
	):
		dev_choice.select(playable)
	buttons["play_dev"].disabled = (
		waiting_roll
		or manual_roll
		or rules.phase not in [IslandRules.ROLL, IslandRules.ACTION]
		or rules.dev_played
		or playable < 0
	)
	buttons["accept"].disabled = rules.phase != IslandRules.TRADE_RESPONSE
	buttons["reject"].disabled = rules.phase != IslandRules.TRADE_RESPONSE
	victim.clear()
	for player in rules.eligible_victims:
		victim.add_item("J%d" % (player + 1), player)
	if victim.item_count == 0:
		victim.add_item("Sin víctima", -1)
	victim.disabled = rules.phase != IslandRules.STEAL
	turn_controls["roll"].visible = rules.phase == IslandRules.ROLL
	turn_controls["build"].visible = rules.phase == IslandRules.ACTION
	turn_controls["resource"].visible = (
		rules.phase in [IslandRules.DISCARD, IslandRules.PLENTY, IslandRules.MONOPOLY]
	)
	turn_controls["steal"].visible = rules.phase == IslandRules.STEAL
	turn_controls["bank"].visible = rules.phase != IslandRules.TRADE_RESPONSE
	turn_controls["offer"].visible = rules.phase != IslandRules.TRADE_RESPONSE
	turn_controls["response"].visible = rules.phase == IslandRules.TRADE_RESPONSE
	if rules.phase != previous_phase:
		tabs.current_tab = 1 if rules.phase == IslandRules.TRADE_RESPONSE else 0
		previous_phase = rules.phase
		_help(_phase_guidance())
	for player in range(4):
		trade_partner.set_item_disabled(player, player >= rules.players or player == rules.turn)
	if trade_partner.get_selected_id() == rules.turn:
		trade_partner.select((rules.turn + 1) % rules.players)
	_update_markers()


func _has_build_option(kind: String) -> bool:
	var count := rules.board.edges.size() if kind == "road" else rules.board.vertices.size()
	for id in range(count):
		match kind:
			"road":
				if rules.can_road(id):
					return true
			"settlement":
				if rules.can_settlement(id):
					return true
			"city":
				if rules.can_city(id):
					return true
	return false


func _phase_guidance() -> String:
	var tips := {
		IslandRules.SETUP_SETTLEMENT:
		"Coloca tu pueblo en una marca verde; deja espacio entre pueblos.",
		IslandRules.SETUP_ROAD: "Elige un camino verde junto al pueblo que acabas de colocar.",
		IslandRules.ROLL: "Pulsa R o lanza ambos dados con el ratón. Espera a que se detengan.",
		IslandRules.DISCARD:
		"J%d: toca una carta inferior para devolverla al banco." % (rules.discard_player + 1),
		IslandRules.ROBBER: "Mueve el ladrón: toca una marca verde en otro terreno.",
		IslandRules.STEAL: "Elige una persona adyacente para robar un recurso.",
		IslandRules.FREE_ROADS: "Coloca los caminos gratuitos en las marcas verdes.",
		IslandRules.PLENTY: "Toca una carta inferior para elegir un recurso del banco.",
		IslandRules.MONOPOLY: "Toca una carta inferior para elegir el recurso del monopolio.",
		IslandRules.TRADE_RESPONSE: "La persona destinataria debe aceptar o rechazar la oferta.",
		IslandRules.ACTION: "Construye, comercia o usa una carta; después termina el turno.",
		IslandRules.FINISHED: "La partida ha terminado. En Partida puedes empezar otra isla.",
	}
	return tips.get(rules.phase, "")


func _bank_selection_changed(_index: int) -> void:
	_refresh()


func _resource_summary(amounts: Array) -> String:
	var entries: Array[String] = []
	for resource in range(5):
		if int(amounts[resource]) > 0:
			entries.append("%d %s" % [int(amounts[resource]), IslandBoard.RESOURCE_NAMES[resource]])
	return ", ".join(entries) if not entries.is_empty() else "nada"


func _resource_pressed(resource: int) -> void:
	if rules.phase == IslandRules.DISCARD:
		give.select(resource)
		_discard()
	elif rules.phase in [IslandRules.PLENTY, IslandRules.MONOPOLY]:
		take.select(resource)
		_choose_development_resource()


func _trade_inputs(parent: Node) -> void:
	for resource in range(5):
		var row := _row(parent)
		var name_label := _label(row, IslandBoard.RESOURCE_NAMES[resource])
		name_label.custom_minimum_size.x = 70
		for offer in [true, false]:
			var spin := SpinBox.new()
			spin.name = ("Offer" if offer else "Request") + str(resource)
			spin.min_value = 0
			spin.max_value = 19
			spin.step = 1
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spin)
			if offer:
				trade_give.append(spin)
			else:
				trade_take.append(spin)


func _award_text(owner: int) -> String:
	return "nadie" if owner < 0 else "J%d" % (owner + 1)


func _offer_trade() -> void:
	var offered: Array = []
	var requested: Array = []
	for i in range(5):
		offered.append(int(trade_give[i].value))
		requested.append(int(trade_take[i].value))
	if rules.propose_trade(trade_partner.get_selected_id(), offered, requested):
		_set_mode("")
		_help("La persona destinataria debe aceptar o rechazar la oferta.")
	else:
		_help("Oferta inválida: revisa jugador, cantidades y recursos disponibles.")
	_refresh()


func _respond_trade(accept: bool) -> void:
	var recipient: int = rules.trade_offer.get("to", -1)
	var ok := rules.respond_trade(recipient, accept)
	_refresh()
	if ok:
		_help("Intercambio aceptado." if accept else "Intercambio rechazado.")
	else:
		_help("No se puede aceptar: la persona destinataria no tiene los recursos pedidos.")


func _buy_development() -> void:
	if rules.buy_development():
		_help("Carta comprada. Las cartas jugables se activan a partir del próximo turno.")
	else:
		_help("No se puede comprar: faltan recursos o el mazo está vacío.")
	_refresh()


func _play_development() -> void:
	if waiting_roll or manual_roll or grabber.held != null:
		_help("Termina o cancela la tirada y suelta cualquier objeto antes de jugar la carta.")
		return
	if rules.play_development(dev_choice.get_selected_id()):
		_set_mode("")
		_help("Carta jugada. Completa su efecto antes de continuar.")
	else:
		_help("Carta no disponible, recién comprada, ya jugaste una o no puede aplicarse.")
	_refresh()


func _choose_development_resource() -> void:
	var resource := take.get_selected_id()
	var ok := false
	if rules.phase == IslandRules.PLENTY:
		ok = rules.take_plenty(resource)
	elif rules.phase == IslandRules.MONOPOLY:
		ok = rules.choose_monopoly(resource)
	_help("Recurso aplicado." if ok else "Recurso no disponible.")
	_refresh()


func _help(message: String) -> void:
	help.text = message


func _begin_selection(mode: String) -> void:
	if rules.phase != IslandRules.ACTION or waiting_roll:
		return
	if grabber.held != null:
		_help("Suelta el objeto antes de seleccionar una construcción.")
		return
	_set_mode(mode)
	_refresh()
	_help("Selecciona una marca verde en el tablero; cancela para volver a manipular piezas.")


func _cancel_selection() -> void:
	if rules.phase == IslandRules.ACTION:
		_set_mode("")
		_refresh()
		_help("Selección cancelada. Puedes manipular los objetos.")


func _roll() -> void:
	if rules.phase != IslandRules.ROLL or waiting_roll:
		return
	if grabber.held != null:
		_help("Suelta el objeto antes de tirar.")
		return
	tabs.current_tab = 0
	manual_roll = false
	manually_thrown = [false, false]
	waiting_roll = true
	settled_time = 0.0
	stuck_times = [0.0, 0.0]
	nudge_counts = [0, 0]
	roll_results = [0, 0]
	for die in dice:
		die.roll(0.55)
	_refresh()
	_help(
		(
			"Los resultados se leen cuando cada dado se detiene. "
			+ "Si quedan bloqueados, cancela y vuelve a lanzar."
		)
	)


func _reset_dice() -> void:
	if rules.phase != IslandRules.ROLL or grabber.held != null:
		_help("Suelta cualquier objeto antes de recolocar los dados.")
		return
	_cancel_roll()
	for i in range(dice.size()):
		dice[i].global_position = Vector3(2.97, 1.2, -0.8 + i * 1.6)
		dice[i].linear_velocity = Vector3.ZERO
		dice[i].angular_velocity = Vector3.ZERO
		dice[i].sleeping = false
	_refresh()
	_help("Dados recolocados en la bandeja. La tirada no se ha resuelto.")


func _on_physical_release(object: InteractiveTableObject, _target: Vector3, reason: String) -> void:
	if rules.phase != IslandRules.ROLL or waiting_roll or reason != "released":
		return
	var index := dice.find(object)
	if index < 0:
		return
	if not manual_roll:
		manually_thrown = [false, false]
		roll_results = [0, 0]
	tabs.current_tab = 0
	manual_roll = true
	manually_thrown[index] = true
	if manually_thrown[0] and manually_thrown[1]:
		manual_roll = false
		waiting_roll = true
		settled_time = 0.0
		stuck_times = [0.0, 0.0]
		nudge_counts = [0, 0]
		_help("Dados soltados. Espera a que ambos se detengan.")
	else:
		_help("Primer dado soltado. Tira ahora el otro, o pulsa R para lanzar los dos.")
	_refresh()


func _on_die_result(value: int, index: int) -> void:
	if waiting_roll and index >= 0 and index < 2 and value >= 1 and value <= 6:
		roll_results[index] = value


func _finish_roll() -> void:
	# Releer simultáneamente: el segundo dado podría haber movido al primero.
	roll_results = [dice[0].top_face(), dice[1].top_face()]
	waiting_roll = false
	manually_thrown = [false, false]
	for die in dice:
		die._awaiting_result = false
	if rules.roll(roll_results[0], roll_results[1]):
		_help("Dados aceptados: %d + %d." % [roll_results[0], roll_results[1]])
	_refresh()


func _cancel_roll() -> void:
	if not waiting_roll and not manual_roll:
		return
	waiting_roll = false
	manual_roll = false
	manually_thrown = [false, false]
	for die in dice:
		die._awaiting_result = false
	_refresh()
	_help("Tirada cancelada sin alterar el turno. Puedes lanzar de nuevo.")


func _trade() -> void:
	if not rules.trade_bank(give.get_selected_id(), take.get_selected_id()):
		_help("Cambio no permitido: revisa la proporción de tu puerto y las existencias.")
	else:
		_help("Cambio con el banco completado.")
	_refresh()


func _discard() -> void:
	if not rules.discard(give.get_selected_id()):
		_help("Selecciona un recurso disponible del jugador que debe descartar.")
	else:
		_help("Recurso devuelto al banco.")
	_refresh()


func _steal() -> void:
	if not rules.steal(victim.get_selected_id()):
		_help("Selecciona una víctima válida.")
	else:
		_help("Se robó un recurso al azar de la víctima.")
	_refresh()


func _end_turn() -> void:
	if rules.end_turn():
		_set_mode("")
		_help("Turno terminado.")
	_refresh()


func _save_game() -> void:
	if waiting_roll or manual_roll or grabber.held != null:
		_help("Suelta el objeto y termina o cancela la tirada antes de guardar.")
		return
	if rules.events.size() > IslandRules.MAX_EVENTS:
		_help("La partida supera el límite; se conserva el guardado anterior.")
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.island):
		_help("No se pudo guardar; comprueba el espacio e inténtalo de nuevo.")
		return
	_help("Partida guardada en este dispositivo.")


func _load_game() -> void:
	if waiting_roll or manual_roll or grabber.held != null:
		_help("Suelta el objeto y termina o cancela la tirada antes de cargar.")
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.island)
	if loaded.is_empty():
		_help("Guardado ausente o inválido; se conserva la partida actual.")
		return
	rules = loaded["value"] as IslandRules
	privacy_owner = -1
	_rebuild_loaded_board()
	_set_mode("")
	_refresh()
	_help(
		(
			"Cargada la copia anterior: el guardado principal falta o es inválido."
			if loaded["backup"]
			else "Partida cargada en este dispositivo."
		)
	)


func _rebuild_loaded_board() -> void:
	for child in $Board/Tiles.get_children():
		$Board/Tiles.remove_child(child)
		child.queue_free()
	for child in objects.get_children():
		if child is IslandPiece3D:
			objects.remove_child(child)
			child.queue_free()
	homes.clear()
	road_rotations.clear()
	building_nodes.clear()
	road_nodes.clear()
	markers_vertex.clear()
	markers_edge.clear()
	markers_tile.clear()
	_make_board()
	_make_ports()
	_make_markers()
	for id in range(rules.building_owner.size()):
		var player: int = rules.building_owner[id]
		if player < 0:
			continue
		var kind := "city" if rules.building_level[id] == 2 else "settlement"
		var piece := _spawn_piece(
			kind, PLAYER_COLORS[player], _vertex_position(id) + Vector3.UP * 0.15
		)
		piece.display_name += " J%d" % (player + 1)
		building_nodes[id] = piece
		homes[piece] = _vertex_position(id)
	for id in range(rules.road_owner.size()):
		var player: int = rules.road_owner[id]
		if player < 0:
			continue
		var piece := _spawn_piece(
			"road", PLAYER_COLORS[player], _edge_position(id) + Vector3.UP * 0.12
		)
		var edge: Vector2i = rules.board.edges[id]
		var direction := _vertex_position(edge.y) - _vertex_position(edge.x)
		piece.rotation.y = atan2(-direction.z, direction.x)
		piece.display_name += " J%d" % (player + 1)
		road_rotations[piece] = Quaternion(Vector3.UP, piece.rotation.y)
		road_nodes[id] = piece
		homes[piece] = _edge_position(id)
	var destination := _tile_position(rules.robber_tile)
	robber_node = _spawn_piece("robber", Color("262b2a"), destination + Vector3.UP * 0.12)
	homes[robber_node] = destination


func _new_game() -> void:
	new_game_confirmation.popup_centered()


func _confirm_new_game() -> void:
	get_tree().change_scene_to_file(scene_file_path)


func _placement_message(message: String) -> void:
	_help(message)
