extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := (
		(load("res://scenes/PhysicalChess.tscn") as PackedScene).instantiate() as PhysicalChess
	)
	root.add_child(view)
	await _ticks(2)
	var pieces: Array[Node] = view.objects.get_children()
	_check(pieces.size() == 32, "32 piezas físicas")
	var counts := {}
	for child in pieces:
		var piece := child as PhysicalChessPiece
		_check(piece != null, "pieza rígida de ajedrez")
		if piece == null:
			continue
		var id := "%d:%s" % [piece.piece_type, piece.white]
		counts[id] = int(counts.get(id, 0)) + 1
		_check(
			piece.collision_layer == 2 and piece.collision_mask == 3 and not piece.freeze,
			"colisiones activas"
		)
		_check(piece.continuous_cd, "CCD activado")
		var model := piece.get_node("Visual/ChessModel") as Node3D
		_check(int(model.get_meta("kind")) == piece.piece_type, "silueta corresponde al tipo")
		_check(
			(
				(model.get_node("PieceLetter") as Label3D).text
				== ChessPieceModel.SYMBOLS[piece.piece_type]
			),
			"letra de identificación"
		)
		_check(
			(
				absf(
					piece.bottom_offset() - (ChessPieceModel.height(piece.piece_type) + 0.01) / 2.0
				)
				< 0.001
			),
			"colisionador ajustado a la altura"
		)
	for color in [true, false]:
		for kind in range(1, 7):
			var expected := 8 if kind == 1 else (1 if kind >= 5 else 2)
			_check(
				int(counts.get("%d:%s" % [kind, color], 0)) == expected,
				"inventario por tipo y color"
			)
	var rook: PhysicalChessPiece
	var knight: PhysicalChessPiece
	var bishop: PhysicalChessPiece
	var queen: PhysicalChessPiece
	var king: PhysicalChessPiece
	for child in pieces:
		var p := child as PhysicalChessPiece
		if not p.white:
			continue
		match p.piece_type:
			2:
				knight = p
			3:
				bishop = p
			4:
				rook = p
			5:
				queen = p
			6:
				king = p
	_check(rook.has_node("Visual/ChessModel/Merlon0"), "torre tiene almenas")
	_check(
		knight.has_node("Visual/ChessModel/KnightProfile/Muzzle"), "caballo tiene perfil y hocico"
	)
	_check(bishop.has_node("Visual/ChessModel/Mitre"), "alfil tiene mitra")
	_check(queen.has_node("Visual/ChessModel/Jewel0"), "dama tiene corona")
	_check(king.has_node("Visual/ChessModel/CrossArm"), "rey tiene cruz")
	await _ticks(100)
	var first := pieces[8] as PhysicalChessPiece
	var second := pieces[9] as PhysicalChessPiece
	_check(
		absf(first.global_position.y - view.BOARD_HEIGHT - first.bottom_offset()) < 0.05,
		"pieza descansa sobre tablero"
	)
	# Aislar dos piezas para comprobar choque y agarre con el mismo controlador físico.
	for piece in pieces:
		if piece != first and piece != second:
			piece.queue_free()
	await process_frame
	first.freeze = true
	second.freeze = true
	first.quaternion = Quaternion.IDENTITY
	second.quaternion = Quaternion.IDENTITY
	first.global_position = Vector3(-1.0, view.BOARD_HEIGHT + first.bottom_offset(), 0)
	second.global_position = Vector3(-0.3, view.BOARD_HEIGHT + second.bottom_offset(), 0)
	first.linear_velocity = Vector3.ZERO
	second.linear_velocity = Vector3.ZERO
	await _ticks(2)
	first.freeze = false
	second.freeze = false
	first.sleeping = false
	second.sleeping = false
	first.linear_velocity = Vector3(3.0, 0, 0)
	var initial_x: float = second.global_position.x
	await _ticks(50)
	_check(second.global_position.x > initial_x + 0.04, "choque desplaza otra pieza")
	second.queue_free()
	first.freeze = true
	first.quaternion = Quaternion.IDENTITY
	first.global_position = Vector3(0, view.BOARD_HEIGHT + first.bottom_offset(), 0)
	first.linear_velocity = Vector3.ZERO
	first.angular_velocity = Vector3.ZERO
	await _ticks(2)
	first.freeze = false
	first.sleeping = false
	view.grabber.set_physics_process(false)
	var mouse: Vector2 = view.grabber.camera.unproject_position(first.global_position)
	view.grabber._update_hover(mouse)
	_check(view.grabber.hovered == first, "rayo selecciona la pieza modelada")
	view.grabber._begin_grab(mouse)
	_check(first.is_grabbed and view.grabber.held == first, "agarrar ajedrez físico")
	var start: Vector3 = first.global_position
	view.grabber._target = start + Vector3.UP * 0.5
	for i in range(45):
		view.grabber._apply_held_force()
		await physics_frame
	_check(first.global_position.y > start.y + 0.2, "resorte levanta pieza")
	view.grabber._release()
	_check(not first.is_grabbed and not first.freeze, "liberar conserva dinámica")
	view.queue_free()
	await process_frame
	if failures:
		printerr("Physical chess: %d errores" % failures)
		quit(1)
	else:
		print("Physical chess tests OK")
		quit(0)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
