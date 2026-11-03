extends SceneTree

var failures := 0
var releases: Array[String] = []
var ui_presses := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var nav := root.get_node("SessionNavigation")
	var old_settings_path: String = nav.settings_path
	var old_value: bool = nav.click_to_grab
	nav.settings_path = "user://test_click_grab.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(nav.settings_path))
	change_scene_to_file("res://scenes/Menu.tscn")
	await process_frame
	await process_frame
	var menu_option := current_scene.find_child("ClickToGrab", true, false) as CheckButton
	_check(menu_option != null, "opción disponible en menú")
	if menu_option != null:
		menu_option.set_pressed_no_signal(false)
		menu_option.button_pressed = true
		_check(nav.click_to_grab, "el menú cambia la preferencia")
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	await _ticks(2)
	var view := current_scene
	var grabber := view.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var die := view.get_node("Objects/Dice") as Dice3D
	grabber.grab_finished.connect(_on_release)
	nav.set_click_to_grab(true)
	_check(grabber.click_to_grab, "opción activa en mesa existente")
	_check(FileAccess.file_exists(nav.settings_path), "se guarda el ajuste")
	nav.click_to_grab = false
	nav._load_controls()
	_check(nav.click_to_grab, "ajuste se vuelve a cargar")
	var config := ConfigFile.new()
	config.set_value("controls", "click_to_grab", "incorrecto")
	config.save(nav.settings_path)
	nav.click_to_grab = false
	nav._load_controls()
	_check(not nav.click_to_grab, "ignora tipos inválidos en preferencias")
	nav.set_click_to_grab(true)
	# Eventos reales del viewport: el primer clic mantiene el cuerpo al soltar el botón.
	var point := grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(grabber.held == die and die.is_grabbed, "un clic agarra y mantiene la ficha")
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(grabber.held == null and not die.is_grabbed, "segundo clic suelta")
	_check(releases.size() == 1 and releases.back() == "released", "liberación normal")
	# Sobre un botón se cancela la suelta sin activar la acción oculta.
	var layer := CanvasLayer.new()
	view.add_child(layer)
	var button := Button.new()
	button.text = "Acción"
	button.position = Vector2(900, 100)
	button.size = Vector2(140, 60)
	button.pressed.connect(func(): ui_presses += 1)
	layer.add_child(button)
	point = grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(930, 120)
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	_check(root.gui_get_hovered_control() == button, "puntero reconoce el botón")
	_mouse(motion.position, true)
	_mouse(motion.position, false)
	await _ticks(3)
	_check(
		grabber.held == null and not releases.is_empty() and releases.back() == "cancelled",
		"clic sobre UI cancela"
	)
	_check(ui_presses == 0, "el clic de suelta no acciona el botón")
	grabber.hovered = die
	grabber.last_selected = die
	grabber._physics_process(1.0 / 60.0)
	_check(
		grabber.hovered == null and grabber.last_selected == die,
		"la UI no selecciona piezas detrás"
	)
	layer.queue_free()
	# Dos clics entre dos ticks físicos no dejan un agarre pegado.
	point = grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	_mouse(point, false)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(grabber.held == null and not die.is_grabbed, "clics rápidos no dejan pieza pegada")
	_check(
		releases.size() == 3 and releases.back() == "released", "clics rápidos se procesan en orden"
	)
	# Perder foco antes del siguiente tick descarta también el clic pendiente.
	point = grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	grabber._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _ticks(2)
	_check(grabber.held == null, "pérdida de foco cancela agarre pendiente")
	# La pérdida de foco cancela sin confirmar una colocación.
	point = grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	grabber._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _ticks(2)
	_check(grabber.held == null and releases.back() == "cancelled", "pérdida de foco cancela")
	# La pausa debe cancelar y no confirmar una jugada.
	point = grabber.camera.unproject_position(die.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(grabber.held == die, "agarre antes de pausar")
	nav._toggle()
	_check(
		(
			paused
			and grabber.held == null
			and not releases.is_empty()
			and releases.back() == "cancelled"
		),
		"pausa cancela"
	)
	nav._toggle()
	# En un modo con reglas la pausa tampoco confirma la jugada.
	change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
	await process_frame
	await process_frame
	await _ticks(60)
	var guided := current_scene as GuidedPhysicalCheckers
	var original_board: Array[int] = guided.rules.board.duplicate()
	var piece := guided._token_at_square(44)
	point = guided.grabber.camera.unproject_position(piece.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(guided.grabber.held == piece, "clic agarra ficha con reglas")
	nav._toggle()
	_check(
		guided.rules.board == original_board and guided.grabber.held == null,
		"pausa no confirma jugada"
	)
	nav._toggle()
	await _ticks(45)
	piece = guided._token_at_square(44)
	point = guided.grabber.camera.unproject_position(piece.global_position)
	_mouse(point, true)
	_mouse(point, false)
	await _ticks(3)
	_check(guided.grabber.held == piece, "segunda selección con reglas")
	guided.grabber.set_physics_process(false)
	var goal := guided._square_center(35)
	piece.global_position = goal + Vector3.UP * 0.3
	var pointer_world := Vector3(
		goal.x - guided.grabber._grab_offset.x,
		guided.grabber._drag_height,
		goal.z - guided.grabber._grab_offset.z
	)
	var destination := guided.grabber.camera.unproject_position(pointer_world)
	_mouse(destination, true)
	_mouse(destination, false)
	guided.grabber._physics_process(1.0 / 60.0)
	_check(guided.rules.board[35] == CheckersRules.MAN, "segundo clic confirma jugada legal")
	# Un cambio de escena obtiene el mismo ajuste.
	change_scene_to_file("res://scenes/CardTable.tscn")
	await process_frame
	await process_frame
	await _ticks(3)
	grabber = current_scene.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	_check(grabber.click_to_grab, "opción se aplica a otras mesas")
	nav.set_click_to_grab(false)
	_check(not grabber.click_to_grab, "volver al modo mantener")
	# Los atajos globales no se ejecutan al escribir en un campo de texto.
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	await _ticks(3)
	grabber = current_scene.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var grid := current_scene.get_node("SnapGrid3D") as SnapGrid3D
	die = current_scene.get_node("Objects/Dice") as Dice3D
	grabber.hovered = die
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_R
	grabber._unhandled_input(key)
	_check(not die._awaiting_result, "escribir R no lanza dado")
	key.keycode = KEY_S
	grabber._unhandled_input(key)
	_check(not grid.enabled, "escribir S no activa imán")
	text.queue_free()
	nav.settings_path = old_settings_path
	nav.click_to_grab = old_value
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_click_grab.cfg"))
	if failures:
		printerr("Click grab: %d errores" % failures)
		quit(1)
	else:
		print("Click grab tests OK")
		quit(0)


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event, true)


func _on_release(_object: InteractiveTableObject, _target: Vector3, reason: String) -> void:
	releases.append(reason)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
