extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var grabber := main.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var die := main.get_node("Objects/Dice") as Dice3D
	grabber.set_physics_process(false)
	var point := grabber.camera.unproject_position(die.global_position)
	grabber._update_hover(point)
	_check(grabber.hovered == die and grabber.last_selected == die, "recuerda pieza señalada")
	grabber._update_hover(Vector2(-10000, -10000))
	_check(grabber.hovered == null and grabber.last_selected == die, "recuerda al salir el puntero")
	var selection := main.get_node("UI/Margin/Panel/Content/Selection") as Label
	_check("ÚLTIMA" in selection.text, "se indica qué pieza recupera H")
	die.global_position.y = -5.0
	die.linear_velocity = Vector3.ZERO
	await physics_frame
	var event := InputEventKey.new()
	event.keycode = KEY_H
	event.pressed = true
	grabber._unhandled_input(event)
	_check(grabber._pending_recovery == die, "H alcanza la última pieza fuera de cámara")
	grabber._physics_process(1.0 / 60.0)
	_check(die.global_position.y > 0.8, "recupera el dado en la mesa")
	_check(die.linear_velocity.length() < 0.1, "recuperación detiene la velocidad")
	# Otros atajos siguen dirigidos únicamente al objeto bajo el cursor.
	grabber.hovered = null
	die._awaiting_result = false
	event.keycode = KEY_R
	grabber._unhandled_input(event)
	_check(not die._awaiting_result, "R no lanza una pieza fuera del cursor")
	# Si se elimina el último objeto, no debe quedar una referencia utilizable.
	main.get_node("Objects").remove_child(die)
	die.queue_free()
	await process_frame
	event.keycode = KEY_H
	grabber._unhandled_input(event)
	grabber._physics_process(1.0 / 60.0)
	_check(not is_instance_valid(grabber._pending_recovery), "no recupera objeto eliminado")
	main.queue_free()
	if failures:
		printerr("Grab recovery: %d errores" % failures)
		quit(1)
	else:
		print("Grab recovery tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
