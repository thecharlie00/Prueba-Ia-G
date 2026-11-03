extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var camera := scene.get_node("TabletopCamera3D") as TabletopCamera3D
	var initial_focus := camera.focus
	var initial_distance := camera.distance
	var initial_yaw := camera._yaw
	camera.focus = Vector3(4, 2, 9)
	camera.distance = 15
	camera._target_distance = 15
	camera._yaw = 1.8
	camera._elevation = 0.5
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	camera._unhandled_input(key)
	_check(camera.focus == initial_focus, "centra el foco")
	_check(
		camera.distance == initial_distance and camera._target_distance == initial_distance,
		"restaura zoom"
	)
	_check(
		camera._yaw == initial_yaw and is_equal_approx(camera._elevation, 0.8),
		"restaura orientación"
	)
	var grabber := scene.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	grabber.held = scene.get_node("Objects/Dice") as Dice3D
	camera.focus = Vector3(4, 2, 9)
	camera._unhandled_input(key)
	_check(camera.focus == Vector3(4, 2, 9), "no cambia la cámara durante un agarre")
	grabber.held = null
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	camera.focus = Vector3(4, 2, 9)
	camera._unhandled_input(key)
	_check(camera.focus == Vector3(4, 2, 9), "atajo no interfiere con edición de texto")
	text.queue_free()
	scene.queue_free()
	if failures:
		printerr("Camera controls: %d errores" % failures)
		quit(1)
	else:
		print("Camera controls tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
