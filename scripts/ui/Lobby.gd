extends Control

## Lobby online: nombre de jugador, crear o entrar sala por código, butacas,
## chat y «Empezar» (solo anfitrión). Sin App ID en los ajustes del proyecto
## (net/app_id) arranca en sala offline para probar el protocolo sin cuenta
## de Photon. La demo solo puede entrar a salas, no crearlas.

const INK := Color("1d1a3a")
const ACCENT := Color("ffc83d")
const PANEL := Color("2a2552")

var _username: LineEdit
var _code: LineEdit
var _status: Label
var _seats: VBoxContainer
var _chat_log: TextEdit
var _chat_input: LineEdit
var _game: OptionButton
var _continue_button: Button
var _create_button: Button
var _enter_button: Button
var _start_button: Button
var _leave_button: Button
var _send_button: Button
var _code_label: Label


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
		_show_connect()


func _exit_tree() -> void:
	if Engine.has_singleton("Fusion"):
		Fusion.unregister_broadcast_receiver(self)


func _build() -> void:
	var background := ColorRect.new()
	background.color = PANEL
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.set_anchor(SIDE_LEFT, 0.5)
	column.set_anchor(SIDE_RIGHT, 0.5)
	column.set_anchor(SIDE_TOP, 0.5)
	column.set_anchor(SIDE_BOTTOM, 0.5)
	column.set_offset(SIDE_LEFT, -180.0)
	column.set_offset(SIDE_RIGHT, 180.0)
	column.set_offset(SIDE_TOP, -170.0)
	column.set_offset(SIDE_BOTTOM, 170.0)
	var title := Label.new()
	title.name = "Title"
	title.text = "Tablerama · Online"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("f3ead9"))
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
	var name_row := _row()
	var name_label := _label(name_row, "Nombre")
	name_label.custom_minimum_size.x = 70
	_username = LineEdit.new()
	_username.name = "Username"
	_username.custom_minimum_size.x = 220
	_username.text = str(ProjectSettings.get_setting("net/user", "Jugador"))
	name_row.add_child(_username)
	column.add_child(name_row)
	_continue_button = _button(column, "Continuar", "Continue", _continue)
	_continue_button.custom_minimum_size = Vector2(260, 56)
	var code_row := _row()
	var code_label := _label(code_row, "Código")
	code_label.custom_minimum_size.x = 70
	_code = LineEdit.new()
	_code.name = "Code"
	_code.custom_minimum_size.x = 220
	_code.text = ""
	_code.placeholder_text = "ABC123"
	code_row.add_child(_code)
	column.add_child(code_row)
	_code_label = Label.new()
	_code_label.name = "RoomCode"
	_code_label.add_theme_font_size_override("font_size", 16)
	_code_label.add_theme_color_override("font_color", Color("ffd96e"))
	column.add_child(_code_label)
	var game_row := _row()
	var game_label := _label(game_row, "Mesa")
	game_label.custom_minimum_size.x = 70
	_game = OptionButton.new()
	_game.name = "Game"
	for entry in Net.ONLINE_GAMES:
		_game.add_item(entry["title"])
	_game.custom_minimum_size.x = 260
	game_row.add_child(_game)
	column.add_child(game_row)
	_create_button = _button(column, "Crear sala", "Create", _create_room)
	_create_button.custom_minimum_size = Vector2(260, 52)
	_enter_button = _button(column, "Entrar", "Join", _enter_button_pressed)
	_enter_button.custom_minimum_size = Vector2(260, 52)
	_start_button = _button(column, "Empezar", "Start", _start)
	_start_button.custom_minimum_size = Vector2(260, 56)
	_leave_button = _button(column, "Salir", "Leave", _leave)
	_leave_button.custom_minimum_size = Vector2(260, 48)
	var seats_label := Label.new()
	seats_label.text = "Butacas"
	seats_label.add_theme_font_size_override("font_size", 16)
	column.add_child(seats_label)
	_seats = VBoxContainer.new()
	_seats.name = "Seats"
	_seats.add_theme_constant_override("separation", 4)
	column.add_child(_seats)
	var chat_label := Label.new()
	chat_label.text = "Chat"
	chat_label.add_theme_font_size_override("font_size", 16)
	column.add_child(chat_label)
	_chat_log = TextEdit.new()
	_chat_log.name = "ChatLog"
	_chat_log.custom_minimum_size.x = 300
	_chat_log.custom_minimum_size.y = 70
	_chat_log.editable = false
	_chat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(_chat_log)
	var chat_row := _row()
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.custom_minimum_size.x = 200
	_chat_input.placeholder_text = "Escribe y pulsa Enviar"
	_chat_input.text_submitted.connect(_send_chat)
	chat_row.add_child(_chat_input)
	_send_button = _button(chat_row, "Enviar", "Send", _send_chat)
	column.add_child(chat_row)
	_style_button(_continue_button, ACCENT)
	_style_button(_create_button, ACCENT)
	_style_button(_enter_button, Color("fff8ec"))
	_style_button(_start_button, ACCENT)
	_style_button(_leave_button, Color("fff8ec"))
	_style_button(_send_button, Color("fff8ec"))
	_refresh()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	return row


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("c9c5ef"))
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, _id: String, callback: Callable) -> Button:
	var button := Button.new()
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

func _show_connect() -> void:
	_continue_button.visible = true
	_create_button.visible = false
	_enter_button.visible = false
	_start_button.visible = false
	_leave_button.visible = false
	_game.visible = false
	_code_label.visible = false
	_code_label.text = ""
	if not Net.is_available():
		_set_status("Instala el addon Photon Fusion para jugar online.")
		_continue_button.disabled = true
	else:
		_continue_button.disabled = false
	_refresh_seats()


## Conectado a Photon pero sin sala: crear o entrar.
func _show_pre_room() -> void:
	_continue_button.visible = false
	_leave_button.visible = false
	_code_label.visible = false
	_start_button.visible = false
	_game.visible = not Edition.demo
	_create_button.visible = true
	_create_button.disabled = Edition.demo or _game.selected < 0
	_enter_button.visible = true
	_set_status("Conectado: crea una sala o entra con un código.")
	_refresh_seats()


func _show_lobby() -> void:
	_continue_button.visible = false
	_leave_button.visible = true
	var in_room := Engine.has_singleton("Fusion") and Fusion.is_in_room()
	var offline := Net.is_singleplayer()
	var is_host := in_room and (offline or Net.is_host())
	_game.visible = is_host and not in_room_started() and Net.room_game.is_empty()
	_create_button.visible = is_host and not offline and not in_room_started() and Net.room_game.is_empty()
	_create_button.disabled = _create_button.visible and Edition.demo
	_enter_button.visible = (
		in_room
		and not offline
		and (Net.room_game.is_empty() or (Net.room_started and not is_host))
	)
	_code_label.visible = in_room and not Net.room_game.is_empty() and not Net.room_code.is_empty()
	_code_label.text = "Código: %s" % Net.room_code
	_start_button.visible = is_host and not in_room_started()
	_start_button.disabled = _start_button.visible and not _can_start()
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
	var connected := Net.is_available() and Fusion.is_connected_to_photon()
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		_show_lobby()
	elif connected:
		_show_pre_room()
	else:
		_show_connect()


func _set_status(message: String) -> void:
	_status.text = message


func _refresh_seats() -> void:
	for child in _seats.get_children():
		_seats.remove_child(child)
		child.queue_free()
	if not (Engine.has_singleton("Fusion") and Fusion.is_in_room()):
		return
	var local_id := Fusion.get_local_player_id()
	var names: Array[String] = []
	for player_id in Net.players:
		names.append(str(Net.players[player_id]))
	var label := Label.new()
	label.text = "J%d · %s%s" % [
		local_id,
		Net.local_name if not Net.local_name.is_empty() else "jugador",
		" (anfitrión)" if Net.is_host() else "",
	]
	_seats.add_child(label)
	for user in names:
		var other := Label.new()
		other.text = user
		_seats.add_child(other)


func _on_connected() -> void:
	_set_status("Conectado a Photon Cloud.")
	_refresh()


func _on_connection_failed(error: String) -> void:
	_set_status("No se pudo conectar: %s" % error)


func _on_room_joined() -> void:
	_set_status("En sala.")
	_refresh()
	Net.request_room_info()


func _on_room_left() -> void:
	Net.room_game = ""
	Net.room_started = false
	Net.start_scene = ""
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

func _continue() -> void:
	var name := _username.text.strip_edges()
	if name.is_empty():
		_set_status("Escribe un nombre antes de continuar.")
		return
	Net.start_session(name)
	_set_status("Conectando…")


func _create_room() -> void:
	if Edition.demo:
		_set_status("La demo solo puede entrar a salas; compra el juego para crearlas.")
		return
	var entry := _selected_entry()
	if entry.is_empty():
		return
	Net.create_room(entry["id"], int(entry["seats"]))
	_set_status("Creando sala…")


func _enter_button_pressed() -> void:
	if Net.room_game.is_empty():
		_join_room()
	else:
		_enter_running()


func _join_room() -> void:
	var code := _code.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("Escriba el código de la sala.")
		return
	Net.join_room(code)
	_set_status("Entrando a la sala…")


func _start() -> void:
	if not (Net.is_host() or Net.is_singleplayer()):
		return
	var entry := _game_entry()
	if entry.is_empty() and Net.room_game.is_empty():
		entry = _selected_entry()
	if entry.is_empty():
		return
	if Net.is_host() and not Net.is_singleplayer() and not Edition.allows(entry["scene"]):
		_set_status("Esa mesa está en el juego completo; la demo solo puede entrar a salas.")
		return
	Net.room_game = entry["id"]
	Net.room_seats = int(entry["seats"])
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc(_rpc_start_announced, entry["scene"], int(entry["seats"]))
	Net.start_game(entry["scene"], int(entry["seats"]))


func _enter_running() -> void:
	var scene := Net.start_scene
	if scene.is_empty():
		_set_status("El anfitrión aún no ha empezado la partida.")
		return
	get_tree().change_scene_to_file(scene)


func _send_chat() -> void:
	var text := _chat_input.text.strip_edges()
	if text.is_empty():
		return
	_chat_input.clear()
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc(_rpc_chat, text)
	else:
		_append_chat(Net.local_name, text)


func _append_chat(who: String, text: String) -> void:
	_chat_log.append_text("%s: %s" % [who, text])


func _leave() -> void:
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.leave_room()
	Net.room_game = ""
	Net.room_started = false
	Net.start_scene = ""
	get_tree().change_scene_to_file("res://scenes/BotMenu.tscn")


#endregion

#region RPCs

@rpc("any_peer", "call_remote")
func _rpc_chat(text: String) -> void:
	var sender := Fusion.get_rpc_sender()
	var who := str(Net.players.get(sender, "jugador"))
	_append_chat(who, text)


@rpc("any_peer", "call_remote")
func _rpc_start_announced(scene: String, seats: int) -> void:
	Net.start_scene = scene
	Net.start_seats = seats
	Net.room_started = true
	Net.start_announced.emit(scene, seats)


#endregion
