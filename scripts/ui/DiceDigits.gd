class_name DiceDigits
extends Node
## Imágenes de los números del dado (1–6), dibujadas una sola vez por mesa con la fuente
## de títulos, contorno y sombra de tinta. Cada número es un SubViewport pequeño que se
## pinta una vez y luego se reutiliza como textura (DicePop).

const SIZE := 160
const MAX_VALUE := 6

var _viewports: Array[SubViewport] = []


## La mesa comparte un único juego de números entre todos sus dados.
static func for_scene(scene: Node) -> DiceDigits:
	var digits := scene.get_node_or_null("DiceDigits") as DiceDigits
	if digits == null:
		digits = DiceDigits.new()
		digits.name = "DiceDigits"
		scene.add_child(digits)
	return digits


func _ready() -> void:
	var style := get_node_or_null("/root/ToonStyle")
	for value in range(1, MAX_VALUE + 1):
		var viewport := SubViewport.new()
		viewport.name = "Digit%d" % value
		viewport.size = Vector2i(SIZE, SIZE)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var label := Label.new()
		label.text = str(value)
		label.size = Vector2(SIZE, SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 118)
		label.add_theme_color_override("font_color", Palette.SUN)
		label.add_theme_color_override("font_outline_color", Palette.INK)
		label.add_theme_constant_override("outline_size", 26)
		label.add_theme_color_override("font_shadow_color", Palette.INK)
		label.add_theme_constant_override("shadow_offset_x", 5)
		label.add_theme_constant_override("shadow_offset_y", 7)
		if style != null:
			label.add_theme_font_override("font", style.DISPLAY_FONT)
		viewport.add_child(label)
		_viewports.append(viewport)


func texture_for(value: int) -> Texture2D:
	var index := clampi(value, 1, MAX_VALUE) - 1
	return _viewports[index].get_texture() if index < _viewports.size() else null
