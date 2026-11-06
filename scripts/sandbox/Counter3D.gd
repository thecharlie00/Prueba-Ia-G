class_name Counter3D
extends TableUtility
## Contador de puntos o vidas: bloque con un número grande. + / − suman y restan, R lo pone
## a cero.

const MIN_VALUE := -999
const MAX_VALUE := 9999

@export var value := 0
var _label: Label3D


func _ready() -> void:
	super._ready()
	$Visual.mesh = PieceKit.rounded_box(Vector3(0.52, 0.2, 0.4), 0.07)
	$Visual.material_override = _material(piece_color)
	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	plate.mesh = PieceKit.rounded_box(Vector3(0.4, 0.02, 0.28), 0.01)
	plate.position.y = 0.1
	plate.material_override = _material(Palette.PAPER, 0.7)
	$Visual.add_child(plate)
	for side in [-1, 1]:
		var knob := MeshInstance3D.new()
		knob.mesh = PieceKit.rounded_disc(0.05, 0.05, 0.015)
		knob.rotation_degrees.z = 90.0
		knob.position = Vector3(side * 0.28, 0.0, 0.0)
		knob.material_override = _material(piece_color.darkened(0.25))
		$Visual.add_child(knob)
	_label = _make_label(0.34)
	_refresh()


func change(amount: int) -> void:
	set_value(value + amount)
	_bump()


func set_value(next: int) -> void:
	value = clampi(next, MIN_VALUE, MAX_VALUE)
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = str(value)


func handle_shortcut(keycode: int) -> bool:
	if keycode in KEYS_PLUS:
		change(1)
	elif keycode in KEYS_MINUS:
		change(-1)
	elif keycode == KEY_R:
		set_value(0)
		_bump()
	else:
		return false
	return true


func radial_actions() -> Array[Dictionary]:
	return [
		{"label": "+1", "key": "+", "keycode": KEY_PLUS},
		{"label": "−1", "key": "−", "keycode": KEY_MINUS},
		{"label": "A cero", "key": "R", "keycode": KEY_R},
	]


func shortcut_hint() -> String:
	return "Contador · + / − sumar y restar · R a cero · L bloquear"


func extra_data() -> Dictionary:
	return {"value": value, "color": [piece_color.r, piece_color.g, piece_color.b, piece_color.a]}


func apply_extra(data: Dictionary) -> void:
	set_value(int(data["value"]))
