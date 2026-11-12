extends Control
	## Selector de modo de juego: presenta de un vistazo las cuatro experiencias principales
	## (Mesa local, Solitario contra bots, Salas online y Estudio de creación) en tarjetas
	## ilustradas con emblemas, resumen de características y navegación directa con ratón,
	## teclado o mando.


func _ready() -> void:
	MenuStyle.add_backdrop(self, Palette.MINT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	scroll.add_child(margin)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 20)
	margin.add_child(page)

	# 1. Cabecera con botón Volver a la izquierda y título centrado
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	page.add_child(header)

	var back_holder := VBoxContainer.new()
	back_holder.custom_minimum_size.x = 148
	back_holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	header.add_child(back_holder)

	var back_btn := Button.new()
	back_btn.name = "Back"
	back_btn.text = "← Volver"
	back_btn.custom_minimum_size = Vector2(140, 44)
	MenuStyle.style_secondary(back_btn, 12, 6)
	back_btn.pressed.connect(_go_back)
	back_holder.add_child(back_btn)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 4)
	header.add_child(title_box)

	title_box.add_child(
		MenuStyle.make_eyebrow(
			"TABLERAMA  ·  SELECCIÓN DE MODO", Palette.SUN, HORIZONTAL_ALIGNMENT_CENTER
		)
	)

	var title := MenuStyle.make_title("Elige cómo jugar", 40, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title_box.add_child(title)

	var subtitle := MenuStyle.make_muted(
		"Comparte mesa en este equipo, juega contra bots, conéctate online o crea tus propios juegos en el editor.",
		15,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.name = "Subtitle"
	title_box.add_child(subtitle)

	var right_spacer := Control.new()
	right_spacer.custom_minimum_size.x = 148
	header.add_child(right_spacer)

	# 2. Cuatro tarjetas panorámicas de modo
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 22)
	center.add_child(cards_row)

	var local_btn := _add_mode_card(
		cards_row,
		"Local",
		"Jugar en local",
		"Mesa en este equipo",
		"1–4 jugadores",
		Palette.MINT,
		["sandbox", "chess"],
		"18 mesas listas para compartir pantalla o experimentar libremente con dados, cartas y fichas físicas.",
		[
			"Reglas guiadas o física manual",
			"Incluye el tutorial paso a paso",
			"Guardado local y rebobinado",
		],
		"res://scenes/Menu.tscn"
	)

	var bots_btn := _add_mode_card(
		cards_row,
		"Bots",
		"Jugar con bots",
		"Solitario contra IA",
		"1 jugador · 3 niveles",
		Palette.SUN,
		["parchis", "brisca"],
		"Entra directo a una partida individual contra rivales automáticos y elige cuánto calculan.",
		[
			"Dificultad Fácil, Normal o Difícil",
			"9 mesas preparadas con bots",
			"Isla, Parchís, Brisca, Damas y más",
		],
		"res://scenes/BotSelect.tscn"
	)

	var online_btn := _add_mode_card(
		cards_row,
		"Online",
		"Jugar online",
		"Salas multijugador",
		"2–4 en red",
		Color("7cc6fe"),
		["island", "ludo"],
		"Crea una sala pública o privada con contraseña, comparte el código o únete desde el buscador.",
		[
			"Buscador de salas públicas en vivo",
			"Clave opcional con hash seguro",
			"Butacas con bots, chat y «Listo»",
		],
		"res://scenes/Lobby.tscn"
	)

	var create_btn := _add_mode_card(
		cards_row,
		"Create",
		"Crear juegos",
		"Estudio de creación",
		"Editor de tableros",
		Color("a855f7"),
		["sandbox", "cards"],
		"Diseña tableros, reglas visuales, barajas de cartas y dados personalizados para publicar tus propios juegos de mesa.",
		[
			"Importa imágenes y asigna texturas a entidades",
			"Motor de reglas visuales sin código",
			"Exporta y publica mods en el Workshop",
		],
		"res://scenes/game_creator/GameCreatorEditor.tscn"
	)

	# Vecinos de foco explícitos para mando y cursores
	local_btn.focus_neighbor_right = local_btn.get_path_to(bots_btn)
	bots_btn.focus_neighbor_left = bots_btn.get_path_to(local_btn)
	bots_btn.focus_neighbor_right = bots_btn.get_path_to(online_btn)
	online_btn.focus_neighbor_left = online_btn.get_path_to(bots_btn)
	online_btn.focus_neighbor_right = online_btn.get_path_to(create_btn)
	create_btn.focus_neighbor_left = create_btn.get_path_to(online_btn)

	local_btn.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/BotMenu.tscn")


func _add_mode_card(
	parent: Control,
	button_name: String,
	cta_text: String,
	heading_text: String,
	badge_text: String,
	accent: Color,
	emblems: Array,
	description: String,
	bullets: Array,
	scene_path: String
) -> Button:
	var card := MenuStyle.make_card_panel(
		button_name + "Card", Palette.PANEL, Palette.INK, 22, 20, 20, 6
	)
	card.custom_minimum_size = Vector2(356, 396)
	parent.add_child(card)

	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	# Fila superior: emblemas dobles + insignia de modo
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	for key in emblems:
		top.add_child(MenuStyle.make_emblem_badge(str(key), 30.0, MenuStyle.CARD_WELL))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	var fg := Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
	var pill := MenuStyle.make_pill(badge_text, accent, fg, 12, 11, 4)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pill)

	# Título y resumen de la experiencia
	var card_title := MenuStyle.make_title(heading_text, 26, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(card_title)

	var desc := MenuStyle.make_muted(description, 14)
	col.add_child(desc)

	# Recuadro interior de puntos clave
	var well := MenuStyle.make_card_panel(
		"", MenuStyle.CARD_WELL, Palette.INK, 14, 10, 14, 0
	)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(well)

	var bullet_col := VBoxContainer.new()
	bullet_col.alignment = BoxContainer.ALIGNMENT_CENTER
	bullet_col.add_theme_constant_override("separation", 5)
	well.add_child(bullet_col)

	for item in bullets:
		var item_lbl := Label.new()
		item_lbl.text = "✦  " + tr(str(item))
		item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_lbl.add_theme_font_size_override("font_size", 13)
		item_lbl.add_theme_color_override("font_color", Palette.PAPER)
		bullet_col.add_child(item_lbl)

	# Botón principal de acción (conserva el nombre exacto de nodo esperado por los tests)
	var btn := Button.new()
	btn.name = button_name
	btn.text = cta_text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	MenuStyle.style_primary(btn, 14, 6)
	btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))
	col.add_child(btn)
	return btn
