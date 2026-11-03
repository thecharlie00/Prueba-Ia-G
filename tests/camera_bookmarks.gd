extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var view := current_scene
	var camera := view.get_node("TabletopCamera3D") as TabletopCamera3D
	var grabber := view.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var nav := root.get_node("SessionNavigation")
	_check(not camera.has_bookmark(1) and not camera.load_bookmark(1), "vista vacía")
	_check(not camera.save_bookmark(0) and not camera.save_bookmark(4), "solo tres ranuras")
	camera.focus = Vector3(2, 0.8, -3)
	camera.distance = 6
	camera._target_distance = 10
	camera._yaw = 1.3
	camera._elevation = 0.65
	camera._unhandled_input(_key(KEY_1, true, false))
	_check(camera.has_bookmark(1) and camera._view_notice.visible, "Ctrl+1 guarda y da aviso")
	camera.focus = Vector3.ZERO
	camera.distance = 12
	camera._target_distance = 14
	camera._yaw = -0.8
	camera._unhandled_input(_key(KEY_1, false, true))
	_check(
		camera.focus == Vector3(2, 0.8, -3) and is_equal_approx(camera._yaw, 1.3),
		"Mayús+1 recupera posición y orientación"
	)
	_check(
		camera.distance == 6 and camera._target_distance == 6, "recupera zoom visible sin deriva"
	)
	# Simula una tecla que con Mayús genera un símbolo, pero físicamente es el 2.
	var shifted := _key(KEY_AT, false, true)
	shifted.physical_keycode = KEY_2
	camera._unhandled_input(shifted)
	_check(camera._view_notice.text.contains("vacía"), "avisa de vista vacía con tecla física")
	grabber._pending_press = true
	camera._unhandled_input(_key(KEY_2, true, false))
	_check(not camera.has_bookmark(2), "no cambia vista durante agarre pendiente")
	grabber._pending_press = false
	grabber.held = view.get_node("Objects/Dice") as Dice3D
	camera._unhandled_input(_key(KEY_2, true, false))
	_check(not camera.has_bookmark(2), "no cambia vista mientras se agarra")
	grabber.held = null
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	camera._unhandled_input(_key(KEY_2, true, false))
	_check(not camera.has_bookmark(2), "no roba atajos al escribir")
	text.release_focus()
	text.queue_free()
	camera.focus = Vector3(1, 0.8, 1)
	nav.call("_toggle")
	_check(paused, "menú de pausa abierto")
	var slot := nav.get("camera_slot") as OptionButton
	var save := nav.get("camera_save") as Button
	var load_button := nav.get("camera_load") as Button
	slot.select(1)
	nav.call("_camera_slot_changed", 1)
	_check(not save.disabled and load_button.disabled, "ranura vacía accesible en pausa")
	save.pressed.emit()
	_check(camera.has_bookmark(2) and not load_button.disabled, "guardar desde pausa")
	camera.focus = Vector3.ZERO
	load_button.pressed.emit()
	_check(camera.focus == Vector3(1, 0.8, 1), "restaurar desde pausa")
	nav.call("_toggle")
	_check(not paused, "reanudación")
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	camera = current_scene.get_node("TabletopCamera3D") as TabletopCamera3D
	_check(
		not camera.has_bookmark(1) and not camera.has_bookmark(2),
		"vistas no se filtran a otra mesa"
	)
	if failures:
		printerr("Camera bookmarks: %d errores" % failures)
		quit(1)
	else:
		print("Camera bookmarks tests OK")
		quit(0)


func _key(code: Key, ctrl: bool, shift: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	key.pressed = true
	return key


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
