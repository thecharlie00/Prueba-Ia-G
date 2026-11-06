class_name Timer3D
extends TableUtility
## Reloj de mesa: R arranca o pausa. Parado, + / − ponen una cuenta atrás de 30 en 30 s
## (sin cuenta atrás funciona como cronómetro). Retroceso lo vuelve a cero.

const STEP := 30.0
const MAX_SECONDS := 5999.0

var seconds := 0.0
var countdown := 0.0
var running := false
var _label: Label3D
var _ringing := 0.0


func _ready() -> void:
	super._ready()
	$Visual.mesh = PieceKit.rounded_box(Vector3(0.46, 0.3, 0.34), 0.1)
	$Visual.material_override = _material(piece_color)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = PieceKit.rounded_box(Vector3(0.34, 0.02, 0.22), 0.01)
	face.position.y = 0.15
	face.material_override = _material(Palette.PAPER, 0.7)
	$Visual.add_child(face)
	var bell := MeshInstance3D.new()
	bell.name = "Button"
	bell.mesh = PieceKit.rounded_disc(0.06, 0.05, 0.02)
	bell.position = Vector3(0.0, 0.17, -0.2)
	bell.material_override = _material(Palette.CORAL)
	$Visual.add_child(bell)
	_label = _make_label(0.42, 84)
	_refresh()


func _process(delta: float) -> void:
	if _ringing > 0.0:
		_ringing -= delta
		if _label != null:
			_label.modulate = Palette.CORAL if int(_ringing * 6.0) % 2 == 0 else Palette.PAPER
		if _ringing <= 0.0 and _label != null:
			_label.modulate = Palette.PAPER
	if not running:
		return
	if countdown > 0.0:
		seconds = maxf(0.0, seconds - delta)
		if seconds <= 0.0:
			running = false
			_ring()
	else:
		seconds = minf(MAX_SECONDS, seconds + delta)
	_refresh()


func toggle() -> void:
	if not running and countdown > 0.0 and seconds <= 0.0:
		seconds = countdown
	running = not running
	_bump()
	_refresh()


func adjust(amount: float) -> void:
	if running:
		return
	countdown = clampf(countdown + amount, 0.0, MAX_SECONDS)
	seconds = countdown
	_bump()
	_refresh()


func reset() -> void:
	running = false
	seconds = countdown
	_ringing = 0.0
	_bump()
	_refresh()


func _ring() -> void:
	_ringing = 2.4
	_sound("turn")
	_juice(Vector3(1.25, 0.8, 1.25))
	if _label != null:
		_label.text = tr("¡TIEMPO!")


func _refresh() -> void:
	if _label == null or _ringing > 0.0:
		return
	var total := int(ceilf(seconds)) if countdown > 0.0 else int(seconds)
	_label.text = "%s%02d:%02d" % ["▶ " if running else "", total / 60, total % 60]


func handle_shortcut(keycode: int) -> bool:
	if keycode == KEY_R:
		toggle()
	elif keycode in KEYS_PLUS:
		adjust(STEP)
	elif keycode in KEYS_MINUS:
		adjust(-STEP)
	elif keycode == KEY_BACKSPACE:
		reset()
	else:
		return false
	return true


func radial_actions() -> Array[Dictionary]:
	return [
		{"label": "Pausar" if running else "Arrancar", "key": "R", "keycode": KEY_R},
		{"label": "+30 s", "key": "+", "keycode": KEY_PLUS},
		{"label": "−30 s", "key": "−", "keycode": KEY_MINUS},
		{"label": "A cero", "key": "⌫", "keycode": KEY_BACKSPACE},
	]


func shortcut_hint() -> String:
	return "Reloj · R arrancar/pausar · + / − cuenta atrás · ⌫ a cero"


func extra_data() -> Dictionary:
	return {
		"seconds": seconds,
		"countdown": countdown,
		"color": [piece_color.r, piece_color.g, piece_color.b, piece_color.a],
	}


func apply_extra(data: Dictionary) -> void:
	countdown = float(data["countdown"])
	seconds = float(data["seconds"])
	running = false  # Al cargar o rebobinar el reloj queda en pausa.
	_refresh()
