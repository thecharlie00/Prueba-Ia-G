class_name GuidedDomino
extends PhysicalDomino

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const MAX_SAVE_BYTES := 262144
const HOME_SPRING := 28.0
const HOME_DAMPING := 9.0
const MAX_ACCELERATION := 20.0
const ANGULAR_SPRING := 4.0
const ANGULAR_DAMPING := 1.4
const TORQUE_SCALE := 0.8
const CHAIN_STEP := 0.46
const CHAIN_START_Z := -0.97
const LEFT_ZONE := Vector3(-1.05, BOARD_HEIGHT + 0.02, 1.45)
const RIGHT_ZONE := Vector3(1.05, BOARD_HEIGHT + 0.02, 1.45)
const ZONE_RADIUS := 0.42

@export var save_path := "user://diceon_domino.json"

var rules := DominoRules.new()
var tiles: Array[Domino3D] = []
var tile_ids: Dictionary = {}
var homes: Dictionary = {}
# Solo las fichas en cadena tienen una orientación asistida.
var home_rotations: Dictionary = {}
var _dragged: Domino3D
var _legal_ends: Array[String] = []
var _zone_materials: Dictionary = {}


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	super._ready()
	for child in objects.get_children():
		var tile := child as Domino3D
		if tile != null:
			var id: int = rules.values.find(Vector2i(tile.left_value, tile.right_value))
			tiles.append(tile)
			tile_ids[tile] = id
	_make_zone("left", LEFT_ZONE, "IZQUIERDA")
	_make_zone("right", RIGHT_ZONE, "DERECHA")
	grabber.grab_started.connect(_on_grab_started)
	grabber.grab_finished.connect(_on_grab_finished)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Rules as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_free,
		_can_leave_table
	)
	$UI/Panel/Margin/Content/Actions/Draw.pressed.connect(_draw)
	$UI/Panel/Margin/Content/Actions/Pass.pressed.connect(_pass)
	$UI/Panel/Margin/Content/SaveRow/Save.pressed.connect(_save_game)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/SaveRow/Load as Button,
		"Cargar partida",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game,
		_can_leave_table
	)
	_sync_homes(true)
	_refresh()


func _physics_process(_delta: float) -> void:
	for key in homes:
		var tile := key as Domino3D
		if not is_instance_valid(tile) or tile == grabber.held or tile.freeze:
			continue
		var home: Vector3 = homes[tile]
		var displacement := Vector3(
			home.x - tile.global_position.x, 0, home.z - tile.global_position.z
		)
		var velocity := Vector3(tile.linear_velocity.x, 0, tile.linear_velocity.z)
		if displacement.length() >= 0.015 or velocity.length() >= 0.03:
			var acceleration: Vector3 = displacement * HOME_SPRING - velocity * HOME_DAMPING
			if tile.sleeping:
				tile.sleeping = false
			tile.apply_central_force(acceleration.limit_length(MAX_ACCELERATION) * tile.mass)
		if home_rotations.has(tile):
			_steer_rotation(tile, home_rotations[tile])


func _on_grab_started(object: InteractiveTableObject) -> void:
	_dragged = object as Domino3D
	_legal_ends.clear()
	if is_instance_valid(_dragged):
		_legal_ends = rules.legal_ends(int(tile_ids.get(_dragged, -1)))
	_refresh_zones()
	if _legal_ends.is_empty():
		_help("Esa ficha no se puede jugar en este turno.")
	else:
		_help("Lleva la ficha a una zona verde y espera a que llegue antes de soltar.")


func _on_grab_finished(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if not is_instance_valid(_dragged) or object != _dragged:
		return
	var accepted := false
	if reason == "released":
		for end in _legal_ends:
			var zone := LEFT_ZONE if end == "left" else RIGHT_ZONE
			if (
				_horizontal_distance(target, zone) <= ZONE_RADIUS
				and _horizontal_distance(_dragged.global_position, zone) <= ZONE_RADIUS
			):
				if rules.play(int(tile_ids[_dragged]), end):
					accepted = true
					_sync_homes(false)
					break
	_dragged = null
	_legal_ends.clear()
	_refresh()
	if accepted:
		_help("Jugada aceptada. Las fichas se colocan y orientan por fuerzas.")
	elif reason in ["cancelled", "recovered"]:
		_help("Jugada cancelada; la ficha volverá a su sitio.")
	elif reason == "released":
		_help("Jugada rechazada; la ficha volverá a su sitio.")


func _draw() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la ficha antes de robar.")
		return
	var id := rules.draw()
	if id < 0:
		_help("Solo puedes robar si no tienes jugada y queda pozo.")
		return
	_sync_homes(false)
	_refresh()
	_help("Has robado. Si sigues sin jugada, roba otra ficha.")


func _pass() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la ficha antes de pasar.")
		return
	if not rules.pass_turn():
		_help("Solo puedes pasar si no hay jugada y el pozo está vacío.")
		return
	_refresh()
	_help("Turno pasado. Con dos pases se resuelve por puntos.")


func _save_game() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la ficha antes de guardar.")
		return
	if rules.events.size() > 128:
		_help("La partida supera el límite; se conserva el guardado anterior.")
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.domino):
		_help("No se pudo guardar; comprueba el espacio e inténtalo de nuevo.")
		return
	_help("Partida guardada en este dispositivo.")


func _load_game() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la ficha antes de cargar.")
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.domino)
	if loaded.is_empty():
		_help("Guardado ausente o inválido; se conserva la partida actual.")
		return
	rules = loaded["value"] as DominoRules
	_dragged = null
	_legal_ends.clear()
	_sync_homes(false)
	_refresh()
	_help(
		(
			"Cargada la copia anterior: el guardado principal falta o es inválido."
			if loaded["backup"]
			else "Partida cargada en este dispositivo."
		)
	)


# En la preparación inicial se colocan las fichas; después solo se actualizan destinos.
func _sync_homes(initial: bool) -> void:
	for tile in tiles:
		var id: int = tile_ids[tile]
		var position := Vector3.ZERO
		if id in rules.hands[0]:
			position = _hand_position(0, rules.hands[0].find(id))
		elif id in rules.hands[1]:
			position = _hand_position(1, rules.hands[1].find(id))
		elif id in rules.stock:
			var index: int = rules.stock.find(id)
			position = Vector3(
				(index % 7 - 3) * 0.49, BOARD_HEIGHT + 0.04, -1.57 + (index / 7) * 0.30
			)
		else:
			var index := _chain_index(id)
			position = _chain_position(index)
			home_rotations[tile] = _chain_rotation(index, rules.chain[index], tile)
		if id in rules.hands[0] or id in rules.hands[1] or id in rules.stock:
			home_rotations.erase(tile)
		homes[tile] = position
		if initial:
			tile.global_position = position + Vector3.UP * 0.08
			tile.linear_velocity = Vector3.ZERO
			tile.angular_velocity = Vector3.ZERO


# Seis fichas horizontales y una pieza de giro; las filas alternan el sentido.
func _chain_position(index: int) -> Vector3:
	var row := index / 7
	var column := index % 7
	var direction := 1.0 if row % 2 == 0 else -1.0
	var z := CHAIN_START_Z + row * CHAIN_STEP
	if column == 6:
		return Vector3(direction * 1.49, BOARD_HEIGHT + 0.04, z + CHAIN_STEP * 0.5)
	return Vector3(direction * (-1.15 + column * CHAIN_STEP), BOARD_HEIGHT + 0.04, z)


# El lado izquierdo del modelo debe mirar en el sentido de lectura de la cadena.
func _chain_rotation(index: int, entry: Dictionary, tile: Domino3D) -> Quaternion:
	var row := index / 7
	var column := index % 7
	var yaw := 0.0
	if column == 6:
		yaw = -PI / 2.0
	elif row % 2 == 1:
		yaw = PI
	if tile.left_value != int(entry["left"]):
		yaw += PI
	return Quaternion(Vector3.UP, yaw)


# Un resorte angular limita el error sin congelar, girar directamente ni ignorar colisiones.
func _steer_rotation(tile: Domino3D, target: Quaternion) -> void:
	var current := tile.global_basis.get_rotation_quaternion().normalized()
	var error := (target * current.inverse()).normalized()
	if error.w < 0.0:
		error = Quaternion(-error.x, -error.y, -error.z, -error.w)
	var vector := Vector3(error.x, error.y, error.z)
	var length := vector.length()
	if length < 0.005 and tile.angular_velocity.length() < 0.03:
		return
	var angular_error := Vector3.ZERO
	if length > 0.0001:
		angular_error = vector / length * (2.0 * atan2(length, error.w))
	var torque: Vector3 = (
		(angular_error * ANGULAR_SPRING - tile.angular_velocity * ANGULAR_DAMPING)
		* (tile.mass * TORQUE_SCALE)
	)
	# Compensa parcialmente la fricción estática cuando está casi inmóvil.
	if angular_error.length() > 0.06 and tile.angular_velocity.length() < 0.2:
		torque += angular_error.normalized() * tile.mass * 0.8
	if tile.sleeping:
		tile.sleeping = false
	tile.apply_torque(torque.limit_length(tile.mass * 3.0))


func _hand_position(player: int, index: int) -> Vector3:
	var side := -1.0 if player == 0 else 1.0
	return Vector3(side * (2.15 + (index / 7) * 0.48), 0.84, (index % 7 - 3) * 0.48)


func _chain_index(id: int) -> int:
	for i in range(rules.chain.size()):
		if int(rules.chain[i]["id"]) == id:
			return i
	return -1


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _make_zone(key: String, position: Vector3, title: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.82, 0.008, 0.36)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("60716a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.material_override = material
	marker.position = position
	add_child(marker)
	_zone_materials[key] = material
	var label := Label3D.new()
	label.text = title
	label.font_size = 36
	label.pixel_size = 0.0025
	label.modulate = Color("182d25")
	label.rotation_degrees.x = -90
	label.position = position + Vector3.UP * 0.01
	add_child(label)


func _refresh_zones() -> void:
	for end in ["left", "right"]:
		var material: StandardMaterial3D = _zone_materials[end]
		material.albedo_color = (Color("84d6a0") if end in _legal_ends else Color("63736c"))


func _refresh() -> void:
	_refresh_zones()
	var status := ""
	if rules.result == DominoRules.PLAYING:
		status = "Turno: jugador %d · Pozo: %d" % [rules.turn + 1, rules.stock.size()]
	else:
		match rules.result:
			DominoRules.PLAYER_1_WINS:
				status = "Gana el jugador 1"
			DominoRules.PLAYER_2_WINS:
				status = "Gana el jugador 2"
			_:
				status = "Empate"
		status += " · puntos: %d / %d" % [rules.hand_points(0), rules.hand_points(1)]
	if not rules.chain.is_empty():
		status += "\nExtremos: %d / %d" % [rules.chain.front()["left"], rules.chain.back()["right"]]
	status_label.text = status
	var entries: PackedStringArray = []
	for entry in rules.chain:
		entries.append("[%d|%d]" % [entry["left"], entry["right"]])
	$UI/Panel/Margin/Content/Chain.text = (
		"Cadena: " + (" ".join(entries) if not entries.is_empty() else "vacía")
	)
	var playing := rules.result == DominoRules.PLAYING
	$UI/Panel/Margin/Content/Actions/Draw.disabled = (
		not playing or rules.has_play() or rules.stock.is_empty()
	)
	$UI/Panel/Margin/Content/Actions/Pass.disabled = (
		not playing or rules.has_play() or not rules.stock.is_empty()
	)


func _on_selection_changed(object: InteractiveTableObject) -> void:
	# Mostrar los valores no es privacidad; también se ven al seleccionar boca abajo.
	$UI/Panel/Margin/Content/Selected.text = (
		object.display_name if is_instance_valid(object) else "Ninguna ficha seleccionada"
	)


func _on_placement_message(_message: String) -> void:
	_help("Ficha recuperada; volverá a su posición lógica.")


func _help(message: String) -> void:
	$UI/Panel/Margin/Content/Help.text = message


func _open_free() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicalDomino.tscn")


# --- Interfaz integrada en la mesa (TableHud) ---


func hud_seats() -> Array:
	return [
		{"name": "Jugador 1", "color": Palette.PLAYER_RED, "bot": false, "side": "west"},
		{"name": "Jugador 2", "color": Palette.PLAYER_BLUE, "bot": false, "side": "east"},
	]


func hud_active_seat() -> int:
	return rules.turn


func hud_seat_status(index: int) -> String:
	if index < rules.hands.size():
		return "%d fichas" % rules.hands[index].size()
	return ""
