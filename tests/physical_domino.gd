extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/PhysicalDomino.tscn")
	var view := packed.instantiate() as PhysicalDomino
	root.add_child(view)
	await _ticks(2)
	var tiles: Array[Node] = view.objects.get_children()
	_check(tiles.size() == 28, "el doble seis contiene 28 fichas")
	var values := {}
	var sum := 0
	for child in tiles:
		var tile := child as Domino3D
		_check(tile != null, "cada ficha es un cuerpo rígido de dominó")
		if tile == null:
			continue
		var key := "%d-%d" % [tile.left_value, tile.right_value]
		_check(not values.has(key), "combinación única " + key)
		values[key] = true
		_check(
			tile.left_value <= tile.right_value and tile.right_value <= 6, "valores de doble seis"
		)
		_check(tile.collision_layer == 2 and tile.collision_mask == 3, "colisiones activas")
		_check(tile.continuous_cd and not tile.freeze, "ficha dinámica con CCD")
		_check(
			tile.get_node("Visual/Pips").get_child_count() == tile.left_value + tile.right_value,
			"cantidad de puntos coincide con valores"
		)
		sum += tile.left_value + tile.right_value
	_check(values.size() == 28 and sum == 168, "conjunto completo y suma total 168")
	_check(view.grabber.snap_grid == null, "no hay snap obligatorio")
	await _ticks(100)
	var first := tiles[0] as Domino3D
	var second := tiles[1] as Domino3D
	_check(absf(first.global_position.y - 0.87) < 0.03, "la gravedad apoya el dominó en el tablero")
	_check(absf(first.bottom_offset() - 0.04) < 0.02, "altura de colisionador físico")

	# Apartar las otras fichas permite comprobar colisión y arrastre sin obstáculos accidentales.
	for i in range(2, tiles.size()):
		tiles[i].queue_free()
	await process_frame
	first.freeze = true
	second.freeze = true
	first.global_position = Vector3(-1.1, 0.87, 0.0)
	second.global_position = Vector3(-0.4, 0.87, 0.0)
	first.linear_velocity = Vector3.ZERO
	second.linear_velocity = Vector3.ZERO
	await _ticks(2)
	first.freeze = false
	second.freeze = false
	first.sleeping = false
	second.sleeping = false
	first.linear_velocity = Vector3(3.0, 0, 0)
	var before_x: float = second.global_position.x
	await _ticks(50)
	_check(
		second.global_position.x > before_x + 0.06,
		"una ficha transmite movimiento a otra al chocar"
	)

	# El volteo no congela ni teletransporta: aplica impulso y la física resuelve la cara final.
	first.freeze = true
	first.global_position = Vector3(0.9, 1.2, 1.2)
	first.linear_velocity = Vector3.ZERO
	first.angular_velocity = Vector3.ZERO
	first.quaternion = Quaternion.IDENTITY
	await _ticks(2)
	first.freeze = false
	first.sleeping = false
	await _ticks(2)
	first.linear_velocity = Vector3.ZERO
	first.angular_velocity = Vector3.ZERO
	view.grabber.hovered = first
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	view.grabber._unhandled_input(key)
	_check(not first.freeze, "voltear no congela el cuerpo")
	await _ticks(2)
	_check(first.angular_velocity.length() > 0.1, "F aplica impulso angular al dominó")
	_check(first.linear_velocity.y > 0.0, "F aplica impulso vertical")
	await _ticks(15)
	_check(absf(first.quaternion.x) > 0.01, "el dominó gira físicamente")

	# Aislar la ficha, seleccionarla con rayo y levantarla con el mismo resorte de la mesa.
	second.queue_free()
	first.freeze = true
	first.quaternion = Quaternion.IDENTITY
	first.global_position = Vector3(0.0, 0.87, 0.0)
	first.linear_velocity = Vector3.ZERO
	first.angular_velocity = Vector3.ZERO
	await _ticks(2)
	first.freeze = false
	first.sleeping = false
	view.grabber.set_physics_process(false)
	view.grabber.hovered = null
	var mouse: Vector2 = view.grabber.camera.unproject_position(first.global_position)
	view.grabber._update_hover(mouse)
	_check(view.grabber.hovered == first, "el rayo selecciona el dominó")
	view.grabber._begin_grab(mouse)
	_check(view.grabber.held == first and first.is_grabbed, "se agarra el dominó")
	var start: Vector3 = first.global_position
	view.grabber._target = start + Vector3(0, 0.5, 0)
	for i in range(45):
		view.grabber._apply_held_force()
		await physics_frame
	_check(first.global_position.y > start.y + 0.2, "se eleva mediante fuerzas")
	view.grabber._release()
	_check(not first.is_grabbed and not first.freeze, "al soltar continúa la física")
	view.queue_free()
	await process_frame
	if failures:
		printerr("Physical domino: %d errores" % failures)
		quit(1)
	else:
		print("Physical domino tests OK")
		quit(0)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
