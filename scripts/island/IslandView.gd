class_name IslandView
extends Node3D

const PIECE := preload("res://scenes/IslandPiece3D.tscn")
const DICE := preload("res://scenes/Dice3D.tscn")
const RADIUS := 0.4
const HEIGHT := 0.83
const PLAYER_COLORS := [Color("d99552"), Color("5a94bf"), Color("d05b55"), Color("deddd2")]
const TERRAIN_COLORS := [
	Color("376e4b"), Color("ad694a"), Color("9fbf69"), Color("d4b75c"), Color("8e969b")
]
const TERRAIN_LETTERS := ["M", "L", "O", "T", "R"]

@export_range(3, 4) var player_count := 3

var rules := IslandRules.new()
var save_path := "user://diceon_island.json"
var dice: Array[Dice3D] = []
var roll_results: Array[int] = [0, 0]
var waiting_roll := false
var settled_time := 0.0
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
var marker_invalid: Material
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
	grabber.placement_message.connect(_placement_message)
	_refresh()


func _physics_process(delta: float) -> void:
	if waiting_roll and dice.size() == 2:
		var stable := true
		for die in dice:
			var basis := die.global_basis.orthonormalized()
			var upright := maxf(absf(basis.x.dot(Vector3.UP)), absf(basis.y.dot(Vector3.UP)))
			upright = maxf(upright, absf(basis.z.dot(Vector3.UP)))
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
		material.albedo_color = (
			Color("c3ab78") if terrain == IslandBoard.DESERT else TERRAIN_COLORS[terrain]
		)
		material.roughness = 0.9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		hex.material_override = material
		$Board/Tiles.add_child(hex)
		var label := Label3D.new()
		label.text = (
			"DESIERTO"
			if terrain == IslandBoard.DESERT
			else "%s %d" % [TERRAIN_LETTERS[terrain], tile["number"]]
		)
		label.font_size = 44
		label.pixel_size = 0.0022
		label.position = hex.position + Vector3.UP * 0.018
		label.rotation_degrees.x = -90
		label.modulate = Color("f4ead5")
		if tile["number"] in [6, 8]:
			label.modulate = Color("ff9f88")
		$Board/Tiles.add_child(label)


func _make_ports() -> void:
	for port in rules.board.ports:
		var edge_id: int = port["edge"]
		var position := _edge_position(edge_id)
		var outward := Vector3(position.x, 0, position.z).normalized()
		var label := Label3D.new()
		var resource: int = port["resource"]
		label.text = "3:1" if resource == -1 else "%s 2:1" % TERRAIN_LETTERS[resource]
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
	marker_invalid = BoardGeometry3D.make_material(Color("6f7770"))
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
		die.position = Vector3(3.05, 1.2, -0.75 + i * 1.5)
		objects.add_child(die)
		die.result_ready.connect(_on_die_result.bind(i))
		dice.append(die)


func _make_dice_tray() -> void:
	# Bordes físicos, no invisibles: contienen los dados sin sustituir su movimiento.
	var body := StaticBody3D.new()
	body.name = "DiceTray"
	body.collision_layer = 1
	body.collision_mask = 0
	$Board.add_child(body)
	var material := BoardGeometry3D.make_material(Color("775a3f"))
	var walls := [
		[Vector3(2.16, HEIGHT + 0.39, 0), Vector3(0.08, 0.78, 3.2)],
		[Vector3(3.95, HEIGHT + 0.39, 0), Vector3(0.08, 0.78, 3.2)],
		[Vector3(3.05, HEIGHT + 0.39, -1.6), Vector3(1.87, 0.78, 0.08)],
		[Vector3(3.05, HEIGHT + 0.39, 1.6), Vector3(1.87, 0.78, 0.08)],
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
	grabber.set_process_unhandled_input(mode.is_empty())
	_update_markers()


func _unhandled_input(event: InputEvent) -> void:
	if selection_mode.is_empty() or not event is InputEventMouseButton:
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
		_help("Acción aceptada. Las piezas siguen siendo físicas.")
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
		markers_vertex[i].visible = visible_now
		if visible_now:
			var legal := (
				rules.can_settlement(i) if selection_mode == "settlement" else rules.can_city(i)
			)
			markers_vertex[i].material_override = marker_legal if legal else marker_invalid
	for i in range(markers_edge.size()):
		markers_edge[i].visible = selection_mode == "road"
		if selection_mode == "road":
			markers_edge[i].material_override = (
				marker_legal if rules.can_road(i) else marker_invalid
			)
	for i in range(markers_tile.size()):
		markers_tile[i].visible = selection_mode == "robber"
		if selection_mode == "robber":
			markers_tile[i].material_override = (
				marker_invalid if i == rules.robber_tile else marker_legal
			)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IslandUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = 365
	panel.offset_bottom = 676
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)
	game_title = _label(column, "ISLA DE RECURSOS")
	game_title.add_theme_font_size_override("font_size", 19)
	status = _label(column, "")
	hands = _label(column, "")
	_label(
		column,
		"J1 naranja · J2 azul · J3 rojo · J4 blanco\nM madera · L ladrillo · O lana · T trigo · R mineral"
	)
	help = _label(
		column,
		"Preparación: coloca un pueblo y después un camino junto a él. Las marcas verdes son válidas."
	)
	_label(column, "Dados físicos")
	var row := _row(column)
	_button(row, "roll", "Lanzar dados", _roll)
	_button(row, "cancel_roll", "Cancelar tirada", _cancel_roll)
	_label(column, "Construir (pulsa y selecciona una marca)")
	row = _row(column)
	_button(row, "road", "Camino", _begin_selection.bind("road"))
	_button(row, "settlement", "Pueblo", _begin_selection.bind("settlement"))
	_button(row, "city", "Ciudad", _begin_selection.bind("city"))
	_button(column, "cancel_selection", "Cancelar selección", _cancel_selection)
	_label(column, "Costes: camino M+L · pueblo M+L+O+T · ciudad 2T+3R")
	_label(column, "Banco: 4:1; los puertos permiten 3:1 o 2:1. / Descarte al sacar 7")
	row = _row(column)
	give = OptionButton.new()
	give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give.name = "Give"
	row.add_child(give)
	take = OptionButton.new()
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take.name = "Take"
	row.add_child(take)
	for i in range(5):
		give.add_item(IslandBoard.RESOURCE_NAMES[i], i)
		take.add_item(IslandBoard.RESOURCE_NAMES[i], i)
	take.select(1)
	row = _row(column)
	_button(row, "trade", "Cambiar con banco", _trade)
	_button(row, "discard", "Descartar 1", _discard)
	_label(column, "Intercambio entre jugadores (cantidades M / L / O / T / R)")
	trade_partner = OptionButton.new()
	for player in range(4):
		trade_partner.add_item("Proponer a J%d" % (player + 1), player)
	column.add_child(trade_partner)
	_label(column, "Recurso · ofrezco / pido")
	_trade_inputs(column)
	_button(column, "offer", "Proponer intercambio", _offer_trade)
	trade_description = _label(column, "Sin oferta pendiente.")
	row = _row(column)
	_button(row, "accept", "Aceptar oferta", _respond_trade.bind(true))
	_button(row, "reject", "Rechazar oferta", _respond_trade.bind(false))
	_label(
		column,
		(
			"Desarrollo: O + T + R. Una carta jugable por turno. "
			+ "C: caballero; P: punto; Ca: caminos; A: abundancia; M: monopolio."
		)
	)
	dev_status = _label(column, "")
	row = _row(column)
	_button(row, "buy_dev", "Comprar", _buy_development)
	dev_choice = OptionButton.new()
	dev_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for card in [
		IslandRules.KNIGHT,
		IslandRules.ROAD_BUILDING,
		IslandRules.YEAR_OF_PLENTY,
		IslandRules.MONOPOLY_CARD
	]:
		dev_choice.add_item(IslandRules.DEV_NAMES[card], card)
	row.add_child(dev_choice)
	_button(column, "play_dev", "Jugar carta seleccionada", _play_development)
	_label(column, "Abundancia y monopolio: selecciona recurso en 'recibir' y confirma.")
	_button(column, "choose_resource", "Confirmar recurso de carta", _choose_development_resource)
	_label(column, "Ladrón: mueve a otra casilla y elige víctima si procede.")
	row = _row(column)
	victim = OptionButton.new()
	victim.name = "Victim"
	victim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(victim)
	_button(row, "steal", "Robar", _steal)
	_button(column, "end", "Terminar turno", _end_turn)
	row = _row(column)
	_button(row, "save", "Guardar", _save_game)
	_button(row, "load", "Cargar", _load_game)
	_button(column, "new", "Nueva isla (descarta la partida)", _new_game)
	_label(
		column,
		(
			"Rueda: zoom · botón derecho: orbitar · WASD: mover cámara\n"
			+ "Arrastra piezas con el ratón · H: recuperar · Esc: pausa/menú\n"
			+ "Las manos son visibles. Sin red. El guardado es local y lógico."
		)
	)


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
	var lines: Array[String] = []
	for player in range(rules.players):
		var hand: Array = rules.resources[player]
		lines.append(
			(
				"J%d (%d puntos): %d / %d / %d / %d / %d"
				% [player + 1, rules.score(player), hand[0], hand[1], hand[2], hand[3], hand[4]]
			)
		)
	lines.append(
		(
			"Banco: %d / %d / %d / %d / %d"
			% [rules.bank[0], rules.bank[1], rules.bank[2], rules.bank[3], rules.bank[4]]
		)
	)
	hands.text = "\n".join(lines)
	var cards: Array = rules.dev_ready[rules.turn]
	var fresh: Array = rules.dev_new[rules.turn]
	dev_status.text = (
		"Mazo: %d · J%d: C%d P%d Ca%d A%d M%d (+%d nuevas)\nRuta: %s · Ejército: %s"
		% [
			rules.development_deck.size(),
			rules.turn + 1,
			cards[0],
			cards[1] + fresh[1],
			cards[2],
			cards[3],
			cards[4],
			fresh[0] + fresh[2] + fresh[3] + fresh[4],
			_award_text(rules.longest_road),
			_award_text(rules.largest_army)
		]
	)
	if rules.phase == IslandRules.TRADE_RESPONSE:
		trade_description.text = (
			"J%d ofrece %s; pide %s a J%d."
			% [
				rules.turn + 1,
				str(rules.trade_offer["give"]),
				str(rules.trade_offer["take"]),
				int(rules.trade_offer["to"]) + 1
			]
		)
	else:
		trade_description.text = "Sin oferta pendiente."
	buttons["roll"].disabled = rules.phase != IslandRules.ROLL or waiting_roll
	buttons["cancel_roll"].disabled = not waiting_roll
	var action := rules.phase == IslandRules.ACTION and not waiting_roll
	for id in ["road", "settlement", "city", "trade", "end", "offer", "buy_dev"]:
		buttons[id].disabled = not action
	buttons["cancel_selection"].disabled = not action or selection_mode.is_empty()
	buttons["discard"].disabled = rules.phase != IslandRules.DISCARD
	buttons["steal"].disabled = rules.phase != IslandRules.STEAL
	buttons["play_dev"].disabled = (
		waiting_roll
		or rules.phase not in [IslandRules.ROLL, IslandRules.ACTION]
		or rules.dev_played
	)
	buttons["choose_resource"].disabled = (
		rules.phase not in [IslandRules.PLENTY, IslandRules.MONOPOLY]
	)
	buttons["accept"].disabled = rules.phase != IslandRules.TRADE_RESPONSE
	buttons["reject"].disabled = rules.phase != IslandRules.TRADE_RESPONSE
	victim.clear()
	for player in rules.eligible_victims:
		victim.add_item("J%d" % (player + 1), player)
	if victim.item_count == 0:
		victim.add_item("Sin víctima", -1)
	victim.disabled = rules.phase != IslandRules.STEAL
	_update_markers()


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
	if rules.respond_trade(recipient, accept):
		_help("Intercambio aceptado." if accept else "Intercambio rechazado.")
	else:
		_help("No se puede aceptar: la persona destinataria no tiene los recursos pedidos.")
	_refresh()


func _buy_development() -> void:
	if rules.buy_development():
		_help("Carta comprada. Las cartas jugables se activan a partir del próximo turno.")
	else:
		_help("No se puede comprar: faltan recursos o el mazo está vacío.")
	_refresh()


func _play_development() -> void:
	if waiting_roll or grabber.held != null:
		_help("Espera la tirada y suelta cualquier objeto antes de jugar la carta.")
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
	waiting_roll = true
	settled_time = 0.0
	roll_results = [0, 0]
	for die in dice:
		die.roll()
	_refresh()
	_help(
		(
			"Los resultados se leen cuando cada dado se detiene. "
			+ "Si quedan bloqueados, cancela y vuelve a lanzar."
		)
	)


func _on_die_result(value: int, index: int) -> void:
	if waiting_roll and index >= 0 and index < 2 and value >= 1 and value <= 6:
		roll_results[index] = value


func _finish_roll() -> void:
	# Releer simultáneamente: el segundo dado podría haber movido al primero.
	roll_results = [dice[0].top_face(), dice[1].top_face()]
	waiting_roll = false
	for die in dice:
		die._awaiting_result = false
	if rules.roll(roll_results[0], roll_results[1]):
		_help("Dados aceptados: %d + %d." % [roll_results[0], roll_results[1]])
	_refresh()


func _cancel_roll() -> void:
	if not waiting_roll:
		return
	waiting_roll = false
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
	if waiting_roll or grabber.held != null:
		_help("Suelta el objeto y termina o cancela la tirada antes de guardar.")
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_help("No se pudo abrir el archivo de guardado.")
		return
	file.store_string(JSON.stringify(rules.export_record()))
	file.flush()
	if file.get_error() != OK:
		_help("No se pudo completar el guardado.")
	else:
		_help("Partida guardada en este dispositivo; las poses físicas no se conservan.")
	file.close()


func _load_game() -> void:
	if waiting_roll or grabber.held != null:
		_help("Suelta el objeto y termina o cancela la tirada antes de cargar.")
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_help("No se encontró el guardado local.")
		return
	if file.get_length() > 2000000:
		_help("Guardado demasiado grande.")
		file.close()
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		_help("Guardado inválido: se conserva la partida actual.")
		return
	var loaded := IslandRules.from_record(json.data)
	if loaded == null:
		_help("Guardado inválido: se conserva la partida actual.")
		return
	rules = loaded
	_rebuild_loaded_board()
	_set_mode("")
	_refresh()
	_help("Partida cargada; las piezas físicas se reconstruyen en sus destinos lógicos.")


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
	get_tree().change_scene_to_file(scene_file_path)


func _placement_message(message: String) -> void:
	_help(message)
