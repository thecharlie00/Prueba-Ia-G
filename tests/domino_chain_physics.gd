extends SceneTree

const GUIDED_SCENE := preload("res://scenes/GuidedDomino.tscn")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := GUIDED_SCENE.instantiate() as GuidedDomino
	root.add_child(view)
	await _ticks(2)
	var tile: Domino3D = view.tiles[1]
	var entry := {"id": view.tile_ids[tile], "left": tile.left_value, "right": tile.right_value}
	var slots: Array[Rect2] = []
	for index in range(28):
		var position := view._chain_position(index)
		var turn := index % 7 == 6
		var half := Vector2(0.11, 0.22) if turn else Vector2(0.22, 0.11)
		var rect := Rect2(Vector2(position.x, position.z) - half, half * 2.0)
		_check(
			rect.position.x >= -1.84 and rect.end.x <= 1.84, "cadena dentro del ancho del tablero"
		)
		_check(
			rect.position.y >= -1.84 and rect.end.y <= 1.84, "cadena dentro del fondo del tablero"
		)
		for previous in slots:
			_check(not rect.intersects(previous), "objetivos de la cadena no se solapan")
		if not slots.is_empty():
			_check(rect.grow(0.025).intersects(slots.back()), "fichas consecutivas quedan próximas")
		slots.append(rect)
		var target: Quaternion = view._chain_rotation(index, entry, tile)
		var direction: Vector3 = target * Vector3.RIGHT
		var expected := (
			Vector3(0, 0, 1) if turn else (Vector3.RIGHT if index / 7 % 2 == 0 else Vector3.LEFT)
		)
		_check(direction.is_equal_approx(expected), "orientación sigue el orden de la cadena")
		var reversed := {"id": entry["id"], "left": tile.right_value, "right": tile.left_value}
		if tile.left_value != tile.right_value:
			_check(
				(view._chain_rotation(index, reversed, tile) * Vector3.RIGHT).is_equal_approx(
					-expected
				),
				"orientación invierte los extremos cuando corresponde"
			)

	# Aislar un cuerpo para comprobar el resorte angular sin congelarlo ni teletransportarlo.
	for other in view.tiles:
		if other != tile:
			view.homes.erase(other)
			view.home_rotations.erase(other)
			other.queue_free()
	await process_frame
	tile.freeze = true
	tile.global_position = Vector3(0, 1.05, 0)
	tile.quaternion = Quaternion(Vector3.UP, PI * 0.25)
	tile.linear_velocity = Vector3.ZERO
	tile.angular_velocity = Vector3.ZERO
	await _ticks(2)
	tile.freeze = false
	tile.sleeping = false
	view.homes[tile] = Vector3(0, view.BOARD_HEIGHT + 0.04, 0)
	var target := Quaternion(Vector3.UP, PI)
	view.home_rotations[tile] = target
	var start_rotation := tile.quaternion
	await _ticks(240)
	var dot := absf(tile.quaternion.normalized().dot(target))
	_check(not tile.freeze, "la orientación asistida no congela el cuerpo")
	_check(absf(start_rotation.dot(target)) < dot, "el resorte angular reduce el error")
	_check(dot > 0.98, "la orientación física converge cerca del objetivo")
	_check(tile.global_basis.y.dot(Vector3.UP) > 0.9, "la cara superior queda hacia arriba")
	view.queue_free()
	await process_frame
	await _test_chain_contacts()
	if failures:
		printerr("Domino chain physics: %d errores" % failures)
		quit(1)
	else:
		print("Domino chain physics tests OK")
		quit(0)


func _test_chain_contacts() -> void:
	var view := GUIDED_SCENE.instantiate() as GuidedDomino
	root.add_child(view)
	await _ticks(2)
	var chain_tiles: Array[Domino3D] = []
	for i in range(8):
		chain_tiles.append(view.tiles[i])
	for other in view.tiles:
		if other not in chain_tiles:
			view.homes.erase(other)
			other.queue_free()
	view.rules.chain.clear()
	for tile in chain_tiles:
		var id: int = view.tile_ids[tile]
		view.rules.hands[0].erase(id)
		view.rules.hands[1].erase(id)
		view.rules.stock.erase(id)
		view.rules.chain.append({"id": id, "left": tile.right_value, "right": tile.left_value})
	view.tiles = chain_tiles
	view._sync_homes(false)
	for tile in chain_tiles:
		tile.freeze = true
		tile.global_position = view.homes[tile] + Vector3.UP * 0.1
		tile.quaternion = Quaternion.IDENTITY
		tile.linear_velocity = Vector3.ZERO
		tile.angular_velocity = Vector3.ZERO
	await _ticks(2)
	for tile in chain_tiles:
		tile.freeze = false
		tile.sleeping = false
	await _ticks(420)
	for tile in chain_tiles:
		var home: Vector3 = view.homes[tile]
		var actual: Vector3 = tile.global_position
		var distance := Vector2(home.x - actual.x, home.z - actual.z).length()
		var target: Quaternion = view.home_rotations[tile]
		_check(not tile.freeze and tile.collision_mask == 3, "las fichas mantienen colisiones")
		_check(distance < 0.12, "la ficha se estabiliza cerca de la cadena")
		_check(absf(tile.quaternion.dot(target)) > 0.94, "la ficha se orienta cerca de su destino")
		_check(
			tile.linear_velocity.length() < 0.15, "la cadena se estabiliza sin movimiento excesivo"
		)
	view.queue_free()
	await process_frame


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 15:
			printerr("FALLO: " + message)
