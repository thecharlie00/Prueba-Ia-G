extends Control

# Paleta cartoon común (scripts/style/ToonStyle.gd, docs/ARTE.md).
const BUTTON_STYLE := Color("fff8ec")
const ACCENT := Color("ffc83d")
const MUTED := Color("c9c5ef")
const INK := Color("1d1a3a")
var controls_feedback: Label


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
	var eyebrow := _label("DICE ON!!  /  MESA DE JUEGO LOCAL", 13, ACCENT)
	column.add_child(eyebrow)
	var title := _label("Elige tu mesa", 36, Color("f3ead9"))
	column.add_child(title)
	var subtitle := _label(
		"Juegos para compartir en el mismo equipo. Cada opción inicia una mesa nueva.", 15, MUTED
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.name = "GameList"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	_group(list, "ISLA DE RECURSOS", "Tres o cuatro jugadores · estrategia inspirada en Catán.")
	_game(list, "Island", "Isla de recursos · 3 jugadores", "res://scenes/Island.tscn")
	_game(list, "IslandFour", "Isla de recursos · 4 jugadores", "res://scenes/IslandFour.tscn")
	_group(list, "MESA LIBRE", "Experimenta con dados, cartas y fichas con físicas.")
	_game(list, "Sandbox", "Abrir mesa libre", "res://scenes/Main.tscn")
	_group(list, "AJEDREZ", "Dos jugadores · vista simple, física con reglas o física libre.")
	_game(list, "Chess", "Ajedrez con reglas · vista simple", "res://scenes/Chess.tscn")
	_game(list, "GuidedChess", "Ajedrez físico con reglas", "res://scenes/GuidedPhysicalChess.tscn")
	_game(list, "PhysicalChess", "Ajedrez físico libre", "res://scenes/PhysicalChess.tscn")
	_group(list, "DAMAS", "Damas inglesas adaptadas · elige física con reglas o modo manual.")
	_game(
		list,
		"GuidedCheckers",
		"Damas físicas con reglas",
		"res://scenes/GuidedPhysicalCheckers.tscn"
	)
	_game(list, "FreeCheckers", "Damas físicas libres", "res://scenes/PhysicalCheckers.tscn")
	_game(list, "SimpleCheckers", "Damas con reglas · vista simple", "res://scenes/Checkers.tscn")
	_group(list, "LUDO", "Carrera con dado y fichas físicas · variante local.")
	_game(list, "Ludo", "Ludo · 2 jugadores", "res://scenes/Ludo.tscn")
	_game(list, "Ludo3", "Ludo · 3 jugadores", "res://scenes/Ludo3.tscn")
	_game(list, "Ludo4", "Ludo · 4 jugadores", "res://scenes/Ludo4.tscn")
	_group(list, "DOMINÓ", "Doble seis · reglas para dos jugadores o mesa libre.")
	_game(list, "GuidedDomino", "Dominó físico con reglas", "res://scenes/GuidedDomino.tscn")
	_game(list, "FreeDomino", "Dominó físico libre", "res://scenes/PhysicalDomino.tscn")
	_group(list, "CARTAS", "Barajas inglesa y española · mesa física libre, sin privacidad.")
	_game(list, "Cards", "Abrir mesa de cartas", "res://scenes/CardTable.tscn")
	var option := CheckButton.new()
	option.name = "ClickToGrab"
	option.text = "Clic para agarrar y clic para soltar (opcional)"
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null:
		option.button_pressed = bool(navigation.get("click_to_grab"))
		option.toggled.connect(navigation.set_click_to_grab)
		navigation.controls_changed.connect(option.set_pressed_no_signal)
	column.add_child(option)
	var motion := CheckButton.new()
	motion.name = "ReduceMotion"
	motion.text = "Reducir animaciones (sin rebotes al agarrar y soltar)"
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		motion.button_pressed = bool(style.get("reduce_motion"))
		motion.toggled.connect(style.set_reduce_motion)
	column.add_child(motion)
	controls_feedback = _label("Los ajustes de agarre y animación se guardan en este equipo.", 12, MUTED)
	column.add_child(controls_feedback)
	if navigation != null:
		navigation.controls_changed.connect(_on_controls_changed)
	var footer := _label("Prototipo local · Sin juego en red", 12, MUTED)
	column.add_child(footer)
	var quit_button := Button.new()
	quit_button.name = "Quit"
	quit_button.text = "Salir del juego"
	quit_button.custom_minimum_size.y = 36
	quit_button.pressed.connect(get_tree().quit)
	column.add_child(quit_button)
	var first := list.get_node("Island") as Button
	first.grab_focus()


func _on_controls_changed(_enabled: bool) -> void:
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null and is_instance_valid(controls_feedback):
		controls_feedback.text = navigation.controls_status.text


func _group(parent: VBoxContainer, title: String, description: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	box.add_child(_label(title, 14, ACCENT))
	var detail := _label(description, 13, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)


func _game(parent: VBoxContainer, id: String, title: String, scene: String) -> void:
	var button := Button.new()
	button.name = id
	button.text = title + "   →"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_stylebox_override("normal", _style(BUTTON_STYLE))
	button.add_theme_stylebox_override("hover", _style(Color("ffd96e")))
	button.add_theme_stylebox_override("pressed", _style(ACCENT, true))
	button.add_theme_stylebox_override("focus", _focus_style())
	button.pressed.connect(_open.bind(scene))
	parent.add_child(button)


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)


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
