extends Control
## Portada de Tablerama: el diorama 3D de la sala de juegos a la derecha y, a la izquierda,
## el título y tres botones grandes (jugar, tutorial y salir). Arriba, la barra rápida con
## sonido, pantalla completa e idioma.

var _sound_btn: Button
var _fullscreen_btn: Button
var _report_btn: Button


func _ready() -> void:
	var backdrop := MenuStyle.add_backdrop(self, Palette.SUN) as MenuBackdrop
	backdrop.layout = MenuBackdrop.SIDE

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 56)
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
		"Local · Bots" if is_demo else "Local · Bots · Online",
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

	# 2. Columna de portada a la izquierda (sin tarjeta: el texto va sobre el velo del diorama)
	var hero_row := HBoxContainer.new()
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hero_row)

	var hero_col := VBoxContainer.new()
	hero_col.name = "HeroColumn"
	hero_col.custom_minimum_size = Vector2(520, 0)
	hero_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_col.add_theme_constant_override("separation", 12)
	hero_row.add_child(hero_col)

	var eyebrow := MenuStyle.make_eyebrow("UN ESPACIO PARA JUGAR", Palette.SUN)
	eyebrow.add_theme_font_size_override("font_size", 14)
	hero_col.add_child(eyebrow)

	var title := MenuStyle.make_title("Tablerama", 92)
	title.name = "Title"
	hero_col.add_child(title)

	var tagline := MenuStyle.make_muted(
		"Tu mesa de juegos en 3D con piezas físicas, reglas clásicas, bots y salas online."
		if not is_demo
		else "Tu mesa de juegos en 3D con piezas físicas, reglas clásicas y bots. El online llega con el juego completo.",
		17
	)
	tagline.add_theme_color_override("font_color", Palette.LAVENDER)
	tagline.custom_minimum_size.x = 480
	hero_col.add_child(tagline)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.add_child(MenuStyle.make_pill("Física táctil", Palette.SUN, Palette.INK, 12, 11, 3))
	chips.add_child(MenuStyle.make_pill("Rivales bot", Palette.MINT, Palette.INK, 12, 11, 3))
	if not is_demo:
		chips.add_child(MenuStyle.make_pill("Salas con código", Color("7cc6fe"), Palette.INK, 12, 11, 3))
	hero_col.add_child(chips)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 18
	hero_col.add_child(spacer)

	var play_btn := Button.new()
	play_btn.name = "Jugar"
	play_btn.text = "Jugar"
	play_btn.custom_minimum_size = Vector2(340, 68)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play_btn.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	play_btn.add_theme_font_size_override("font_size", 28)
	MenuStyle.style_primary(play_btn, 18, 7)
	play_btn.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/ModeSelect.tscn")
	)
	hero_col.add_child(play_btn)

	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 12)
	hero_col.add_child(secondary_row)

	var tutorial_btn := Button.new()
	tutorial_btn.name = "QuickTutorial"
	tutorial_btn.text = "Tutorial jugable"
	tutorial_btn.custom_minimum_size = Vector2(200, 48)
	MenuStyle.style_secondary(tutorial_btn, 14, 6)
	tutorial_btn.pressed.connect(_open_tutorial)
	secondary_row.add_child(tutorial_btn)

	var quit_btn := Button.new()
	quit_btn.name = "Salir"
	quit_btn.text = "Salir"
	quit_btn.custom_minimum_size = Vector2(128, 48)
	MenuStyle.style_subtle(quit_btn, 14)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	secondary_row.add_child(quit_btn)

	# 3. Pie discreto: controles a la izquierda; versión, créditos y fallos a la derecha
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 8)
	page.add_child(footer_row)
	var footer := MenuStyle.make_muted(
		"Ratón · Teclado · Mando y Steam Deck   ·   Pulsa F1 dentro de una mesa para ver sus atajos",
		13
	)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_row.add_child(footer)

	var version_label := MenuStyle.make_muted("v" + AppInfo.version(), 13)
	version_label.name = "Version"
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	version_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer_row.add_child(version_label)

	var credits_btn := Button.new()
	credits_btn.name = "Credits"
	credits_btn.text = "Créditos"
	credits_btn.custom_minimum_size = Vector2(0, 34)
	credits_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_subtle(credits_btn, 10)
	credits_btn.pressed.connect(
		func() -> void: get_tree().change_scene_to_file("res://scenes/Credits.tscn")
	)
	footer_row.add_child(credits_btn)

	_report_btn = Button.new()
	_report_btn.name = "ReportBug"
	_report_btn.text = "Informar de un fallo"
	_report_btn.tooltip_text = "Copia la versión y la ruta del registro, y abre su carpeta."
	_report_btn.custom_minimum_size = Vector2(0, 34)
	_report_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuStyle.style_subtle(_report_btn, 10)
	_report_btn.pressed.connect(_report_bug)
	footer_row.add_child(_report_btn)

	play_btn.grab_focus.call_deferred()


## Copia los datos del informe y avisa en el propio botón durante unos segundos.
func _report_bug() -> void:
	AppInfo.copy_report()
	_report_btn.text = tr("Copiado: pégalo en tu mensaje")
	get_tree().create_timer(4.0).timeout.connect(
		func() -> void:
			if is_instance_valid(_report_btn):
				_report_btn.text = tr("Informar de un fallo")
	)


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
