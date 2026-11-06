extends Node
## Mando y Steam Deck (queja 8 de TTS). Traduce el mando a ratón y teclado para que todas las
## mesas funcionen sin código propio:
##   stick izquierdo: cursor · A: agarrar/soltar (clic izquierdo) · B: menú radial (clic derecho)
##   stick derecho: orbitar · gatillos: zoom · X: tirar/mezclar (R) · Y: voltear (F)
##   LB / RB: girar (Q / E) · cruceta ↑↓: altura y zoom · ← vistas (V) · → señalar (P)
##   Start: pausa (Esc) · Select: ayuda (F1) · L3: pincel (D) · R3: vista inicial (Inicio)

const DEADZONE := 0.18
const CURSOR_SPEED := 1100.0
const ORBIT_SPEED := 520.0
const ZOOM_RATE := 7.0

## Botón del mando -> tecla o botón del ratón.
const BUTTON_KEYS := {
	JOY_BUTTON_X: KEY_R,
	JOY_BUTTON_Y: KEY_F,
	JOY_BUTTON_LEFT_SHOULDER: KEY_Q,
	JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
	JOY_BUTTON_DPAD_LEFT: KEY_V,
	JOY_BUTTON_DPAD_RIGHT: KEY_P,
	JOY_BUTTON_START: KEY_ESCAPE,
	JOY_BUTTON_BACK: KEY_F1,
	JOY_BUTTON_LEFT_STICK: KEY_D,
	JOY_BUTTON_RIGHT_STICK: KEY_HOME,
}
const BUTTON_MOUSE := {
	JOY_BUTTON_A: MOUSE_BUTTON_LEFT,
	JOY_BUTTON_B: MOUSE_BUTTON_RIGHT,
	JOY_BUTTON_DPAD_UP: MOUSE_BUTTON_WHEEL_UP,
	JOY_BUTTON_DPAD_DOWN: MOUSE_BUTTON_WHEEL_DOWN,
}

var enabled := true
var _left_down := false
var _zoom := 0.0
var _notice: Label
var _notice_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_notice = Label.new()
	_notice.name = "GamepadNotice"
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notice.offset_bottom = -150
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Palette.PAPER)
	_notice.add_theme_color_override("font_outline_color", Palette.INK)
	_notice.add_theme_constant_override("outline_size", 8)
	_notice.add_theme_font_size_override("font_size", 17)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	layer.add_child(_notice)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		show_help()


func show_help() -> void:
	_notice.text = (
		"Mando conectado · stick izq.: cursor · A agarrar · B menú · stick der.: orbitar\n"
		+ "gatillos: zoom · X tirar · Y voltear · LB/RB girar · ← vistas · → señalar · Select ayuda"
	)
	_notice.visible = true
	_notice_until = Time.get_ticks_msec() + 7000


## Eventos de ratón o teclado equivalentes a un botón del mando (lo usan también los tests).
static func translate_button(button: int, pressed: bool, at: Vector2) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if BUTTON_KEYS.has(button):
		var key := InputEventKey.new()
		key.keycode = BUTTON_KEYS[button]
		key.physical_keycode = BUTTON_KEYS[button]
		key.pressed = pressed
		result.append(key)
	elif BUTTON_MOUSE.has(button):
		var index: int = BUTTON_MOUSE[button]
		var wheel := index == MOUSE_BUTTON_WHEEL_UP or index == MOUSE_BUTTON_WHEEL_DOWN
		if wheel and not pressed:
			return result
		var click := InputEventMouseButton.new()
		click.button_index = index
		click.pressed = pressed
		click.position = at
		click.global_position = at
		if not wheel and pressed:
			click.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
		result.append(click)
		if wheel:
			var release := click.duplicate() as InputEventMouseButton
			release.pressed = false
			result.append(release)
	return result


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventJoypadButton):
		return
	var at := get_viewport().get_mouse_position()
	if event.button_index == JOY_BUTTON_A:
		_left_down = event.pressed
	for translated in translate_button(event.button_index, event.pressed, at):
		_emit.call_deferred(translated)
	get_viewport().set_input_as_handled()


func _emit(event: InputEvent) -> void:
	Input.parse_input_event(event)


func _process(delta: float) -> void:
	if _notice.visible and Time.get_ticks_msec() > _notice_until:
		_notice.visible = false
	if not enabled or Input.get_connected_joypads().is_empty():
		return
	var device: int = Input.get_connected_joypads()[0]
	var left := _stick(device, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if left != Vector2.ZERO:
		move_cursor(left * CURSOR_SPEED * delta)
	var right := _stick(device, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if right != Vector2.ZERO:
		var orbit := InputEventMouseMotion.new()
		orbit.position = get_viewport().get_mouse_position()
		orbit.relative = right * ORBIT_SPEED * delta
		orbit.button_mask = MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(orbit)
	var triggers := (
		Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
	)
	if absf(triggers) > DEADZONE:
		_zoom += triggers * ZOOM_RATE * delta
		while absf(_zoom) >= 1.0:
			var step := signf(_zoom)
			_zoom -= step
			for wheel in translate_button(
				JOY_BUTTON_DPAD_UP if step > 0.0 else JOY_BUTTON_DPAD_DOWN, true, get_viewport().get_mouse_position()
			):
				Input.parse_input_event(wheel)


## Mueve el cursor del sistema y avisa al juego (arrastrar con A mantiene el agarre).
func move_cursor(offset: Vector2) -> void:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var from := viewport.get_mouse_position()
	var to := (from + offset).clamp(rect.position, rect.end - Vector2.ONE)
	viewport.warp_mouse(to)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _left_down else 0
	Input.parse_input_event(motion)


func _stick(device: int, axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var value := Vector2(Input.get_joy_axis(device, axis_x), Input.get_joy_axis(device, axis_y))
	if value.length() < DEADZONE:
		return Vector2.ZERO
	# Curva suave: precisión con poca inclinación y velocidad con el stick a fondo.
	return value.normalized() * pow((value.length() - DEADZONE) / (1.0 - DEADZONE), 1.6)
