class_name LudoView
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const TOKEN := preload("res://scenes/Token3D.tscn")
const DICE := preload("res://scenes/Dice3D.tscn")
# Rojo, azul, amarillo y verde de la paleta (docs/ARTE.md); los textos usan estos nombres.
const COLORS := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
const NAMES := ["rojo", "azul", "amarillo", "verde"]
# Casas tradicionales del parchís español (salidas en 5, 22, 39 y 56).
const PARCHIS_COLORS := [
	Palette.PLAYER_YELLOW,
	Palette.PLAYER_BLUE,
	Palette.PLAYER_RED,
	Palette.PLAYER_GREEN,
]
const PARCHIS_NAMES := ["amarillo", "azul", "rojo", "verde"]
const PARCHIS_TWO_HOUSES := [0, 2, 1, 3]
const PARCHIS_META_SLOTS := [
	Vector2(-0.20, 0.40),
	Vector2(0.0, 0.40),
	Vector2(0.20, 0.40),
	Vector2(0.0, 0.23),
]
const PARCHIS_COL_W := 0.34
const PARCHIS_ROW_D := 0.19
const PARCHIS_META_HALF := 0.51
const PARCHIS_BOARD_SIZE := 4.24
const CENTER := Vector3(-0.62, 0.83, 0)
const TRACK_RADIUS := 1.37
const MAX_SAVE_BYTES := 500000

@export_range(2, 4) var player_count := 2
## "ludo" o "parchis" (LudoRules): mismo tablero, reglas del parchís español.
@export var variant := "ludo"
@export var save_path := "user://diceon_ludo.json"
var confirm_action: ConfirmAction
var rules: LudoRules
var die: Dice3D
var tokens: Array = []
var markers: Array[MeshInstance3D] = []
var in_transit: Dictionary = {}
## Tiempo que lleva cada ficha quieta lejos de su sitio (ver _physics_process).
var _stalled: Dictionary = {}
## Tiempo en tránsito sin haber podido subir (otra ficha encima): pasado un momento, se desliza.
var _lift_wait: Dictionary = {}
const LIFT_PATIENCE := 0.6
## Último recurso: una ficha que lleva tanto tiempo en tránsito sin llegar se recoloca encima
## de su casilla (como la tecla H de recuperar en la mesa libre).
const TRANSIT_LIMIT := 3.0
var _transit_time: Dictionary = {}
const STALL_DISTANCE := 0.06
const STALL_TIME := 0.5
var waiting_roll := false
var stable_time := 0.0
var stuck_time := 0.0
var nudges := 0
var _roll_elapsed := 0.0
var status: Label
var help: Label
var title_label: Label
var roll_button: Button
var reset_button: Button
var load_game_button: Button
var new_game_button: Button
var token_buttons: Array[Button] = []
var new_game_confirmation: ConfirmationDialog
## Jugadores que lleva un bot (TableBots); el resto juega en el mismo equipo.
var bots: Array[bool] = [false, false, false, false]
var bot_toggles: Array[CheckBox] = []
var _bot_wait := 0.0
var online := false
var net_table: LudoNetTable
var _remote_roll_expected := 0
var _remote_roll_seat := -1
var _roll_should_submit := true
var _suppress_roll_anim := false
var _awaiting_roll_ack := false
var _last_roll_note := ""
var _last_engine_frame := -1
var _last_roll_seat := -1
var _last_roll_value := 0
var dice_banner: PanelContainer
var dice_banner_label: Label

const TRAY_REST := Vector3(2.66, 1.052, 0.0)

@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var camera: Camera3D = $CameraRig/Camera3D


func _net() -> Node:
	return get_node_or_null("/root/Net")


func _local_seat() -> int:
	var net := _net()
	return int(net.local_seat()) if net != null else -1


func _ready() -> void:
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	rules = LudoRules.new(player_count, variant)
	_make_board()
	_make_tokens()
	_make_tray()
	_make_ui()
	_apply_solo_bots()
	_make_seats()
	grabber.dice_shortcuts_enabled = false
	grabber.grab_started.connect(_on_grab_started)
	grabber.grab_finished.connect(_on_release)
	_start_online()
	_refresh()


func _start_online() -> void:
	var net := _net()
	if net == null or str(net.room_game) not in ["Parchis2", "Parchis", "Ludo", "Ludo3", "Ludo4"]:
		return
	if not (Engine.has_singleton("Fusion") and Fusion.is_in_room()):
		return
	online = true
	net_table = LudoNetTable.new()
	net_table.name = "NetTable"
	net_table.view_node = self
	net_table.ludo = rules
	add_child(net_table)
	if title_label != null:
		title_label.text = "PARCHÍS · MESA ONLINE" if rules.is_parchis() else "LUDO · MESA ONLINE"
	if net_table.is_host():
		var rbots: Array = net.room_bots
		for seat in range(mini(rules.players, rbots.size())):
			if bool(rbots[seat]):
				set_bot(true, seat)
	else:
		for toggle in bot_toggles:
			if is_instance_valid(toggle):
				toggle.disabled = true
		net_table.request_sync()
	net.player_left.connect(_on_net_player_left)


func _on_net_player_left(player_id: int) -> void:
	if online and net_table != null and net_table.is_host():
		set_bot(true, player_id - 1)


func _is_awaiting_sync() -> bool:
	return online and net_table != null and not net_table.synced


func is_local_turn() -> bool:
	if not online:
		return not is_bot_turn()
	if _is_awaiting_sync():
		return false
	var seat := _local_seat()
	return seat >= 0 and seat < rules.players and rules.turn == seat and not is_bot_turn()


func submit_change(action: Dictionary, acting_seat: int = -1) -> bool:
	if not online or net_table == null:
		return false
	return net_table.submit(action, acting_seat)


func _finish_forced_die() -> void:
	if die != null and die.is_forced_rolling():
		die.finish_forced_roll(true)
	elif waiting_roll and not _roll_should_submit and _remote_roll_expected >= 1:
		die.global_position = TRAY_REST
		die.set_top_face(_remote_roll_expected)
		die.ensure_celebrated(_remote_roll_expected)
	if not _roll_should_submit:
		_remote_roll_expected = 0
		_remote_roll_seat = -1
		_roll_should_submit = true
		waiting_roll = false
		if die != null:
			die._awaiting_result = false


func apply_change(change: Dictionary) -> bool:
	var kind := str(change.get("type", ""))
	if kind == "roll":
		_finish_forced_die()
		var val := int(change.get("value", 0))
		var seat := int(change.get("seat", rules.turn))
		var manual := bool(change.get("manual", false))
		if not rules.apply_roll(val):
			if seat == _local_seat():
				_awaiting_roll_ack = false
			return false
		if seat == _local_seat():
			_awaiting_roll_ack = false
		if net_table != null:
			net_table.ludo = rules
		_last_roll_seat = seat
		_last_roll_value = val
		_last_roll_note = "Última tirada: J%d sacó %d" % [seat + 1, val]
		var skip_local_manual := (
			manual
			and seat == _local_seat()
			and (seat < 0 or seat >= bots.size() or not bots[seat])
		)
		if not _suppress_roll_anim and not skip_local_manual:
			_animate_remote_roll(val, seat)
			_bot_wait = -0.55
		elif die != null and val >= 1 and val <= 6:
			die.set_top_face(val)
			if not _suppress_roll_anim:
				die.ensure_celebrated(val)
			_bot_wait = -0.55
		_refresh()
		return true
	if kind == "move":
		_finish_forced_die()
		var tok := int(change.get("token", -1))
		var previous := rules.positions.duplicate(true)
		if not rules.move(tok):
			return false
		if net_table != null:
			net_table.ludo = rules
		for player in range(rules.players):
			for token_index in range(4):
				if previous[player][token_index] != rules.positions[player][token_index]:
					in_transit[tokens[player][token_index]] = false
		_refresh()
		return true
	return false


func _animate_remote_roll(value: int, seat: int) -> void:
	_remote_roll_expected = value
	_remote_roll_seat = seat
	_roll_should_submit = false
	waiting_roll = true
	stable_time = 0.0
	stuck_time = 0.0
	nudges = 0
	die.roll_to_value(value, TRAY_REST)


func sync_from_rules() -> void:
	in_transit.clear()
	if die != null and die.is_forced_rolling():
		die.cancel_forced_roll()
	waiting_roll = false
	_roll_elapsed = 0.0
	_awaiting_roll_ack = false
	_roll_should_submit = true
	_remote_roll_expected = 0
	_remote_roll_seat = -1
	_last_roll_seat = -1
	_last_roll_value = rules.die if rules != null else 0
	if die != null and rules != null and rules.die >= 1 and rules.die <= 6:
		die.global_position = TRAY_REST
		die.set_top_face(rules.die)
	_update_token_activity()
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			token.global_position = (
				_token_position(player, index, rules.positions[player][index]) + Vector3.UP * 0.1
			)
			token.linear_velocity = Vector3.ZERO
			token.angular_velocity = Vector3.ZERO
	_refresh()


## Jugadores sentados junto a su casa, con lo que llevan a la meta encima.
var seats: TableSeats


## Menú de bots: la mesa empieza en solitario contra bots (J1 es el humano).
func _apply_solo_bots() -> void:
	if not TableBots.solo:
		return
	TableBots.solo = false
	for player in range(1, rules.players):
		set_bot(true, player)


func _is_parchis_board() -> bool:
	return (rules != null and rules.is_parchis()) or variant == LudoRules.PARCHIS


func _player_house(player: int) -> int:
	var p := clampi(player, 0, 3)
	if not _is_parchis_board():
		return p
	var count := rules.players if rules != null else player_count
	if count == 2:
		return int(PARCHIS_TWO_HOUSES[p])
	return p


func _player_color(player: int) -> Color:
	if _is_parchis_board():
		return PARCHIS_COLORS[_player_house(player)]
	return COLORS[clampi(player, 0, 3)]


func _player_name(player: int) -> String:
	if _is_parchis_board():
		return PARCHIS_NAMES[_player_house(player)]
	return NAMES[clampi(player, 0, 3)]


func _make_seats() -> void:
	var list := []
	# Asientos fuera de la mesa física: el radio fijo anterior clavaba los personajes
	# en el tablero (que es más ancho que el tablero de juego).
	var bounds := TableSeats.table_aabb($Table/CollisionShape3D)
	for player in range(rules.players):
		var home := Vector3.ZERO
		for token in range(4):
			home += _yard_position(player, token) * 0.25
		var outward := Vector3(home.x - CENTER.x, 0, home.z - CENTER.z).normalized()
		var spot := TableSeats.seat_outside(
			Vector3(CENTER.x, -0.15, CENTER.z), outward, -0.15, bounds,
			TableSeats.AVATAR_CLEARANCE
		)
		list.append(
			{
				"name": "Jugador %d" % (player + 1),
				"color": _player_color(player),
				"bot": bots[player],
				"position": spot,
				"look_at": Vector3(CENTER.x, -0.15, CENTER.z),
			}
		)
	seats = TableSeats.new()
	seats.name = "TableSeats"
	add_child(seats)
	seats.setup(list)
	seats.center = CENTER
	SocialOverlay3D.attach(self, seats, net_table)
	_update_seats()


func _update_seats() -> void:
	if seats == null:
		return
	seats.set_active(rules.turn if rules.phase != LudoRules.FINISHED else rules.winner)
	var finish_goal := rules.finish_progress()
	for player in range(rules.players):
		var done := 0
		var waiting := 0
		for progress in rules.positions[player]:
			if progress == finish_goal:
				done += 1
			elif progress == LudoRules.YARD:
				waiting += 1
		seats.set_status(
			player, "%sMeta %d/4 · casa %d" % ["Bot · " if bots[player] else "", done, waiting]
		)


func _make_board() -> void:
	if _is_parchis_board():
		_make_parchis_board()
		return
	var shape := $Board/CollisionShape3D.shape.duplicate() as BoxShape3D
	shape.size = Vector3(4.9, 0.03, 4.25)
	$Board/CollisionShape3D.shape = shape
	$Board/CollisionShape3D.position.x = CENTER.x
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = shape.size
	base.mesh = base_mesh
	base.position = Vector3(CENTER.x, 0.815, 0)
	base.material_override = BoardGeometry3D.make_material(Color("374d3b"))
	$Board/Tiles.add_child(base)
	for square in range(52):
		var color := Color("d8d2b4")
		if square in LudoRules.SAFE:
			color = COLORS[(square / 13) % 4].lightened(0.2)
		_disc(_track_position(square), 0.071, color)
	for player in range(4):
		for progress in range(52, 57):
			_disc(_lane_position(player, progress), 0.073, COLORS[player].darkened(0.12))
		for token in range(4):
			_disc(_yard_position(player, token), 0.10, COLORS[player].darkened(0.25))
			_disc(_finished_position(player, token), 0.10, COLORS[player].lightened(0.35))
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.10
		mesh.bottom_radius = 0.10
		mesh.height = 0.012
		marker.mesh = mesh
		marker.material_override = BoardGeometry3D.make_material(Color("9efa9a"))
		$Board/Tiles.add_child(marker)
		marker.visible = false
		markers.append(marker)


func _make_parchis_board() -> void:
	var tiles_root: Node3D = $Board/Tiles
	var shape := $Board/CollisionShape3D.shape.duplicate() as BoxShape3D
	shape.size = Vector3(PARCHIS_BOARD_SIZE, 0.03, PARCHIS_BOARD_SIZE)
	$Board/CollisionShape3D.shape = shape
	$Board/CollisionShape3D.position.x = CENTER.x

	# Marco exterior de madera barnizada y lecho de tinta para líneas de casillas.
	var frame := MeshInstance3D.new()
	frame.name = "BoardFrame"
	frame.mesh = PieceKit.rounded_box_xyz(
		Vector3(PARCHIS_BOARD_SIZE, 0.031, PARCHIS_BOARD_SIZE),
		Vector3(0.055, 0.007, 0.055),
		5
	)
	frame.position = Vector3(CENTER.x, 0.814, CENTER.z)
	frame.material_override = BoardGeometry3D.make_material(Color("6d3b1e"))
	tiles_root.add_child(frame)

	var ink_mat := BoardGeometry3D.make_material(Palette.INK)
	var cream_mat := BoardGeometry3D.make_material(Color("fbf4e2"))
	var cream_soft_mat := BoardGeometry3D.make_material(Color("fffaf0"))
	var safe_mat := BoardGeometry3D.make_material(Color("cfd8e6"))
	var house_mats: Array[StandardMaterial3D] = []
	var house_light_mats: Array[StandardMaterial3D] = []
	var tri_mats: Array[StandardMaterial3D] = []
	for h in range(4):
		var hcol: Color = PARCHIS_COLORS[h]
		house_mats.append(BoardGeometry3D.make_material(hcol))
		house_light_mats.append(BoardGeometry3D.make_material(hcol.lightened(0.20)))
		var tri_mat := BoardGeometry3D.make_material(hcol)
		tri_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		tri_mats.append(tri_mat)

	var ink_bed := MeshInstance3D.new()
	ink_bed.name = "InkGridBed"
	var ink_bed_mesh := BoxMesh.new()
	ink_bed_mesh.size = Vector3(4.10, 0.002, 4.10)
	ink_bed.mesh = ink_bed_mesh
	ink_bed.position = Vector3(CENTER.x, 0.8302, CENTER.z)
	ink_bed.material_override = ink_mat
	tiles_root.add_child(ink_bed)

	var cell_mesh_h := BoxMesh.new()
	cell_mesh_h.size = Vector3(PARCHIS_COL_W - 0.015, 0.002, PARCHIS_ROW_D - 0.015)
	var cell_mesh_v := BoxMesh.new()
	cell_mesh_v.size = Vector3(PARCHIS_ROW_D - 0.015, 0.002, PARCHIS_COL_W - 0.015)

	# 4 casas clásicas en las esquinas con medallón circular y los 4 nidos de fichas.
	var house_span := 8.0 * PARCHIS_ROW_D - 0.018
	var house_box := BoxMesh.new()
	house_box.size = Vector3(house_span, 0.002, house_span)
	var ring_outer_mesh := _thin_cylinder(0.565, 0.0015)
	var ring_cream_mesh := _thin_cylinder(0.540, 0.0015)
	var ring_color_mesh := _thin_cylinder(0.486, 0.0015)
	var ring_core_mesh := _thin_cylinder(0.464, 0.0015)
	var nest_ink_mesh := _thin_cylinder(0.096, 0.0015)
	var nest_fill_mesh := _thin_cylinder(0.082, 0.0015)

	for house in range(4):
		var hcenter := _parchis_house_center(house)
		_add_tile_mesh(
			tiles_root,
			house_box,
			Vector3(hcenter.x, 0.8316, hcenter.z),
			house_mats[house],
			"House%d" % house
		)
		_add_tile_mesh(tiles_root, ring_outer_mesh, Vector3(hcenter.x, 0.8328, hcenter.z), ink_mat)
		_add_tile_mesh(tiles_root, ring_cream_mesh, Vector3(hcenter.x, 0.8336, hcenter.z), cream_mat)
		_add_tile_mesh(
			tiles_root, ring_color_mesh, Vector3(hcenter.x, 0.8344, hcenter.z), house_mats[house]
		)
		_add_tile_mesh(
			tiles_root, ring_core_mesh, Vector3(hcenter.x, 0.8352, hcenter.z), cream_soft_mat
		)
		for slot in range(4):
			var npos := _parchis_yard_slot(house, slot)
			_add_tile_mesh(
				tiles_root, nest_ink_mesh, Vector3(npos.x, 0.8360, npos.z), ink_mat
			)
			_add_tile_mesh(
				tiles_root,
				nest_fill_mesh,
				Vector3(npos.x, 0.8368, npos.z),
				house_light_mats[house]
			)

	# 68 casillas numeradas del recorrido exterior, salidas de color y seguros clásicos.
	var safe_ring_mesh := _thin_cylinder(0.052, 0.0015)
	var safe_inner_mesh := _thin_cylinder(0.039, 0.0015)
	var safe_dot_mesh := _thin_cylinder(0.017, 0.0015)

	for sq in range(LudoRules.PARCHIS_TRACK):
		var info := _parchis_square_info(sq)
		var arm: int = int(info["arm"])
		var pos: Vector3 = info["pos"]
		var wide_axis: Vector3 = info["wide_axis"]
		var cmesh := cell_mesh_h if (arm % 2 == 0) else cell_mesh_v
		var tile_mat: StandardMaterial3D = cream_mat
		var is_exit := (sq % 17 == 4)
		var is_safe := sq in LudoRules.PARCHIS_SAFE
		if is_exit:
			tile_mat = house_mats[sq / 17]
		elif is_safe:
			tile_mat = safe_mat
		_add_tile_mesh(
			tiles_root,
			cmesh,
			Vector3(pos.x, 0.8316, pos.z),
			tile_mat,
			"Square%d" % (sq + 1)
		)
		if is_safe:
			_add_tile_mesh(
				tiles_root, safe_ring_mesh, Vector3(pos.x, 0.8330, pos.z), ink_mat
			)
			_add_tile_mesh(
				tiles_root, safe_inner_mesh, Vector3(pos.x, 0.8338, pos.z), cream_soft_mat
			)
			var dot_mat: StandardMaterial3D = ink_mat
			if is_exit:
				dot_mat = house_mats[sq / 17]
			elif sq % 17 == 16:
				dot_mat = house_mats[((sq / 17) + 1) % 4]
			_add_tile_mesh(
				tiles_root, safe_dot_mesh, Vector3(pos.x, 0.8346, pos.z), dot_mat
			)
		var num_label := Label3D.new()
		num_label.name = "Num%d" % (sq + 1)
		num_label.text = str(sq + 1)
		num_label.font_size = 32
		num_label.pixel_size = 0.0013
		num_label.outline_size = 0
		num_label.modulate = Palette.INK
		num_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		var lpos := pos - wide_axis * 0.114
		num_label.position = Vector3(lpos.x, 0.8348, lpos.z)
		tiles_root.add_child(num_label)

	# 4 pasillos de color de 7 casillas hacia la meta central.
	for house in range(4):
		var cmesh := cell_mesh_h if (house % 2 == 0) else cell_mesh_v
		for step in range(7):
			var lpos := _parchis_corridor_pos(house, step)
			_add_tile_mesh(
				tiles_root,
				cmesh,
				Vector3(lpos.x, 0.8316, lpos.z),
				house_mats[house],
				"Lane%d_%d" % [house, step + 1]
			)

	# Meta central dividida en los 4 triángulos clásicos de color.
	var meta_spot_mesh := _thin_cylinder(0.062, 0.0015)
	for house in range(4):
		var tri := MeshInstance3D.new()
		tri.name = "MetaTriangle%d" % house
		tri.mesh = _make_meta_triangle_mesh(house)
		tri.position = Vector3(CENTER.x, 0.8318, CENTER.z)
		tri.material_override = tri_mats[house]
		tiles_root.add_child(tri)
		for slot in range(4):
			var fpos := _parchis_finish_slot(house, slot)
			_add_tile_mesh(
				tiles_root,
				meta_spot_mesh,
				Vector3(fpos.x, 0.8330, fpos.z),
				house_light_mats[house]
			)
	_add_tile_mesh(
		tiles_root, _thin_cylinder(0.046, 0.0015), Vector3(CENTER.x, 0.8336, CENTER.z), ink_mat
	)
	_add_tile_mesh(
		tiles_root,
		_thin_cylinder(0.030, 0.0015),
		Vector3(CENTER.x, 0.8344, CENTER.z),
		cream_soft_mat
	)

	# Marcas verdes de destino legal.
	for player in range(4):
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.088
		mesh.bottom_radius = 0.088
		mesh.height = 0.008
		marker.mesh = mesh
		marker.material_override = BoardGeometry3D.make_material(Color("6ef5a8"))
		tiles_root.add_child(marker)
		marker.visible = false
		markers.append(marker)


static func _thin_cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 28
	return mesh


static func _add_tile_mesh(
	parent: Node3D,
	mesh: Mesh,
	pos: Vector3,
	mat: Material,
	node_name: String = ""
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	if not node_name.is_empty():
		visual.name = node_name
	visual.mesh = mesh
	visual.position = pos
	visual.material_override = mat
	parent.add_child(visual)
	return visual


static func _make_meta_triangle_mesh(house: int) -> ArrayMesh:
	var edge := PARCHIS_META_HALF - 0.008
	var diag_gap := 0.011
	var half_base := edge - diag_gap
	var v0 := _parchis_arm_vec(house, -half_base, edge)
	var v1 := _parchis_arm_vec(house, 0.0, diag_gap)
	var v2 := _parchis_arm_vec(house, half_base, edge)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.add_vertex(v0)
	st.set_normal(Vector3.UP)
	st.add_vertex(v1)
	st.set_normal(Vector3.UP)
	st.add_vertex(v2)
	return st.commit()


static func _parchis_arm_vec(arm: int, lx: float, lz: float) -> Vector3:
	match posmod(arm, 4):
		0:
			return Vector3(lx, 0.0, lz)
		1:
			return Vector3(lz, 0.0, -lx)
		2:
			return Vector3(-lx, 0.0, -lz)
		_:
			return Vector3(-lz, 0.0, lx)


static func _parchis_square_info(square: int) -> Dictionary:
	var sq := posmod(square, LudoRules.PARCHIS_TRACK)
	var block := sq / 17
	var k := sq % 17
	var arm := block
	var lx := 0.0
	var row := 7
	if k < 8:
		arm = block
		lx = PARCHIS_COL_W
		row = 7 - k
	elif k < 16:
		arm = (block + 1) % 4
		lx = -PARCHIS_COL_W
		row = k - 8
	else:
		arm = (block + 1) % 4
		lx = 0.0
		row = 7
	var lz := PARCHIS_META_HALF + (float(row) + 0.5) * PARCHIS_ROW_D
	return {
		"arm": arm,
		"lx": lx,
		"lz": lz,
		"pos": CENTER + _parchis_arm_vec(arm, lx, lz),
		"wide_axis": _parchis_arm_vec(arm, 1.0, 0.0),
	}


static func _parchis_house_center(house: int) -> Vector3:
	var offset := PARCHIS_META_HALF + 4.0 * PARCHIS_ROW_D
	return CENTER + _parchis_arm_vec(house, offset, offset)


static func _parchis_yard_slot(house: int, token: int) -> Vector3:
	var hcenter := _parchis_house_center(house)
	return hcenter + Vector3((float(token % 2) - 0.5) * 0.42, 0.0, (float(token / 2) - 0.5) * 0.42)


static func _parchis_corridor_pos(house: int, step: int) -> Vector3:
	var row := 6 - clampi(step, 0, 6)
	var lz := PARCHIS_META_HALF + (float(row) + 0.5) * PARCHIS_ROW_D
	return CENTER + _parchis_arm_vec(house, 0.0, lz)


static func _parchis_finish_slot(house: int, token: int) -> Vector3:
	var slot: Vector2 = PARCHIS_META_SLOTS[clampi(token, 0, 3)]
	return CENTER + _parchis_arm_vec(house, slot.x, slot.y)


func _disc(position: Vector3, radius: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.014
	visual.mesh = mesh
	visual.position = position + Vector3.UP * 0.01
	visual.material_override = BoardGeometry3D.make_material(color)
	$Board/Tiles.add_child(visual)


func _track_position(square: int) -> Vector3:
	if _is_parchis_board():
		var info := _parchis_square_info(square)
		return info["pos"] as Vector3
	var angle := TAU * float(square) / 52.0 - PI / 2.0
	return CENTER + Vector3(cos(angle) * TRACK_RADIUS, 0, sin(angle) * TRACK_RADIUS)


func _lane_position(player: int, progress: int) -> Vector3:
	if _is_parchis_board():
		return _parchis_corridor_pos(_player_house(player), progress - LudoRules.PARCHIS_CORRIDOR)
	var angle := TAU * float(player * 13 - 1) / 52.0 - PI / 2.0
	var radius := 1.14 - float(progress - 52) * 0.19
	return CENTER + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


func _yard_position(player: int, token: int) -> Vector3:
	if _is_parchis_board():
		return _parchis_yard_slot(_player_house(player), token)
	var angle := TAU * float(player) / 4.0 - PI / 2.0
	var base := CENTER + Vector3(cos(angle) * 1.79, 0, sin(angle) * 1.79)
	return base + Vector3((token % 2 - 0.5) * 0.19, 0, (token / 2 - 0.5) * 0.19)


func _finished_position(player: int, token: int) -> Vector3:
	if _is_parchis_board():
		return _parchis_finish_slot(_player_house(player), token)
	var angle := TAU * float(player) / 4.0 - PI / 2.0
	return _yard_position(player, token) + Vector3(-sin(angle), 0, cos(angle)) * 0.45


func _token_position(player: int, token: int, progress: int) -> Vector3:
	if progress == LudoRules.YARD:
		return _yard_position(player, token)
	var finish_goal := rules.finish_progress() if rules != null else LudoRules.FINISH
	if progress == finish_goal:
		return _finished_position(player, token)
	var lane_start := rules.corridor_start() if rules != null else 52
	if progress >= lane_start:
		return _lane_position(player, progress) + _share_offset(player, token, progress)
	var sq := rules.player_square(player, progress) if rules != null else LudoRules.track_square(player, progress)
	return _track_position(sq) + _share_offset(player, token, progress)


# Parchís: dos fichas en la misma casilla (barrera o seguro compartido) se colocan una al lado
# de la otra a lo ancho de la casilla rectangular sin invadir las casillas vecinas.
func _share_offset(player: int, token: int, progress: int) -> Vector3:
	if rules == null or not rules.is_parchis():
		return Vector3.ZERO
	var mates: Array[Vector2i] = []
	var lane_start := rules.corridor_start()
	if progress < lane_start:
		mates = rules.tokens_on(rules.player_square(player, progress))
	else:
		for other in range(4):
			if rules.positions[player][other] == progress:
				mates.append(Vector2i(player, other))
	if not Vector2i(player, token) in mates:
		mates.append(Vector2i(player, token))
	if mates.size() < 2:
		return Vector3.ZERO
	mates.sort()
	var here: Vector3
	var wide_axis: Vector3
	if progress < lane_start:
		var info := _parchis_square_info(rules.player_square(player, progress))
		here = info["pos"] as Vector3
		wide_axis = info["wide_axis"] as Vector3
	else:
		var house := _player_house(player)
		here = _lane_position(player, progress)
		wide_axis = _parchis_arm_vec(house, 1.0, 0.0)
	# Cada ficha va al lado en el que ya está: con un orden fijo, dos fichas cruzadas se
	# empujarían una contra otra sin poder pasar.
	var other: Vector2i = mates[1] if mates[0] == Vector2i(player, token) else mates[0]
	var mine := _side_value(player, token, here, wide_axis)
	var theirs := _side_value(other.x, other.y, here, wide_axis)
	var side := 1.0 if mine > theirs or (is_equal_approx(mine, theirs) and mates.find(Vector2i(player, token)) == 1) else -1.0
	return wide_axis * side * 0.082


func _side_value(player: int, token: int, origin: Vector3, axis: Vector3) -> float:
	if player >= tokens.size() or token >= tokens[player].size():
		return 0.0
	var body: Token3D = tokens[player][token]
	return snappedf(
		Vector3(body.global_position.x - origin.x, 0.0, body.global_position.z - origin.z).dot(axis),
		0.01
	)


func _make_tokens() -> void:
	var parchis := _is_parchis_board()
	var visual_scale := 0.32 if parchis else 0.4
	var col_radius := 0.064 if parchis else 0.08
	var col_height := 0.044 if parchis else 0.048
	for player in range(4):
		var pieces: Array[Token3D] = []
		for index in range(4):
			var token := TOKEN.instantiate() as Token3D
			token.piece_color = _player_color(player)
			token.display_name = "J%d · ficha %d" % [player + 1, index + 1]
			token.position = _yard_position(player, index) + Vector3.UP * 0.1
			token.mass = 0.05
			(token.get_node("Visual") as MeshInstance3D).scale = Vector3.ONE * visual_scale
			var collision := token.get_node("CollisionShape3D") as CollisionShape3D
			var shape := collision.shape.duplicate() as CylinderShape3D
			shape.radius = col_radius
			shape.height = col_height
			collision.shape = shape
			objects.add_child(token)
			var label := Label3D.new()
			label.text = str(index + 1)
			label.font_size = 46 if parchis else 52
			label.pixel_size = 0.002
			label.rotation_degrees.x = -90
			label.position.y = 0.033 if parchis else 0.038
			label.modulate = Palette.INK if parchis else Color("13291f")
			if parchis:
				label.outline_size = 5
				label.outline_modulate = Palette.PAPER
			token.add_child(label)
			pieces.append(token)
		tokens.append(pieces)
	_update_token_activity()


func _update_token_activity() -> void:
	for player in range(4):
		for token: Token3D in tokens[player]:
			token.visible = player < rules.players
			token.freeze = player >= rules.players
			token.collision_layer = 2 if player < rules.players else 0
			token.collision_mask = 3 if player < rules.players else 0


func _make_tray() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	for pair in [
		[Vector3(1.98, 1.15, 0), Vector3(0.08, 0.7, 2.0)],
		[Vector3(3.34, 1.15, 0), Vector3(0.08, 0.7, 2.0)],
		[Vector3(2.66, 1.15, -1.0), Vector3(1.44, 0.7, 0.08)],
		[Vector3(2.66, 1.15, 1.0), Vector3(1.44, 0.7, 0.08)]
	]:
		var shape := BoxShape3D.new()
		shape.size = pair[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = pair[0]
		body.add_child(collision)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = pair[1]
		visual.mesh = mesh
		visual.position = pair[0]
		visual.material_override = BoardGeometry3D.make_material(Color("50796b"))
		body.add_child(visual)
	die = DICE.instantiate() as Dice3D
	die.position = Vector3(2.66, 1.2, 0)
	die.collision_mask |= 4
	die.display_name = "Dado físico · R"
	objects.add_child(die)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LudoUI"
	add_child(layer)
	# Tarjeta compacta arriba a la izquierda: lo de cada turno a la vista y el resto en «⋯».
	var panel := PanelContainer.new()
	panel.name = "GameCard"
	HudCard.float_top_left(panel, 300)
	var theme := GameThemes.theme_for(self)
	var style := GameThemes.panel_box(theme)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	header.add_child(GameThemes.emblem(theme, 36.0))
	var title := _label(header, "PARCHÍS · MESA LOCAL" if rules.is_parchis() else "LUDO · MESA LOCAL")
	title_label = title
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", theme["accent"].lightened(0.2))
	status = _label(column, "")
	help = _label(column, "")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roll_button = _button(column, "Lanzar dado · R", _roll)
	GameThemes.style_button(roll_button, theme)
	var row := HBoxContainer.new()
	row.tooltip_text = "Elige una ficha o arrástrala a su marca verde"
	column.add_child(row)
	for index in range(4):
		var button := _button(row, "%d" % (index + 1), _choose_token.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		token_buttons.append(button)
	var more := HudCard.more_section(column, header)
	reset_button = _button(more, "Recolocar dado", _reset_die)
	_label(more, "Jugadores que lleva un bot:")
	var bot_row := HBoxContainer.new()
	bot_row.name = "BotRow"
	more.add_child(bot_row)
	for player in range(rules.players):
		var toggle := CheckBox.new()
		toggle.name = "Bot%d" % (player + 1)
		toggle.text = "J%d" % (player + 1)
		toggle.add_theme_color_override("font_color", _player_color(player).lightened(0.3))
		toggle.toggled.connect(set_bot.bind(player))
		bot_row.add_child(toggle)
		bot_toggles.append(toggle)
	var explanation := _label(
		more,
		(
			"Tablero clásico de 68 casillas · salida obligatoria con 5 · el 6 repite (7 sin fichas en casa).\n"
			+ "Dos fichas forman barrera: nadie pasa. En los 12 seguros no se come.\n"
			+ "Comer: 20 de premio · llegar a meta: 10 · el tercer 6 manda a casa la última ficha movida."
		)
		if rules.is_parchis()
		else (
			"Salida con 6 · el 6 da otra tirada · meta exacta.\n"
			+ "Verde: destino válido; casillas de color: seguras.\n"
			+ "Recorrido horario; sin apilar ni bloqueos de barrera. "
			+ "Las casillas claras junto a casa son las metas."
		)
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 12)
	_button(more, "Guardar partida", _save_game)
	load_game_button = _button(more, "Cargar partida", _request_load)
	new_game_button = _button(more, "Nueva partida", _new_game)
	var shortcuts := _label(more, "Rueda: zoom · Derecho: orbitar · Inicio: centrar · Esc: menú")
	shortcuts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shortcuts.add_theme_font_size_override("font_size", 12)
	new_game_confirmation = ConfirmationDialog.new()
	new_game_confirmation.title = "Nueva partida"
	new_game_confirmation.dialog_text = "¿Descartar la partida actual y empezar de nuevo?"
	new_game_confirmation.ok_button_text = "Nueva partida"
	new_game_confirmation.confirmed.connect(_confirm_new_game)
	layer.add_child(new_game_confirmation)
	_build_dice_banner(layer, theme)


func _build_dice_banner(layer: CanvasLayer, theme: Dictionary) -> void:
	var top := CenterContainer.new()
	top.name = "DiceBannerAnchor"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_top = 16
	top.offset_right = -18
	top.offset_bottom = 74
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	dice_banner = PanelContainer.new()
	dice_banner.name = "DiceBanner"
	dice_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := GameThemes.panel_box(theme)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	dice_banner.add_theme_stylebox_override("panel", box)
	dice_banner.visible = false
	top.add_child(dice_banner)
	dice_banner_label = Label.new()
	dice_banner_label.name = "DiceBannerText"
	dice_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dice_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_banner_label.add_theme_font_size_override("font_size", 20)
	dice_banner_label.add_theme_color_override("font_color", Palette.SUN)
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		dice_banner_label.add_theme_font_override("font", style.DISPLAY_FONT)
	dice_banner.add_child(dice_banner_label)


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func set_bot(enabled: bool, player: int) -> void:
	if player < 0 or player >= bots.size():
		return
	bots[player] = enabled
	_bot_wait = 0.0
	if player < bot_toggles.size() and bot_toggles[player].button_pressed != enabled:
		bot_toggles[player].set_pressed_no_signal(enabled)
	_refresh()


func is_bot_turn() -> bool:
	if online and (net_table == null or not net_table.is_host()):
		return false
	return rules.phase != LudoRules.FINISHED and rules.turn < bots.size() and bots[rules.turn]


func _process(delta: float) -> void:
	var cur_frame := Engine.get_process_frames()
	var manual_loop := (cur_frame == _last_engine_frame)
	_last_engine_frame = cur_frame
	if waiting_roll and not _roll_should_submit and die != null:
		if manual_loop and die.is_forced_rolling():
			die._step_forced_roll(delta)
		if not die.is_forced_rolling():
			_update_die(0.0)
	if not is_bot_turn() or waiting_roll or grabber.held != null or not in_transit.is_empty():
		if _bot_wait > 0.0:
			_bot_wait = 0.0
		return
	_bot_wait += delta
	if _bot_wait >= TableBots.think_time(TableBots.difficulty):
		_bot_wait = 0.0
		bot_step()


## Una acción del bot: tirar el dado o mover la ficha que elige TableBots.
func bot_step() -> bool:
	var seat := rules.turn
	if rules.phase == LudoRules.ROLL:
		_roll(seat)
		return true
	if rules.phase == LudoRules.MOVE:
		var token := TableBots.ludo_choice(rules, TableBots.difficulty)
		if token >= 0:
			_choose_token(token, seat)
			help.text = tr("El bot mueve su ficha %d.") % (token + 1)
			return true
	return false


func _refresh() -> void:
	_update_seats()
	var shown_turn := _remote_roll_seat if (waiting_roll and _remote_roll_seat >= 0) else rules.turn
	status.text = (
		"%s · %d jugadores\nTurno J%d (%s)%s"
		% [
			"Parchís" if rules.is_parchis() else "Ludo",
			rules.players,
			shown_turn + 1,
			_player_name(shown_turn),
			" · bot" if (shown_turn >= 0 and shown_turn < bots.size() and bots[shown_turn]) else "",
		]
	)
	if rules.phase == LudoRules.FINISHED and not waiting_roll:
		status.text = "¡Gana J%d (%s)!" % [rules.winner + 1, _player_name(rules.winner)]
	elif waiting_roll or _awaiting_roll_ack:
		status.text += " · 🎲 tirando el dado…"
	elif rules.phase == LudoRules.MOVE and rules.bonus > 0:
		status.text += " · premio de %d casillas" % rules.bonus
	elif rules.phase == LudoRules.MOVE:
		status.text += " · dado %d" % rules.die
		if rules.steps() != rules.die:
			status.text += " (cuenta %d)" % rules.steps()
	elif not _last_roll_note.is_empty():
		status.text += "\n" + _last_roll_note
	_update_dice_banner()
	var can_act := is_local_turn()
	roll_button.disabled = (
		rules.phase != LudoRules.ROLL or waiting_roll or _awaiting_roll_ack or not can_act
	)
	reset_button.disabled = (
		rules.phase != LudoRules.ROLL
		or _awaiting_roll_ack
		or (waiting_roll and not _roll_should_submit)
		or not can_act
	)
	if load_game_button != null:
		load_game_button.disabled = online
	if new_game_button != null:
		new_game_button.disabled = online
	var legal: Array[int] = []
	if not waiting_roll:
		legal = rules.legal_tokens()
	var marker_y := 0.014 if _is_parchis_board() else 0.035
	for index in range(4):
		token_buttons[index].disabled = (index not in legal) or not can_act or waiting_roll
		markers[index].visible = (index in legal) and can_act and not waiting_roll
		if index in legal and not waiting_roll:
			markers[index].position = (
				_token_position(rules.turn, index, rules.destination(index)) + Vector3.UP * marker_y
			)
	if waiting_roll:
		help.text = "El dado está rodando; espera a ver el resultado."
	elif not can_act and rules.phase != LudoRules.FINISHED:
		help.text = "Esperando el turno de J%d (%s)…" % [rules.turn + 1, _player_name(rules.turn)]
	elif rules.phase == LudoRules.ROLL:
		help.text = "Lanza o arrastra y suelta el dado."
	elif rules.phase == LudoRules.MOVE and rules.bonus > 0:
		help.text = "Premio: mueve %d casillas con la ficha que quieras." % rules.bonus
	elif rules.phase == LudoRules.MOVE:
		help.text = "Elige una ficha disponible o arrástrala a su destino verde."
	else:
		help.text = "Partida terminada. Vuelve al menú para empezar otra."


func _update_dice_banner() -> void:
	if dice_banner == null or dice_banner_label == null:
		return
	if waiting_roll:
		var roller := _remote_roll_seat if _remote_roll_seat >= 0 else rules.turn
		dice_banner_label.text = "🎲 J%d (%s) tirando el dado…" % [
			roller + 1,
			_player_name(roller),
		]
		dice_banner.visible = true
		return
	var val := _last_roll_value if _last_roll_value >= 1 else rules.die
	if val >= 1 and val <= 6:
		var seat := _last_roll_seat if _last_roll_seat >= 0 else rules.turn
		dice_banner_label.text = "🎲 J%d (%s) sacó %d" % [
			seat + 1,
			_player_name(seat),
			val,
		]
		dice_banner.visible = true
	else:
		dice_banner.visible = false


func _physics_process(delta: float) -> void:
	if waiting_roll:
		_update_die(delta)
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			if token == grabber.held:
				continue
			var progress: int = rules.positions[player][index]
			var target := _token_position(player, index, progress)
			if in_transit.has(token):
				_steer_in_transit(token, target, progress == LudoRules.YARD)
				continue
			var displacement := Vector3(
				target.x - token.global_position.x, 0, target.z - token.global_position.z
			)
			var velocity := Vector3(token.linear_velocity.x, 0, token.linear_velocity.z)
			# Una ficha parada a varios centímetros de su sitio (porque se formó o deshizo una
			# barrera, o la empujó otra) no se mueve con esta fuerza: el rozamiento la frena.
			# Se la vuelve a llevar por el aire, como en un movimiento.
			# Se mide si se ha desplazado de verdad, no la velocidad: encajada contra otra ficha
			# tiembla con algo de velocidad sin avanzar.
			if displacement.length() > STALL_DISTANCE:
				var stall: Dictionary = _stalled.get(token, {"at": token.global_position, "time": 0.0})
				if token.global_position.distance_to(stall["at"]) > 0.02:
					stall = {"at": token.global_position, "time": 0.0}
				stall["time"] = float(stall["time"]) + delta
				_stalled[token] = stall
				if stall["time"] >= STALL_TIME:
					_stalled.erase(token)
					in_transit[token] = false
					continue
			else:
				_stalled.erase(token)
			if displacement.length() > 0.012 or velocity.length() > 0.03:
				token.sleeping = false
				token.apply_central_force(
					(displacement * 28.0 - velocity * 9.0).limit_length(20.0) * token.mass
				)


func _steer_in_transit(token: Token3D, target: Vector3, is_returning: bool = false) -> void:
	var parchis := _is_parchis_board()
	# Sube primero para no quedar atascada en las demás fichas de la casa.
	var traveling: bool = in_transit[token]
	var transit_limit := 1.6 if parchis else TRANSIT_LIMIT
	_transit_time[token] = float(_transit_time.get(token, 0.0)) + get_physics_process_delta_time()
	if _transit_time[token] >= transit_limit:
		token.global_position = target + Vector3.UP * 0.10
		token.linear_velocity = Vector3.ZERO
		token.angular_velocity = Vector3.ZERO
		_finish_transit(token)
		return
	if not traveling:
		_lift_wait[token] = float(_lift_wait.get(token, 0.0)) + get_physics_process_delta_time()
	var lift_ready_y := (0.98 if is_returning else 0.885) if parchis else 1.02
	var patience := 0.25 if parchis else LIFT_PATIENCE
	if not traveling and (token.global_position.y >= lift_ready_y or _lift_wait[token] >= patience):
		traveling = true
		in_transit[token] = true
		_lift_wait.erase(token)
	var displacement := Vector3(
		target.x - token.global_position.x, 0, target.z - token.global_position.z
	)
	var arrive_dist := 0.042 if parchis else 0.035
	if traveling and displacement.length() < arrive_dist:
		if parchis:
			token.linear_velocity.x *= 0.25
			token.linear_velocity.z *= 0.25
		_finish_transit(token)
		return
	if not traveling:
		displacement = Vector3.ZERO
	if parchis:
		var cruise_y := 1.08 if is_returning else 0.95
		var pull_p := displacement * 260.0
		var acc_p := pull_p - Vector3(token.linear_velocity.x, 0, token.linear_velocity.z) * 32.5
		acc_p.y = (cruise_y - token.global_position.y) * 110.0 - token.linear_velocity.y * 21.0
		acc_p.y += float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		token.sleeping = false
		token.apply_central_force(acc_p.limit_length(195.0) * token.mass)
		return
	var pull := displacement * 28.0
	if traveling and token.global_position.y < 1.0 and displacement.length() > 0.035:
		# Deslizándose (no pudo subir): empuje mínimo para vencer el rozamiento de otra ficha encima.
		pull = displacement.normalized() * maxf(pull.length(), 16.0)
	var acceleration := pull - Vector3(token.linear_velocity.x, 0, token.linear_velocity.z) * 9.0
	acceleration.y = (1.07 - token.global_position.y) * 45.0 - token.linear_velocity.y * 12.0
	acceleration.y += float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	token.sleeping = false
	token.apply_central_force(acceleration.limit_length(40.0) * token.mass)


func _finish_transit(token: Token3D) -> void:
	in_transit.erase(token)
	_lift_wait.erase(token)
	_transit_time.erase(token)


func _update_die(delta: float) -> void:
	if not _roll_should_submit:
		if not die.is_forced_rolling():
			_remote_roll_expected = 0
			_remote_roll_seat = -1
			_roll_should_submit = true
			waiting_roll = false
			_roll_elapsed = 0.0
			_bot_wait = -0.55
			_refresh()
		return
	if die.is_grabbed:
		_roll_elapsed = 0.0
	else:
		_roll_elapsed += delta
	if (
		absf(die.global_position.x) > 3.4
		or absf(die.global_position.z) > 2.3
		or die.global_position.y < 0.75
	):
		if is_bot_turn() or _roll_elapsed >= 4.5:
			var fallback_face := clampi(die.top_face(), 1, 6)
			die.global_position = TRAY_REST
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			die.set_top_face(fallback_face)
			stable_time = 1.0
		else:
			stable_time = 0.0
			help.text = "El dado salió de la mesa. Usa Recolocar dado."
			return
	var basis := die.global_basis.orthonormalized()
	var upright := maxf(absf(basis.x.dot(Vector3.UP)), absf(basis.y.dot(Vector3.UP)))
	upright = maxf(upright, absf(basis.z.dot(Vector3.UP)))
	var slow := die.linear_velocity.length() < 0.07 and die.angular_velocity.length() < 0.16
	if not die.is_grabbed and slow and upright < 0.96:
		stuck_time += delta
		if stuck_time >= 1.2 and nudges < 3:
			stuck_time = 0.0
			nudges += 1
			die.sleeping = false
			var inward := Vector3(2.66 - die.position.x, 0, -die.position.z).normalized()
			die.apply_central_impulse((Vector3.UP * 1.1 + inward * 0.35) * die.mass)
			die.apply_torque_impulse(
				Vector3(randf_range(-0.7, 0.7), 0.25, randf_range(-0.7, 0.7)) * die.mass
			)
			help.text = "Dado inclinado: se aplica un pequeño impulso físico."
		elif stuck_time >= 1.2:
			stuck_time = 0.0
			var settled_face := clampi(die.top_face(), 1, 6)
			die.global_position = Vector3(
				clampf(die.global_position.x, 2.15, 3.15),
				TRAY_REST.y,
				clampf(die.global_position.z, -0.8, 0.8)
			)
			die.linear_velocity = Vector3.ZERO
			die.angular_velocity = Vector3.ZERO
			die.set_top_face(settled_face)
			upright = 1.0
			slow = true
	else:
		stuck_time = 0.0
	if not die.is_grabbed and _roll_elapsed >= 4.5 and stable_time < 1.0:
		var cap_face := clampi(die.top_face(), 1, 6)
		die.global_position = Vector3(
			clampf(die.global_position.x, 2.15, 3.15),
			TRAY_REST.y,
			clampf(die.global_position.z, -0.8, 0.8)
		)
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		die.set_top_face(cap_face)
		stable_time = 1.0
	else:
		stable_time = stable_time + delta if not die.is_grabbed and slow and upright >= 0.96 else 0.0
	if stable_time >= 1.0:
		_roll_elapsed = 0.0
		if online:
			var val := die.top_face()
			var rseat := _remote_roll_seat
			var should_sub := _roll_should_submit
			_remote_roll_expected = 0
			_remote_roll_seat = -1
			_roll_should_submit = true
			waiting_roll = false
			die._awaiting_result = false
			die.ensure_celebrated(val)
			if should_sub:
				var submit_seat := rseat if rseat >= 0 else _local_seat()
				_last_roll_seat = submit_seat
				_last_roll_value = val
				if net_table != null and not net_table.is_host():
					_awaiting_roll_ack = true
				submit_change(
					{"type": "roll", "value": val, "seat": submit_seat, "manual": true},
					submit_seat
				)
			_bot_wait = -0.55
			_refresh()
			return
		var value := die.top_face()
		var actor := rules.turn
		waiting_roll = false
		_remote_roll_seat = -1
		die._awaiting_result = false
		die.ensure_celebrated(value)
		_last_roll_seat = actor
		_last_roll_value = value
		_last_roll_note = "Última tirada: J%d sacó %d" % [actor + 1, value]
		rules.apply_roll(value)
		_refresh()
		if rules.phase == LudoRules.ROLL:
			help.text = (
				"Salió %d; no había fichas disponibles. Continúa con la siguiente tirada." % value
			)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_R, KEY_T]
	):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		_roll()
		get_viewport().set_input_as_handled()


func _roll(actor_seat: int = -1) -> void:
	if (
		rules.phase != LudoRules.ROLL
		or waiting_roll
		or _awaiting_roll_ack
		or grabber.held != null
	):
		return
	if actor_seat < 0 and not is_local_turn():
		return
	if online:
		var submit_seat := actor_seat if actor_seat >= 0 else _local_seat()
		var val := randi_range(1, 6)
		if net_table != null and not net_table.is_host():
			_awaiting_roll_ack = true
			_refresh()
		submit_change({"type": "roll", "value": val, "seat": submit_seat}, submit_seat)
		return
	_remote_roll_expected = 0
	_remote_roll_seat = actor_seat
	_roll_should_submit = true
	_begin_roll()
	die.roll(0.55)


func _begin_roll() -> void:
	waiting_roll = true
	stable_time = 0.0
	stuck_time = 0.0
	nudges = 0
	_roll_elapsed = 0.0
	_refresh()


func _reset_die() -> void:
	if rules.phase != LudoRules.ROLL or grabber.held != null or _awaiting_roll_ack:
		return
	if not is_local_turn() or (online and not _roll_should_submit):
		return
	if die != null and die.is_forced_rolling():
		return
	waiting_roll = false
	_roll_elapsed = 0.0
	die._awaiting_result = false
	die.global_position = Vector3(2.66, 1.2, 0)
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	die.sleeping = false
	_refresh()
	help.text = "Dado recolocado; la tirada anterior no cuenta."


func _on_grab_started(object: InteractiveTableObject) -> void:
	if not online and not bots.has(true):
		return
	if not is_local_turn() or _awaiting_roll_ack or (waiting_roll and not _roll_should_submit):
		grabber.call_deferred("_release", "cancelled")
		return
	if object == die and (rules.phase != LudoRules.ROLL or waiting_roll):
		grabber.call_deferred("_release", "cancelled")
		return
	for player in range(rules.players):
		if object in tokens[player]:
			if online and player != _local_seat():
				grabber.call_deferred("_release", "cancelled")
				return
			if not online and player < bots.size() and bots[player]:
				grabber.call_deferred("_release", "cancelled")
				return


func _on_release(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if object == die:
		if (
			reason == "released"
			and rules.phase == LudoRules.ROLL
			and not waiting_roll
			and not _awaiting_roll_ack
		):
			if not is_local_turn():
				return
			_remote_roll_expected = 0
			_remote_roll_seat = -1
			_roll_should_submit = true
			_begin_roll()
		return
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			if object != token:
				continue
			var dest := rules.destination(index) if player == rules.turn else -2
			if reason == "released" and dest >= 0 and is_local_turn() and not waiting_roll:
				var goal := _token_position(player, index, dest)
				var aim := Vector2(target.x - goal.x, target.z - goal.z).length()
				var actual := (
					Vector2(token.global_position.x - goal.x, token.global_position.z - goal.z)
					. length()
				)
				if aim <= 0.12 and actual <= 0.16:
					_choose_token(index)
					return
			_refresh()
			help.text = "Movimiento no válido: la ficha vuelve a su casilla."
			return


func _choose_token(index: int, actor_seat: int = -1) -> void:
	if grabber.held != null or (waiting_roll and actor_seat < 0):
		return
	if actor_seat < 0 and not is_local_turn():
		return
	if online:
		var submit_seat := actor_seat if actor_seat >= 0 else _local_seat()
		if submit_change({"type": "move", "token": index, "seat": submit_seat}, submit_seat):
			help.text = "Movimiento aceptado; las fichas se desplazan con fuerzas."
		return
	var previous := rules.positions.duplicate(true)
	if rules.move(index):
		for player in range(rules.players):
			for token_index in range(4):
				if previous[player][token_index] != rules.positions[player][token_index]:
					in_transit[tokens[player][token_index]] = false
		_refresh()
		help.text = "Movimiento aceptado; las fichas se desplazan con fuerzas."


func _save_game() -> void:
	if waiting_roll or grabber.held != null:
		help.text = "Termina la tirada y suelta la ficha antes de guardar."
		return
	if rules.events.size() > LudoRules.MAX_EVENTS:
		help.text = "La partida supera el límite; se conserva el guardado anterior."
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.ludo):
		help.text = "No se pudo guardar; comprueba el espacio e inténtalo de nuevo."
		return
	help.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	if online:
		help.text = "La partida en línea se sincroniza desde el anfitrión; el guardado local no se usa."
		return
	if waiting_roll or grabber.held != null:
		help.text = "Termina la tirada y suelta la ficha antes de cargar."
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.ludo)
	if loaded.is_empty():
		help.text = "Guardado ausente o inválido; se conserva la partida actual."
		return
	rules = loaded["value"] as LudoRules
	in_transit.clear()
	_update_token_activity()
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			token.global_position = (
				_token_position(player, index, rules.positions[player][index]) + Vector3.UP * 0.1
			)
			token.linear_velocity = Vector3.ZERO
			token.angular_velocity = Vector3.ZERO
	_refresh()
	help.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


func _new_game() -> void:
	if online:
		help.text = "La partida en línea continúa desde el anfitrión; usa el menú para salir."
		return
	if _can_replace_game():
		new_game_confirmation.popup_centered()


func _confirm_new_game() -> void:
	if online:
		return
	if _can_replace_game():
		get_tree().change_scene_to_file(scene_file_path)


func _can_replace_game() -> bool:
	if waiting_roll or is_instance_valid(grabber.held) or grabber._pending_press:
		help.text = "Termina la tirada y suelta la ficha antes de continuar."
		return false
	return true


func _request_load() -> void:
	confirm_action.request(
		"Cargar partida",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game,
		_can_replace_game
	)
