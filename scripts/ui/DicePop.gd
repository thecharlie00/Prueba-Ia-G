class_name DicePop
extends Label
## Número del resultado del dado, en el centro de la pantalla.
##
## Sale en el centro de la pantalla, grande, con rebote y desvanecido. Las versiones 3D (Label3D
## y luego Sprite3D con imágenes ya hechas) congelaban ~0,4 s cada tirada en el equipo de
## Carlos (medido con F3/F4); la interfaz 2D es el mismo camino que usa el HUD, que no da
## problemas.

const RISE := 0.35
const BASE_FONT := 96
## Tamaño en pantalla (respecto a la letra base) y subida del salto, en píxeles.
const SCREEN_SCALE := 1.6
const RISE_PIXELS := 40.0

var anchor: Node3D
## Animados por la tirada: subida (0 a RISE) y escala del rebote.
var rise := 0.0
var pop_scale := 1.0
var _tween: Tween


## Capa compartida de la escena para los números de los dados.
static func layer_for(scene: Node) -> CanvasLayer:
	var layer := scene.get_node_or_null("DicePops") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "DicePops"
		layer.layer = 4
		scene.add_child(layer)
	return layer


func _init() -> void:
	name = "ResultPop"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(160, 130)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	add_theme_font_size_override("font_size", BASE_FONT)
	add_theme_color_override("font_color", Palette.SUN)
	add_theme_color_override("font_outline_color", Palette.INK)
	add_theme_constant_override("outline_size", 22)
	add_theme_color_override("font_shadow_color", Palette.INK)
	add_theme_constant_override("shadow_offset_x", 4)
	add_theme_constant_override("shadow_offset_y", 6)


func _ready() -> void:
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		add_theme_font_override("font", style.DISPLAY_FONT)


## Valor mostrado (para los tests).
var text_value := 0


func show_value(value: int, follow: Node3D, calm: bool) -> void:
	anchor = follow
	text_value = value
	text = str(value)
	rise = 0.0
	modulate.a = 1.0
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if calm:
		pop_scale = 1.0
		_tween.tween_interval(1.0)
	else:
		pop_scale = 0.2
		_tween.tween_property(self, "pop_scale", 1.25, 0.16).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "rise", RISE, 0.5)
		_tween.tween_property(self, "pop_scale", 1.0, 0.18).set_trans(Tween.TRANS_BACK)
		_tween.tween_interval(0.6)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(hide)
	_follow()


func _process(_delta: float) -> void:
	if visible:
		_follow()


func _follow() -> void:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		hide()
		return
	# En el centro de la pantalla, no sobre el dado. Si salen varios a la vez (los dos dados
	# de la isla), se colocan uno al lado del otro.
	var screen := get_viewport().get_visible_rect().size
	var shown: Array[Node] = []
	for sibling in get_parent().get_children():
		if sibling is DicePop and sibling.visible:
			shown.append(sibling)
	var index := shown.find(self)
	var spread := (index - (shown.size() - 1) * 0.5) * size.x * 1.15 * SCREEN_SCALE
	var center := screen * 0.5 + Vector2(spread, -rise * RISE_PIXELS / RISE)
	scale = Vector2.ONE * SCREEN_SCALE * pop_scale
	position = center - size * 0.5
