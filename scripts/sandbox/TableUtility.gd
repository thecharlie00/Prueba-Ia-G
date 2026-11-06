class_name TableUtility
extends InteractiveTableObject
## Base de los componentes utilitarios de la mesa libre (queja 18 de TTS): contador, bolsa,
## nota y temporizador. Cada uno define sus atajos, sus acciones del menú radial y los datos
## extra que se guardan con la partida (SandboxPersistence).

const KEYS_PLUS := [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]
const KEYS_MINUS := [KEY_MINUS, KEY_KP_SUBTRACT]

@export var piece_color := Palette.SUN


## Devuelve true si la tecla tenía significado para este componente.
func handle_shortcut(_keycode: int) -> bool:
	return false


## Acciones propias para el menú radial ({"label", "key", "keycode"}).
func radial_actions() -> Array[Dictionary]:
	return []


## Atajos que se muestran sobre la pieza al pasar el ratón.
func shortcut_hint() -> String:
	return "Q/E girar · H recuperar · L bloquear"


## Datos propios que se guardan con la mesa.
func extra_data() -> Dictionary:
	return {}


## Restaura los datos propios ya validados. Se llama después de _ready().
func apply_extra(_data: Dictionary) -> void:
	pass


static func validate_extra(_kind: String, _data: Dictionary) -> bool:
	return true


func _material(color: Color, roughness := 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## Rótulo grande que siempre mira a la cámara, con contorno de tinta.
func _make_label(height: float, font_size := 96) -> Label3D:
	var label := Label3D.new()
	label.name = "Readout"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.pixel_size = 0.0028
	label.outline_size = 22
	label.outline_modulate = Palette.INK
	label.modulate = Palette.PAPER
	label.position.y = height
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		label.font = style.DISPLAY_FONT
	add_child(label)
	return label


func _bump() -> void:
	_juice(Vector3(1.12, 0.88, 1.12))
	_sound("ui")
