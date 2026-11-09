extends Control

## Menú principal sencillo: título del juego, botón «Jugar» (abre la selección de
## dificultad y mesa contra bots) y botón «Salir».

const BUTTON_STYLE := Color("fff8ec")
const ACCENT := Color("ffc83d")
const INK := Color("1d1a3a")


func _ready() -> void:
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("2a2552")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.anchors_left = 0.5
	column.anchors_right = 0.5
	column.anchors_top = 0.5
	column.anchors_bottom = 0.5
	column.offset_left = -160.0
	column.offset_right = 160.0
	column.offset_top = -130.0
	column.offset_bottom = 130.0
	column.add_theme_constant_override("separation", 26)
	add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.text = "Tablerama"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color("f3ead9"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var jugar := Button.new()
	jugar.name = "Jugar"
	jugar.text = "Jugar"
	jugar.custom_minimum_size = Vector2(300, 62)
	jugar.add_theme_font_size_override("font_size", 22)
	jugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jugar.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/BotSelect.tscn")
	)
	column.add_child(jugar)
	var salir := Button.new()
	salir.name = "Salir"
	salir.text = "Salir"
	salir.custom_minimum_size = Vector2(300, 54)
	salir.add_theme_font_size_override("font_size", 18)
	salir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salir.pressed.connect(get_tree().quit)
	column.add_child(salir)
	_style_button(jugar, ACCENT)
	_style_button(salir, BUTTON_STYLE)
	jugar.grab_focus()


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
