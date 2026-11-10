extends Control
## Selección para jugar en solitario contra bots:
## - Selector visual de las tres dificultades (`Difficulty0..2`) con indicadores de nivel.
## - Cuadrícula desplazable de las 9 mesas con IA disponible (`ScrollContainer` + `GridContainer`),
##   evitando cualquier desbordamiento vertical en 1280×720 y mostrando el emblema y número de
##   jugadores de cada juego.

const GAMES := [
	{
		"id": "IslandTwo",
		"title": "Isla de recursos · 2 jugadores",
		"scene": "res://scenes/IslandTwo.tscn",
		"note": "Contra 1 bot · duelo rápido",
		"badge": "2J · IA",
		"theme": "island",
		"primary": false,
	},
	{
		"id": "Island",
		"title": "Isla de recursos · 3 jugadores",
		"scene": "res://scenes/Island.tscn",
		"note": "Contra 2 bots · equilibrio clásico",
		"badge": "3J · IA",
		"theme": "island",
		"primary": true,
	},
	{
		"id": "IslandFour",
		"title": "Isla de recursos · 4 jugadores",
		"scene": "res://scenes/IslandFour.tscn",
		"note": "Contra 3 bots · isla completa",
		"badge": "4J · IA",
		"theme": "island",
		"primary": false,
	},
	{
		"id": "Parchis",
		"title": "Parchís · 4 jugadores",
		"scene": "res://scenes/Parchis.tscn",
		"note": "Contra 3 bots · reglas españolas",
		"badge": "4J · IA",
		"theme": "parchis",
		"primary": true,
	},
	{
		"id": "Parchis2",
		"title": "Parchís · 2 jugadores",
		"scene": "res://scenes/Parchis2.tscn",
		"note": "Contra 1 bot · duelo de barreras",
		"badge": "2J · IA",
		"theme": "parchis",
		"primary": false,
	},
	{
		"id": "Brisca",
		"title": "Brisca",
		"scene": "res://scenes/Brisca.tscn",
		"note": "Contra el bot · baraja española",
		"badge": "2J · IA",
		"theme": "brisca",
		"primary": true,
	},
	{
		"id": "Checkers",
		"title": "Damas físicas",
		"scene": "res://scenes/GuidedPhysicalCheckers.tscn",
		"note": "Contra el bot de las fichas oscuras",
		"badge": "2J · IA",
		"theme": "checkers",
		"primary": false,
	},
	{
		"id": "Domino",
		"title": "Dominó físico",
		"scene": "res://scenes/GuidedDomino.tscn",
		"note": "Contra el bot del jugador 2",
		"badge": "2J · IA",
		"theme": "domino",
		"primary": false,
	},
	{
		"id": "Ludo",
		"title": "Ludo · 2 jugadores",
		"scene": "res://scenes/Ludo.tscn",
		"note": "Contra 1 bot · carrera rápida",
		"badge": "2J · IA",
		"theme": "ludo",
		"primary": false,
	},
]

const DIFFICULTIES := [
	{
		"label": "Fácil",
		"stars": "★☆☆",
		"short": "Relajado · jugadas variadas",
		"desc": "Se equivoca a propósito · 0,35 s por jugada",
		"level": TableBots.Difficulty.FACIL,
		"accent": Palette.MINT,
	},
	{
		"label": "Normal",
		"stars": "★★☆",
		"short": "Equilibrado · sentido común",
		"desc": "Juega con sentido común · 0,8 s por jugada",
		"level": TableBots.Difficulty.NORMAL,
		"accent": Palette.SUN,
	},
	{
		"label": "Difícil",
		"stars": "★★★",
		"short": "Estratega · busca ventaja",
		"desc": "Busca ventaja · 1,4 s por jugada",
		"level": TableBots.Difficulty.DIFICIL,
		"accent": Palette.CORAL,
	},
]

var _level := TableBots.Difficulty.NORMAL
var _diff_buttons: Array[Button] = []
var _diff_note: Label


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

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# 1. Cabecera con botón Back (requerido por tests) y acceso al catálogo local
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)

	var back := Button.new()
	back.name = "Back"
	back.text = "← Volver"
	back.custom_minimum_size = Vector2(132, 44)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_secondary(back, 12, 6)
	back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
	)
	header.add_child(back)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 1)
	header.add_child(title_col)

	title_col.add_child(MenuStyle.make_eyebrow("TABLERAMA  /  JUGAR CON BOTS", Palette.SUN))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_col.add_child(title_row)
	title_row.add_child(MenuStyle.make_title("Solitario contra la IA", 32))
	var subtitle := MenuStyle.make_muted(
		"Juegas en el asiento 1 y la máquina controla al resto de jugadores.", 13
	)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(subtitle)

	var local_shortcut := Button.new()
	local_shortcut.name = "LocalCatalog"
	local_shortcut.text = "Catálogo local  →"
	local_shortcut.custom_minimum_size = Vector2(164, 44)
	local_shortcut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_secondary(local_shortcut, 12, 6)
	local_shortcut.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)
	header.add_child(local_shortcut)

	# 2. Tarjeta de selección de dificultad
	var diff_card := MenuStyle.make_card_panel(
		"DifficultyCard", Palette.PANEL, Palette.INK, 18, 14, 18, 5
	)
	page.add_child(diff_card)

	var diff_col := VBoxContainer.new()
	diff_col.add_theme_constant_override("separation", 10)
	diff_card.add_child(diff_col)

	var diff_head := HBoxContainer.new()
	diff_head.add_theme_constant_override("separation", 12)
	diff_col.add_child(diff_head)

	var diff_label := MenuStyle.make_eyebrow("DIFICULTAD DEL BOT", Palette.SUN)
	diff_label.name = "Dificultad"
	diff_head.add_child(diff_label)

	_diff_note = MenuStyle.make_muted(DIFFICULTIES[1]["desc"], 13, HORIZONTAL_ALIGNMENT_RIGHT)
	_diff_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_head.add_child(_diff_note)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 12)
	diff_col.add_child(diff_row)

	for index in DIFFICULTIES.size():
		var info: Dictionary = DIFFICULTIES[index]
		var button := Button.new()
		button.name = "Difficulty%d" % index
		button.text = ""
		button.clip_contents = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(200, 62)
		button.pressed.connect(_select_difficulty.bind(index))

		var inner := MarginContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("margin_left", 14)
		inner.add_theme_constant_override("margin_right", 14)
		inner.add_theme_constant_override("margin_top", 7)
		inner.add_theme_constant_override("margin_bottom", 10)
		button.add_child(inner)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		inner.add_child(row)

		var stars := Label.new()
		stars.text = str(info["stars"])
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_theme_font_size_override("font_size", 18)
		stars.add_theme_color_override("font_color", Palette.INK)
		stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(stars)

		var tcol := VBoxContainer.new()
		tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tcol.add_theme_constant_override("separation", 0)
		row.add_child(tcol)

		var main_lbl := Label.new()
		main_lbl.text = str(info["label"])
		main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_lbl.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
		main_lbl.add_theme_font_size_override("font_size", 18)
		main_lbl.add_theme_color_override("font_color", Palette.INK)
		tcol.add_child(main_lbl)

		var sub_lbl := Label.new()
		sub_lbl.text = str(info["short"])
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override("font_color", Palette.INK.lightened(0.2))
		tcol.add_child(sub_lbl)

		diff_row.add_child(button)
		_diff_buttons.append(button)

	var initial := 1
	for i in DIFFICULTIES.size():
		if int(DIFFICULTIES[i]["level"]) == TableBots.difficulty:
			initial = i
			break
	_select_difficulty(initial)

	# 3. Tarjeta de cuadrícula de mesas con bot (en ScrollContainer para 720p y panorámico)
	var tables_card := MenuStyle.make_card_panel(
		"BotTablesCard", Palette.PANEL, Palette.INK, 18, 14, 20, 6
	)
	tables_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(tables_card)

	var tables_col := VBoxContainer.new()
	tables_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tables_col.add_theme_constant_override("separation", 10)
	tables_card.add_child(tables_col)

	var group_head := HBoxContainer.new()
	group_head.add_theme_constant_override("separation", 12)
	tables_col.add_child(group_head)

	var group_label := MenuStyle.make_eyebrow("MESAS CON BOT", Palette.SUN)
	group_label.name = "MESAS CON BOT"
	group_head.add_child(group_label)

	var group_desc := MenuStyle.make_muted(
		"Elige una mesa: se abrirá directamente en modo solitario con la dificultad seleccionada.",
		13,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	group_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_head.add_child(group_desc)

	var scroll := ScrollContainer.new()
	scroll.name = "BotGamesScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tables_col.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "BotGamesGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	for game in GAMES:
		_add_bot_game(grid, game)

	_diff_buttons[initial].grab_focus.call_deferred()


func _select_difficulty(index: int) -> void:
	if index < 0 or index >= DIFFICULTIES.size():
		return
	_level = int(DIFFICULTIES[index]["level"])
	TableBots.difficulty = _level
	_diff_note.text = tr(str(DIFFICULTIES[index]["desc"]))
	for i in _diff_buttons.size():
		var btn := _diff_buttons[i]
		if i == index:
			var accent: Color = DIFFICULTIES[i]["accent"]
			MenuStyle.style_button(btn, accent, accent.lightened(0.14), Palette.INK, 14, 6, 14, 7)
		else:
			MenuStyle.style_secondary(btn, 14, 6)


func _start(game: Dictionary) -> void:
	TableBots.difficulty = _level
	TableBots.solo = true
	get_tree().change_scene_to_file(str(game["scene"]))


func _add_bot_game(parent: Control, game: Dictionary) -> void:
	var scene := str(game["scene"])
	var edition := get_node_or_null("/root/Edition")
	var locked: bool = edition != null and edition.call("allows", scene) != true
	var button := MenuStyle.make_game_card_button(
		str(game["id"]),
		str(game["title"]),
		str(game["note"]),
		str(game["badge"]),
		str(game["theme"]),
		game.get("primary") == true,
		locked,
		74.0
	)
	button.tooltip_text = (
		"Incluida en el juego completo" if locked else str(game["note"])
	)
	button.pressed.connect(_start.bind(game))
	parent.add_child(button)
