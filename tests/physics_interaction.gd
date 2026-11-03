extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	await _ticks(2)
	var grabber: PhysicsGrabber3D = main.get_node("PhysicsGrabber3D")
	var grid: SnapGrid3D = main.get_node("SnapGrid3D")
	var gold: Token3D = main.get_node("Objects/TokenGold")
	var red: Token3D = main.get_node("Objects/TokenRed")
	var blue: Token3D = main.get_node("Objects/TokenBlue")
	var dice: Dice3D = main.get_node("Objects/Dice")
	grabber.set_physics_process(false)
	_check(not grid.enabled, "imán desactivado por defecto para permitir física libre")
	_check(is_equal_approx(gold.bottom_offset(), 0.06), "altura del colisionador cilíndrico")
	_check(is_equal_approx(dice.bottom_offset(), 0.25), "altura del colisionador del dado")
	var mouse_on_dice: Vector2 = grabber.camera.unproject_position(dice.global_position)
	grabber._update_hover(mouse_on_dice)
	_check(grabber.hovered == dice, "rayo selecciona el dado bajo el cursor")
	grabber._begin_grab(mouse_on_dice)
	_check(grabber.held == dice and dice.is_grabbed, "el clic inicia el agarre físico")
	grabber._release()
	_check(not dice.is_grabbed, "la liberación termina el agarre físico")

	# La altura de agarre reconoce otra ficha como superficie, excluyendo la sostenida.
	gold.freeze = true
	red.freeze = true
	gold.global_position = Vector3(-2.4, 0.86, -1.6)
	red.global_position = Vector3(-2.4, 1.5, -1.6)
	await _ticks(2)
	grabber._drag_height = 1.5
	var above_stack: float = grabber._target_height(red, red.global_position)
	_check(absf(above_stack - 1.16) < 0.03, "altura adaptativa sobre una ficha")
	grabber._adjust_height(0.3)
	_check(
		absf(grabber._target_height(red, red.global_position) - above_stack - 0.3) < 0.02,
		"ajustar altura de agarre"
	)
	grabber._height_adjustment = 0.0

	# Un snap debe rechazar un obstáculo intermedio aunque el destino esté libre.
	grid.enabled = true
	red.global_position = Vector3(-2.7, 1.8, -0.9)
	gold.global_position = Vector3(-2.7, 1.25, -0.9)
	await _ticks(2)
	var spot := Vector3(-2.7, 1.8, -0.9)
	var blocked: Dictionary = grid.candidate(red, spot)
	_check(not blocked.is_empty() and not blocked["valid"], "barrido impide atravesar una ficha")
	gold.global_position = Vector3(0.0, 0.86, 0.5)
	await _ticks(2)
	var free: Dictionary = grid.candidate(red, spot)
	_check(not free.is_empty() and free["valid"], "snap admite cilindro y trayecto libre")
	grid.enabled = false

	# Recuperar no pisa una posición ocupada y libera correctamente el agarre.
	_check(not grabber._recover_object(red), "no recuperar mientras está congelada")
	red.freeze = false
	grabber.held = red
	red.on_grab()
	_check(grabber._recover_object(red), "recuperar la ficha sobre la mesa")
	_check(not red.is_grabbed and grabber.held == null, "recuperación termina el agarre")
	_check(
		red.global_position.distance_to(Vector3(0.0, 0.9, 0.5)) > 0.3,
		"recuperación evita sitio ocupado"
	)

	# La rueda cambia altura y una liberación sobre la UI no deja el cuerpo agarrado.
	grabber.held = red
	red.on_grab()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	grabber._input(wheel)
	_check(grabber._height_adjustment > 0.0, "rueda ajusta la altura al agarrar")
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	grabber._input(mouse_up)
	_check(grabber._pending_release, "liberación capturada aunque la UI consuma el evento")
	grabber._pending_release = false
	grabber._release()

	# Objetos distintos reaccionan físicamente al chocar y pueden formar una pila.
	for child in main.get_node("Objects").get_children():
		if child is RigidBody3D:
			child.freeze = true
	gold.global_position = Vector3(-2.6, 0.87, -1.65)
	blue.global_position = Vector3(-1.95, 0.87, -1.65)
	gold.linear_velocity = Vector3.ZERO
	blue.linear_velocity = Vector3.ZERO
	await _ticks(2)
	gold.freeze = false
	blue.freeze = false
	gold.sleeping = false
	blue.sleeping = false
	gold.linear_velocity = Vector3(3.0, 0, 0)
	await _ticks(55)
	_check(blue.global_position.x > -1.85, "el choque transfiere movimiento a la otra ficha")

	gold.freeze = true
	blue.freeze = true
	gold.global_position = Vector3(-2.4, 0.87, -1.65)
	blue.global_position = Vector3(-2.4, 1.4, -1.65)
	gold.linear_velocity = Vector3.ZERO
	blue.linear_velocity = Vector3.ZERO
	await _ticks(2)
	gold.freeze = false
	blue.freeze = false
	gold.sleeping = false
	blue.sleeping = false
	await _ticks(90)
	_check(blue.global_position.y - gold.global_position.y > 0.09, "fichas apiladas por colisión")

	# El agarre emplea fuerzas y soltar conserva velocidad limitada.
	blue.freeze = true
	blue.global_position = Vector3(2.5, 1.0, -1.7)
	await _ticks(2)
	grabber.held = gold
	gold.on_grab()
	var start: Vector3 = gold.global_position
	grabber._target = start + Vector3(0.35, 0.45, 0)
	for i in range(45):
		grabber._apply_held_force()
		await physics_frame
	_check(gold.global_position.y > start.y + 0.2, "el resorte levanta el cuerpo físico")
	_check(gold.global_position.x > start.x + 0.15, "el resorte desplaza el cuerpo físico")
	gold.linear_velocity = Vector3(3.0, 1.0, 0)
	grabber._release()
	_check(not gold.is_grabbed and gold.linear_velocity.length() > 1.0, "soltar conserva velocidad")
	_check(
		gold.linear_velocity.length() <= grabber.max_release_speed, "velocidad de suelta limitada"
	)

	if failures > 0:
		printerr("Physics interaction tests: %d errores" % failures)
		quit(1)
	else:
		print("Physics interaction tests OK")
		quit(0)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
