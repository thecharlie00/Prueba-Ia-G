extends Control

## Selección de modo: «Jugar en local» (lista de juegos existentes) o
## «Jugar con bots» (dificultad + mesas). Se llega desde el menú principal
## (Jugar) y vuelve allí con «Volver».

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
	column.add_theme_constant_override("separation", 20)
	add_child(column)
	# Colocación centrada (los contenedores no admiten asignar anchors por propiedad;
	# se usa el método, válido para cualquier Control).
	column.set_anchor(SIDE_LEFT, 0.5)
	column.set_anchor(SIDE_RIGHT, 0.5)
	column.set_anchor(SIDE_TOP, 0.5)
	column.set_anchor(SIDE_BOTTOM, 0.5)
	column.set_offset(SIDE_LEFT, -160.0)
	column.set_offset(SIDE_RIGHT, 160.0)
	column.set_offset(SIDE_TOP, -160.0)
	column.set_offset(SIDE_BOTTOM, 160.0)
	var title := Label.new()
	title.name = "Title"
	title.text = "Tablerama"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("f3ead9"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Elige cómo jugar"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("c9c5ef"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var local := Button.new()
	local.name = "Local"
	local.text = "Jugar en local"
	local.custom_minimum_size = Vector2(300, 62)
	local.add_theme_font_size_override("font_size", 18)
	local.alignment = HORIZONTAL_ALIGNMENT_CENTER
	local.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)
	column.add_child(local)
	var bots := Button.new()
	bots.name = "Bots"
	bots.text = "Jugar con bots"
	bots.custom_minimum_size = Vector2(300, 62)
	bots.add_theme_font_size_override("font_size", 18)
	bots.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bots.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/BotSelect.tscn")
	)
	column.add_child(bots)
	var back := Button.new()
	back.name = "Back"
	back.text = "Volver"
	back.custom_minimum_size = Vector2(300, 48)
	back.add_theme_font_size_override("font_size", 16)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/BotMenu.tscn")
	)
	column.add_child(back)
	_style_button(local, BUTTON_STYLE)
	_style_button(bots, ACCENT)
	_style_button(back, BUTTON_STYLE)
	local.grab_focus()


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
