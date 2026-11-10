extends Control

## Lobby online completo:
## - Crear sala (pública en lista o privada por código, título y contraseña opcional con hash SHA-256 + salt)
## - Unirse por código directo
## - Buscador de salas públicas en tiempo real con filtros (texto, jugadores, huecos libres, sin clave)
## - Sala de espera con butacas, bots online, estado «Listo» por jugador, expulsión y chat.

const INK := Color("1d1a3a")
const ACCENT := Color("ffc83d")
const PANEL := Color("2a2552")
const CARD_BG := Color("342e63")
const PAPER := Color("f3ead9")
const MUTED := Color("c9c5ef")
const READY_COLOR := Color("6ee7a8")
const WARN_COLOR := Color("ffd96e")
const REFRESH_COOLDOWN_MS := 2000

var _username: LineEdit
var _room_title_input: LineEdit
var _public_toggle: CheckBox
var _room_password_input: LineEdit
var _code: LineEdit
var _join_password_input: LineEdit
var _status: Label
var _name_row: HBoxContainer
var _pre_room_row: HBoxContainer
var _create_box: VBoxContainer
var _join_box: VBoxContainer
var _browser_box: VBoxContainer
var _room_box: VBoxContainer
var _game_row: HBoxContainer
var _seats: VBoxContainer
var _ready_hint: Label
var _chat_log: TextEdit
var _chat_input: LineEdit
var _game: OptionButton

var _filter_search: LineEdit
var _filter_game: OptionButton
var _filter_open: CheckBox
var _filter_no_pass: CheckBox
var _refresh_list_button: Button
var _room_list_box: VBoxContainer

var _create_button: Button
var _enter_button: Button
var _enter_running_button: Button
var _ready_button: Button
var _start_button: Button
var _leave_button: Button
var _send_button: Button
var _code_label: Label

var _pw_dialog: ConfirmationDialog
var _pw_dialog_input: LineEdit
var _pw_dialog_room: Dictionary = {}

var _pending_action := ""
var _last_refresh_ms := -10000


func _ready() -> void:
	_build()
	Net.room_joined.connect(_on_room_joined)
	Net.room_left.connect(_on_room_left)
	Net.room_list_changed.connect(_on_room_list_changed)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.start_announced.connect(_on_start_announced)
	Net.room_info_received.connect(_refresh)
	Net.auth_rejected.connect(_on_auth_rejected)
	Net.kicked.connect(_on_kicked)
	if Engine.has_singleton("Fusion"):
		Fusion.register_broadcast_receiver(self)
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		_on_room_joined()
	else:
		_refresh()
		_render_room_list()
		var auto_connect := (
			Net.is_available()
			and DisplayServer.get_name() != "headless"
			and not ("--prueba-arranque" in OS.get_cmdline_user_args())
			and not str(ProjectSettings.get_setting("net/app_id", "")).is_empty()
		)
		if auto_connect and not Fusion.is_connected_to_photon():
			Net.local_name = _username.text.strip_edges()
			_set_status("Conectando al buscador de salas…")
			Net.connect_or_retry()
		elif Net.is_available() and Fusion.is_connected_to_photon():
			Net.refresh_room_list()


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
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	center.add_child(margin)

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 880
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "Tablerama · Online"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", WARN_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)

	_name_row = _row()
	_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := _label(_name_row, "Tu nombre")
	name_label.custom_minimum_size.x = 90
	_username = LineEdit.new()
	_username.name = "Username"
	_username.custom_minimum_size.x = 260
	var default_user := (
		Net.local_name
		if not Net.local_name.is_empty()
		else str(ProjectSettings.get_setting("net/user", "Jugador"))
	)
	_username.text = default_user
	_name_row.add_child(_username)
	column.add_child(_name_row)

	# Vista previa a entrar en sala: columna izquierda (Crear + Código) y columna derecha (Buscador público)
	_pre_room_row = HBoxContainer.new()
	_pre_room_row.name = "PreRoomLayout"
	_pre_room_row.add_theme_constant_override("separation", 20)
	column.add_child(_pre_room_row)

	var left_col := VBoxContainer.new()
	left_col.name = "ActionColumn"
	left_col.custom_minimum_size.x = 360
	left_col.add_theme_constant_override("separation", 14)
	_pre_room_row.add_child(left_col)

	# 1. Crear sala (sale primero en ActionColumn)
	_create_box = _card_box("CreateSection")
	left_col.add_child(_create_box)
	_create_box.add_child(_section_label("CREAR SALA"))

	var title_row := _row()
	var title_lbl := _label(title_row, "Sala")
	title_lbl.custom_minimum_size.x = 76
	_room_title_input = LineEdit.new()
	_room_title_input.name = "RoomTitle"
	_room_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_title_input.placeholder_text = "Mesa de amigos (opcional)"
	title_row.add_child(_room_title_input)
	_create_box.add_child(title_row)

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
	_game_row.add_child(_game)
	_create_box.add_child(_game_row)

	_public_toggle = CheckBox.new()
	_public_toggle.name = "PublicToggle"
	_public_toggle.text = "Sala pública (visible en el buscador)"
	_public_toggle.button_pressed = true
	_public_toggle.add_theme_color_override("font_color", PAPER)
	_create_box.add_child(_public_toggle)

	var pw_row := _row()
	var pw_lbl := _label(pw_row, "Clave")
	pw_lbl.custom_minimum_size.x = 76
	_room_password_input = LineEdit.new()
	_room_password_input.name = "RoomPassword"
	_room_password_input.secret = true
	_room_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_password_input.placeholder_text = "Sin contraseña (opcional)"
	pw_row.add_child(_room_password_input)
	_create_box.add_child(pw_row)

	_create_button = _button(_create_box, "Crear sala", "Create", _create_room)
	_create_button.custom_minimum_size = Vector2(240, 48)

	# 2. Unirse con código directo (sale justo debajo de Crear sala)
	_join_box = _card_box("JoinSection")
	left_col.add_child(_join_box)
	_join_box.add_child(_section_label("UNIRSE CON CÓDIGO"))

	var code_row := _row()
	var code_label := _label(code_row, "Código")
	code_label.custom_minimum_size.x = 76
	_code = LineEdit.new()
	_code.name = "Code"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.placeholder_text = "ABC123"
	_code.text_submitted.connect(func(_t: String) -> void: _enter_button_pressed())
	code_row.add_child(_code)
	_join_box.add_child(code_row)

	var join_pw_row := _row()
	var join_pw_lbl := _label(join_pw_row, "Clave")
	join_pw_lbl.custom_minimum_size.x = 76
	_join_password_input = LineEdit.new()
	_join_password_input.name = "JoinPassword"
	_join_password_input.secret = true
	_join_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_password_input.placeholder_text = "Solo si la sala tiene clave"
	_join_password_input.text_submitted.connect(func(_t: String) -> void: _enter_button_pressed())
	join_pw_row.add_child(_join_password_input)
	_join_box.add_child(join_pw_row)

	_enter_button = _button(_join_box, "Entrar a sala", "Join", _enter_button_pressed)
	_enter_button.custom_minimum_size = Vector2(240, 48)

	# 3. Buscador de salas públicas con filtros (columna derecha)
	_browser_box = _card_box("BrowserSection")
	_browser_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_box.custom_minimum_size = Vector2(480, 380)
	_pre_room_row.add_child(_browser_box)

	var browser_header := _row()
	var browser_title := _section_label("SALAS PÚBLICAS")
	browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_header.add_child(browser_title)
	_refresh_list_button = _button(
		browser_header, "Actualizar", "RefreshRooms", _request_list_refresh
	)
	_refresh_list_button.custom_minimum_size = Vector2(110, 36)
	_browser_box.add_child(browser_header)

	var filter_top := _row()
	_filter_search = LineEdit.new()
	_filter_search.name = "FilterSearch"
	_filter_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_search.placeholder_text = "Buscar por sala, anfitrión o código…"
	_filter_search.text_changed.connect(func(_t: String) -> void: _render_room_list())
	filter_top.add_child(_filter_search)

	_filter_game = OptionButton.new()
	_filter_game.name = "FilterGame"
	_filter_game.add_item("Todas las mesas")
	for entry in Net.ONLINE_GAMES:
		_filter_game.add_item(str(entry["title"]))
	_filter_game.item_selected.connect(func(_idx: int) -> void: _render_room_list())
	filter_top.add_child(_filter_game)
	_browser_box.add_child(filter_top)

	var filter_checks := _row()
	_filter_open = CheckBox.new()
	_filter_open.name = "FilterOpen"
	_filter_open.text = "Solo con hueco"
	_filter_open.button_pressed = true
	_filter_open.add_theme_color_override("font_color", PAPER)
	_filter_open.toggled.connect(func(_v: bool) -> void: _render_room_list())
	filter_checks.add_child(_filter_open)

	_filter_no_pass = CheckBox.new()
	_filter_no_pass.name = "FilterNoPass"
	_filter_no_pass.text = "Sin contraseña"
	_filter_no_pass.button_pressed = false
	_filter_no_pass.add_theme_color_override("font_color", PAPER)
	_filter_no_pass.toggled.connect(func(_v: bool) -> void: _render_room_list())
	filter_checks.add_child(_filter_no_pass)
	_browser_box.add_child(filter_checks)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "RoomListScroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size.y = 220
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_browser_box.add_child(list_scroll)

	_room_list_box = VBoxContainer.new()
	_room_list_box.name = "RoomList"
	_room_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_list_box.add_theme_constant_override("separation", 8)
	list_scroll.add_child(_room_list_box)

	# 4. Vista dentro de la sala (oculta hasta crear o entrar)
	_room_box = _card_box("RoomSection")
	column.add_child(_room_box)

	_code_label = Label.new()
	_code_label.name = "RoomCode"
	_code_label.add_theme_font_size_override("font_size", 18)
	_code_label.add_theme_color_override("font_color", WARN_COLOR)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_box.add_child(_code_label)

	_room_box.add_child(_section_label("BUTACAS Y ESTADO «LISTO»"))

	_seats = VBoxContainer.new()
	_seats.name = "Seats"
	_seats.add_theme_constant_override("separation", 6)
	_room_box.add_child(_seats)

	_ready_hint = Label.new()
	_ready_hint.name = "ReadyHint"
	_ready_hint.add_theme_font_size_override("font_size", 13)
	_ready_hint.add_theme_color_override("font_color", MUTED)
	_ready_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_box.add_child(_ready_hint)

	var room_actions := _row()
	_ready_button = _button(room_actions, "Estoy listo", "ReadyToggle", _toggle_ready)
	_ready_button.custom_minimum_size = Vector2(220, 50)
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_start_button = _button(room_actions, "Empezar partida", "Start", _start)
	_start_button.custom_minimum_size = Vector2(240, 52)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_enter_running_button = _button(
		room_actions, "Entrar a la partida", "EnterRunning", _enter_running
	)
	_enter_running_button.custom_minimum_size = Vector2(240, 50)
	_enter_running_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_box.add_child(room_actions)

	_room_box.add_child(_section_label("CHAT DE SALA"))

	_chat_log = TextEdit.new()
	_chat_log.name = "ChatLog"
	_chat_log.custom_minimum_size = Vector2(400, 100)
	_chat_log.editable = false
	_chat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_room_box.add_child(_chat_log)

	var chat_row := _row()
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.placeholder_text = "Escribe y pulsa Enviar"
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	chat_row.add_child(_chat_input)
	_send_button = _button(chat_row, "Enviar", "Send", _send_chat)
	_room_box.add_child(chat_row)

	var footer_row := _row()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_leave_button = _button(footer_row, "Volver", "Leave", _leave)
	_leave_button.custom_minimum_size = Vector2(240, 46)
	column.add_child(footer_row)

	# Diálogo modal para salas públicas protegidas con contraseña
	_pw_dialog = ConfirmationDialog.new()
	_pw_dialog.name = "PasswordDialog"
	_pw_dialog.title = "Sala protegida con contraseña"
	_pw_dialog.ok_button_text = "Unirse"
	_pw_dialog.cancel_button_text = "Cancelar"
	var pw_box := VBoxContainer.new()
	pw_box.add_theme_constant_override("separation", 8)
	var pw_prompt_lbl := Label.new()
	pw_prompt_lbl.text = "Introduce la contraseña de la sala:"
	pw_box.add_child(pw_prompt_lbl)
	_pw_dialog_input = LineEdit.new()
	_pw_dialog_input.name = "DialogPasswordInput"
	_pw_dialog_input.secret = true
	_pw_dialog_input.placeholder_text = "Contraseña"
	_pw_dialog_input.text_submitted.connect(
		func(_t: String) -> void:
			_pw_dialog.hide()
			_confirm_password_dialog()
	)
	pw_box.add_child(_pw_dialog_input)
	_pw_dialog.add_child(pw_box)
	_pw_dialog.confirmed.connect(_confirm_password_dialog)
	add_child(_pw_dialog)

	_style_button(_create_button, ACCENT)
	_style_button(_enter_button, Color("fff8ec"))
	_style_button(_refresh_list_button, Color("fff8ec"))
	_style_button(_ready_button, ACCENT)
	_style_button(_start_button, ACCENT)
	_style_button(_enter_running_button, ACCENT)
	_style_button(_leave_button, Color("fff8ec"))
	_style_button(_send_button, Color("fff8ec"))


func _card_box(node_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.add_theme_constant_override("separation", 8)
	return box


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
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8 if pressed else 5
	style.set_corner_radius_all(12)
	return style


func _room_item_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
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


#region Buscador de salas públicas y filtros

func _selected_filter_game_id() -> String:
	var idx := _filter_game.selected
	if idx <= 0 or idx - 1 >= Net.ONLINE_GAMES.size():
		return ""
	return str(Net.ONLINE_GAMES[idx - 1]["id"])


func _render_room_list(source_rooms: Variant = null) -> void:
	for child in _room_list_box.get_children():
		_room_list_box.remove_child(child)
		child.queue_free()

	var raw_rooms: Array = source_rooms if source_rooms is Array else Net.room_listings
	var filtered := Net.filter_rooms(
		raw_rooms,
		_filter_search.text,
		_selected_filter_game_id(),
		_filter_open.button_pressed,
		_filter_no_pass.button_pressed
	)

	if filtered.is_empty():
		var empty := Label.new()
		empty.name = "EmptyRoomsLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", MUTED)
		if not Net.is_available():
			empty.text = "SDK Photon Fusion no disponible en este entorno."
		elif not (Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon()) and raw_rooms.is_empty():
			empty.text = "Pulsa «Actualizar» para conectar y consultar las salas públicas activas."
		elif raw_rooms.is_empty():
			empty.text = "No hay salas públicas abiertas ahora mismo. ¡Crea una sala a la izquierda!"
		else:
			empty.text = "Ninguna sala coincide con los filtros actuales."
		_room_list_box.add_child(empty)
		return

	for info in filtered:
		var panel := PanelContainer.new()
		panel.name = "RoomCard_%s" % str(info.get("code", ""))
		panel.add_theme_stylebox_override("panel", _room_item_style())
		var row := _row()
		panel.add_child(row)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 2)
		row.add_child(details)

		var locked := bool(info.get("locked", false))
		var badge := "[Clave] " if locked else ""
		var room_title := Label.new()
		room_title.text = "%s%s" % [badge, str(info.get("title", "Sala"))]
		room_title.add_theme_font_size_override("font_size", 15)
		room_title.add_theme_color_override("font_color", WARN_COLOR if locked else PAPER)
		details.add_child(room_title)

		var subtitle := Label.new()
		var host_str := str(info.get("host", ""))
		var host_part := ("Anfitrión: %s · " % host_str) if not host_str.is_empty() else ""
		var state_str := "En partida" if bool(info.get("started", false)) else "Esperando"
		subtitle.text = "%s%s · %d/%d jugadores · %s" % [
			host_part,
			Net.game_title_for(str(info.get("game", "Island"))),
			int(info.get("players", 1)),
			int(info.get("max_players", 3)),
			state_str,
		]
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.add_theme_color_override("font_color", MUTED)
		details.add_child(subtitle)

		var can_join := bool(info.get("is_open", true)) and not bool(info.get("started", false)) and int(info.get("players", 0)) < int(info.get("max_players", 4))
		var join_btn := _button(
			row,
			"Unirse",
			"JoinRoom_%s" % str(info.get("code", "")),
			_on_public_room_clicked.bind(info)
		)
		join_btn.custom_minimum_size = Vector2(96, 38)
		join_btn.disabled = not can_join or not _pending_action.is_empty()
		_style_button(join_btn, ACCENT if can_join else Color("8f8aa8"))
		_room_list_box.add_child(panel)


func _request_list_refresh() -> void:
	if not Net.is_available():
		_set_status("Instala el addon Photon Fusion para jugar online.")
		return
	var now := Time.get_ticks_msec()
	if now - _last_refresh_ms < REFRESH_COOLDOWN_MS:
		_set_status("Espera un momento antes de volver a actualizar la lista.")
		return
	_last_refresh_ms = now
	var user_name := _username.text.strip_edges()
	if not user_name.is_empty():
		Net.local_name = user_name
	if Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon():
		Net.refresh_room_list()
		_set_status("Lista de salas actualizada.")
	else:
		_set_status("Conectando a Photon Cloud…")
		Net.connect_or_retry()


func _on_room_list_changed(_rooms: Array) -> void:
	_render_room_list()


func _on_public_room_clicked(info: Dictionary) -> void:
	var user_name := _ensure_name()
	if user_name.is_empty():
		return
	if bool(info.get("locked", false)):
		_pw_dialog_room = info
		_pw_dialog_input.text = ""
		_pw_dialog.popup_centered(Vector2i(360, 150))
		_pw_dialog_input.grab_focus()
		return
	_code.text = str(info.get("code", ""))
	_join_password_input.text = ""
	_join_room()


func _confirm_password_dialog() -> void:
	if _pw_dialog_room.is_empty():
		return
	var typed_pw := _pw_dialog_input.text.strip_edges()
	var salt := str(_pw_dialog_room.get("salt", ""))
	var expected_hash := str(_pw_dialog_room.get("pw_hash", ""))
	if not expected_hash.is_empty() and not Net.verify_password(typed_pw, salt, expected_hash):
		_set_status("Contraseña incorrecta para «%s»." % str(_pw_dialog_room.get("title", "la sala")))
		return
	_code.text = str(_pw_dialog_room.get("code", ""))
	_join_password_input.text = typed_pw
	_pw_dialog_room = {}
	_join_room()

#endregion

#region Flujo de pantalla

func _show_pre_room() -> void:
	var available := Net.is_available()
	var busy := not _pending_action.is_empty()
	_name_row.visible = true
	_pre_room_row.visible = true
	_create_box.visible = not Edition.demo
	_create_button.visible = true
	_join_box.visible = true
	_browser_box.visible = true
	_room_box.visible = false
	_leave_button.text = "Volver"
	_create_button.disabled = not available or busy or Edition.demo or _game.selected < 0
	_enter_button.disabled = not available or busy
	_refresh_list_button.disabled = not available or busy
	if not available:
		_set_status("Instala el addon Photon Fusion para jugar online.")
	elif not busy and _status.text.is_empty():
		if Edition.demo:
			_set_status("Edición demo: únete desde el buscador de salas públicas o con un código.")
		else:
			_set_status("Crea una sala, entra con código o elige una sala pública a la derecha.")
	_refresh_seats()


func _show_lobby() -> void:
	var in_room := Engine.has_singleton("Fusion") and Fusion.is_in_room()
	var offline := Net.is_singleplayer()
	var is_host := in_room and (offline or Net.is_host())
	_name_row.visible = false
	_pre_room_row.visible = is_host and Net.room_game.is_empty()
	_create_box.visible = is_host and Net.room_game.is_empty()
	_create_button.visible = false
	_join_box.visible = false
	_browser_box.visible = false
	_room_box.visible = true
	_leave_button.text = "Salir de la sala"

	var entry := _game_entry()
	var game_title := str(entry.get("title", ""))
	var vis_tag := "Sala pública" if Net.room_public else "Sala privada"
	if Net.room_locked:
		vis_tag += " · Con clave"
	var header_lines: Array[String] = []
	if not Net.room_title.is_empty():
		header_lines.append("%s (%s)" % [Net.room_title, vis_tag])
	if not Net.room_code.is_empty():
		header_lines.append("Código: %s" % Net.room_code)
	if not game_title.is_empty():
		header_lines.append(game_title)
	_code_label.text = "  ·  ".join(header_lines)
	_code_label.visible = not header_lines.is_empty()

	var my_seat := Net.local_seat()
	var my_ready := Net.is_seat_ready(my_seat)
	_ready_button.visible = not is_host and not in_room_started()
	_ready_button.text = "Cancelar «Listo»" if my_ready else "Estoy listo"
	_style_button(_ready_button, Color("fff8ec") if my_ready else ACCENT)

	var all_ready := Net.are_all_guests_ready()
	_start_button.visible = is_host and not in_room_started()
	_start_button.disabled = _start_button.visible and (not _can_start() or not all_ready)
	_enter_running_button.visible = in_room_started() and not is_host

	if in_room_started():
		_ready_hint.text = "La partida está en marcha."
	elif is_host:
		_ready_hint.text = (
			"Todos los jugadores están listos. Puedes empezar la partida."
			if all_ready
			else "Esperando a que todos los invitados pulsen «Estoy listo»…"
		)
	else:
		_ready_hint.text = (
			"Estás marcado como «Listo». Esperando a que el anfitrión inicie…"
			if my_ready
			else "Pulsa «Estoy listo» cuando estés preparado para jugar."
		)
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
		_render_room_list()


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
	var master_id := 1
	var room: Variant = Fusion.get_room()
	if room != null and room is Object and room.has_method("get_master_client_id"):
		master_id = int(room.call("get_master_client_id"))

	var entry := _game_entry()
	if entry.is_empty():
		entry = _selected_entry()
	var seat_count := int(entry.get("seats", Net.room_seats if Net.room_seats > 0 else 3))

	for seat in range(seat_count):
		var pid := seat + 1
		var row := _row()
		var seat_label := Label.new()
		seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var state_label := Label.new()
		state_label.add_theme_font_size_override("font_size", 13)

		var is_occupied_self := (pid == local_id)
		var is_occupied_peer := Net.players.has(pid)

		if is_occupied_self or is_occupied_peer:
			var p_name := (
				(Net.local_name if not Net.local_name.is_empty() else "Jugador")
				if is_occupied_self
				else str(Net.players[pid])
			)
			var peer_is_host := (is_host and is_occupied_self) or (not offline and pid == master_id)
			seat_label.text = "J%d · %s%s" % [
				pid,
				p_name,
				" (anfitrión)" if peer_is_host else "",
			]
			seat_label.add_theme_color_override("font_color", PAPER)
			row.add_child(seat_label)

			if peer_is_host:
				state_label.text = "★ Anfitrión"
				state_label.add_theme_color_override("font_color", WARN_COLOR)
			elif is_host and Net.room_locked and not bool(Net.authenticated_peers.get(pid, false)):
				state_label.text = "Verificando clave…"
				state_label.add_theme_color_override("font_color", WARN_COLOR)
			elif Net.is_seat_ready(seat):
				state_label.text = "✓ Listo"
				state_label.add_theme_color_override("font_color", READY_COLOR)
			else:
				state_label.text = "Esperando…"
				state_label.add_theme_color_override("font_color", MUTED)
			row.add_child(state_label)

			if is_host and not is_occupied_self and not in_room_started():
				var kick_btn := _button(
					row, "Expulsar", "KickSeat%d" % pid, _on_kick_pressed.bind(pid)
				)
				kick_btn.custom_minimum_size = Vector2(88, 32)
				_style_button(kick_btn, Color("fff8ec"))
		else:
			var is_bot := seat < Net.room_bots.size() and Net.room_bots[seat]
			seat_label.text = "J%d · %s" % [pid, "Bot" if is_bot else "Libre"]
			seat_label.add_theme_color_override("font_color", WARN_COLOR if is_bot else MUTED)
			row.add_child(seat_label)

			if is_bot:
				state_label.text = "✓ Listo"
				state_label.add_theme_color_override("font_color", READY_COLOR)
				row.add_child(state_label)

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


func _on_kick_pressed(player_id: int) -> void:
	Net.kick_player(player_id)


func _toggle_ready() -> void:
	var seat := Net.local_seat()
	Net.set_local_ready(not Net.is_seat_ready(seat))


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


func _on_disconnected() -> void:
	_pending_action = ""
	_set_status("Desconectado de Photon Cloud.")
	_refresh()


func _on_connection_failed(error: String) -> void:
	_pending_action = ""
	_set_status("No se pudo conectar: %s" % error)
	_refresh()


func _on_auth_rejected(reason: String) -> void:
	_pending_action = ""
	_set_status(reason)
	_refresh()


func _on_kicked(reason: String) -> void:
	_pending_action = ""
	_set_status(reason)
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
	if _status.text == "En sala.":
		_set_status("Has salido de la sala.")
	_refresh()


func _on_player_joined(player_id: int, _user_id: String) -> void:
	_refresh()
	Net.send_room_info_to(player_id)


func _on_player_left(_player_id: int) -> void:
	_refresh()


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
	var custom_title := _room_title_input.text.strip_edges()
	var is_public := _public_toggle.button_pressed
	var password := _room_password_input.text.strip_edges()
	Net.local_name = user_name
	if Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon():
		Net.create_room(
			str(entry["id"]),
			int(entry["seats"]),
			is_public,
			custom_title,
			password
		)
		_set_status("Creando sala…")
		return
	Net.room_game = str(entry["id"])
	Net.room_seats = int(entry["seats"])
	Net.room_public = is_public
	Net.room_title = custom_title if not custom_title.is_empty() else ("Mesa de %s" % user_name)
	Net.reset_room_bots()
	Net.reset_room_ready()
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
		_set_status("Escribe el código de la sala o pulsa «Unirse» en una sala pública.")
		return
	var typed_pw := _join_password_input.text.strip_edges()
	# Si la sala está en la lista pública y tiene hash conocido, verificamos antes de entrar.
	var listed := Net.find_listed_room(code)
	if not listed.is_empty() and bool(listed.get("locked", false)):
		var salt := str(listed.get("salt", ""))
		var expected_hash := str(listed.get("pw_hash", ""))
		if not expected_hash.is_empty() and not Net.verify_password(typed_pw, salt, expected_hash):
			_set_status("Esta sala requiere una contraseña válida.")
			return
	Net.local_name = user_name
	if Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon():
		Net.join_room(code, typed_pw)
		_set_status("Entrando a la sala…")
		return
	_pending_action = "join"
	_set_status("Conectando y entrando a la sala…")
	_refresh()
	Net.start_session(user_name)


func _start() -> void:
	if not (Net.is_host() or Net.is_singleplayer()):
		return
	if not Net.are_all_guests_ready():
		_set_status("Espera a que todos los invitados marquen «Estoy listo».")
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
	if Net.room_started and Net.start_scene == scene:
		return
	Net._apply_bots_mask(bots_mask)
	Net.start_scene = scene
	Net.start_seats = seats
	Net.room_started = true
	Net.start_announced.emit(scene, seats)

#endregion
