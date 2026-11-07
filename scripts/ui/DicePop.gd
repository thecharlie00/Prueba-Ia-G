class_name DicePop
extends Label
## Número que salta encima del dado al salir el resultado.
##
## Se dibuja con la interfaz 2D, pero colocado y escalado según la cámara para que se vea
## como antes: encima del dado, más pequeño cuanto más lejos. Las dos versiones 3D (Label3D
## y luego Sprite3D con imágenes ya hechas) congelaban ~0,4 s cada tirada en el equipo de
## Carlos (medido con F3/F4); la interfaz 2D es el mismo camino que usa el HUD, que no da
## problemas.

const HEIGHT := 0.65
const RISE := 0.35
## Altura del número en la mesa, en metros (para calcular su tamaño en pantalla).
const WORLD_SIZE := 0.55
const BASE_FONT := 96

var anchor: Node3D
## Animados por la tirada: subida en metros y escala del rebote.
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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var point := anchor.global_position + Vector3.UP * (HEIGHT + rise)
	if camera.is_position_behind(point):
		self_modulate.a = 0.0
		return
	self_modulate.a = 1.0
	var center := camera.unproject_position(point)
	# Tamaño en pantalla de WORLD_SIZE metros a esa distancia: perspectiva como en 3D.
	var top := camera.unproject_position(point + camera.global_basis.y * WORLD_SIZE)
	var perspective := clampf(center.distance_to(top) / (BASE_FONT * 0.72), 0.25, 3.0)
	scale = Vector2.ONE * perspective * pop_scale
	position = center - size * 0.5
