extends SceneTree

const TEST_SAVE := "user://test_diceon_domino.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for seed_value in range(20):
		_play_and_check_replays(seed_value)
	_test_invalid_records()
	await _test_view()
	if failures:
		printerr("Domino save: %d errores" % failures)
		quit(1)
	else:
		print("Domino save tests OK · 20 partidas con replay")
		quit(0)


func _play_and_check_replays(seed_value: int) -> void:
	var rules := DominoRules.new()
	rules.reset(seed_value)
	var step := 0
	while rules.result == DominoRules.PLAYING and step < 150:
		var moves := _moves(rules)
		if not moves.is_empty():
			var move: Dictionary = moves[(seed_value + step) % moves.size()]
			_check(rules.play(move["id"], move["end"]), "jugada de partida")
		elif not rules.stock.is_empty():
			_check(rules.draw() >= 0, "robo de partida")
		else:
			_check(rules.pass_turn(), "pase de partida")
		step += 1
		if step % 7 == 0 or rules.result != DominoRules.PLAYING:
			var record: Variant = JSON.parse_string(JSON.stringify(rules.export_record()))
			var restored := DominoRules.new()
			_check(restored.import_record(record), "replay válido")
			_check(
				restored.hands == rules.hands and restored.stock == rules.stock,
				"replay conserva manos y pozo"
			)
			_check(
				restored.chain == rules.chain and restored.turn == rules.turn,
				"replay conserva cadena y turno"
			)
			_check(
				restored.result == rules.result and restored.passes == rules.passes,
				"replay conserva resultado y pases"
			)
	_check(rules.result != DominoRules.PLAYING, "replay termina la partida")


func _test_invalid_records() -> void:
	var rules := DominoRules.new()
	rules.reset(12)
	var saved := rules.export_record()
	var target := DominoRules.new()
	target.reset(99)
	var before := target.export_record()
	var invalid: Dictionary = saved.duplicate(true)
	invalid["hands"][0][0] = invalid["hands"][1][0]
	_check(not target.import_record(invalid), "rechazar fichas duplicadas")
	invalid = saved.duplicate(true)
	invalid["stock"][0] = 2.5
	_check(not target.import_record(invalid), "rechazar identificador no entero")
	invalid = saved.duplicate(true)
	invalid["events"] = [{"type": "draw"}]
	_check(not target.import_record(invalid), "rechazar robo si hay jugada inicial")
	invalid = saved.duplicate(true)
	invalid["events"] = [{"type": "play", "id": saved["hands"][1][0], "end": "left"}]
	_check(not target.import_record(invalid), "rechazar jugada del otro jugador")
	invalid = saved.duplicate(true)
	invalid["events"] = [{"type": "pass"}]
	_check(not target.import_record(invalid), "rechazar pase ilegal")
	invalid = saved.duplicate(true)
	invalid["events"] = []
	invalid["events"].resize(129)
	_check(not target.import_record(invalid), "limitar historial")
	_check(target.export_record() == before, "archivo inválido no altera la partida")


func _test_view() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var view := (
		(load("res://scenes/GuidedDomino.tscn") as PackedScene).instantiate() as GuidedDomino
	)
	root.add_child(view)
	await process_frame
	view.grabber.set_physics_process(false)
	view.save_path = TEST_SAVE
	view.rules.reset(33)
	view._sync_homes(true)
	view._refresh()
	var move: Dictionary = _moves(view.rules)[0]
	_simulated_release(view, move["id"], move["end"])
	var record := view.rules.export_record()
	(view.get_node("UI/Panel/Margin/Content/SaveRow/Save") as Button).pressed.emit()
	_check(FileAccess.file_exists(TEST_SAVE), "botón guarda partida")
	var saved_json := FileAccess.get_file_as_string(TEST_SAVE)
	var another := _moves(view.rules)
	if another.is_empty():
		view._draw()
	else:
		_simulated_release(view, another[0]["id"], another[0]["end"])
	_check(view.rules.events.size() > record["events"].size(), "la partida cambió antes de cargar")
	(view.get_node("UI/Panel/Margin/Content/SaveRow/Load") as Button).pressed.emit()
	_check(view.rules.export_record() == record, "carga restaura el historial")
	_check(view.rules.chain.size() == 1 and view.rules.turn == 1, "carga restaura cadena y turno")
	var tile := _tile(view, int(record["events"][0]["id"]))
	_check(
		view.homes[tile] == view._chain_position(0), "carga devuelve un destino físico de cadena"
	)
	_check(
		view.home_rotations.has(tile) and not tile.freeze, "carga restaura asistencia sin congelar"
	)
	view.grabber.held = tile
	tile.on_grab()
	view._save_game()
	view._load_game()
	_check(
		(
			view.rules.export_record() == record
			and FileAccess.get_file_as_string(TEST_SAVE) == saved_json
		),
		"no guardar ni cargar mientras se agarra"
	)
	view.grabber._release("cancelled")
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{archivo inválido")
	file.close()
	var previous_home: Vector3 = view.homes[tile]
	view._load_game()
	_check(
		view.rules.export_record() == record and view.homes[tile] == previous_home,
		"carga corrupta no altera la escena"
	)
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("x".repeat(view.MAX_SAVE_BYTES + 1))
	file.close()
	view._load_game()
	_check(view.rules.export_record() == record, "archivo grande no altera la partida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	view.queue_free()
	await process_frame


func _moves(rules: DominoRules) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for id in rules.hands[rules.turn]:
		for end in rules.legal_ends(id):
			moves.append({"id": id, "end": end})
	return moves


func _tile(view: GuidedDomino, id: int) -> Domino3D:
	for tile in view.tiles:
		if int(view.tile_ids[tile]) == id:
			return tile
	return null


func _simulated_release(view: GuidedDomino, id: int, end: String) -> void:
	var tile := _tile(view, id)
	view.grabber.hovered = tile
	var mouse: Vector2 = view.grabber.camera.unproject_position(tile.global_position)
	view.grabber._begin_grab(mouse)
	var target: Vector3 = (view.LEFT_ZONE if end == "left" else view.RIGHT_ZONE) + Vector3.UP * 0.5
	view.grabber._target = target
	tile.global_position = target
	view.grabber._release()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		if failures <= 15:
			printerr("FALLO: " + message)
