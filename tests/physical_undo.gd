extends SceneTree

const PATH := "user://test_physical_undo.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	await _test_sandbox()
	await _test_card_table()
	await _test_guided_guard()
	_clean()
	if failures:
		printerr("Physical undo: %d errores" % failures)
		quit(1)
	else:
		print("Physical undo tests OK")
		quit(0)


func _test_sandbox() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await _frames()
	var view := current_scene
	view.sandbox_save_path = PATH
	var grabber: PhysicsGrabber3D = view.grabber
	grabber.set_physics_process(false)
	var token := view.get_node("Objects/TokenGold") as Token3D
	token.gravity_scale = 0.0
	token.linear_velocity = Vector3.ZERO
	token.global_position = Vector3(-2.0, 2.0, 0.0)
	await physics_frame
	var original := token.global_position
	var other := view.get_node("Objects/TokenRed") as Token3D
	other.gravity_scale = 0.0
	other.linear_velocity = Vector3.ZERO
	var other_position := other.global_position
	_move(grabber, token, Vector3(1.6, 2.0, 0.0))
	_check(grabber.can_undo_movement(), "recuerda el último agarre en mesa libre")
	var nav := root.get_node("SessionNavigation")
	nav.call("_process", 0.0)
	_check(nav.undo_button.visible and not nav.undo_button.disabled, "botón deshacer disponible")
	# Con pieza agarrada no puede ejecutarse el deshacer anterior.
	grabber.hovered = other
	grabber._begin_grab(grabber.camera.unproject_position(other.global_position))
	grabber.request_movement_undo()
	_check(not grabber._pending_undo and grabber.held == other, "rechaza deshacer con agarre")
	grabber._release("cancelled")
	# Al confirmar un destino ocupado no se mueve ningún cuerpo y puede reintentarse.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	collision.shape = shape
	blocker.add_child(collision)
	view.add_child(blocker)
	blocker.global_position = original + Vector3.UP * 0.04
	await physics_frame
	var moved_position := token.global_position
	_key_undo()
	grabber._physics_process(1.0 / 60.0)
	_check(
		token.global_position.distance_to(moved_position) < 0.01, "no restaura en espacio ocupado"
	)
	_check(grabber.can_undo_movement(), "un bloqueo temporal permite reintentar")
	_check(other.global_position.distance_to(other_position) < 0.02, "no mueve otras piezas")
	blocker.queue_free()
	await physics_frame
	# Un bloqueo explícito tampoco debe eliminar el punto de deshacer.
	_check(token.set_table_locked(true), "bloquea pieza movida")
	grabber.request_movement_undo()
	grabber._physics_process(1.0 / 60.0)
	_check(grabber.can_undo_movement(), "pieza bloqueada conserva historial")
	token.set_table_locked(false)
	nav.undo_button.pressed.emit()
	grabber._physics_process(1.0 / 60.0)
	_check(
		token.global_position.distance_to(original + Vector3.UP * 0.04) < 0.01, "restaura ubicación"
	)
	_check(not grabber.can_undo_movement(), "deshacer se consume una sola vez")
	_check(token.linear_velocity.length() < 0.01, "restauración no añade impulso")
	# Las teclas no actúan mientras se escribe.
	_move(grabber, token, Vector3(1.6, 2.0, 0.0))
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	_key_undo()
	_check(not grabber._pending_undo, "Ctrl+Z al escribir no modifica la mesa")
	text.queue_free()
	await process_frame
	# La carga invalida las referencias, incluso si había un deshacer solicitado.
	view._on_save_pressed()
	grabber.request_movement_undo()
	view._on_load_pressed()
	_check(
		not grabber.can_undo_movement() and not grabber._pending_undo, "carga invalida historial"
	)

	# El dado con tirada en curso no puede teletransportarse ni producir un resultado artificial.
	var die := view.get_node("Objects/Dice") as Dice3D
	die.gravity_scale = 0.0
	die.linear_velocity = Vector3.ZERO
	die.global_position = Vector3(-2.0, 2.5, 0.0)
	await physics_frame
	_move(grabber, die, Vector3(1.0, 2.5, 0.0))
	die._awaiting_result = true
	var die_position := die.global_position
	grabber.request_movement_undo()
	grabber._physics_process(1.0 / 60.0)
	_check(die.global_position.distance_to(die_position) < 0.01, "no interrumpe una tirada")
	_check(grabber.can_undo_movement() and die._awaiting_result, "conserva tirada pendiente")
	die._awaiting_result = false
	# La carga reemplazó las instancias: tomar una pieza de la mesa actual.
	for child in view.get_node("Objects").get_children():
		if child is Token3D:
			token = child
			break
	token.gravity_scale = 0.0
	token.global_position = Vector3(-1.0, 2.0, 0.0)
	# Cancelar un agarre desplazado también crea un punto de recuperación.
	grabber.hovered = token
	grabber._begin_grab(grabber.camera.unproject_position(token.global_position))
	token.global_position += Vector3(0.4, 0.0, 0.0)
	grabber._release("cancelled")
	_check(grabber._undo_object == token, "recuerda la pieza desplazada al cancelar")
	_check(grabber._recover_object(token), "H recupera pieza en una zona libre")
	_check(not grabber.can_undo_movement(), "H invalida el historial de esa pieza")
	_move(grabber, token, Vector3(1.5, 2.0, 0.0))
	grabber.request_movement_undo()
	grabber.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not grabber._pending_undo, "pérdida de foco cancela solicitud encolada")


func _test_card_table() -> void:
	change_scene_to_file("res://scenes/CardTable.tscn")
	await _frames()
	var view := current_scene as CardTable
	var grabber := view.grabber
	grabber.set_physics_process(false)
	view.english.draw_card()
	var card := view.objects.get_child(2) as Card3D
	card.gravity_scale = 0.0
	card.global_position = Vector3(-1.0, 2.0, 0.0)
	await physics_frame
	var original := card.global_position
	_move(grabber, card, Vector3(1.0, 2.0, 0.0))
	card.quaternion = Quaternion(Vector3.FORWARD, PI)
	var face := card.quaternion
	grabber.request_movement_undo()
	grabber._physics_process(1.0 / 60.0)
	_check(card.global_position.distance_to(original + Vector3.UP * 0.04) < 0.01, "devuelve carta")
	_check(card.quaternion.is_equal_approx(face), "no cambia orientación ni revela carta")
	_move(grabber, card, Vector3(1.0, 2.0, 0.0))
	_check(view._return_card(card), "devuelve carta al mazo")
	_check(not grabber.can_undo_movement(), "carta retirada no puede recuperarse con deshacer")


func _test_guided_guard() -> void:
	change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
	await _frames()
	var view := current_scene as GuidedPhysicalCheckers
	var grabber := view.grabber
	grabber.set_physics_process(false)
	var piece := view._token_at_square(44)
	var before: Array[int] = view.rules.board.duplicate()
	_move(grabber, piece, piece.global_position + Vector3(0.4, 0.2, 0.0))
	_check(not grabber.can_undo_movement(), "no crea historial físico en modo con reglas")
	grabber.request_movement_undo()
	grabber._physics_process(1.0 / 60.0)
	_check(view.rules.board == before, "deshacer físico no altera reglas guiadas")
	var nav := root.get_node("SessionNavigation")
	nav.call("_process", 0.0)
	_check(not nav.undo_button.visible, "botón físico oculto en mesa con reglas")


func _move(grabber: PhysicsGrabber3D, object: InteractiveTableObject, target: Vector3) -> void:
	grabber.hovered = object
	grabber._begin_grab(grabber.camera.unproject_position(object.global_position))
	if grabber.held != object:
		_check(false, "se puede agarrar objeto")
		return
	object.global_position = target
	grabber._target = target
	grabber._release("released")


func _key_undo() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Z
	event.ctrl_pressed = true
	event.pressed = true
	root.push_input(event)


func _frames() -> void:
	await process_frame
	await process_frame


func _clean() -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = PATH + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
