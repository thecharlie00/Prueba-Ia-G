extends Control
## Catálogo de mesas locales y ajustes rápidos de Tablerama:
## - Cabecera de navegación con vuelta a modos y accesos directos a Bots y Online.
## - Catálogo a la izquierda con filtros por categoría, emblemas vectoriales por familia,
##   insignias de jugadores/reglas y tarjetas táctiles en cuadrícula.
## - Panel lateral fijo a la derecha con todos los ajustes de control, movimiento, sonido,
##   pantalla completa, idioma y salida siempre a mano sin restar altura a la lista.

var controls_feedback: Label
var _filter_buttons: Dictionary = {}
var _family_cards: Array[Dictionary] = []
var _active_filter := "all"
var _game_scroll: ScrollContainer


func _ready() -> void:
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
		get_viewport().set_input_as_handled()


func _build() -> void:
	MenuStyle.add_backdrop(self, Palette.SUN)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	# El menú no llena la pantalla: se centra con un tamaño máximo y deja ver la sala.
	MenuStyle.limit_page(margin, Vector2(1260, 740), 24)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# 1. Barra superior: Volver a modos · Título · Accesos rápidos (Bots / Online)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)

	var back_btn := Button.new()
	back_btn.name = "BackToModes"
	back_btn.text = "← Modos"
	back_btn.custom_minimum_size = Vector2(124, 44)
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_secondary(back_btn, 12, 6)
	back_btn.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
	)
	header.add_child(back_btn)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 1)
	header.add_child(title_col)

	title_col.add_child(
		MenuStyle.make_eyebrow("TABLERAMA  /  MESA DE JUEGO LOCAL", Palette.SUN)
	)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_col.add_child(title_row)
	var title := MenuStyle.make_title("Elige tu mesa", 32)
	title_row.add_child(title)
	var subtitle := MenuStyle.make_muted(
		"Juegos para compartir en el mismo equipo. Cada opción inicia una mesa nueva.", 13
	)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(subtitle)

	var quick_actions := HBoxContainer.new()
	quick_actions.add_theme_constant_override("separation", 10)
	quick_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(quick_actions)

	var bots := Button.new()
	bots.name = "BotsMenu"
	bots.text = "Contra bots  →"
	bots.custom_minimum_size = Vector2(158, 44)
	MenuStyle.style_primary(bots, 12, 6)
	bots.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/BotSelect.tscn")
	)
	quick_actions.add_child(bots)

	var online := Button.new()
	online.name = "OnlineMenu"
	online.text = "Salas online"
	online.custom_minimum_size = Vector2(138, 44)
	MenuStyle.style_secondary(online, 12, 6)
	online.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	)
	quick_actions.add_child(online)

	# 2. Cartel de edición demo (solo cuando Edition.demo == true)
	_demo_banner(page)

	# 3. Cuerpo principal en dos columnas: Catálogo (izquierda) + Ajustes (derecha)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)

	var catalog_panel := MenuStyle.make_card_panel(
		"CatalogPanel", Palette.PANEL, Palette.INK, 18, 14, 20, 6
	)
	catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(catalog_panel)

	var catalog_col := VBoxContainer.new()
	catalog_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_col.add_theme_constant_override("separation", 12)
	catalog_panel.add_child(catalog_col)

	# Barra de filtros de categoría
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 8)
	catalog_col.add_child(filter_bar)

	var filter_defs := [
		["all", "Todas"],
		["strategy", "Estrategia"],
		["race", "Carrera y fichas"],
		["cards_free", "Cartas y mesa libre"],
	]
	for f in filter_defs:
		var fid := str(f[0])
		var fbtn := Button.new()
		fbtn.name = "Filter_" + fid
		fbtn.text = str(f[1])
		fbtn.custom_minimum_size = Vector2(0, 34)
		fbtn.pressed.connect(_set_category_filter.bind(fid))
		filter_bar.add_child(fbtn)
		_filter_buttons[fid] = fbtn
	_refresh_filter_pills()

	_game_scroll = ScrollContainer.new()
	_game_scroll.name = "GameList"
	_game_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_game_scroll.follow_focus = true
	catalog_col.add_child(_game_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	_game_scroll.add_child(list)

	_build_catalog_entries(list)

	# 4. Columna lateral derecha de ajustes, idioma y salida
	_build_settings_sidebar(body)

	var first := list.find_child("Island", true, false) as Button
	if first == null or first.disabled:
		first = list.find_child("Tutorial", true, false) as Button
	if first != null:
		first.grab_focus.call_deferred()


func _build_catalog_entries(list: VBoxContainer) -> void:
	# Tarjeta destacada: Tutorial jugable
	var tut_grid := _family_section(
		list,
		"EMPIEZA AQUÍ",
		"Aprende a jugar en la mesa libre en tres minutos, paso a paso.",
		"sandbox",
		"3 min · Guiado",
		"cards_free",
		1,
		true
	)
	var tutorial := _game_card(
		tut_grid,
		"Tutorial",
		"Tutorial jugable",
		"Agarrar, lanzar dados, orbitar cámara, manos privadas y pincel",
		"Paso a paso",
		"sandbox",
		"res://scenes/Main.tscn",
		true,
		true
	)
	tutorial.pressed.connect(_enable_tutorial_flag)

	var edition := get_node_or_null("/root/Edition")
	if edition != null and edition.get("demo") == true:
		var demo_grid := _family_section(
			list,
			"INCLUIDO EN LA DEMO",
			"Mesa libre y dos juegos completos con reglas y bots.",
			"parchis",
			"Jugable gratis",
			"all",
			3,
			true
		)
		_game_card(
			demo_grid,
			"DemoBrisca",
			"Brisca · 2 jugadores",
			"Baraja española con bot o local",
			"2J",
			"brisca",
			"res://scenes/Brisca.tscn",
			true
		)
		_game_card(
			demo_grid,
			"DemoParchis",
			"Parchís · 4 jugadores",
			"Reglas españolas completas",
			"4J",
			"parchis",
			"res://scenes/Parchis.tscn",
			true
		)
		_game_card(
			demo_grid,
			"DemoSandbox",
			"Abrir mesa libre",
			"Dados, cartas, fichas y herramientas",
			"Libre",
			"sandbox",
			"res://scenes/Main.tscn",
			true
		)

	# Isla de recursos
	var island_grid := _family_section(
		list,
		"ISLA DE RECURSOS",
		"Dos, tres o cuatro jugadores · estrategia inspirada en Catán.",
		"island",
		"2–4 jugadores",
		"strategy",
		3
	)
	_game_card(
		island_grid,
		"IslandTwo",
		"Isla de recursos · 2 jugadores",
		"Duelo rápido de comercio y expansión",
		"2J",
		"island",
		"res://scenes/IslandTwo.tscn"
	)
	_game_card(
		island_grid,
		"Island",
		"Isla de recursos · 3 jugadores",
		"Partida clásica equilibrada",
		"3J",
		"island",
		"res://scenes/Island.tscn",
		true
	)
	_game_card(
		island_grid,
		"IslandFour",
		"Isla de recursos · 4 jugadores",
		"Isla llena y máxima negociación",
		"4J",
		"island",
		"res://scenes/IslandFour.tscn"
	)

	# Parchís
	var parchis_grid := _family_section(
		list,
		"PARCHÍS",
		"Reglas españolas: salir con 5, barreras, comer cuenta 20 y meta 10.",
		"parchis",
		"2 o 4 jugadores",
		"race",
		2
	)
	_game_card(
		parchis_grid,
		"Parchis",
		"Parchís · 4 jugadores",
		"Cuatro colores clásicos y barreras",
		"4J",
		"parchis",
		"res://scenes/Parchis.tscn",
		true
	)
	_game_card(
		parchis_grid,
		"Parchis2",
		"Parchís · 2 jugadores",
		"Mano a mano táctico",
		"2J",
		"parchis",
		"res://scenes/Parchis2.tscn"
	)

	# Cartas y Brisca
	var cards_grid := _family_section(
		list,
		"CARTAS",
		"Brisca contra el bot o entre dos · mesa libre con barajas inglesa, española y propias.",
		"brisca",
		"Barajas y reglas",
		"cards_free",
		2
	)
	_game_card(
		cards_grid,
		"Brisca",
		"Brisca · 2 jugadores",
		"Triunfo, bazas y tanteo automático",
		"2J · Reglas",
		"brisca",
		"res://scenes/Brisca.tscn",
		true
	)
	_game_card(
		cards_grid,
		"Cards",
		"Abrir mesa de cartas",
		"Baraja española, inglesa y mazos propios",
		"Física libre",
		"cards",
		"res://scenes/CardTable.tscn"
	)

	# Mesa libre
	var sandbox_grid := _family_section(
		list,
		"MESA LIBRE",
		"Experimenta con dados, cartas y fichas con físicas.",
		"sandbox",
		"1–4 jugadores",
		"cards_free",
		1
	)
	_game_card(
		sandbox_grid,
		"Sandbox",
		"Abrir mesa libre",
		"Dados, contadores, bolsas, notas, reloj, pincel y rebobinado",
		"Sandbox 3D",
		"sandbox",
		"res://scenes/Main.tscn",
		true
	)

	# Ajedrez
	var chess_grid := _family_section(
		list,
		"AJEDREZ",
		"Dos jugadores · vista simple, física con reglas o física libre.",
		"chess",
		"2 jugadores",
		"strategy",
		3
	)
	_game_card(
		chess_grid,
		"GuidedChess",
		"Ajedrez físico con reglas",
		"Piezas 3D agarrables con validación legal",
		"Física + Reglas",
		"chess",
		"res://scenes/GuidedPhysicalChess.tscn",
		true
	)
	_game_card(
		chess_grid,
		"Chess",
		"Ajedrez con reglas · vista simple",
		"Selección limpia por clic y promoción",
		"Clásico",
		"chess",
		"res://scenes/Chess.tscn"
	)
	_game_card(
		chess_grid,
		"PhysicalChess",
		"Ajedrez físico libre",
		"Tablero manual sin restricciones",
		"Física libre",
		"chess",
		"res://scenes/PhysicalChess.tscn"
	)

	# Damas
	var checkers_grid := _family_section(
		list,
		"DAMAS",
		"Damas inglesas adaptadas · elige física con reglas o modo manual.",
		"checkers",
		"2 jugadores",
		"strategy",
		3
	)
	_game_card(
		checkers_grid,
		"GuidedCheckers",
		"Damas físicas con reglas",
		"Capturas, coronación y bot opcional",
		"Física + Reglas",
		"checkers",
		"res://scenes/GuidedPhysicalCheckers.tscn",
		true
	)
	_game_card(
		checkers_grid,
		"SimpleCheckers",
		"Damas con reglas · vista simple",
		"Partida directa por clic",
		"Clásico",
		"checkers",
		"res://scenes/Checkers.tscn"
	)
	_game_card(
		checkers_grid,
		"FreeCheckers",
		"Damas físicas libres",
		"Fichas apilables sin árbitro",
		"Física libre",
		"checkers",
		"res://scenes/PhysicalCheckers.tscn"
	)

	# Ludo
	var ludo_grid := _family_section(
		list,
		"LUDO",
		"Carrera con dado y fichas físicas · variante local.",
		"ludo",
		"2–4 jugadores",
		"race",
		3
	)
	_game_card(
		ludo_grid,
		"Ludo",
		"Ludo · 2 jugadores",
		"Duelo rápido con dado físico",
		"2J",
		"ludo",
		"res://scenes/Ludo.tscn",
		true
	)
	_game_card(
		ludo_grid,
		"Ludo3",
		"Ludo · 3 jugadores",
		"Tres esquinas activas",
		"3J",
		"ludo",
		"res://scenes/Ludo3.tscn"
	)
	_game_card(
		ludo_grid,
		"Ludo4",
		"Ludo · 4 jugadores",
		"Tablero completo de cuatro colores",
		"4J",
		"ludo",
		"res://scenes/Ludo4.tscn"
	)

	# Dominó
	var domino_grid := _family_section(
		list,
		"DOMINÓ",
		"Doble seis · reglas para dos jugadores o mesa libre.",
		"domino",
		"2 jugadores",
		"race",
		2
	)
	_game_card(
		domino_grid,
		"GuidedDomino",
		"Dominó físico con reglas",
		"Cadena automática, pozo y bot opcional",
		"Física + Reglas",
		"domino",
		"res://scenes/GuidedDomino.tscn",
		true
	)
	_game_card(
		domino_grid,
		"FreeDomino",
		"Dominó físico libre",
		"28 fichas doble seis para colocar a mano",
		"Física libre",
		"domino",
		"res://scenes/PhysicalDomino.tscn"
	)

	# Estudio de creación de juegos (Game Creator Studio).
	var creator_grid := _family_section(
		list,
		"ESTUDIO DE CREACIÓN",
		"Diseña, programa visualmente y publica tus propios juegos de mesa, tablero, cartas y arcade ligero.",
		"sandbox",
		"Herramienta de autor",
		"creator",
		1
	)
	_game_card(
		creator_grid,
		"GameCreator",
		"Editor de juegos",
		"Crea tableros, reglas visuales, barajas y dados sin código",
		"Game Creator Studio",
		"creator",
		"res://scenes/game_creator/GameCreatorEditor.tscn",
		true,
		true
	)


func _build_settings_sidebar(parent: HBoxContainer) -> void:
	var sidebar := MenuStyle.make_card_panel(
		"SettingsPanel", Palette.PANEL, Palette.INK, 18, 16, 20, 6
	)
	sidebar.custom_minimum_size = Vector2(336, 0)
	sidebar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(sidebar)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	sidebar.add_child(col)

	col.add_child(MenuStyle.make_eyebrow("AJUSTES DE MESA", Palette.SUN))
	col.add_child(MenuStyle.make_title("Comodidad y equipo", 22))

	var toggles_well := MenuStyle.make_card_panel(
		"", MenuStyle.CARD_WELL, Palette.INK, 14, 10, 14, 0
	)
	col.add_child(toggles_well)

	var toggles_col := VBoxContainer.new()
	toggles_col.add_theme_constant_override("separation", 6)
	toggles_well.add_child(toggles_col)

	var option := CheckButton.new()
	option.name = "ClickToGrab"
	option.text = "Clic para agarrar y soltar"
	option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null:
		option.button_pressed = navigation.get("click_to_grab") == true
		option.toggled.connect(navigation.set_click_to_grab)
		navigation.controls_changed.connect(option.set_pressed_no_signal)
		navigation.controls_changed.connect(_on_controls_changed)
	toggles_col.add_child(option)

	var motion := CheckButton.new()
	motion.name = "ReduceMotion"
	motion.text = "Reducir animaciones"
	motion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		motion.button_pressed = style.get("reduce_motion") == true
		motion.toggled.connect(style.set_reduce_motion)
	toggles_col.add_child(motion)

	var sound := CheckButton.new()
	sound.name = "SoundEffects"
	sound.text = "Efectos de sonido"
	sound.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sound.button_pressed = sfx.get("enabled") == true
		sound.toggled.connect(sfx.set_enabled)
	toggles_col.add_child(sound)

	var fullscreen := CheckButton.new()
	fullscreen.name = "Fullscreen"
	fullscreen.text = "Pantalla completa"
	fullscreen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if style != null and style.has_method("set_fullscreen"):
		fullscreen.toggled.connect(style.set_fullscreen)
	toggles_col.add_child(fullscreen)

	var locale := get_node_or_null("/root/Locale")
	if locale != null:
		var language_row := HBoxContainer.new()
		language_row.add_theme_constant_override("separation", 10)
		var lang_lbl := Label.new()
		lang_lbl.text = "Idioma"
		lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lang_lbl.add_theme_color_override("font_color", Palette.PAPER)
		language_row.add_child(lang_lbl)
		var selector: OptionButton = locale.make_selector()
		selector.custom_minimum_size = Vector2(146, 38)
		MenuStyle.style_secondary(selector, 12, 5)
		language_row.add_child(selector)
		col.add_child(language_row)

	controls_feedback = MenuStyle.make_muted(
		"Los ajustes de agarre, animación y sonido se guardan en este equipo.", 12
	)
	col.add_child(controls_feedback)

	var tip_card := MenuStyle.make_card_panel(
		"", MenuStyle.CARD_SURFACE, Palette.INK, 12, 10, 14, 0
	)
	col.add_child(tip_card)
	tip_card.add_child(
		MenuStyle.make_muted(
			"Consejo: pulsa F1 en cualquier mesa para ver sus controles o Esc para pausar y centrar la cámara.",
			12
		)
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var quit_button := Button.new()
	quit_button.name = "Quit"
	quit_button.text = "Salir del juego"
	quit_button.custom_minimum_size = Vector2(0, 44)
	MenuStyle.style_secondary(quit_button, 12, 6)
	quit_button.pressed.connect(get_tree().quit)
	col.add_child(quit_button)


func _family_section(
	parent: VBoxContainer,
	title_text: String,
	description: String,
	theme_key: String,
	players_badge: String,
	category: String,
	item_count: int,
	highlighted := false
) -> GridContainer:
	var info := MenuStyle.theme_info(theme_key)
	var accent: Color = info["accent"]
	var bg := MenuStyle.CARD_ELEVATED if highlighted else MenuStyle.CARD_SURFACE
	var card := MenuStyle.make_card_panel(
		"", bg, Palette.INK, 16, 14, 16, 4
	)
	parent.add_child(card)
	_family_cards.append({"node": card, "category": category})

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)

	head.add_child(MenuStyle.make_emblem_badge(theme_key, 28.0, MenuStyle.CARD_WELL))

	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_text.add_theme_constant_override("separation", 1)
	head.add_child(head_text)

	var family_lbl := Label.new()
	family_lbl.text = title_text
	family_lbl.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	family_lbl.add_theme_font_size_override("font_size", 19)
	family_lbl.add_theme_color_override("font_color", accent.lightened(0.28))
	head_text.add_child(family_lbl)

	head_text.add_child(MenuStyle.make_muted(description, 13))

	var fg := Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
	var badge := MenuStyle.make_pill(players_badge, accent, fg, 11, 10, 3)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)

	var grid := GridContainer.new()
	grid.columns = 1 if item_count <= 1 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	return grid


func _game_card(
	parent: Control,
	id: String,
	title_text: String,
	subtitle_text: String,
	badge_text: String,
	theme_key: String,
	scene: String,
	primary := false,
	always_unlocked := false
) -> Button:
	var edition := get_node_or_null("/root/Edition")
	var locked: bool = (
		not always_unlocked
		and edition != null
		and edition.call("allows", scene) != true
	)
	var button := MenuStyle.make_game_card_button(
		id, title_text, subtitle_text, badge_text, theme_key, primary, locked, 66.0
	)
	if locked:
		button.tooltip_text = "Incluida en el juego completo"
	button.pressed.connect(_open.bind(scene))
	parent.add_child(button)
	return button


func _enable_tutorial_flag() -> void:
	Tutorial.requested = true


func _set_category_filter(category: String) -> void:
	_active_filter = category
	_refresh_filter_pills()
	for item in _family_cards:
		var node := item["node"] as Control
		var cat := str(item["category"])
		node.visible = (_active_filter == "all" or cat == "all" or cat == _active_filter)
	if _game_scroll != null:
		_game_scroll.scroll_vertical = 0


func _refresh_filter_pills() -> void:
	for key in _filter_buttons:
		var btn := _filter_buttons[key] as Button
		MenuStyle.style_pill_filter(btn, key == _active_filter, Palette.SUN)


func _on_controls_changed(_enabled: bool) -> void:
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null and is_instance_valid(controls_feedback):
		controls_feedback.text = navigation.controls_status.text


## Demo: cartel con lo que incluye y, si ya hay página de tienda, el botón para apuntarse.
func _demo_banner(column: VBoxContainer) -> void:
	var edition := get_node_or_null("/root/Edition")
	if edition == null or edition.get("demo") != true:
		return
	var banner := MenuStyle.make_card_panel(
		"DemoBanner", Palette.SUN, Palette.INK, 18, 10, 14, 4
	)
	column.add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	banner.add_child(row)
	var pill := MenuStyle.make_pill("DEMO", Palette.CORAL, Palette.INK, 12, 10, 3)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pill)
	var text := Label.new()
	text.text = "DEMO GRATUITA · Mesa libre, brisca y parchís. El resto de mesas, en el juego completo."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", Palette.INK)
	row.add_child(text)
	if not str(edition.STORE_URL).is_empty():
		var store := Button.new()
		store.name = "Store"
		store.text = "Añadir a la lista de deseados"
		MenuStyle.style_secondary(store, 12, 5)
		store.pressed.connect(func() -> void: OS.shell_open(edition.STORE_URL))
		row.add_child(store)
	if not str(edition.notice).is_empty():
		var notice := Label.new()
		notice.name = "DemoNotice"
		notice.text = str(edition.notice)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.add_theme_font_size_override("font_size", 14)
		notice.add_theme_color_override("font_color", Palette.CORAL.lightened(0.22))
		column.add_child(notice)
		edition.notice = ""


func _open(path: String) -> void:
	if path.contains("Island") and not TableBots.solo:
		IslandView.local_pass_privacy = true
	get_tree().change_scene_to_file(path)
