extends Control

## Menú principal de «jugar contra bots»: elige la dificultad (tres niveles) y la
## mesa; la máquina controla al resto de jugadores. La dificultad y el modo solitario
## se guardan en TableBots para que los juegos los usen al abrirse.

const BUTTON_STYLE := Color("fff8ec")
const ACCENT := Color("ffc83d")
const MUTED := Color("c9c5ef")
const INK := Color("1d1a3a")

## Mesas con bot disponible: identificador, título, escena y nota.
const GAMES := [
	{
		"id": "Parchis",
		"title": "Parchís · 4 jugadores",
		"scene": "res://scenes/Parchis.tscn",
		"note": "Contra tres bots · reglas españolas",
	},
	{
		"id": "Parchis2",
		"title": "Parchís · 2 jugadores",
		"scene": "res://scenes/Parchis2.tscn",
		"note": "Contra un bot · reglas españolas",
	},
	{
		"id": "Ludo",
		"title": "Ludo · 2 jugadores",
		"scene": "res://scenes/Ludo.tscn",
		"note": "Contra un bot",
	},
	{
		"id": "Checkers",
		"title": "Damas físicas",
		"scene": "res://scenes/GuidedPhysicalCheckers.tscn",
		"note": "Contra el bot de las oscuras",
	},
	{
		"id": "Domino",
		"title": "Dominó físico",
		"scene": "res://scenes/GuidedDomino.tscn",
		"note": "Contra el bot del jugador 2",
	},
	{
		"id": "Brisca",
		"title": "Brisca",
		"scene": "res://scenes/Brisca.tscn",
		"note": "Contra el bot · 2 jugadores",
	},
]

## Las tres dificultades: etiqueta, descripción y valor de TableBots.Difficulty.
const DIFFICULTIES := [
	{
		"label": "Fácil",
		"desc": "Se equivoca a propósito · 0,35 s por jugada",
		"level": TableBots.Difficulty.FACIL,
	},
	{
		"label": "Normal",
		"desc": "Juega con sentido común · 0,8 s por jugada",
		"level": TableBots.Difficulty.NORMAL,
	},
	{
		"label": "Difícil",
		"desc": "Busca ventaja · 1,4 s por jugada",
		"level": TableBots.Difficulty.DIFICIL,
	},
]

var _level := TableBots.Difficulty.NORMAL
var _diff_buttons: Array[Button] = []
var _diff_note: Label


func _ready() -> void:
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("2a2552")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_label("TABLERAMA  /  JUGAR CON BOTS", 13, ACCENT))
	column.add_child(_label("Elige la dificultad", 36, Color("f3ead9")))
	var subtitle := _label(
		"Juegas solo: la máquina controla al resto de jugadores. "
		+ "La dificultad se aplica a todos los bots de la mesa.",
		15,
		MUTED
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	column.add_child(_label("Dificultad", 14, ACCENT))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	column.add_child(diff_row)
	for index in DIFFICULTIES.size():
		var button := Button.new()
		button.name = "Difficulty%d" % index
		button.text = DIFFICULTIES[index]["label"]
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select_difficulty.bind(index))
		_style_button(button, BUTTON_STYLE)
		diff_row.add_child(button)
		_diff_buttons.append(button)
	_diff_note = _label(DIFFICULTIES[1]["desc"], 12, MUTED)
	column.add_child(_diff_note)
	_select_difficulty(1)
	_group(
		column,
		"MESAS CON BOT",
		"Cada mesa empieza contra bots; el humano siempre es el jugador 1."
	)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	column.add_child(list)
	for game in GAMES:
		_game(list, game)
	var back := Button.new()
	back.name = "Back"
	back.text = "Volver al menú"
	back.custom_minimum_size.y = 36
	back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)
	column.add_child(back)
	_diff_buttons[1].grab_focus()


func _select_difficulty(index: int) -> void:
	if index < 0 or index >= DIFFICULTIES.size():
		return
	_level = int(DIFFICULTIES[index]["level"])
	_diff_note.text = DIFFICULTIES[index]["desc"]
	for i in _diff_buttons.size():
		_style_button(_diff_buttons[i], ACCENT if i == index else BUTTON_STYLE)


## Un juego contra bots: guarda la dificultad, marca el modo solitario y abre la mesa.
func _start(game: Dictionary) -> void:
	TableBots.difficulty = _level
	TableBots.solo = true
	get_tree().change_scene_to_file(game["scene"])


func _game(parent: VBoxContainer, game: Dictionary) -> void:
	var button := Button.new()
	button.name = game["id"]
	button.text = game["title"] + "   →"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_start.bind(game))
	_style_button(button, BUTTON_STYLE)
	button.tooltip_text = game["note"]
	var edition := get_node_or_null("/root/Edition")
	if edition != null and not edition.allows(game["scene"]):
		# Demo: la mesa se ve, pero se abre en el juego completo.
		button.disabled = true
		button.tooltip_text = "Incluida en el juego completo"
		button.add_theme_stylebox_override("disabled", _style(Color("8f8aa8")))
		button.add_theme_color_override("font_disabled_color", Color("3b3760"))
	parent.add_child(button)


func _group(parent: VBoxContainer, title: String, description: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	box.add_child(_label(title, 14, ACCENT))
	var detail := _label(description, 13, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)


func _style_button(button: Button, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_stylebox_override("normal", _style(color))
	button.add_theme_stylebox_override("hover", _style(Color("ffd96e")))
	button.add_theme_stylebox_override("pressed", _style(ACCENT, true))
	button.add_theme_stylebox_override("focus", _focus_style())


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


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
