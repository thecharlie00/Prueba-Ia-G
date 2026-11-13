extends Control
## Selector de modo de juego: cuatro filas compactas a la izquierda (mesa local, contra bots,
## salas online y estudio de creación), con la sala de juegos a la vista a la derecha. Cada
## fila lleva su emblema, una línea de resumen y un botón; se navega con ratón, teclado o mando.


func _ready() -> void:
	var backdrop := MenuStyle.add_backdrop(self, Palette.MINT) as MenuBackdrop
	backdrop.layout = MenuBackdrop.SIDE

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	scroll.add_child(margin)

	var page := VBoxContainer.new()
	page.custom_minimum_size.x = 660
	page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)

	# 1. Cabecera con botón Volver a la izquierda y título centrado
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)

	var back_holder := HBoxContainer.new()
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
			"TABLERAMA  ·  SELECCIÓN DE MODO", Palette.SUN, HORIZONTAL_ALIGNMENT_LEFT
		)
	)

	var title := MenuStyle.make_title("Elige cómo jugar", 44, HORIZONTAL_ALIGNMENT_LEFT)
	title.name = "Title"
	title_box.add_child(title)

	var edition := get_node_or_null("/root/Edition")
	var is_demo: bool = edition != null and edition.get("demo") == true
	var subtitle := MenuStyle.make_muted(
		"Comparte mesa en este equipo o juega contra bots. El online y el editor llegan con el juego completo."
		if is_demo
		else "Comparte mesa en este equipo, juega contra bots, conéctate online o crea tus propios juegos en el editor.",
		15,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	subtitle.name = "Subtitle"
	subtitle.custom_minimum_size.x = 620
	title_box.add_child(subtitle)

	# 2. Cuatro filas compactas, una por modo
	var cards_row := VBoxContainer.new()
	cards_row.name = "ModeCards"
	cards_row.add_theme_constant_override("separation", 12)
	page.add_child(cards_row)

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
		"En desarrollo",
		Color("b48cf2"),
		["sandbox", "cards"],
		"Primer paso del editor: monta piezas con tus propias imágenes y pruébalas sobre la mesa.",
		[
			"Importa tus imágenes",
			"Crea piezas y ponles imagen",
			"Pruébalas con física en la mesa",
		],
		"res://scenes/game_creator/GameCreatorEditor.tscn"
	)

	# Vecinos de foco explícitos para mando y cursores
	local_btn.focus_neighbor_bottom = local_btn.get_path_to(bots_btn)
	bots_btn.focus_neighbor_top = bots_btn.get_path_to(local_btn)
	bots_btn.focus_neighbor_bottom = bots_btn.get_path_to(online_btn)
	online_btn.focus_neighbor_top = online_btn.get_path_to(bots_btn)
	online_btn.focus_neighbor_bottom = online_btn.get_path_to(create_btn)
	create_btn.focus_neighbor_top = create_btn.get_path_to(online_btn)

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
	# Fila: emblemas · título con insignia y una línea de resumen · botón.
	var card := MenuStyle.make_card_panel(
		button_name + "Card", Palette.PANEL, Palette.INK, 20, 18, 14, 4
	)
	card.tooltip_text = "\n".join(bullets.map(func(item: Variant) -> String: return "✦ " + tr(str(item))))
	parent.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var emblem_row := HBoxContainer.new()
	emblem_row.add_theme_constant_override("separation", 6)
	emblem_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emblem_row)
	for key in emblems:
		emblem_row.add_child(MenuStyle.make_emblem_badge(str(key), 28.0, MenuStyle.CARD_WELL))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	col.add_child(heading)
	var card_title := MenuStyle.make_title(heading_text, 22, HORIZONTAL_ALIGNMENT_LEFT)
	heading.add_child(card_title)
	# En la demo, los modos que no incluye se ven (para que se sepa lo que trae el juego
	# completo) pero no se abren.
	var edition := get_node_or_null("/root/Edition")
	var locked: bool = edition != null and not edition.allows(scene_path)
	if locked:
		badge_text = "En el juego completo"
		accent = Palette.LAVENDER
		card.modulate = Color(1, 1, 1, 0.78)
	var fg := Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
	var pill := MenuStyle.make_pill(badge_text, accent, fg, 11, 9, 2)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(pill)

	var desc := MenuStyle.make_muted(description, 13)
	desc.custom_minimum_size.x = 300
	col.add_child(desc)

	# Botón de acción (conserva el nombre exacto de nodo esperado por los tests)
	var btn := Button.new()
	btn.name = button_name
	btn.text = cta_text
	btn.custom_minimum_size = Vector2(156, 46)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	btn.add_theme_font_size_override("font_size", 17)
	MenuStyle.style_primary(btn, 14, 6)
	btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene_path))
	if locked:
		btn.disabled = true
		btn.text = "Bloqueado"
		btn.tooltip_text = "Disponible en el juego completo."
		btn.focus_mode = Control.FOCUS_NONE
	row.add_child(btn)
	return btn
