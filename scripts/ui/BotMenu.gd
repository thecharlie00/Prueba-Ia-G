extends Control
## Pantalla de bienvenida de Tablerama: portada ilustrada procedural estilo cartoon-tabletop,
## escaparate de emblemas de juego, acceso directo al selector de modos y al tutorial jugable,
## y barra rápida superior con sonido, pantalla completa e idioma.

var _sound_btn: Button
var _fullscreen_btn: Button


func _ready() -> void:
	MenuStyle.add_backdrop(self, Palette.SUN)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 32)
	root_margin.add_theme_constant_override("margin_right", 32)
	root_margin.add_theme_constant_override("margin_top", 24)
	root_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(root_margin)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(page)

	# 1. Barra superior de edición y ajustes rápidos
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	page.add_child(top_bar)

	var edition := get_node_or_null("/root/Edition")
	var is_demo: bool = edition != null and edition.get("demo") == true
	var badge := MenuStyle.make_pill(
		"EDICIÓN DEMO" if is_demo else "TABLERO FÍSICO 3D",
		Palette.CORAL if is_demo else Palette.SUN,
		Palette.INK,
		12,
		12,
		4
	)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(badge)

	var catalog_pill := MenuStyle.make_pill(
		"Local · Bots · Online",
		MenuStyle.CARD_SURFACE,
		Palette.PAPER,
		12,
		12,
		4
	)
	catalog_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(catalog_pill)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	_sound_btn = Button.new()
	_sound_btn.name = "QuickSound"
	_sound_btn.custom_minimum_size = Vector2(132, 38)
	_sound_btn.pressed.connect(_toggle_sound)
	MenuStyle.style_secondary(_sound_btn, 12, 5)
	top_bar.add_child(_sound_btn)
	_refresh_sound_button()

	_fullscreen_btn = Button.new()
	_fullscreen_btn.name = "QuickFullscreen"
	_fullscreen_btn.custom_minimum_size = Vector2(168, 38)
	_fullscreen_btn.pressed.connect(_toggle_fullscreen)
	MenuStyle.style_secondary(_fullscreen_btn, 12, 5)
	top_bar.add_child(_fullscreen_btn)
	_refresh_fullscreen_button()

	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_method("make_selector"):
		var lang_selector: OptionButton = locale.make_selector()
		lang_selector.custom_minimum_size = Vector2(124, 38)
		MenuStyle.style_secondary(lang_selector, 12, 5)
		top_bar.add_child(lang_selector)
		if locale.has_signal("language_changed"):
			locale.language_changed.connect(func(_c: String) -> void:
				_refresh_sound_button()
				_refresh_fullscreen_button()
			)

	# 2. Tarjeta central de portada
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)

	var hero := MenuStyle.make_card_panel(
		"HeroCard", Palette.PANEL, Palette.INK, 44, 30, 24, 6, 8
	)
	var hero_style := hero.get_theme_stylebox("panel") as StyleBoxFlat
	if hero_style != null:
		hero_style.border_color = Palette.INK
	hero.custom_minimum_size = Vector2(640, 0)
	center.add_child(hero)

	var hero_col := VBoxContainer.new()
	hero_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_col.add_theme_constant_override("separation", 14)
	hero.add_child(hero_col)

	# Escaparate de emblemas de las familias de juegos
	var emblems_row := HBoxContainer.new()
	emblems_row.alignment = BoxContainer.ALIGNMENT_CENTER
	emblems_row.add_theme_constant_override("separation", 12)
	for entry in [
		["island", 32.0],
		["chess", 34.0],
		["sandbox", 44.0],
		["brisca", 34.0],
		["parchis", 32.0],
	]:
		emblems_row.add_child(
			MenuStyle.make_emblem_badge(str(entry[0]), float(entry[1]), MenuStyle.CARD_WELL)
		)
	hero_col.add_child(emblems_row)

	var eyebrow := MenuStyle.make_eyebrow(
		"UN ESPACIO PARA JUGAR", Palette.SUN, HORIZONTAL_ALIGNMENT_CENTER
	)
	hero_col.add_child(eyebrow)

	var title := MenuStyle.make_title("Tablerama", 64, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	hero_col.add_child(title)

	var tagline := MenuStyle.make_muted(
		"Tu mesa de juegos en 3D con piezas físicas, reglas clásicas, bots y salas online.",
		16,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	tagline.custom_minimum_size.x = 520
	hero_col.add_child(tagline)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(MenuStyle.make_pill("Física táctil", Palette.SUN, Palette.INK, 12, 11, 3))
	chips.add_child(MenuStyle.make_pill("Rivales bot", Palette.MINT, Palette.INK, 12, 11, 3))
	chips.add_child(MenuStyle.make_pill("Salas con código", Color("7cc6fe"), Palette.INK, 12, 11, 3))
	hero_col.add_child(chips)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	hero_col.add_child(spacer)

	var primary_row := HBoxContainer.new()
	primary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_col.add_child(primary_row)

	var play_btn := Button.new()
	play_btn.name = "Jugar"
	play_btn.text = "Jugar"
	play_btn.custom_minimum_size = Vector2(320, 62)
	play_btn.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	play_btn.add_theme_font_size_override("font_size", 26)
	MenuStyle.style_primary(play_btn, 16, 7)
	play_btn.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
	)
	primary_row.add_child(play_btn)

	var secondary_row := HBoxContainer.new()
	secondary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary_row.add_theme_constant_override("separation", 12)
	hero_col.add_child(secondary_row)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "QuickTutorial"
	tutorial_btn.text = "Tutorial jugable"
	tutorial_btn.custom_minimum_size = Vector2(182, 46)
	MenuStyle.style_secondary(tutorial_btn, 13, 6)
	tutorial_btn.pressed.connect(_open_tutorial)
	secondary_row.add_child(tutorial_btn)

	var quit_btn := Button.new()
	quit_btn.name = "Salir"
	quit_btn.text = "Salir"
	quit_btn.custom_minimum_size = Vector2(126, 46)
	MenuStyle.style_secondary(quit_btn, 13, 6)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	secondary_row.add_child(quit_btn)

	# 3. Pie discreto de compatibilidad de controles
	var footer := MenuStyle.make_muted(
		"Ratón · Teclado · Mando y Steam Deck   ·   Pulsa F1 dentro de una mesa para ver sus atajos",
		13,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	page.add_child(footer)

	play_btn.grab_focus.call_deferred()


func _open_tutorial() -> void:
	Tutorial.requested = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _toggle_sound() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.set_enabled(sfx.get("enabled") != true)
	_refresh_sound_button()


func _refresh_sound_button() -> void:
	if _sound_btn == null:
		return
	var sfx := get_node_or_null("/root/Sfx")
	var on: bool = sfx == null or sfx.get("enabled") == true
	_sound_btn.text = tr("Sonido: SÍ") if on else tr("Sonido: NO")


func _toggle_fullscreen() -> void:
	var style := get_node_or_null("/root/ToonStyle")
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if style != null and style.has_method("set_fullscreen"):
		style.set_fullscreen(not is_full)
	_refresh_fullscreen_button()


func _refresh_fullscreen_button() -> void:
	if _fullscreen_btn == null:
		return
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_btn.text = tr("Ventana") if is_full else tr("Pantalla completa")
