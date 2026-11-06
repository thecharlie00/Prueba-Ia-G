extends SceneTree
## Mando y Steam Deck: cada botón se traduce al ratón o al teclado de las mesas.

const GAMEPAD := preload("res://scripts/ui/Gamepad.gd")


func _initialize() -> void:
	var at := Vector2(320, 200)
	var a: Array[InputEvent] = GAMEPAD.translate_button(JOY_BUTTON_A, true, at)
	if a.size() != 1 or not (a[0] is InputEventMouseButton) or a[0].button_index != MOUSE_BUTTON_LEFT:
		return _fail("A debe ser el clic izquierdo para agarrar.")
	if not a[0].pressed or a[0].position != at:
		return _fail("El clic de A se hace donde está el cursor.")
	var b: Array[InputEvent] = GAMEPAD.translate_button(JOY_BUTTON_B, false, at)
	if b.size() != 1 or b[0].button_index != MOUSE_BUTTON_RIGHT or b[0].pressed:
		return _fail("Soltar B suelta el clic derecho (menú radial).")
	var expected := {
		JOY_BUTTON_X: KEY_R, JOY_BUTTON_Y: KEY_F, JOY_BUTTON_LEFT_SHOULDER: KEY_Q,
		JOY_BUTTON_RIGHT_SHOULDER: KEY_E, JOY_BUTTON_DPAD_LEFT: KEY_V, JOY_BUTTON_DPAD_RIGHT: KEY_P,
		JOY_BUTTON_START: KEY_ESCAPE, JOY_BUTTON_BACK: KEY_F1,
	}
	for button in expected:
		var keys: Array[InputEvent] = GAMEPAD.translate_button(button, true, at)
		if keys.size() != 1 or not (keys[0] is InputEventKey) or keys[0].keycode != expected[button]:
			return _fail("El botón %d debe pulsar la tecla %s." % [button, OS.get_keycode_string(expected[button])])
	var wheel: Array[InputEvent] = GAMEPAD.translate_button(JOY_BUTTON_DPAD_UP, true, at)
	if wheel.size() != 2 or wheel[0].button_index != MOUSE_BUTTON_WHEEL_UP:
		return _fail("Cruceta arriba gira la rueda (altura o zoom).")
	if not GAMEPAD.translate_button(JOY_BUTTON_DPAD_UP, false, at).is_empty():
		return _fail("Soltar la cruceta no repite la rueda.")
	if root.get_node_or_null("Gamepad") == null:
		return _fail("El mando debe estar activo como autoload.")
	print("gamepad: ok")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
