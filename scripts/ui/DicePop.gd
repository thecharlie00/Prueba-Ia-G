class_name DicePop
extends Sprite3D
## Número 3D que salta encima del dado al salir el resultado.
##
## Antes era un Label3D con contorno y sin prueba de profundidad: en cada tirada rehacía el
## texto y en algunas tarjetas gráficas eso congelaba el juego ~0,4 s (medido con F3/F4 en el
## equipo de Carlos). Ahora los números del 1 al 6 se dibujan una sola vez al abrir la mesa
## (DiceDigits) y en cada tirada solo se enseña la imagen ya hecha: misma pinta, sin rehacer
## texto ni materiales.

const HEIGHT := 0.65
const RISE := 0.35

var anchor: Node3D
var _tween: Tween


func _init() -> void:
	name = "ResultPop"
	visible = false
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	double_sided = true
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	render_priority = 3
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pixel_size = 0.0052


## value: número que se muestra; digits: las imágenes ya dibujadas de la escena.
func show_value(value: int, follow: Node3D, digits: DiceDigits, calm: bool) -> void:
	anchor = follow
	text_value = value
	texture = digits.texture_for(value)
	modulate = Color.WHITE
	visible = true
	global_position = follow.global_position + Vector3.UP * HEIGHT
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if calm:
		scale = Vector3.ONE
		_tween.tween_interval(1.0)
	else:
		scale = Vector3.ONE * 0.2
		_tween.tween_property(self, "scale", Vector3.ONE * 1.25, 0.16).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(self, "position:y", position.y + RISE, 0.5)
		_tween.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		_tween.tween_interval(0.6)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(hide)


## Valor mostrado (para los tests).
var text_value := 0
