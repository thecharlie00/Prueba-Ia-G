extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/GuidedDomino.tscn")
	var view := packed.instantiate() as GuidedDomino
	root.add_child(view)
	await _ticks(2)
	view.rules.reset(5)
	view._sync_homes(true)
	view._refresh()
	await _ticks(70)
	view.grabber.set_physics_process(false)
	_check(view.tiles.size() == 28 and view.homes.size() == 28, "hay 28 fichas físicas asociadas")
	_check(view.rules.hands[0].size() == 7 and view.rules.hands[1].size() == 7, "manos iniciales")
	_check(view.rules.stock.size() == 14, "pozo inicial")

	var first_id: int = view.rules.hands[0][0]
	var first := _tile(view, first_id)
	_start_grab(view, first)
	_check(view._legal_ends.size() == 2, "apertura permite ambos extremos")
	var target: Vector3 = view.LEFT_ZONE + Vector3.UP * 0.65
	view.grabber._target = target
	for i in range(150):
		view.grabber._apply_held_force()
		await physics_frame
	_check(
		view._horizontal_distance(first.global_position, target) <= view.ZONE_RADIUS,
		"el resorte lleva la ficha a la zona"
	)
	view.grabber._release()
	_check(view.rules.chain.size() == 1 and view.rules.turn == 1, "se confirma apertura física")
	_check(view.homes[first] == _chain_home(view, 0), "ficha jugada tiene destino físico de cadena")
	_check(not first.freeze and not first.is_grabbed, "ficha sigue dinámica al soltar")

	var before: Array = view.rules.chain.duplicate(true)
	var wrong_id: int = view.rules.hands[0][0]
	_start_grab(view, _tile(view, wrong_id))
	var stock_before := view.rules.stock.size()
	view._draw()
	view._pass()
	_check(
		view.rules.chain == before and view.rules.stock.size() == stock_before,
		"no robar ni pasar con una ficha agarrada"
	)
	view.grabber._release("cancelled")
	_simulated_release(view, wrong_id, "left", true)
	_check(view.rules.chain == before, "no jugar una ficha del rival")
	var playable := _first_move(view.rules)
	if not playable.is_empty():
		_simulated_release(view, playable["id"], playable["end"], false)
		_check(view.rules.chain == before, "no confirmar si el cuerpo no llegó")
		_simulated_release(view, playable["id"], playable["end"], true, "cancelled")
		_check(view.rules.chain == before, "la cancelación no confirma jugada")
		_simulated_release(view, playable["id"], playable["end"], true, "recovered")
		_check(view.rules.chain == before, "recuperar no confirma jugada")
		_start_grab(view, _tile(view, playable["id"]))
		view.grabber._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		view.grabber._physics_process(1.0 / 60.0)
		_check(
			view.grabber.held == null and view.rules.chain == before,
			"perder foco cancela el agarre"
		)
		_simulated_release(view, playable["id"], playable["end"], true)
		_check(
			view.rules.chain.size() == 2 and view.rules.turn == 0, "jugada compatible cambia turno"
		)

	# Un desplazamiento físico no modifica el modelo; vuelve con la fuerza asistida.
	var stable: Array = view.rules.chain.duplicate(true)
	var token := _tile(view, view.rules.hands[view.rules.turn][0])
	var home: Vector3 = view.homes[token]
	token.global_position = Vector3(home.x + 0.2, 1.0, home.z)
	token.linear_velocity = Vector3.ZERO
	token.sleeping = false
	var distance_before := absf(token.global_position.x - home.x)
	await _ticks(100)
	_check(view.rules.chain == stable, "una colisión no altera la cadena")
	_check(absf(token.global_position.x - home.x) < distance_before, "la fuerza devuelve la ficha")

	# Completar una partida mediante las acciones de la vista y comprobar también el robo.
	var steps := 0
	var drew := false
	while view.rules.result == DominoRules.PLAYING and steps < 150:
		var move := _first_move(view.rules)
		if not move.is_empty():
			_simulated_release(view, move["id"], move["end"], true)
		elif not view.rules.stock.is_empty():
			var old_stock := view.rules.stock.size()
			var old_hand: int = view.rules.hands[view.rules.turn].size()
			(view.get_node("UI/Panel/Margin/Content/Actions/Draw") as Button).pressed.emit()
			_check(view.rules.stock.size() == old_stock - 1, "botón roba del pozo")
			_check(
				view.rules.hands[view.rules.turn].size() == old_hand + 1,
				"robo añade ficha a la mano"
			)
			var drawn_id: int = view.rules.hands[view.rules.turn].back()
			_check(
				view.homes[_tile(view, drawn_id)] == view._hand_position(view.rules.turn, old_hand),
				"ficha robada vuelve a la mano por fuerzas"
			)
			drew = true
		else:
			view._pass()
		steps += 1
	_check(drew, "partida de prueba alcanza una situación de robo")
	_check(
		view.rules.result != DominoRules.PLAYING and steps < 150, "la vista completa una partida"
	)
	_check(
		view.status_label.text.contains("Gana") or view.status_label.text.contains("Empate"),
		"resultado final visible"
	)
	# Posición sintética bloqueada para comprobar el botón de pase y el resultado.
	var end_id: int = view.rules.values.find(Vector2i(2, 5))
	var white_id: int = view.rules.values.find(Vector2i(0, 0))
	var black_id: int = view.rules.values.find(Vector2i(1, 1))
	view.rules.chain = [{"id": end_id, "left": 2, "right": 5}]
	view.rules.hands = [[white_id], [black_id]]
	view.rules.stock.clear()
	view.rules.turn = 0
	view.rules.passes = 0
	view.rules.result = DominoRules.PLAYING
	view._refresh()
	var pass_button: Button = view.get_node("UI/Panel/Margin/Content/Actions/Pass")
	_check(not pass_button.disabled, "pase disponible con pozo vacío y sin jugada")
	pass_button.pressed.emit()
	_check(view.rules.turn == 1, "botón de pase cambia el turno")
	pass_button.pressed.emit()
	_check(view.rules.result == DominoRules.PLAYER_1_WINS, "botón de pase cierra bloqueo")
	_check(view.status_label.text.contains("Gana el jugador 1"), "resultado visible en el panel")
	view.queue_free()
	await process_frame
	if failures:
		printerr("Guided domino: %d errores" % failures)
		quit(1)
	else:
		print("Guided domino tests OK")
		quit(0)


func _tile(view: GuidedDomino, id: int) -> Domino3D:
	for tile in view.tiles:
		if int(view.tile_ids[tile]) == id:
			return tile
	return null


func _first_move(rules: DominoRules) -> Dictionary:
	for id in rules.hands[rules.turn]:
		var ends := rules.legal_ends(id)
		if not ends.is_empty():
			return {"id": id, "end": ends[0]}
	return {}


func _start_grab(view: GuidedDomino, tile: Domino3D) -> void:
	view.grabber.hovered = tile
	var mouse: Vector2 = view.grabber.camera.unproject_position(tile.global_position)
	view.grabber._begin_grab(mouse)


func _simulated_release(
	view: GuidedDomino, id: int, end: String, arrive: bool, reason := "released"
) -> void:
	var tile := _tile(view, id)
	_start_grab(view, tile)
	var target: Vector3 = (view.LEFT_ZONE if end == "left" else view.RIGHT_ZONE) + Vector3.UP * 0.5
	view.grabber._target = target
	if arrive:
		tile.global_position = target
	else:
		tile.global_position = Vector3(-2.7, 1.0, -1.6)
	view.grabber._release(reason)


func _chain_home(view: GuidedDomino, index: int) -> Vector3:
	return view._chain_position(index)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
