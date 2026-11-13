extends Control
## Lobby online completo con estética cartoon-tabletop:
## - Cabecera integrada con retorno a modos, estado de conexión e identidad del jugador.
## - Crear sala (pública o privada con código, título, emblema dinámico de mesa y clave opcional).
## - Unirse con código directo.
## - Buscador de salas públicas en tiempo real con filtros y tarjetas ilustradas por juego.
## - Sala de espera en dos columnas: butacas coloreadas con bots/«Listo»/expulsión + chat de sala.

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
var _conn_pill_holder: HBoxContainer
var _name_row: Control
var _pre_room_row: HBoxContainer
var _create_card: PanelContainer
var _create_box: VBoxContainer
var _create_emblem_slot: HBoxContainer
var _join_card: PanelContainer
var _join_box: VBoxContainer
var _browser_card: PanelContainer
var _browser_box: VBoxContainer
var _room_card: PanelContainer
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
var _room_count_slot: HBoxContainer
var _room_list_box: VBoxContainer

var _create_button: Button
var _enter_button: Button
var _enter_running_button: Button
var _ready_button: Button
var _start_button: Button
var _leave_button: Button
var _copy_code_button: Button
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _pw_dialog != null and _pw_dialog.visible:
			return
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		_leave()
		get_viewport().set_input_as_handled()


func _build() -> void:
	MenuStyle.add_backdrop(self, Color("7cc6fe"))

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	MenuStyle.limit_page(margin, Vector2(1200, 0), 28)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	# 1. Cabecera superior: botón Leave/Volver + Título + Tu nombre + Estado de red
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)

	_leave_button = _button(header, "← Modos", "Leave", _leave)
	_leave_button.custom_minimum_size = Vector2(138, 44)
	_leave_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_secondary(_leave_button, 12, 6)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 1)
	header.add_child(title_col)

	title_col.add_child(
		MenuStyle.make_eyebrow("TABLERAMA  /  MULTIJUGADOR EN RED", Color("7cc6fe"))
	)
	var title := MenuStyle.make_title("Tablerama · Online", 32)
	title.name = "Title"
	title_col.add_child(title)

	var name_panel := MenuStyle.make_card_panel(
		"IdentityCard", Palette.PANEL, Palette.INK, 12, 8, 14, 3
	)
	name_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_row = name_panel
	header.add_child(name_panel)

	var name_inner := _row()
	name_panel.add_child(name_inner)
	var name_lbl := _label(name_inner, "Jugador")
	name_lbl.add_theme_font_size_override("font_size", 13)
	_username = LineEdit.new()
	_username.name = "Username"
	_username.custom_minimum_size = Vector2(190, 34)
	var default_user := (
		Net.local_name
		if not Net.local_name.is_empty()
		else str(ProjectSettings.get_setting("net/user", "Jugador"))
	)
	_username.text = default_user
	_username.text_changed.connect(
		func(new_text: String) -> void:
			var cleaned := new_text.strip_edges()
			if not cleaned.is_empty():
				Net.local_name = cleaned
	)
	name_inner.add_child(_username)

	_conn_pill_holder = HBoxContainer.new()
	_conn_pill_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_conn_pill_holder)

	# 2. Cintillo de estado
	var status_bar := MenuStyle.make_card_panel(
		"StatusBar", MenuStyle.CARD_WELL, Palette.INK, 14, 7, 12, 0
	)
	column.add_child(status_bar)
	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", WARN_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_bar.add_child(_status)

	# 3. Vista previa a entrar en sala: columna izquierda (Crear + Código) y columna derecha (Buscador)
	_pre_room_row = HBoxContainer.new()
	_pre_room_row.name = "PreRoomLayout"
	_pre_room_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pre_room_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pre_room_row.add_theme_constant_override("separation", 18)
	column.add_child(_pre_room_row)

	var left_col := VBoxContainer.new()
	left_col.name = "ActionColumn"
	left_col.custom_minimum_size.x = 390
	left_col.add_theme_constant_override("separation", 14)
	_pre_room_row.add_child(left_col)

	# 3a. Crear sala (índice 0 dentro de ActionColumn)
	_create_card = MenuStyle.make_card_panel(
		"CreateSection", Palette.PANEL, Palette.INK, 18, 14, 18, 5
	)
	left_col.add_child(_create_card)
	_create_box = VBoxContainer.new()
	_create_box.add_theme_constant_override("separation", 9)
	_create_card.add_child(_create_box)

	var create_head := _row()
	var create_sec_lbl := _section_label("CREAR SALA")
	create_sec_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_head.add_child(create_sec_lbl)
	_create_emblem_slot = HBoxContainer.new()
	create_head.add_child(_create_emblem_slot)
	_create_box.add_child(create_head)

	var title_row := _row()
	var title_lbl := _label(title_row, "Sala")
	title_lbl.custom_minimum_size.x = 68
	_room_title_input = LineEdit.new()
	_room_title_input.name = "RoomTitle"
	_room_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_title_input.placeholder_text = "Mesa de amigos (opcional)"
	title_row.add_child(_room_title_input)
	_create_box.add_child(title_row)

	_game_row = _row()
	var game_label := _label(_game_row, "Mesa")
	game_label.custom_minimum_size.x = 68
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
	MenuStyle.style_secondary(_game, 10, 5)
	_game.item_selected.connect(func(_idx: int) -> void: _refresh_create_emblem())
	_game_row.add_child(_game)
	_create_box.add_child(_game_row)
	_refresh_create_emblem()

	_public_toggle = CheckBox.new()
	_public_toggle.name = "PublicToggle"
	_public_toggle.text = "Sala pública (visible en el buscador)"
	_public_toggle.button_pressed = true
	_public_toggle.add_theme_color_override("font_color", Palette.PAPER)
	_create_box.add_child(_public_toggle)

	var pw_row := _row()
	var pw_lbl := _label(pw_row, "Clave")
	pw_lbl.custom_minimum_size.x = 68
	_room_password_input = LineEdit.new()
	_room_password_input.name = "RoomPassword"
	_room_password_input.secret = true
	_room_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_password_input.placeholder_text = "Sin contraseña (opcional)"
	pw_row.add_child(_room_password_input)
	_create_box.add_child(pw_row)

	_create_button = _button(_create_box, "Crear sala", "Create", _create_room)
	_create_button.custom_minimum_size = Vector2(0, 48)
	MenuStyle.style_primary(_create_button, 13, 6)

	# 3b. Unirse con código directo (índice 1 dentro de ActionColumn)
	_join_card = MenuStyle.make_card_panel(
		"JoinSection", Palette.PANEL, Palette.INK, 18, 14, 18, 5
	)
	left_col.add_child(_join_card)
	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 9)
	_join_card.add_child(_join_box)
	_join_box.add_child(_section_label("UNIRSE CON CÓDIGO"))

	var code_row := _row()
	var code_label := _label(code_row, "Código")
	code_label.custom_minimum_size.x = 68
	_code = LineEdit.new()
	_code.name = "Code"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.placeholder_text = "ABC123"
	_code.text_submitted.connect(func(_t: String) -> void: _enter_button_pressed())
	code_row.add_child(_code)
	_join_box.add_child(code_row)

	var join_pw_row := _row()
	var join_pw_lbl := _label(join_pw_row, "Clave")
	join_pw_lbl.custom_minimum_size.x = 68
	_join_password_input = LineEdit.new()
	_join_password_input.name = "JoinPassword"
	_join_password_input.secret = true
	_join_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_password_input.placeholder_text = "Solo si la sala tiene clave"
	_join_password_input.text_submitted.connect(func(_t: String) -> void: _enter_button_pressed())
	join_pw_row.add_child(_join_password_input)
	_join_box.add_child(join_pw_row)

	_enter_button = _button(_join_box, "Entrar a sala", "Join", _enter_button_pressed)
	_enter_button.custom_minimum_size = Vector2(0, 46)
	MenuStyle.style_secondary(_enter_button, 13, 6)

	# 3c. Buscador de salas públicas con filtros (columna derecha)
	_browser_card = MenuStyle.make_card_panel(
		"BrowserSection", Palette.PANEL, Palette.INK, 18, 14, 18, 5
	)
	_browser_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_browser_card.custom_minimum_size = Vector2(480, 380)
	_pre_room_row.add_child(_browser_card)

	_browser_box = VBoxContainer.new()
	_browser_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser_box.add_theme_constant_override("separation", 10)
	_browser_card.add_child(_browser_box)

	var browser_header := _row()
	var browser_title := _section_label("SALAS PÚBLICAS")
	browser_header.add_child(browser_title)
	_room_count_slot = HBoxContainer.new()
	_room_count_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	browser_header.add_child(_room_count_slot)
	var bspacer := Control.new()
	bspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_header.add_child(bspacer)
	_refresh_list_button = _button(
		browser_header, "↻ Actualizar", "RefreshRooms", _request_list_refresh
	)
	_refresh_list_button.custom_minimum_size = Vector2(128, 38)
	MenuStyle.style_secondary(_refresh_list_button, 12, 5)
	_browser_box.add_child(browser_header)

	var filter_well := MenuStyle.make_card_panel(
		"", MenuStyle.CARD_WELL, Palette.INK, 12, 10, 14, 0
	)
	_browser_box.add_child(filter_well)

	var filter_col := VBoxContainer.new()
	filter_col.add_theme_constant_override("separation", 8)
	filter_well.add_child(filter_col)

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
	MenuStyle.style_secondary(_filter_game, 10, 5)
	_filter_game.item_selected.connect(func(_idx: int) -> void: _render_room_list())
	filter_top.add_child(_filter_game)
	filter_col.add_child(filter_top)

	var filter_checks := _row()
	_filter_open = CheckBox.new()
	_filter_open.name = "FilterOpen"
	_filter_open.text = "Solo con hueco"
	_filter_open.button_pressed = true
	_filter_open.add_theme_color_override("font_color", Palette.PAPER)
	_filter_open.toggled.connect(func(_v: bool) -> void: _render_room_list())
	filter_checks.add_child(_filter_open)

	_filter_no_pass = CheckBox.new()
	_filter_no_pass.name = "FilterNoPass"
	_filter_no_pass.text = "Sin contraseña"
	_filter_no_pass.button_pressed = false
	_filter_no_pass.add_theme_color_override("font_color", Palette.PAPER)
	_filter_no_pass.toggled.connect(func(_v: bool) -> void: _render_room_list())
	filter_checks.add_child(_filter_no_pass)
	filter_col.add_child(filter_checks)

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
	_room_card = MenuStyle.make_card_panel(
		"RoomSection", Palette.PANEL, Palette.INK, 20, 16, 20, 6
	)
	_room_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_room_card)

	_room_box = VBoxContainer.new()
	_room_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_room_box.add_theme_constant_override("separation", 12)
	_room_card.add_child(_room_box)

	# Cintillo de código y datos de sala
	var room_banner := MenuStyle.make_card_panel(
		"", MenuStyle.CARD_SURFACE, Palette.INK, 14, 10, 14, 0
	)
	_room_box.add_child(room_banner)
	var room_banner_row := _row()
	room_banner.add_child(room_banner_row)

	_code_label = Label.new()
	_code_label.name = "RoomCode"
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_label.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	_code_label.add_theme_font_size_override("font_size", 20)
	_code_label.add_theme_color_override("font_color", WARN_COLOR)
	_code_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_banner_row.add_child(_code_label)

	_copy_code_button = _button(room_banner_row, "Copiar código", "CopyCode", _copy_room_code)
	_copy_code_button.custom_minimum_size = Vector2(138, 38)
	MenuStyle.style_secondary(_copy_code_button, 12, 5)

	# División panorámica dentro de la sala: Butacas (izquierda) + Chat (derecha)
	var room_split := HBoxContainer.new()
	room_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_split.add_theme_constant_override("separation", 18)
	_room_box.add_child(room_split)

	var seats_col := VBoxContainer.new()
	seats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seats_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seats_col.add_theme_constant_override("separation", 10)
	room_split.add_child(seats_col)

	seats_col.add_child(_section_label("BUTACAS Y ESTADO «LISTO»"))

	_seats = VBoxContainer.new()
	_seats.name = "Seats"
	_seats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seats.add_theme_constant_override("separation", 8)
	seats_col.add_child(_seats)

	_ready_hint = MenuStyle.make_muted("", 13)
	_ready_hint.name = "ReadyHint"
	seats_col.add_child(_ready_hint)

	var room_actions := _row()
	_ready_button = _button(room_actions, "Estoy listo", "ReadyToggle", _toggle_ready)
	_ready_button.custom_minimum_size = Vector2(200, 50)
	_ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_primary(_ready_button, 13, 6)

	_start_button = _button(room_actions, "Empezar partida", "Start", _start)
	_start_button.custom_minimum_size = Vector2(220, 52)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_primary(_start_button, 13, 6)

	_enter_running_button = _button(
		room_actions, "Entrar a la partida", "EnterRunning", _enter_running
	)
	_enter_running_button.custom_minimum_size = Vector2(220, 50)
	_enter_running_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_primary(_enter_running_button, 13, 6)
	seats_col.add_child(room_actions)

	var chat_col := VBoxContainer.new()
	chat_col.custom_minimum_size.x = 390
	chat_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_col.add_theme_constant_override("separation", 10)
	room_split.add_child(chat_col)

	chat_col.add_child(_section_label("CHAT DE SALA"))

	_chat_log = TextEdit.new()
	_chat_log.name = "ChatLog"
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.custom_minimum_size = Vector2(340, 170)
	_chat_log.editable = false
	_chat_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	MenuStyle.style_text_well(_chat_log)
	chat_col.add_child(_chat_log)

	var chat_row := _row()
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.placeholder_text = "Escribe y pulsa Enviar"
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	chat_row.add_child(_chat_input)
	_send_button = _button(chat_row, "Enviar", "Send", _send_chat)
	_send_button.custom_minimum_size = Vector2(96, 40)
	MenuStyle.style_secondary(_send_button, 12, 5)
	chat_col.add_child(chat_row)

	# 5. Diálogo modal para salas públicas protegidas con contraseña
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


func _row() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	return box


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Palette.PAPER)
	parent.add_child(label)
	return label


func _section_label(text: String) -> Label:
	return MenuStyle.make_eyebrow(text, Palette.SUN)


func _button(parent: Node, text: String, node_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _theme_key_for_game(game_id: String) -> String:
	var low := game_id.to_lower()
	if low.begins_with("island"):
		return "island"
	if low.begins_with("parchis"):
		return "parchis"
	if low.begins_with("ludo"):
		return "ludo"
	if "chess" in low:
		return "chess"
	if "checkers" in low:
		return "checkers"
	if "domino" in low:
		return "domino"
	if low.begins_with("brisca"):
		return "brisca"
	if low.begins_with("card"):
		return "cards"
	return "sandbox"


func _refresh_create_emblem() -> void:
	if _create_emblem_slot == null:
		return
	for child in _create_emblem_slot.get_children():
		_create_emblem_slot.remove_child(child)
		child.queue_free()
	var entry := _selected_entry()
	var gid := str(entry.get("id", "Island"))
	var seats_n := int(entry.get("seats", 3))
	_create_emblem_slot.add_child(
		MenuStyle.make_pill("%dJ" % seats_n, MenuStyle.CARD_ELEVATED, Palette.PAPER, 11, 9, 2)
	)
	_create_emblem_slot.add_child(
		MenuStyle.make_emblem_badge(_theme_key_for_game(gid), 22.0, MenuStyle.CARD_WELL)
	)


func _refresh_connection_pill() -> void:
	if _conn_pill_holder == null:
		return
	for child in _conn_pill_holder.get_children():
		_conn_pill_holder.remove_child(child)
		child.queue_free()
	var in_room: bool = Engine.has_singleton("Fusion") and Fusion.is_in_room()
	var connected: bool = Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon()
	if in_room:
		_conn_pill_holder.add_child(
			MenuStyle.make_pill("● En sala", READY_COLOR, Palette.INK, 12, 11, 4)
		)
	elif connected:
		_conn_pill_holder.add_child(
			MenuStyle.make_pill("● Photon conectado", Color("7cc6fe"), Palette.INK, 12, 11, 4)
		)
	elif Net.is_available():
		_conn_pill_holder.add_child(
			MenuStyle.make_pill("◌ Red lista", MenuStyle.CARD_SURFACE, Palette.PAPER, 12, 11, 4)
		)
	else:
		_conn_pill_holder.add_child(
			MenuStyle.make_pill("◌ Sin SDK online", MenuStyle.CARD_SURFACE, Palette.MUTED, 12, 11, 4)
		)


func _copy_room_code() -> void:
	if Net.room_code.is_empty():
		return
	DisplayServer.clipboard_set(Net.room_code)
	_set_status("Código «%s» copiado al portapapeles." % Net.room_code)


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

	if _room_count_slot != null:
		for child in _room_count_slot.get_children():
			_room_count_slot.remove_child(child)
			child.queue_free()
		_room_count_slot.add_child(
			MenuStyle.make_pill(
				"%d" % filtered.size(),
				MenuStyle.CARD_ELEVATED,
				Palette.SUN_LIGHT,
				11,
				9,
				2
			)
		)

	if filtered.is_empty():
		var empty_card := MenuStyle.make_card_panel(
			"EmptyRoomsCard", MenuStyle.CARD_SURFACE, Palette.INK, 16, 16, 14, 0
		)
		var empty := Label.new()
		empty.name = "EmptyRoomsLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Palette.MUTED)
		if not Net.is_available():
			empty.text = "SDK Photon Fusion no disponible en este entorno."
		elif not (Engine.has_singleton("Fusion") and Fusion.is_connected_to_photon()) and raw_rooms.is_empty():
			empty.text = "Pulsa «↻ Actualizar» para conectar y consultar las salas públicas activas."
		elif raw_rooms.is_empty():
			empty.text = "No hay salas públicas abiertas ahora mismo. ¡Crea una sala a la izquierda!"
		else:
			empty.text = "Ninguna sala coincide con los filtros actuales."
		empty_card.add_child(empty)
		_room_list_box.add_child(empty_card)
		return

	for item in filtered:
		var info: Dictionary = item
		var code_str := str(info.get("code", ""))
		var game_id := str(info.get("game", "Island"))
		var panel := MenuStyle.make_card_panel(
			"RoomCard_%s" % code_str, MenuStyle.CARD_SURFACE, Palette.INK, 12, 10, 14, 3
		)
		var row := _row()
		panel.add_child(row)

		row.add_child(
			MenuStyle.make_emblem_badge(_theme_key_for_game(game_id), 28.0, MenuStyle.CARD_WELL)
		)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 3)
		row.add_child(details)

		var locked: bool = info.get("locked") == true
		var title_line := _row()
		details.add_child(title_line)

		var room_title := Label.new()
		room_title.text = str(info.get("title", "Sala"))
		room_title.add_theme_font_size_override("font_size", 15)
		room_title.add_theme_color_override("font_color", WARN_COLOR if locked else Palette.PAPER)
		title_line.add_child(room_title)

		if locked:
			title_line.add_child(
				MenuStyle.make_pill("Clave", WARN_COLOR, Palette.INK, 10, 8, 1)
			)

		var subtitle := Label.new()
		var host_str := str(info.get("host", ""))
		var host_part := ("Anfitrión: %s · " % host_str) if not host_str.is_empty() else ""
		var state_str := "En partida" if info.get("started") == true else "Esperando"
		subtitle.text = "%s%s · %d/%d jugadores · %s" % [
			host_part,
			Net.game_title_for(game_id),
			int(info.get("players", 1)),
			int(info.get("max_players", 3)),
			state_str,
		]
		subtitle.add_theme_font_size_override("font_size", 12)
		subtitle.add_theme_color_override("font_color", Palette.MUTED)
		details.add_child(subtitle)

		var can_join: bool = (
			info.get("is_open") != false
			and info.get("started") != true
			and int(info.get("players", 0)) < int(info.get("max_players", 4))
		)
		var join_btn := _button(
			row,
			"Unirse",
			"JoinRoom_%s" % code_str,
			_on_public_room_clicked.bind(info)
		)
		join_btn.custom_minimum_size = Vector2(102, 40)
		join_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		join_btn.disabled = not can_join or not _pending_action.is_empty()
		if can_join:
			MenuStyle.style_primary(join_btn, 12, 5)
		else:
			MenuStyle.style_secondary(join_btn, 12, 5)
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
	if info.get("locked") == true:
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
	_create_card.visible = not Edition.demo
	_create_button.visible = true
	_join_card.visible = true
	_browser_card.visible = true
	_room_card.visible = false
	_leave_button.text = "← Modos"
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
	_refresh_connection_pill()
	_refresh_seats()


func _show_lobby() -> void:
	var in_room := Engine.has_singleton("Fusion") and Fusion.is_in_room()
	var offline := Net.is_singleplayer()
	var is_host := in_room and (offline or Net.is_host())
	_name_row.visible = false
	_pre_room_row.visible = is_host and Net.room_game.is_empty()
	_create_card.visible = is_host and Net.room_game.is_empty()
	_create_button.visible = false
	_join_card.visible = false
	_browser_card.visible = false
	_room_card.visible = true
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
	_copy_code_button.visible = not Net.room_code.is_empty()

	var my_seat := Net.local_seat()
	var my_ready := Net.is_seat_ready(my_seat)
	_ready_button.visible = not is_host and not in_room_started()
	_ready_button.text = "Cancelar «Listo»" if my_ready else "Estoy listo"
	if my_ready:
		MenuStyle.style_secondary(_ready_button, 13, 6)
	else:
		MenuStyle.style_primary(_ready_button, 13, 6)

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
	_refresh_connection_pill()
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
		var seat_card := MenuStyle.make_card_panel(
			"SeatCard%d" % pid, MenuStyle.CARD_SURFACE, Palette.INK, 12, 9, 12, 2
		)
		var row := _row()
		seat_card.add_child(row)

		var seat_colors: Array[Color] = [
			Palette.PLAYER_RED,
			Palette.PLAYER_BLUE,
			Palette.PLAYER_ORANGE,
			Palette.PLAYER_GREEN,
		]
		var seat_col: Color = seat_colors[seat % seat_colors.size()]
		var seat_fg := Palette.INK if seat_col.get_luminance() > 0.42 else Palette.PAPER
		var badge := MenuStyle.make_pill("J%d" % pid, seat_col, seat_fg, 12, 9, 2)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)

		var seat_label := Label.new()
		seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var is_occupied_self := (pid == local_id)
		var is_occupied_peer := Net.players.has(pid)

		if is_occupied_self or is_occupied_peer:
			var p_name := (
				(Net.local_name if not Net.local_name.is_empty() else "Jugador")
				if is_occupied_self
				else str(Net.players[pid])
			)
			var peer_is_host := (is_host and is_occupied_self) or (not offline and pid == master_id)
			seat_label.text = "%s%s" % [
				p_name,
				"  (tú)" if is_occupied_self else "",
			]
			seat_label.add_theme_color_override("font_color", Palette.PAPER)
			row.add_child(seat_label)

			if peer_is_host:
				row.add_child(
					MenuStyle.make_pill("★ Anfitrión", WARN_COLOR, Palette.INK, 11, 9, 2)
				)
			elif is_host and Net.room_locked and Net.authenticated_peers.get(pid, false) != true:
				row.add_child(
					MenuStyle.make_pill("Verificando…", WARN_COLOR, Palette.INK, 11, 9, 2)
				)
			elif Net.is_seat_ready(seat):
				row.add_child(
					MenuStyle.make_pill("✓ Listo", READY_COLOR, Palette.INK, 11, 9, 2)
				)
			else:
				row.add_child(
					MenuStyle.make_pill("Esperando…", MenuStyle.CARD_WELL, Palette.MUTED, 11, 9, 2)
				)

			if is_host and not is_occupied_self and not in_room_started():
				var kick_btn := _button(
					row, "Expulsar", "KickSeat%d" % pid, _on_kick_pressed.bind(pid)
				)
				kick_btn.custom_minimum_size = Vector2(90, 34)
				MenuStyle.style_secondary(kick_btn, 10, 4)
		else:
			var is_bot: bool = seat < Net.room_bots.size() and Net.room_bots[seat]
			seat_label.text = "Bot automático" if is_bot else "Asiento libre"
			seat_label.add_theme_color_override("font_color", WARN_COLOR if is_bot else Palette.MUTED)
			row.add_child(seat_label)

			if is_bot:
				row.add_child(
					MenuStyle.make_pill("✓ IA Lista", READY_COLOR, Palette.INK, 11, 9, 2)
				)

			if is_host and not in_room_started():
				var bot_check := CheckBox.new()
				bot_check.name = "SeatBot%d" % pid
				bot_check.text = "Bot"
				bot_check.add_theme_color_override("font_color", Palette.PAPER)
				bot_check.set_pressed_no_signal(is_bot)
				bot_check.toggled.connect(_on_seat_bot_toggled.bind(seat))
				row.add_child(bot_check)
		_seats.add_child(seat_card)


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
	var listed := Net.find_listed_room(code)
	if not listed.is_empty() and listed.get("locked") == true:
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
	get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")

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
