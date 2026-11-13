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
## El jugador 2 lo juega un bot (TableBots).
var bot_enabled := false
var _bot_wait := 0.0
var _bot_toggle: CheckBox
var online := false
var net_table: DominoNetTable
var _online_bots: Array[bool] = [false, false]


func _net() -> Node:
	return get_node_or_null("/root/Net")


func _local_seat() -> int:
	var net := _net()
	return int(net.local_seat()) if net != null else -1


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
	_bot_toggle = CheckBox.new()
	_bot_toggle.name = "BotToggle"
	_bot_toggle.text = "El jugador 2 lo juega un bot"
	_bot_toggle.toggled.connect(set_bot_enabled)
	var content := $UI/Panel/Margin/Content
	content.add_child(_bot_toggle)
	content.move_child(_bot_toggle, $UI/Panel/Margin/Content/Actions.get_index())
	if TableBots.solo:
		# Menú de bots: la mesa empieza en solitario contra el bot del jugador 2.
		TableBots.solo = false
		set_bot_enabled(true)
	_sync_homes(true)
	_start_online()
	_refresh()


func _start_online() -> void:
	var net := _net()
	if net == null or str(net.room_game) != "DominoOnline":
		return
	if not (FusionBridge.in_room()):
		return
	online = true
	net_table = DominoNetTable.new()
	net_table.name = "NetTable"
	net_table.view_node = self
	net_table.domino = rules
	add_child(net_table)
	if net_table.is_host():
		var rbots: Array = net.room_bots
		_online_bots[0] = rbots.size() > 0 and bool(rbots[0])
		_online_bots[1] = rbots.size() > 1 and bool(rbots[1])
		if _online_bots[1]:
			set_bot_enabled(true)
	else:
		if _bot_toggle != null:
			_bot_toggle.disabled = true
		net_table.request_sync()
	var reset_btn := get_node_or_null("UI/Panel/Margin/Content/Reset") as Button
	if reset_btn != null:
		reset_btn.disabled = true
	var load_btn := get_node_or_null("UI/Panel/Margin/Content/SaveRow/Load") as Button
	if load_btn != null:
		load_btn.disabled = true
	net.player_left.connect(_on_net_player_left)


func _on_net_player_left(player_id: int) -> void:
	if online and net_table != null and net_table.is_host():
		var seat := player_id - 1
		if seat >= 0 and seat < _online_bots.size() and seat != _local_seat():
			_online_bots[seat] = true
			if seat == 1:
				set_bot_enabled(true)
			_refresh()


func _is_awaiting_sync() -> bool:
	return online and net_table != null and not net_table.synced


func is_local_turn() -> bool:
	if not online:
		return not is_bot_turn()
	if _is_awaiting_sync():
		return false
	return _local_seat() == rules.turn and not is_bot_turn()


func submit_change(action: Dictionary, acting_seat: int = -1) -> bool:
	if not online or net_table == null:
		return false
	return net_table.submit(action, acting_seat)


func apply_change(change: Dictionary) -> bool:
	var kind := str(change.get("type", ""))
	if kind == "play":
		if not rules.play(int(change.get("id", -1)), str(change.get("end", ""))):
			return false
		_sync_homes(false)
		_refresh()
		return true
	if kind == "draw":
		if rules.draw() < 0:
			return false
		_sync_homes(false)
		_refresh()
		return true
	if kind == "pass":
		if not rules.pass_turn():
			return false
		_refresh()
		return true
	return false


func sync_from_record(record: Dictionary) -> bool:
	if not rules.import_record(record):
		return false
	_dragged = null
	_legal_ends.clear()
	_sync_homes(true)
	_refresh()
	return true


func _viewer_seat() -> int:
	if online:
		if _is_awaiting_sync():
			return -1
		var in_room := FusionBridge.in_room()
		var seat := _local_seat() if in_room else maxi(0, _local_seat())
		if seat < 0 or seat >= 2 or _online_bots[seat]:
			return -1
		return seat
	if bot_enabled:
		return 0
	return rules.turn


func _update_tile_privacy() -> void:
	var awaiting := _is_awaiting_sync()
	var my_seat := _viewer_seat()
	var hand0: Array = rules.hands[0]
	var hand1: Array = rules.hands[1]
	var my_hand: Array = rules.hands[my_seat] if my_seat >= 0 and my_seat < 2 else []
	for tile in tiles:
		if not is_instance_valid(tile):
			continue
		var id: int = int(tile_ids[tile])
		var in_chain: bool = not hand0.has(id) and not hand1.has(id) and not rules.stock.has(id)
		var visible_pips: bool = not awaiting and (my_hand.has(id) or in_chain)
		var pips_node := tile.get_node_or_null("Visual/Pips") as Node3D
		if pips_node != null:
			pips_node.visible = visible_pips
		tile.display_name = (
			("Dominó %d | %d" % [tile.left_value, tile.right_value])
			if visible_pips
			else "Dominó oculto"
		)


func set_bot_enabled(enabled: bool) -> void:
	bot_enabled = enabled
	_bot_wait = 0.0
	if _bot_toggle != null and _bot_toggle.button_pressed != enabled:
		_bot_toggle.set_pressed_no_signal(enabled)
	_refresh()


func is_bot_turn() -> bool:
	if rules.result != DominoRules.PLAYING:
		return false
	if online:
		if net_table == null or not net_table.is_host():
			return false
		return (rules.turn == 1 and (bot_enabled or _online_bots[1])) or (rules.turn == 0 and _online_bots[0])
	return bot_enabled and rules.turn == 1


func _process(delta: float) -> void:
	if not is_bot_turn() or is_instance_valid(grabber.held):
		_bot_wait = 0.0
		return
	_bot_wait += delta
	if _bot_wait >= TableBots.think_time(TableBots.difficulty):
		_bot_wait = 0.0
		bot_step()


## Una acción del bot: jugar una ficha, robar o pasar.
func bot_step() -> bool:
	var choice := TableBots.domino_choice(rules, TableBots.difficulty)
	if online:
		var bot_seat := rules.turn
		if choice.has("id"):
			if not submit_change({"type": "play", "id": int(choice["id"]), "end": String(choice["end"])}, bot_seat):
				return false
			var btile: Vector2i = rules.values[int(choice["id"])]
			_help(tr("El bot juega [%d|%d] a la %s.") % [btile.x, btile.y, tr("izquierda" if choice["end"] == "left" else "derecha")])
			return true
		if choice.get("action") == "draw":
			if submit_change({"type": "draw"}, bot_seat):
				_help("El bot roba del pozo.")
				return true
			return false
		if choice.get("action") == "pass":
			if submit_change({"type": "pass"}, bot_seat):
				_help("El bot pasa.")
				return true
			return false
		return false
	if choice.has("id"):
		if not rules.play(int(choice["id"]), String(choice["end"])):
			return false
		_sync_homes(false)
		_refresh()
		var tile: Vector2i = rules.values[int(choice["id"])]
		_help(tr("El bot juega [%d|%d] a la %s.") % [tile.x, tile.y, tr("izquierda" if choice["end"] == "left" else "derecha")])
		return true
	if choice.get("action") == "draw":
		_draw()
		_help("El bot roba del pozo.")
		return true
	if choice.get("action") == "pass":
		_pass()
		_help("El bot pasa.")
		return true
	return false


func _physics_process(_delta: float) -> void:
	for key in homes:
		var tile := key as Domino3D
		if not is_instance_valid(tile) or tile == grabber.held or tile.freeze:
			continue
		HomeSteering.steer(tile, homes[tile], HOME_SPRING, HOME_DAMPING, MAX_ACCELERATION)
		if home_rotations.has(tile):
			_steer_rotation(tile, home_rotations[tile])


func _on_grab_started(object: InteractiveTableObject) -> void:
	_dragged = object as Domino3D
	_legal_ends.clear()
	var grabbed_id := int(tile_ids.get(_dragged, -1)) if is_instance_valid(_dragged) else -1
	if online or bot_enabled:
		var my_seat := _viewer_seat()
		var my_hand: Array = rules.hands[my_seat] if my_seat >= 0 and my_seat < 2 else []
		if not is_local_turn() or not my_hand.has(grabbed_id):
			grabber.call_deferred("_release", "cancelled")
			_refresh_zones()
			_help("Solo puedes jugar tus fichas cuando sea tu turno.")
			return
	if is_instance_valid(_dragged) and rules.hands[rules.turn].has(grabbed_id):
		_legal_ends = rules.legal_ends(grabbed_id)
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
				if online:
					if submit_change({"type": "play", "id": int(tile_ids[_dragged]), "end": end}):
						accepted = true
						break
				elif rules.play(int(tile_ids[_dragged]), end):
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
		if is_instance_valid(object):
			object.flash_invalid()
		_help("Jugada rechazada; la ficha volverá a su sitio.")


func _draw() -> void:
	if is_instance_valid(grabber.held):
		_help("Suelta la ficha antes de robar.")
		return
	if online:
		if not is_local_turn():
			_help("Espera tu turno.")
			return
		if submit_change({"type": "draw"}):
			_help("Has robado. Si sigues sin jugada, roba otra ficha.")
		else:
			_help("Solo puedes robar si no tienes jugada y queda pozo.")
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
	if online:
		if not is_local_turn():
			_help("Espera tu turno.")
			return
		if submit_change({"type": "pass"}):
			_help("Turno pasado. Con dos pases se resuelve por puntos.")
		else:
			_help("Solo puedes pasar si no hay jugada y el pozo está vacío.")
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


func _reset() -> void:
	if online:
		_help("La partida online se sincroniza desde el anfitrión.")
		return
	super._reset()


func _load_game() -> void:
	if online:
		_help("La partida online se sincroniza desde el anfitrión; el guardado local no se usa.")
		return
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
	if _is_awaiting_sync():
		status_label.text = "Conectando con el anfitrión…"
		$UI/Panel/Margin/Content/Chain.text = "Sincronizando reparto…"
		$UI/Panel/Margin/Content/Actions/Draw.disabled = true
		$UI/Panel/Margin/Content/Actions/Pass.disabled = true
		_update_tile_privacy()
		_help("Recibiendo reparto de fichas de la sala…")
		return
	var status := ""
	if rules.result == DominoRules.PLAYING:
		status = "Turno: jugador %d%s · Pozo: %d" % [
			rules.turn + 1, " (bot)" if is_bot_turn() else "", rules.stock.size()
		]
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
	var can_act := is_local_turn()
	$UI/Panel/Margin/Content/Actions/Draw.disabled = (
		not playing or not can_act or rules.has_play() or rules.stock.is_empty()
	)
	$UI/Panel/Margin/Content/Actions/Pass.disabled = (
		not playing or not can_act or rules.has_play() or not rules.stock.is_empty()
	)
	_update_tile_privacy()


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
	if online:
		var net := _net()
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	get_tree().change_scene_to_file("res://scenes/PhysicalDomino.tscn")


func _open_sandbox() -> void:
	if online:
		var net := _net()
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	super._open_sandbox()


# --- Interfaz integrada en la mesa (TableHud) ---


func hud_seats() -> Array:
	return [
		# J1 al fondo: sentado a la izquierda quedaba cortado en el borde de la pantalla.
		{"name": "Jugador 1", "color": Palette.PLAYER_RED, "bot": false, "side": "north"},
		{"name": "Jugador 2", "color": Palette.PLAYER_BLUE, "bot": bot_enabled, "side": "east"},
	]


func hud_active_seat() -> int:
	return rules.turn


func hud_seat_status(index: int) -> String:
	if index < rules.hands.size():
		return "%d fichas" % rules.hands[index].size()
	return ""
