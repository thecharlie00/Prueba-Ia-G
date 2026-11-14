extends Control
## Créditos y licencias: quién hace Tablerama y con qué piezas de terceros está hecho
## (motor, física, fuentes y, en el juego completo, la red). El texto legal completo de
## Godot y de sus componentes se despliega abajo, sin salir del juego.

const BACK_SCENE := "res://scenes/BotMenu.tscn"

## [título, detalle, licencia]
const CREDITS := [
	["Tablerama", "Diseño, programación, arte y sonido: Carlos y el equipo de Tablerama.", ""],
	["Godot Engine", "© 2014-present Godot Engine contributors. © 2007-2014 Juan Linietsky, Ariel Manzur.", "Licencia MIT"],
	["Jolt Physics", "© 2021 Jorrit Rouwe. Física de las piezas, dados y cartas.", "Licencia MIT"],
	["Lilita One", "© 2011 Juan Montoreano. Fuente de los títulos.", "SIL Open Font License 1.1"],
	["Nunito", "© 2014 The Nunito Project Authors. Fuente de los textos.", "SIL Open Font License 1.1"],
]
const PHOTON := ["Photon Fusion", "© Exit Games GmbH. Red de las salas online.", "Licencia de Photon (propietaria)"]

var _legal: Label


func _ready() -> void:
	var backdrop := MenuStyle.add_backdrop(self, Palette.LAVENDER) as MenuBackdrop
	backdrop.layout = MenuBackdrop.SIDE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)

	var page := VBoxContainer.new()
	page.custom_minimum_size.x = 620
	page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var back := Button.new()
	back.name = "Back"
	back.text = "← Volver"
	back.custom_minimum_size = Vector2(140, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MenuStyle.style_secondary(back, 12, 6)
	back.pressed.connect(_go_back)
	page.add_child(back)

	page.add_child(MenuStyle.make_eyebrow(tr("TABLERAMA  ·  VERSIÓN %s") % AppInfo.version().to_upper(), Palette.SUN))
	var title := MenuStyle.make_title("Créditos y licencias", 44)
	title.name = "Title"
	page.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var entries := CREDITS.duplicate()
	if FusionBridge.available():
		entries.append(PHOTON)
	for entry in entries:
		list.add_child(_credit_card(entry[0], entry[1], entry[2]))

	var extra := MenuStyle.make_muted(
		"Los sonidos se generan por código y las ilustraciones son originales del proyecto. "
		+ "Los textos completos de las licencias de las fuentes están junto a ellas, en assets/fonts.",
		13
	)
	extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(extra)

	var toggle := Button.new()
	toggle.name = "ShowLicenses"
	toggle.text = "Ver licencias completas del motor"
	toggle.custom_minimum_size = Vector2(0, 42)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	MenuStyle.style_subtle(toggle, 12)
	toggle.pressed.connect(_toggle_legal)
	list.add_child(toggle)

	_legal = Label.new()
	_legal.name = "LegalText"
	_legal.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_legal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legal.add_theme_font_size_override("font_size", 11)
	_legal.add_theme_color_override("font_color", Palette.LAVENDER)
	_legal.visible = false
	list.add_child(_legal)

	back.grab_focus.call_deferred()


func _credit_card(heading: String, detail: String, license: String) -> Control:
	var card := MenuStyle.make_card_panel(heading.replace(" ", "") + "Credit", Palette.PANEL, Palette.INK, 18, 12, 14, 4)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var name_label := MenuStyle.make_title(heading, 20)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(name_label)
	if not license.is_empty():
		var pill := MenuStyle.make_pill(license, Palette.SUN, Palette.INK, 11, 9, 2)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pill)
	var text := MenuStyle.make_muted(detail, 13)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	return card


## Texto legal de Godot y de cada componente que incluye (lo da el propio motor).
func legal_text() -> String:
	var parts: Array[String] = [Engine.get_license_text()]
	for info in Engine.get_copyright_info():
		var lines: Array[String] = [str(info.get("name", ""))]
		for piece in info.get("parts", []):
			for holder in piece.get("copyright", []):
				lines.append("  © " + str(holder))
			lines.append("  " + str(piece.get("license", "")))
		parts.append("\n".join(lines))
	return "\n\n".join(parts)


func _toggle_legal() -> void:
	if _legal.text.is_empty():
		_legal.text = legal_text()
	_legal.visible = not _legal.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().change_scene_to_file(BACK_SCENE)
