class_name MenuStyle
extends RefCounted
## Sistema compartido de componentes y estilos cartoon-tabletop para todos los menús
## (`BotMenu`, `ModeSelect`, `Menu`, `BotSelect`, `Lobby` y `SessionNavigation`).
## Respeta estrictamente la guía visual de `docs/ARTE.md`: bordes gruesos de tinta (`3px`),
## sombras duras desplazadas (`5px`), labio inferior táctil (`6px` / `3px` pulsado),
## tipografía `Lilita One` en titulares y `GameEmblem` + `GameThemes` por familia.

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const DONE_META := &"toon_style_applied"

const CARD_SURFACE := Color("332d61")
const CARD_ELEVATED := Color("3c3570")
const CARD_WELL := Color("221e42")
const LOCKED_FILL := Color("6e6894")


static func add_backdrop(parent: Control, accent := Palette.SUN) -> Control:
	var backdrop := MenuBackdrop.new()
	backdrop.accent_color = accent
	parent.add_child(backdrop)
	return backdrop


static func panel_box(
	bg := Palette.PANEL,
	border := Palette.INK,
	radius := 18,
	shadow := 5,
	pad_x := 20,
	pad_y := 16,
	top_stripe := 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(3)
	if top_stripe > 3:
		box.border_width_top = top_stripe
	box.set_corner_radius_all(radius)
	if shadow > 0:
		box.shadow_color = Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.85)
		box.shadow_size = 1
		box.shadow_offset = Vector2(shadow, shadow)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box


static func make_card_panel(
	node_name := "",
	bg := Palette.PANEL,
	border := Palette.INK,
	pad_x := 20,
	pad_y := 16,
	radius := 18,
	shadow := 5,
	top_stripe := 0
) -> PanelContainer:
	var panel := PanelContainer.new()
	if not node_name.is_empty():
		panel.name = node_name
	panel.set_meta(DONE_META, true)
	panel.add_theme_stylebox_override(
		"panel", panel_box(bg, border, radius, shadow, pad_x, pad_y, top_stripe)
	)
	return panel


static func button_box(
	fill: Color,
	pressed := false,
	radius := 12,
	lip := 6,
	pad_x := 16,
	pad_y := 8,
	border := Palette.INK
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(3)
	var bottom := maxi(3, int(lip * 0.5)) if pressed else lip
	box.border_width_bottom = bottom
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y + (lip - bottom)
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	return box


static func focus_box(accent := Palette.SUN_LIGHT, radius := 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = accent
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	box.expand_margin_left = 4
	box.expand_margin_right = 4
	box.expand_margin_top = 4
	box.expand_margin_bottom = 4
	box.anti_aliasing = true
	return box


static func style_button(
	button: BaseButton,
	fill := Palette.SUN,
	hover_fill := Palette.SUN_LIGHT,
	text_color := Palette.INK,
	radius := 12,
	lip := 6,
	pad_x := 16,
	pad_y := 8
) -> void:
	button.add_theme_stylebox_override("normal", button_box(fill, false, radius, lip, pad_x, pad_y))
	button.add_theme_stylebox_override("hover", button_box(hover_fill, false, radius, lip, pad_x, pad_y))
	button.add_theme_stylebox_override("pressed", button_box(fill, true, radius, lip, pad_x, pad_y))
	button.add_theme_stylebox_override("hover_pressed", button_box(hover_fill, true, radius, lip, pad_x, pad_y))
	button.add_theme_stylebox_override("disabled", button_box(LOCKED_FILL, true, radius, lip, pad_x, pad_y))
	button.add_theme_stylebox_override("focus", focus_box(Palette.SUN_LIGHT, radius + 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_color_override("font_disabled_color", Palette.PAPER.darkened(0.18))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func style_primary(button: BaseButton, radius := 14, lip := 6) -> void:
	style_button(button, Palette.SUN, Palette.SUN_LIGHT, Palette.INK, radius, lip, 18, 9)


static func style_secondary(button: BaseButton, radius := 12, lip := 6) -> void:
	style_button(button, Palette.PAPER, Palette.SUN_LIGHT, Palette.INK, radius, lip, 16, 8)


static func style_subtle(button: BaseButton, radius := 12) -> void:
	style_button(
		button,
		CARD_ELEVATED,
		CARD_ELEVATED.lightened(0.14),
		Palette.PAPER,
		radius,
		5,
		14,
		7
	)


static func style_danger(button: BaseButton, radius := 12) -> void:
	style_button(
		button,
		Palette.CORAL,
		Palette.CORAL.lightened(0.16),
		Palette.INK,
		radius,
		6,
		16,
		8
	)


static func style_pill_filter(button: BaseButton, active: bool, accent := Palette.SUN) -> void:
	if active:
		var fg := Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
		style_button(button, accent, accent.lightened(0.14), fg, 999, 5, 16, 6)
	else:
		style_button(button, CARD_SURFACE, CARD_ELEVATED, Palette.PAPER, 999, 4, 16, 6)


static func make_title(
	text: String,
	font_size := 36,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	color := Palette.PAPER
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 6 if font_size < 48 else 9)
	return label


static func make_eyebrow(
	text: String,
	color := Palette.SUN,
	align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


static func make_muted(
	text: String,
	font_size := 14,
	align := HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Palette.MUTED)
	return label


static func make_pill(
	text: String,
	bg := Palette.SUN,
	fg := Palette.INK,
	font_size := 12,
	pad_x := 10,
	pad_y := 3
) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.set_meta(DONE_META, true)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(999)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	box.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", box)
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", fg)
	pill.add_child(lbl)
	return pill


static func theme_info(theme_key: String) -> Dictionary:
	var key := theme_key if GameThemes.THEMES.has(theme_key) else "sandbox"
	var info: Dictionary = GameThemes.THEMES[key].duplicate()
	info["key"] = key
	return info


static func make_emblem_badge(
	theme_key: String,
	emblem_size := 34.0,
	bg := CARD_WELL
) -> PanelContainer:
	var info := theme_info(theme_key)
	var accent: Color = info["accent"]
	var holder := PanelContainer.new()
	holder.set_meta(DONE_META, true)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = Palette.INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.anti_aliasing = true
	holder.add_theme_stylebox_override("panel", box)
	var emblem := GameEmblem.new()
	emblem.kind = str(info["key"])
	emblem.accent = accent
	emblem.custom_minimum_size = Vector2(emblem_size, emblem_size)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(emblem)
	return holder


## Tarjeta-botón táctil para una mesa de juego: el propio nodo raíz es el `Button`
## con `name = node_name` (100% compatible con tests, teclado y mando), llevando dentro
## emblema vectorial, título auto-traducible, subtítulo opcional y píldora de jugadores/estado.
static func make_game_card_button(
	node_name: String,
	title_text: String,
	subtitle_text := "",
	badge_text := "",
	theme_key := "sandbox",
	primary := false,
	locked := false,
	min_height := 66.0
) -> Button:
	var info := theme_info(theme_key)
	var accent: Color = info["accent"]

	var button := Button.new()
	button.name = node_name
	button.text = ""
	button.clip_contents = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(210.0, min_height)
	button.disabled = locked

	if primary and not locked:
		style_primary(button, 14, 6)
	else:
		style_secondary(button, 14, 6)

	if locked:
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 11)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var badge_bg := CARD_WELL if not locked else Palette.PANEL
	var emblem := make_emblem_badge(theme_key, 28.0 if subtitle_text.is_empty() else 32.0, badge_bg)
	row.add_child(emblem)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override(
		"font_color", Palette.PAPER if locked else Palette.INK
	)
	text_col.add_child(title_lbl)

	if not subtitle_text.is_empty():
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle_text
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override(
			"font_color",
			Palette.MUTED if locked else Palette.INK.lightened(0.22)
		)
		text_col.add_child(sub_lbl)

	if locked:
		var lock_pill := make_pill(
			"Juego completo", Palette.PANEL, Palette.SUN_LIGHT, 11, 8, 2
		)
		lock_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock_pill)
	else:
		if not badge_text.is_empty():
			var pill_fg := Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
			var pill := make_pill(badge_text, accent, pill_fg, 11, 9, 2)
			pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pill)
		var arrow := Label.new()
		arrow.text = "→"
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow.add_theme_font_size_override("font_size", 18)
		arrow.add_theme_color_override("font_color", Palette.INK)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow)

	return button


static func style_text_well(edit: TextEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD_WELL
	normal.border_color = Palette.INK
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.anti_aliasing = true
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("read_only", normal)
	edit.add_theme_stylebox_override("focus", focus_box(Palette.SUN, 13))
	edit.add_theme_color_override("font_color", Palette.PAPER)
	edit.add_theme_color_override("font_readonly_color", Palette.PAPER)
