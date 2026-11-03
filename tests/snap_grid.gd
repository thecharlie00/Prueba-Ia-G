extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var grid: SnapGrid3D = main.get_node("SnapGrid3D")
	grid.enabled = true
	var dice: Dice3D = main.get_node("Objects/Dice")
	var card: Card3D = main.get_node("Objects/Card")
	var grabber: PhysicsGrabber3D = main.get_node("PhysicsGrabber3D")
	var spot := Vector3(-2.7, 1.4, -0.9)
	var result: Dictionary = grid.candidate(dice, spot)
	if result.is_empty() or not result["valid"]:
		_fail("Una casilla libre debería aceptar el dado.")
		return
	var destination: Vector3 = result["position"]
	if not is_equal_approx(destination.y, 1.06):
		_fail("La altura de la pieza debe considerar su colisionador.")
		return
	if not grid.candidate(dice, Vector3(20, 1, 20)).is_empty():
		_fail("Un punto fuera de la cuadrícula no debe atraer piezas.")
		return
	grid.enabled = false
	if not grid.candidate(dice, spot).is_empty():
		_fail("La cuadrícula desactivada no debe atraer piezas.")
		return
	grid.enabled = true
	card.freeze = true
	card.global_position = Vector3(destination.x, 0.835, destination.z)
	await physics_frame
	await physics_frame
	result = grid.candidate(dice, spot)
	if result.is_empty() or result["valid"]:
		_fail("Una pieza en la casilla debe bloquear el snap.")
		return
	card.global_position = Vector3(2.5, 0.835, -1.0)
	await physics_frame
	await physics_frame
	grabber.held = dice
	grabber._target = spot
	dice.on_grab()
	grabber._release()
	if dice.is_grabbed or dice.global_position.distance_to(destination) > 0.01:
		_fail("Al soltar, el dado debe colocarse en la casilla libre.")
		return
	print("Snap grid test OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
