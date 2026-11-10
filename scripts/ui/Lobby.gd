extends Control

## Lobby online: crear o entrar a una sala sale de inmediato al abrir la pantalla
## (conectando a Photon automáticamente si hace falta). Dentro de la sala muestra
## el código, las butacas (con opción de bots para el anfitrión), el chat y «Empezar».
## Sin App ID en los ajustes del proyecto (net/app_id) arranca en sala offline.
## La demo solo puede entrar a salas, no crearlas.

const INK := Color("1d1a3a")
const ACCENT := Color("ffc83d")
const PANEL := Color("2a2552")
const PAPER := Color("f3ead9")
const MUTED := Color("c9c5ef")

var _username: LineEdit
var _code: LineEdit
var _status: Label
var _name_row: HBoxContainer
var _create_box: VBoxContainer
var _join_box: VBoxContainer
var _room_box: VBoxContainer
var _game_row: HBoxContainer
var _seats: VBoxContainer
var _chat_log: TextEdit
var _chat_input: LineEdit
var _game: OptionButton
var _create_button: Button
var _enter_button: Button
var _enter_running_button: Button
var _start_button: Button
var _leave_button: Button
var _send_button: Button
var _code_label: Label
var _pending_action := ""


func _ready() -> void:
	_build()
	Net.room_joined.connect(_on_room_joined)
	Net.room_left.connect(_on_room_left)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.start_announced.connect(_on_start_announced)
	Net.room_info_received.connect(_refresh)
	if Engine.has_singleton("Fusion"):
		Fusion.register_broadcast_receiver(self)
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		_on_room_joined()
	else:
		_refresh()


func _exit_tree() -> void:
	if Engine.has_singleton("Fusion"):
		Fusion.unregister_broadcast_receiver(self)


func _build() -> void:
	var background := ColorRect.new()
	background.color = PANEL
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	center.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "Tablerama · Online"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color("ffd96e"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	_name_row = _row()
	var name_label := _label(_name_row, "Nombre")
	name_label.custom_minimum_size.x = 76
	_username = LineEdit.new()
	_username.name = "Username"
	_username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_username.custom_minimum_size.x = 220
	var default_user := (
		Net.local_name
		if not Net.local_name.is_empty()
		else str(ProjectSettings.get_setting("net/user", "Jugador"))
	)
	_username.text = default_user
	_name_row.add_child(_username)
	column.add_child(_name_row)

	# 1. Crear sala (sale primero)
	_create_box = VBoxContainer.new()
	_create_box.name = "CreateSection"
	_create_box.add_theme_constant_override("separation", 8)
	column.add_child(_create_box)

	var create_heading := _section_label("CREAR SALA")
	_create_box.add_child(create_heading)

	_game_row = _row()
	var game_label := _label(_game_row, "Mesa")
	game_label.custom_minimum_size.x = 76
	_game = OptionButton.new()
	_game.name = "Game"
	var default_game_idx := 0
	for i in range(Net.ONLINE_GAMES.size()):
		var entry: Dictionary = Net.ONLINE_GAMES[i]
		_game.add_item(str(entry["title"]))
		if entry["id"] == "Island":
			default_game_idx = i
	if _game.item_count > 0:
		_game.select(default_game_idx)
	_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game.custom_minimum_size.x = 240
	_game_row.add_child(_game)
	_create_box.add_child(_game_row)

	_create_button = _button(_create_box, "Crear sala", "Create", _create_room)
	_create_button.custom_minimum_size = Vector2(260, 52)

	# 2. Entrar a una sala con código (sale justo debajo)
	_join_box = VBoxContainer.new()
	_join_box.name = "JoinSection"
	_join_box.add_theme_constant_override("separation", 8)
	column.add_child(_join_box)

	var join_heading := _section_label("UNIRSE CON CÓDIGO")
	_join_box.add_child(join_heading)

	var code_row := _row()
	var code_label := _label(code_row, "Código")
	code_label.custom_minimum_size.x = 76
	_code = LineEdit.new()
	_code.name = "Code"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size.x = 220
	_code.text = ""
	_code.placeholder_text = "ABC123"
	_code.text_submitted.connect(func(_t: String) -> void: _enter_button_pressed())
	code_row.add_child(_code)
	_join_box.add_child(code_row)

	_enter_button = _button(_join_box, "Entrar a sala", "Join", _enter_button_pressed)
	_enter_button.custom_minimum_size = Vector2(260, 52)

	# 3. Vista dentro de la sala (oculta hasta crear o entrar)
	_room_box = VBoxContainer.new()
	_room_box.name = "RoomSection"
	_room_box.add_theme_constant_override("separation", 10)
	column.add_child(_room_box)

	_code_label = Label.new()
	_code_label.name = "RoomCode"
	_code_label.add_theme_font_size_override("font_size", 18)
	_code_label.add_theme_color_override("font_color", Color("ffd96e"))
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_box.add_child(_code_label)

	var seats_label := _section_label("BUTACAS")
	_room_box.add_child(seats_label)

	_seats = VBoxContainer.new()
	_seats.name = "Seats"
	_seats.add_theme_constant_override("separation", 6)
	_room_box.add_child(_seats)

	_start_button = _button(_room_box, "Empezar partida", "Start", _start)
	_start_button.custom_minimum_size = Vector2(260, 56)

	_enter_running_button = _button(
		_room_box, "Entrar a la partida", "EnterRunning", _enter_running
	)
	_enter_running_button.custom_minimum_size = Vector2(260, 52)

	var chat_label := _section_label("CHAT")
	_room_box.add_child(chat_label)

	_chat_log = TextEdit.new()
	_chat_log.name = "ChatLog"
	_chat_log.custom_minimum_size = Vector2(340, 90)
	_chat_log.editable = false
	_chat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_room_box.add_child(_chat_log)

	var chat_row := _row()
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.x = 220
	_chat_input.placeholder_text = "Escribe y pulsa Enviar"
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	chat_row.add_child(_chat_input)
	_send_button = _button(chat_row, "Enviar", "Send", _send_chat)
	_room_box.add_child(chat_row)

	_leave_button = _button(column, "Volver", "Leave", _leave)
	_leave_button.custom_minimum_size = Vector2(260, 48)

	_style_button(_create_button, ACCENT)
	_style_button(_enter_button, Color("fff8ec"))
	_style_button(_start_button, ACCENT)
	_style_button(_enter_running_button, ACCENT)
	_style_button(_leave_button, Color("fff8ec"))
	_style_button(_send_button, Color("fff8ec"))


func _row() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	return box


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PAPER)
	parent.add_child(label)
	return label


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", ACCENT)
	return label


func _button(parent: Node, text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style_button(button: Button, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(Color("ffd96e")))
	button.add_theme_stylebox_override("pressed", _style(ACCENT, true))
	button.add_theme_stylebox_override("focus", _focus_style())


func _style(color: Color, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	style.border_width_bottom = 3 if pressed else 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9 if pressed else 6
	style.set_corner_radius_all(12)
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = ACCENT
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.expand_margin_left = 4
	style.expand_margin_right = 4
	style.expand_margin_top = 4
	style.expand_margin_bottom = 4
	return style


#region Flujo de pantalla

## Fuera de sala: crear sala y unirse con código salen de inmediato.
func _show_pre_room() -> void:
	var available := Net.is_available()
	var busy := not _pending_action.is_empty()
	_name_row.visible = true
	_create_box.visible = not Edition.demo
	_create_button.visible = true
	_join_box.visible = true
	_room_box.visible = false
	_leave_button.text = "Volver"
	_create_button.disabled = not available or busy or Edition.demo or _game.selected < 0
	_enter_button.disabled = not available or busy
	if not available:
		_set_status("Instala el addon Photon Fusion para jugar online.")
	elif not busy and _status.text.is_empty():
		if Edition.demo:
			_set_status("Edición demo: escribe un código para unirte a una sala.")
		else:
			_set_status("Elige una mesa para crear sala o introduce el código de un amigo.")
	_refresh_seats()


func _show_lobby() -> void:
	var in_room := Engine.has_singleton("Fusion") and Fusion.is_in_room()
	var offline := Net.is_singleplayer()
	var is_host := in_room and (offline or Net.is_host())
	_name_row.visible = false
	_create_box.visible = is_host and Net.room_game.is_empty()
	_create_button.visible = false
	_join_box.visible = false
	_room_box.visible = true
	_leave_button.text = "Salir de la sala"

	var entry := _game_entry()
	var game_title := str(entry.get("title", ""))
	if not Net.room_code.is_empty() and not game_title.is_empty():
		_code_label.text = "Código: %s\n%s" % [Net.room_code, game_title]
		_code_label.visible = true
	elif not Net.room_code.is_empty():
		_code_label.text = "Código: %s" % Net.room_code
		_code_label.visible = true
	elif not game_title.is_empty():
		_code_label.text = game_title
		_code_label.visible = true
	else:
		_code_label.visible = false

	_start_button.visible = is_host and not in_room_started()
	_start_button.disabled = _start_button.visible and not _can_start()
	_enter_running_button.visible = in_room_started() and not is_host
	_refresh_seats()


func in_room_started() -> bool:
	return Net.room_started


func _can_start() -> bool:
	if Net.room_game.is_empty():
		return _game.selected >= 0
	return not _game_entry().is_empty()


func _game_entry() -> Dictionary:
	for entry in Net.ONLINE_GAMES:
		if entry["id"] == Net.room_game:
			return entry
	return {}


func _selected_entry() -> Dictionary:
	var index := _game.selected
	if index < 0 or index >= Net.ONLINE_GAMES.size():
		return {}
	return Net.ONLINE_GAMES[index]


func _refresh() -> void:
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		_show_lobby()
	else:
		_show_pre_room()


func _set_status(message: String) -> void:
	_status.text = message


func _refresh_seats() -> void:
	for child in _seats.get_children():
		_seats.remove_child(child)
		child.queue_free()
	if not (Engine.has_singleton("Fusion") and Fusion.is_in_room()):
		return
	var local_id := Fusion.get_local_player_id()
	var offline := Net.is_singleplayer()
	var is_host := offline or Net.is_host()
	var entry := _game_entry()
	if entry.is_empty():
		entry = _selected_entry()
	var seat_count := int(entry.get("seats", Net.room_seats if Net.room_seats > 0 else 3))

	for seat in range(seat_count):
		var pid := seat + 1
		var row := _row()
		var seat_label := Label.new()
		seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat_label.add_theme_color_override("font_color", PAPER)
		if pid == local_id:
			var my_name := Net.local_name if not Net.local_name.is_empty() else "Jugador"
			seat_label.text = "J%d · %s%s" % [
				pid,
				my_name,
				" (anfitrión)" if is_host else "",
			]
			row.add_child(seat_label)
		elif Net.players.has(pid):
			seat_label.text = "J%d · %s" % [pid, str(Net.players[pid])]
			row.add_child(seat_label)
		else:
			var is_bot := seat < Net.room_bots.size() and Net.room_bots[seat]
			seat_label.text = "J%d · %s" % [pid, "Bot" if is_bot else "Libre"]
			seat_label.add_theme_color_override("font_color", Color("ffd96e") if is_bot else MUTED)
			row.add_child(seat_label)
			if is_host and not in_room_started():
				var bot_check := CheckBox.new()
				bot_check.name = "SeatBot%d" % pid
				bot_check.text = "Bot"
				bot_check.add_theme_color_override("font_color", PAPER)
				bot_check.set_pressed_no_signal(is_bot)
				bot_check.toggled.connect(_on_seat_bot_toggled.bind(seat))
				row.add_child(bot_check)
		_seats.add_child(row)


func _on_seat_bot_toggled(enabled: bool, seat: int) -> void:
	Net.set_room_bot(seat, enabled)


func _on_connected() -> void:
	var action := _pending_action
	_pending_action = ""
	if action == "create":
		_create_room()
	elif action == "join":
		_join_room()
	else:
		_set_status("Conectado a Photon Cloud.")
		_refresh()


func _on_connection_failed(error: String) -> void:
	_pending_action = ""
	_set_status("No se pudo conectar: %s" % error)
	_refresh()


func _on_room_joined() -> void:
	_pending_action = ""
	_set_status("En sala.")
	_create_button.visible = true
	_refresh()
	if not Net.is_host() and not Net.is_singleplayer():
		Net.request_room_info()


func _on_room_left() -> void:
	_pending_action = ""
	Net.room_game = ""
	Net.room_started = false
	Net.start_scene = ""
	_create_button.visible = true
	_set_status("Has salido de la sala.")
	_refresh()


func _on_player_joined(player_id: int, _user_id: String) -> void:
	_refresh_seats()
	# El anfitrión avisa al invitado de la mesa y del estado de la partida.
	Net.send_room_info_to(player_id)


func _on_player_left(_player_id: int) -> void:
	_refresh_seats()


func _on_start_announced(scene: String, _seats: int) -> void:
	get_tree().change_scene_to_file(scene)


#endregion

#region Acciones

func _ensure_name() -> String:
	var user_name := _username.text.strip_edges()
	if user_name.is_empty():
		_set_status("Escribe un nombre antes de continuar.")
	return user_name


func _create_room() -> void:
	if Edition.demo:
		_set_status("La demo solo puede entrar a salas; compra el juego para crearlas.")
		return
	var user_name := _ensure_name()
	if user_name.is_empty():
		return
	var entry := _selected_entry()
	if entry.is_empty():
		return
	Net.local_name = user_name
	if Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon():
		Net.create_room(str(entry["id"]), int(entry["seats"]))
		_set_status("Creando sala…")
		return
	# Conectar primero (o sala offline si no hay App ID) y crear sala al conectar.
	Net.room_game = str(entry["id"])
	Net.room_seats = int(entry["seats"])
	Net.reset_room_bots()
	_pending_action = "create"
	_set_status("Conectando y creando sala…")
	_refresh()
	Net.start_session(user_name)


func _enter_button_pressed() -> void:
	if Engine.has_singleton("Fusion") and Fusion.is_in_room() and not Net.room_game.is_empty():
		_enter_running()
	else:
		_join_room()


func _join_room() -> void:
	var user_name := _ensure_name()
	if user_name.is_empty():
		return
	var code := _code.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Escribe el código de la sala.")
		return
	Net.local_name = user_name
	if Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon():
		Net.join_room(code)
		_set_status("Entrando a la sala…")
		return
	_pending_action = "join"
	_set_status("Conectando y entrando a la sala…")
	_refresh()
	Net.start_session(user_name)


func _start() -> void:
	if not (Net.is_host() or Net.is_singleplayer()):
		return
	var entry := _game_entry()
	if entry.is_empty() and Net.room_game.is_empty():
		entry = _selected_entry()
	if entry.is_empty():
		return
	if Net.is_host() and not Net.is_singleplayer() and not Edition.allows(str(entry["scene"])):
		_set_status("Esa mesa está en el juego completo; la demo solo puede entrar a salas.")
		return
	Net.room_game = str(entry["id"])
	Net.room_seats = int(entry["seats"])
	if Engine.has_singleton("Fusion") and Fusion.is_in_room() and not Net.is_singleplayer():
		Fusion.rpc(
			_rpc_start_announced,
			str(entry["scene"]),
			int(entry["seats"]),
			Net._bots_mask()
		)
	Net.start_game(str(entry["scene"]), int(entry["seats"]))


func _enter_running() -> void:
	var entry := _game_entry()
	if not entry.is_empty():
		get_tree().change_scene_to_file(str(entry["scene"]))
	elif not Net.start_scene.is_empty():
		get_tree().change_scene_to_file(Net.start_scene)


func _send_chat() -> void:
	var text := _chat_input.text.strip_edges()
	if text.is_empty():
		return
	_chat_input.clear()
	if Engine.has_singleton("Fusion") and Fusion.is_in_room() and not Net.is_singleplayer():
		Fusion.rpc(_rpc_chat, text)
	else:
		var my_name := Net.local_name if not Net.local_name.is_empty() else "Jugador"
		_append_chat(my_name, text)


func _append_chat(who: String, text: String) -> void:
	_chat_log.text += "%s: %s\n" % [who, text]
	_chat_log.scroll_vertical = float(_chat_log.get_line_count())


func _leave() -> void:
	_pending_action = ""
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.leave_room()
		Net.room_game = ""
		Net.room_started = false
		Net.start_scene = ""
		_create_button.visible = true
		_set_status("Has salido de la sala.")
		_refresh()
		return
	Net.room_game = ""
	Net.room_started = false
	Net.start_scene = ""
	get_tree().change_scene_to_file("res://scenes/BotMenu.tscn")


#endregion

#region RPCs

@rpc("any_peer", "call_remote")
func _rpc_chat(text: String) -> void:
	var sender := Fusion.get_rpc_sender()
	var fallback := (
		Net.local_name
		if sender == Net.local_id() and not Net.local_name.is_empty()
		else "J%d" % sender
	)
	var who := str(Net.players.get(sender, fallback))
	_append_chat(who, text)


@rpc("any_peer", "call_remote")
func _rpc_start_announced(scene: String, seats: int, bots_mask: int) -> void:
	# El host ya llamó Net.start_game() localmente; Fusion.rpc() reenvía
	# el broadcast al host también, así que se salta para evitar doble cambio
	# de escena.
	if Net.room_started and Net.start_scene == scene:
		return
	Net._apply_bots_mask(bots_mask)
	Net.start_scene = scene
	Net.start_seats = seats
	Net.room_started = true
	Net.start_announced.emit(scene, seats)

#endregion
