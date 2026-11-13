class_name GameThemes
extends RefCounted
## Identidad de interfaz de cada juego (docs/ARTE.md): color de acento, nombre y emblema.
## La paleta base es común; el acento distingue de un vistazo en qué juego estás.

const THEMES := {
	"sandbox": {"name": "Mesa libre", "accent": Color("ffc83d")},
	"cards": {"name": "Mesa de cartas", "accent": Color("e2504a")},
	"chess": {"name": "Ajedrez", "accent": Color("8a7fd6")},
	"checkers": {"name": "Damas", "accent": Color("3fcf8e")},
	"domino": {"name": "Dominó", "accent": Color("4d7cfe")},
	"ludo": {"name": "Ludo", "accent": Color("ff9a3d")},
	"island": {"name": "La isla", "accent": Color("2f8f4e")},
	"brisca": {"name": "Brisca", "accent": Color("d99a00")},
	"parchis": {"name": "Parchís", "accent": Color("e2504a")},
}


## Clave del juego a partir de la escena de la vista.
static func key_for(view: Node) -> String:
	var file := view.scene_file_path.get_file().to_lower() if view != null else ""
	if file.begins_with("brisca"):
		return "brisca"
	if file.begins_with("parchis"):
		return "parchis"
	if file.begins_with("cardtable"):
		return "cards"
	if "chess" in file:
		return "chess"
	if "checkers" in file:
		return "checkers"
	if "domino" in file:
		return "domino"
	if file.begins_with("ludo"):
		return "ludo"
	if file.begins_with("island"):
		return "island"
	return "sandbox"


static func theme_for(view: Node) -> Dictionary:
	var key := key_for(view)
	var theme: Dictionary = THEMES[key].duplicate()
	theme["key"] = key
	var accent: Color = theme["accent"]
	# Texto sobre el acento: tinta en acentos claros, papel en los oscuros.
	theme["on_accent"] = Palette.INK if accent.get_luminance() > 0.42 else Palette.PAPER
	return theme


## Caja «de arcilla» del color de acento, con labio inferior (botones de la barra, «Partida»).
static func accent_box(theme: Dictionary, pressed := false, hover := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var accent: Color = theme["accent"]
	box.bg_color = accent.lightened(0.18) if hover else accent
	box.border_color = (box.bg_color as Color).darkened(0.26)
	box.set_border_width_all(0)
	box.border_width_bottom = 3 if pressed else 6
	MenuStyle.pebble(box, 16)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 9 if pressed else 6
	box.content_margin_bottom = 6
	box.anti_aliasing = true
	return box


static func style_button(button: BaseButton, theme: Dictionary) -> void:
	button.add_theme_stylebox_override("normal", accent_box(theme))
	button.add_theme_stylebox_override("hover", accent_box(theme, false, true))
	button.add_theme_stylebox_override("pressed", accent_box(theme, true))
	button.add_theme_stylebox_override("hover_pressed", accent_box(theme, true, true))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, theme["on_accent"])


## Panel de tinta con el borde del acento del juego.
static func panel_box(theme: Dictionary) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.PANEL, 0.94)
	# Una franja del acento arriba en vez de un marco entero.
	box.border_color = theme["accent"]
	box.set_border_width_all(0)
	box.border_width_top = 5
	MenuStyle.pebble(box, 22)
	box.shadow_color = Color(0.05, 0.04, 0.12, 0.34)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	box.anti_aliasing = true
	return box


## Emblema dibujado del juego, para el cartel o el panel.
static func emblem(theme: Dictionary, size := 30.0) -> Control:
	var node := GameEmblem.new()
	node.kind = theme["key"]
	node.accent = theme["accent"]
	node.custom_minimum_size = Vector2(size, size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
