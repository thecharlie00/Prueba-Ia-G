extends Control

const BUTTON_STYLE := Color("203d32")
const ACCENT := Color("9ad3ad")
const MUTED := Color("aec2b2")


func _ready() -> void:
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1713")
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
	_group(list, "DOMINÓ", "Doble seis · reglas para dos jugadores o mesa libre.")
	_game(list, "GuidedDomino", "Dominó físico con reglas", "res://scenes/GuidedDomino.tscn")
	_game(list, "FreeDomino", "Dominó físico libre", "res://scenes/PhysicalDomino.tscn")
	_group(list, "ISLA DE RECURSOS", "Tres o cuatro jugadores · estrategia inspirada en Catán.")
	_game(list, "Island", "Isla de recursos · 3 jugadores", "res://scenes/Island.tscn")
	_game(list, "IslandFour", "Isla de recursos · 4 jugadores", "res://scenes/IslandFour.tscn")
	_group(list, "CARTAS", "Barajas inglesa y española · mesa física libre, sin privacidad.")
	_game(list, "Cards", "Abrir mesa de cartas", "res://scenes/CardTable.tscn")
	var footer := _label("Prototipo local · Sin juego en red ni manos privadas", 12, MUTED)
	column.add_child(footer)
	var quit_button := Button.new()
	quit_button.name = "Quit"
	quit_button.text = "Salir del juego"
	quit_button.custom_minimum_size.y = 36
	quit_button.pressed.connect(get_tree().quit)
	column.add_child(quit_button)
	var first := list.get_node("Sandbox") as Button
	first.grab_focus()


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
	button.add_theme_color_override("font_color", Color("eff7ec"))
	button.add_theme_stylebox_override("normal", _style(BUTTON_STYLE))
	button.add_theme_stylebox_override("hover", _style(Color("2f5744")))
	button.add_theme_stylebox_override("pressed", _style(Color("406b51")))
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


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
