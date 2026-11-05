extends SceneTree

var failures := 0
var last_reason := ""
var last_target := Vector3.ZERO
var button_presses := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_free_table()
	await _test_guided_table()
	if failures:
		printerr("Grab release safety: %d errores" % failures)
		quit(1)
	else:
		print("Grab release safety tests OK")
		quit(0)


func _test_free_table() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await _frames()
	var view := current_scene
	var grabber := view.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var die := view.get_node("Objects/Dice") as Dice3D
	grabber.set_physics_process(false)
	grabber.click_to_grab = false
	grabber.grab_finished.connect(_on_finished)
	die.gravity_scale = 0.0
	die.linear_velocity = Vector3.ZERO
	await physics_frame
	# Clic completo entre ticks: se procesan agarre y suelta sin quedarse pegado.
	var die_point := grabber.camera.unproject_position(die.global_position)
	_motion(die_point)
	await process_frame
	_mouse(die_point, true)
	_mouse(die_point, false)
	_check(grabber._pending_press and grabber._pending_release, "clic rápido encolado")
	grabber._physics_process(1.0 / 60.0)
	_check(grabber.held == null and last_reason == "released", "clic rápido termina el agarre")
	# La selección usa la posición de la suelta, no la posición de un movimiento posterior.
	_motion(Vector2(800, 430))
	await process_frame
	_begin(grabber, die)
	var release_point := Vector2(820, 460)
	var projected = grabber._plane_point(release_point, grabber._drag_height)
	_check(projected != null, "se proyecta la posición de suelta")
	var expected: Vector3 = projected + grabber._grab_offset
	_mouse(release_point, false)
	_motion(Vector2(1050, 580))
	_check(grabber._release_position == release_point, "guarda la posición del evento de suelta")
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "released", "suelta normal confirmada")
	_check(
		Vector2(last_target.x, last_target.z).distance_to(Vector2(expected.x, expected.z)) < 0.001,
		"un movimiento posterior no cambia el destino"
	)
	# En modo mantener, soltar sobre UI cancela; no activa el botón.
	var button := _button(view)
	_motion(Vector2(930, 120))
	await process_frame
	_check(root.gui_get_hovered_control() == button, "el cursor reconoce la UI")
	_begin(grabber, die)
	_mouse(Vector2(930, 120), false)
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "cancelled" and grabber.held == null, "soltar sobre UI cancela")
	_check(button_presses == 0, "soltar sobre UI no activa el botón")
	# X y la pérdida de foco no pueden convertirse en una suelta normal por un ratón tardío.
	_motion(Vector2(800, 430))
	await process_frame
	_begin(grabber, die)
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	root.push_input(key)
	_mouse(Vector2(800, 430), false)
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "cancelled", "X prevalece sobre una suelta posterior")
	_begin(grabber, die)
	grabber._pending_recovery = die
	grabber.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(grabber._pending_recovery == null, "pérdida de foco cancela recuperación pendiente")
	_mouse(Vector2(800, 430), false)
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "cancelled", "pérdida de foco prevalece sobre suelta posterior")
	# Una suelta fuera de la ventana tampoco confirma acciones.
	_begin(grabber, die)
	_mouse(Vector2(-10, -10), false)
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "cancelled", "suelta fuera de ventana cancela")
	_mouse(Vector2(800, 430), false)
	_check(not grabber._pending_release, "suelta sin agarre no deja acción pendiente")
	# El modo de dos clics conserva el mismo comportamiento y posición exacta.
	grabber.click_to_grab = true
	_begin(grabber, die)
	_motion(Vector2(800, 430))
	await process_frame
	_mouse(Vector2(800, 430), true)
	_motion(Vector2(1050, 580))
	_check(grabber._release_position == Vector2(800, 430), "segundo clic fija la posición")
	grabber._physics_process(1.0 / 60.0)
	_check(last_reason == "released" and grabber.held == null, "segundo clic suelta")


func _test_guided_table() -> void:
	change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
	await _frames()
	await physics_frame
	var view := current_scene as GuidedPhysicalCheckers
	var grabber := view.grabber
	grabber.set_physics_process(false)
	grabber.click_to_grab = false
	var token := view._token_at_square(44)
	var before: Array[int] = view.rules.board.duplicate()
	var button := _button(view)
	_motion(Vector2(930, 120))
	await process_frame
	_check(root.gui_get_hovered_control() == button, "UI presente en mesa guiada")
	_begin(grabber, token)
	_check(not view._legal_destinations.is_empty(), "la ficha tiene jugadas legales")
	if not view._legal_destinations.is_empty():
		var center: Vector3 = view._square_center(view._legal_destinations[0])
		grabber._target = center
		token.global_position = center
		_mouse(Vector2(930, 120), false)
		grabber._physics_process(1.0 / 60.0)
		_check(view.rules.board == before, "soltar sobre UI no confirma una jugada legal")
		_check(view._dragged == null, "cancelación libera ficha guiada")


func _begin(grabber: PhysicsGrabber3D, object: InteractiveTableObject) -> void:
	grabber.hovered = object
	grabber._begin_grab(grabber.camera.unproject_position(object.global_position))
	_check(grabber.held == object, "agarra la pieza")


func _button(view: Node) -> Button:
	var layer := CanvasLayer.new()
	view.add_child(layer)
	var button := Button.new()
	button.position = Vector2(900, 100)
	button.size = Vector2(140, 60)
	button.text = "Acción"
	button.pressed.connect(func(): button_presses += 1)
	layer.add_child(button)
	return button


func _on_finished(_object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	last_target = target
	last_reason = reason


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = pressed
	root.push_input(event, true)


func _motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
