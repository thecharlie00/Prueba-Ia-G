extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/PhysicalCheckers.tscn")
	var view := packed.instantiate() as PhysicalCheckers
	root.add_child(view)
	await _ticks(2)
	var tokens: Array[Node] = view.objects.get_children()
	_check(tokens.size() == 24, "hay 24 fichas físicas")
	var white: int = 0
	var dark: int = 0
	for child in tokens:
		_check(child is Token3D, "cada ficha es un cuerpo físico interactivo")
		if child is Token3D:
			_check(
				child.collision_layer == 2 and child.collision_mask == 3,
				"capas de colisión de la ficha"
			)
			if child.display_name == "Ficha blanca":
				white += 1
			elif child.display_name == "Ficha oscura":
				dark += 1
	_check(white == 12 and dark == 12, "doce fichas por bando")
	_check(view.grabber.snap_grid == null, "el tablero físico no obliga a usar imán")
	await _ticks(60)
	var token: Token3D = tokens.back() as Token3D
	_check(absf(token.global_position.y - 0.89) < 0.04, "la gravedad apoya la ficha en el tablero")
	var target_height: float = view.grabber._target_height(token, token.global_position)
	_check(absf(target_height - 1.07) < 0.04, "el agarre detecta la superficie del tablero")
	view.grabber.set_physics_process(false)
	var mouse: Vector2 = view.grabber.camera.unproject_position(token.global_position)
	view.grabber._update_hover(mouse)
	_check(view.grabber.hovered == token, "el rayo selecciona una ficha del tablero físico")
	view.grabber._begin_grab(mouse)
	_check(view.grabber.held == token and token.is_grabbed, "se puede agarrar la ficha")
	var start: Vector3 = token.global_position
	view.grabber._target = start + Vector3(0.0, 0.5, 0.0)
	for i in range(45):
		view.grabber._apply_held_force()
		await physics_frame
	_check(token.global_position.y > start.y + 0.2, "la ficha se eleva mediante fuerzas")
	view.grabber._release()
	_check(not token.is_grabbed and not token.freeze, "soltar restaura la física normal")
	await _ticks(90)
	_check(absf(token.global_position.y - 0.89) < 0.06, "la ficha cae de nuevo sobre el tablero")
	if failures > 0:
		printerr("Physical checkers tests: %d errores" % failures)
		quit(1)
	else:
		print("Physical checkers tests OK")
		quit(0)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
