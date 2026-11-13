class_name GuidedPhysicalCheckers
extends PhysicalCheckers

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

# El modelo lógico decide las jugadas; los cuerpos siguen siendo dinámicos.
const MAX_SAVE_BYTES := 262144

@export var home_spring := 28.0
@export var home_damping := 9.0
@export var max_home_acceleration := 20.0
@export var save_path := "user://diceon_checkers.json"

var rules := CheckersRules.new()
var token_squares: Dictionary = {}
var initial_squares: Dictionary = {}
var home_positions: Dictionary = {}
var white_captured := 0
var black_captured := 0
var _snapshots: Array[Dictionary] = []
var _dragged: Token3D
var _drag_from := -1
var _legal_destinations: Array[int] = []
var _squares: Array[MeshInstance3D] = []
var _light: Material
var _dark: Material
var _selected: Material
var _legal: Material
## Las oscuras las juega un bot (TableBots).
var bot_enabled := false
var _bot_wait := 0.0
var _bot_toggle: CheckBox
var online := false
var net_table: CheckersNetTable
var _online_bots: Array[bool] = [false, false]


func _net() -> Node:
	return get_node_or_null("/root/Net")


func _local_seat() -> int:
	var net := _net()
	return int(net.local_seat()) if net != null else -1


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	super._ready()
	_light = BoardGeometry.make_material(Palette.BOARD_LIGHT)
	_dark = BoardGeometry.make_material(Palette.BOARD_DARK)
	_selected = BoardGeometry.make_material(Palette.SELECTED)
	_legal = BoardGeometry.make_material(Palette.LEGAL)
	for node in tiles_root.get_children():
		if node is MeshInstance3D and _squares.size() < 64:
			_squares.append(node)
	for child in objects.get_children():
		var token := child as Token3D
		if token == null:
			continue
		var square: int = _square_from_position(token.global_position)
		token_squares[token] = square
		home_positions[token] = _square_center(square)
	initial_squares = token_squares.duplicate()
	grabber.grab_started.connect(_on_grab_started)
	grabber.grab_finished.connect(_on_grab_finished)
	$UI/Panel/Margin/Content/Undo.pressed.connect(_undo)
	$UI/Panel/Margin/Content/Save.pressed.connect(_save_game)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Load as Button,
		"Cargar partida",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game,
		_can_leave_table
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Free as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_free,
		_can_leave_table
	)
	_bot_toggle = CheckBox.new()
	_bot_toggle.name = "BotToggle"
	_bot_toggle.text = "Las oscuras las juega un bot"
	_bot_toggle.toggled.connect(set_bot_enabled)
	var content := $UI/Panel/Margin/Content
	content.add_child(_bot_toggle)
	content.move_child(_bot_toggle, $UI/Panel/Margin/Content/Undo.get_index())
	if TableBots.solo:
		# Menú de bots: la mesa empieza en solitario contra el bot de las oscuras.
		TableBots.solo = false
		set_bot_enabled(true)
	_start_online()
	_refresh_guides()


func _start_online() -> void:
	var net := _net()
	if net == null or str(net.room_game) != "CheckersOnline":
		return
	if not (FusionBridge.in_room()):
		return
	online = true
	net_table = CheckersNetTable.new()
	net_table.name = "NetTable"
	net_table.view_node = self
	net_table.checkers = rules
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
	var load_btn := get_node_or_null("UI/Panel/Margin/Content/Load") as Button
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
			_refresh_guides()


func _is_awaiting_sync() -> bool:
	return online and net_table != null and not net_table.synced


func is_local_turn() -> bool:
	if not online:
		return not is_bot_turn()
	if _is_awaiting_sync():
		return false
	var active_seat := 0 if rules.turn == CheckersRules.WHITE else 1
	return _local_seat() == active_seat and not is_bot_turn()


func submit_change(action: Dictionary, acting_seat: int = -1) -> bool:
	if not online or net_table == null:
		return false
	return net_table.submit(action, acting_seat)


func apply_change(change: Dictionary) -> bool:
	if str(change.get("type", "")) != "move":
		return false
	var from_sq := int(change.get("from", -1))
	var to_sq := int(change.get("to", -1))
	var mover := _token_at_square(from_sq)
	if not _apply_move(from_sq, to_sq, mover):
		return false
	_refresh_guides()
	return true


func sync_from_record(record: Dictionary) -> bool:
	if not _restore_record(record):
		return false
	_dragged = null
	_drag_from = -1
	_legal_destinations.clear()
	_update_kings()
	_refresh_guides()
	return true


func set_bot_enabled(enabled: bool) -> void:
	bot_enabled = enabled
	_bot_wait = 0.0
	if _bot_toggle != null and _bot_toggle.button_pressed != enabled:
		_bot_toggle.set_pressed_no_signal(enabled)
	_refresh_guides()


func is_bot_turn() -> bool:
	if rules.status() != "playing":
		return false
	if online:
		if net_table == null or not net_table.is_host():
			return false
		var active_seat := 0 if rules.turn == CheckersRules.WHITE else 1
		if active_seat == 1 and bot_enabled:
			return true
		return _online_bots[active_seat]
	return bot_enabled and rules.turn == CheckersRules.BLACK


func _process(delta: float) -> void:
	if not is_bot_turn() or is_instance_valid(grabber.held) or is_instance_valid(_dragged):
		_bot_wait = 0.0
		return
	_bot_wait += delta
	if _bot_wait >= TableBots.think_time(TableBots.difficulty):
		_bot_wait = 0.0
		bot_step()


## Una jugada del bot (un paso o un salto de la cadena).
func bot_step() -> bool:
	var move := TableBots.checkers_choice(rules, TableBots.difficulty)
	if move.is_empty():
		return false
	if online:
		var bot_seat := 0 if rules.turn == CheckersRules.WHITE else 1
		if not submit_change({"type": "move", "from": int(move["from"]), "to": int(move["to"])}, bot_seat):
			return false
		$UI/Panel/Margin/Content/Help.text = "El bot ha movido."
		return true
	var mover := _token_at_square(int(move["from"]))
	if not _apply_move(int(move["from"]), int(move["to"]), mover):
		return false
	$UI/Panel/Margin/Content/Help.text = "El bot ha movido. Te toca."
	_refresh_guides()
	return true


func _physics_process(_delta: float) -> void:
	for key in home_positions:
		var token := key as Token3D
		if not is_instance_valid(token) or token == grabber.held or token.freeze:
			continue
		HomeSteering.steer(token, home_positions[token], home_spring, home_damping, max_home_acceleration)


func _on_grab_started(object: InteractiveTableObject) -> void:
	_dragged = object as Token3D
	_drag_from = int(token_squares.get(_dragged, -1))
	_legal_destinations.clear()
	if online and not is_local_turn():
		grabber.call_deferred("_release", "cancelled")
		_refresh_guides()
		$UI/Panel/Margin/Content/Help.text = "Espera el turno de tu rival."
		return
	if online:
		var pval := rules.piece_at(_drag_from) if _drag_from >= 0 else 0
		var own_piece := (pval > 0 and _local_seat() == 0) or (pval < 0 and _local_seat() == 1)
		if not own_piece:
			grabber.call_deferred("_release", "cancelled")
			_refresh_guides()
			$UI/Panel/Margin/Content/Help.text = "Solo puedes mover tus propias fichas."
			return
	if _drag_from >= 0 and rules.status() == "playing":
		for move in rules.legal_moves_from(_drag_from):
			_legal_destinations.append(int(move["to"]))
	_refresh_guides()
	if _legal_destinations.is_empty():
		$UI/Panel/Margin/Content/Help.text = "Esa ficha no tiene movimientos legales en este turno."


func _on_grab_finished(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if object != _dragged or not is_instance_valid(_dragged):
		return
	var accepted := false
	var destination: int = _square_from_position(target)
	if reason == "released" and destination in _legal_destinations:
		var center: Vector3 = _square_center(destination)
		var offset := Vector2(
			_dragged.global_position.x - center.x, _dragged.global_position.z - center.z
		)
		# No confirmar una casilla a la que el cuerpo todavía no ha llegado.
		if offset.length() <= CELL * 0.55:
			if online:
				accepted = submit_change({"type": "move", "from": _drag_from, "to": destination})
			else:
				accepted = _apply_move(_drag_from, destination)
	_dragged = null
	_drag_from = -1
	_legal_destinations.clear()
	_refresh_guides()
	if not accepted and reason == "released":
		if is_instance_valid(object):
			object.flash_invalid()
		$UI/Panel/Margin/Content/Help.text = ("Movimiento rechazado: la ficha vuelve a su casilla.")
	elif reason in ["cancelled", "recovered"]:
		$UI/Panel/Margin/Content/Help.text = "Movimiento cancelado; la ficha vuelve a su casilla."


func _apply_move(from_square: int, to_square: int, mover: Token3D = null) -> bool:
	if mover == null:
		mover = _dragged
	var chosen: Dictionary = {}
	for move in rules.legal_moves_from(from_square):
		if int(move["to"]) == to_square:
			chosen = move
			break
	if chosen.is_empty():
		return false
	var captured_square: int = int(chosen.get("captured", -1))
	var captured_piece: int = rules.piece_at(captured_square)
	var victim: Token3D = _token_at_square(captured_square)
	# Nunca aceptar una captura si falta la representación física.
	if captured_square >= 0 and not is_instance_valid(victim):
		return false
	var snapshot := {
		"squares": token_squares.duplicate(),
		"homes": home_positions.duplicate(),
		"white_captured": white_captured,
		"black_captured": black_captured
	}
	if not rules.play(from_square, to_square):
		return false
	_snapshots.append(snapshot)
	token_squares[mover] = to_square
	home_positions[mover] = _square_center(to_square)
	if is_instance_valid(victim):
		token_squares[victim] = -1
		# El color procede del estado lógico anterior, no de la apariencia.
		home_positions[victim] = _capture_home(captured_piece)
	_update_kings()
	$UI/Panel/Margin/Content/Help.text = "Jugada aceptada. Las fichas se estabilizan con fuerzas."
	return true


func _capture_home(piece: int) -> Vector3:
	var index: int
	var side: int
	if piece > 0:
		index = white_captured
		white_captured += 1
		side = 1
	else:
		index = black_captured
		black_captured += 1
		side = -1
	return _capture_position(side, index)


func _capture_position(side: int, index: int) -> Vector3:
	return Vector3(side * (2.15 + 0.55 * (index / 6)), BOARD_HEIGHT, -1.75 + 0.7 * (index % 6))


func _token_at_square(square: int) -> Token3D:
	if square < 0:
		return null
	for key in token_squares:
		if int(token_squares[key]) == square and is_instance_valid(key):
			return key as Token3D
	return null


func _update_kings() -> void:
	for key in token_squares:
		var token := key as Token3D
		if not is_instance_valid(token):
			continue
		var square: int = int(token_squares[token])
		# Las fichas capturadas no forman parte del tablero y no conservan indicador.
		token.set_king(square >= 0 and absi(rules.piece_at(square)) == CheckersRules.KING)


func _reset() -> void:
	if online:
		$UI/Panel/Margin/Content/Help.text = "La partida online se sincroniza desde el anfitrión."
		return
	super._reset()


func _undo() -> void:
	if online:
		return
	if is_instance_valid(grabber.held):
		$UI/Panel/Margin/Content/Help.text = "Suelta la ficha antes de deshacer."
		return
	if _snapshots.is_empty() or not rules.undo():
		return
	var snapshot: Dictionary = _snapshots.pop_back()
	# Con bot, deshacer vuelve hasta tu última jugada (si no, el bot la repetiría al momento).
	while bot_enabled and rules.turn == CheckersRules.BLACK and not _snapshots.is_empty() and rules.undo():
		snapshot = _snapshots.pop_back()
	token_squares = snapshot["squares"]
	home_positions = snapshot["homes"]
	white_captured = snapshot["white_captured"]
	black_captured = snapshot["black_captured"]
	_update_kings()
	_refresh_guides()


func _save_game() -> void:
	if is_instance_valid(grabber.held):
		$UI/Panel/Margin/Content/Help.text = "Suelta la ficha antes de guardar."
		return
	if rules.move_log.size() > 1024:
		$UI/Panel/Margin/Content/Help.text = "Límite excedido; se conserva el guardado anterior."
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.checkers):
		$UI/Panel/Margin/Content/Help.text = "No se pudo guardar; revisa el espacio disponible."
		return
	$UI/Panel/Margin/Content/Help.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	if online:
		$UI/Panel/Margin/Content/Help.text = "La partida online se sincroniza desde el anfitrión; el guardado local no se usa."
		return
	if is_instance_valid(grabber.held):
		$UI/Panel/Margin/Content/Help.text = "Suelta la ficha antes de cargar."
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.checkers)
	if loaded.is_empty():
		$UI/Panel/Margin/Content/Help.text = "Guardado ausente o inválido; se conserva la partida actual."
		return
	if not _restore_record(loaded["record"]):
		$UI/Panel/Margin/Content/Help.text = "No se pudieron reconstruir las piezas; partida conservada."
		return
	_dragged = null
	_drag_from = -1
	_legal_destinations.clear()
	_update_kings()
	_refresh_guides()
	$UI/Panel/Margin/Content/Help.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


# Primero valida el registro y reconstruye el mapa en memoria; no cambia la mesa si falla.
func _restore_record(record: Variant) -> bool:
	var candidate := CheckersRules.new()
	if not candidate.import_record(record):
		return false
	var replay := CheckersRules.new()
	var squares: Dictionary = initial_squares.duplicate()
	var homes: Dictionary = {}
	for token in squares:
		if not is_instance_valid(token):
			return false
		homes[token] = _square_center(int(squares[token]))
	var snapshots: Array[Dictionary] = []
	var white_count := 0
	var black_count := 0
	for move in candidate.move_log:
		var from_square: int = int(move["from"])
		var to_square: int = int(move["to"])
		var moving: Token3D = _find_token(squares, from_square)
		var capture_square := -1
		for option in replay.legal_moves_from(from_square):
			if int(option["to"]) == to_square:
				capture_square = int(option.get("captured", -1))
				break
		var captured: Token3D = _find_token(squares, capture_square)
		if (
			not is_instance_valid(moving)
			or (capture_square >= 0 and not is_instance_valid(captured))
		):
			return false
		var captured_piece: int = replay.piece_at(capture_square)
		snapshots.append(
			{
				"squares": squares.duplicate(),
				"homes": homes.duplicate(),
				"white_captured": white_count,
				"black_captured": black_count
			}
		)
		if not replay.play(from_square, to_square):
			return false
		squares[moving] = to_square
		homes[moving] = _square_center(to_square)
		if is_instance_valid(captured):
			squares[captured] = -1
			if captured_piece > 0:
				homes[captured] = _capture_position(1, white_count)
				white_count += 1
			else:
				homes[captured] = _capture_position(-1, black_count)
				black_count += 1
	# La asignación solo sucede después de verificar todo el historial.
	rules = candidate
	token_squares = squares
	home_positions = homes
	_snapshots = snapshots
	white_captured = white_count
	black_captured = black_count
	return true


func _find_token(squares: Dictionary, square: int) -> Token3D:
	if square < 0:
		return null
	for token in squares:
		if int(squares[token]) == square and is_instance_valid(token):
			return token as Token3D
	return null


func _refresh_guides() -> void:
	BoardGeometry.update_tiles(
		_squares, _drag_from, _legal_destinations, _light, _dark, _selected, _legal
	)
	var state: String = rules.status()
	if state == "white_wins":
		status_label.text = "Ganan las blancas."
	elif state == "black_wins":
		status_label.text = "Ganan las oscuras."
	else:
		status_label.text = (
			"Turno: " + ("blancas" if rules.turn == CheckersRules.WHITE else "oscuras")
		)
		if is_bot_turn():
			status_label.text += " (bot)"
		if rules.forced_from >= 0:
			status_label.text += " · continúa la captura"
		elif rules.has_any_capture():
			status_label.text += " · captura obligatoria"
	$UI/Panel/Margin/Content/Undo.disabled = online or _snapshots.is_empty()


func _on_selection_changed(_object: InteractiveTableObject) -> void:
	# El estado lógico debe permanecer visible al cambiar el hover.
	if _squares.size() == 64 and not is_instance_valid(grabber.held):
		_refresh_guides()


func _on_placement_message(_message: String) -> void:
	$UI/Panel/Margin/Content/Help.text = "Pieza recuperada; volverá a su posición lógica."


func _square_from_position(point: Vector3) -> int:
	var x: int = floori(point.x / CELL + 4.0)
	var y: int = floori(point.z / CELL + 4.0)
	return y * 8 + x if x >= 0 and x < 8 and y >= 0 and y < 8 else -1


func _square_center(square: int) -> Vector3:
	return BoardGeometry.square_position(square, CELL, BOARD_HEIGHT)


func _open_free() -> void:
	if online:
		var net := _net()
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	get_tree().change_scene_to_file("res://scenes/PhysicalCheckers.tscn")


func _open_sandbox() -> void:
	if online:
		var net := _net()
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	super._open_sandbox()


# --- Interfaz integrada en la mesa (TableHud) ---


func hud_seats() -> Array:
	return [
		{"name": "Blancas", "color": Palette.PIECE_LIGHT, "bot": false, "side": "east"},
		{"name": "Negras", "color": Palette.PIECE_DARK, "bot": bot_enabled, "side": "north"},
	]


func hud_active_seat() -> int:
	return 0 if rules.turn == CheckersRules.WHITE else 1
