extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := load("res://scenes/Ludo.tscn").instantiate() as LudoView
	root.add_child(view)
	await _ticks(3)
	_check(view.rules.players == 2 and view.tokens.size() == 4, "mesa de dos y fichas físicas")
	view._new_game()
	_check(view.new_game_confirmation.visible, "nueva partida solicita confirmación")
	view.new_game_confirmation.hide()
	_check(not view.tokens[2][0].visible and view.tokens[2][0].freeze, "colores inactivos")
	_check(not view.grabber.dice_shortcuts_enabled, "el dado lo coordina el modo")
	_check(view.markers.all(func(marker): return not marker.visible), "sin destinos antes de tirar")
	# Soltar físicamente el dado inicia una tirada; recolocar cancela sin modificar reglas.
	view.grabber.hovered = view.die
	view.grabber._begin_grab(view.camera.unproject_position(view.die.global_position))
	_check(view.grabber.held == view.die, "agarra dado")
	view.grabber._release()
	_check(view.waiting_roll and view.rules.events.is_empty(), "suelta dado sin valor inventado")
	view._reset_die()
	_check(not view.waiting_roll and view.rules.events.is_empty(), "recolocar cancela tirada")
	# La tirada de teclado espera realmente a la física y lee su cara superior.
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(view.waiting_roll, "R lanza el dado")
	for tick in range(750):
		if not view.waiting_roll:
			break
		await physics_frame
	_check(not view.waiting_roll and view.rules.events.size() == 1, "tirada física se resuelve")
	if view.rules.events.size() == 1:
		_check(
			view.rules.events[0]["value"] == view.die.top_face(), "cara física y regla coinciden"
		)
	# Secuencia reproducible desde el modelo para probar interfaz, movimiento físico y replay.
	view.rules = LudoRules.new(2)
	_check(view.rules.apply_roll(6), "dado válido")
	view._refresh()
	_check(
		not view.token_buttons[0].disabled and view.markers[0].visible, "fichas legales y marcas"
	)
	var token: Token3D = view.tokens[0][0]
	var start := token.global_position
	view._choose_token(0)
	_check(view.rules.positions[0][0] == 0 and view.rules.turn == 0, "botón confirma salida")
	await _ticks(180)
	var goal: Vector3 = view._token_position(0, 0, 0)
	_check(token.global_position.distance_to(start) > 0.1, "ficha dinámica se desplaza")
	_check(
		Vector2(token.global_position.x - goal.x, token.global_position.z - goal.z).length() < 0.15,
		"ficha asistida llega al destino"
	)
	view.save_path = "user://test_ludo.json"
	_clean_save(view.save_path)
	view._save_game()
	var saved := FileAccess.get_file_as_string(view.save_path)
	_check(not saved.is_empty(), "guardado lógico")
	view.rules.apply_roll(1)
	view.rules.move(0)
	view._load_game()
	_check(
		view.rules.positions[0][0] == 0 and view.rules.phase == LudoRules.ROLL,
		"carga reconstruye estado"
	)
	var file := FileAccess.open(view.save_path, FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	view._load_game()
	_check(view.rules.positions[0][0] == 0, "carga inválida no altera partida")
	file = FileAccess.open(view.save_path, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	var events: Array[Dictionary] = view.rules.events.duplicate(true)
	view.rules.events.resize(LudoRules.MAX_EVENTS + 1)
	view._save_game()
	_check(
		FileAccess.get_file_as_string(view.save_path) == saved,
		"guardado excesivo conserva anterior"
	)
	view.rules.events = events
	# Una suelta cancelada nunca confirma; una suelta legal sí.
	view.rules.apply_roll(1)
	view._refresh()
	var dest: Vector3 = view._token_position(0, 0, 1)
	view._on_release(token, dest, "cancelled")
	_check(view.rules.positions[0][0] == 0, "suelta cancelada no mueve")
	token.global_position = dest + Vector3.UP * 0.1
	view._on_release(token, dest, "released")
	_check(view.rules.positions[0][0] == 1 and view.rules.turn == 1, "suelta legal mueve")
	# Una captura también desplaza físicamente la ficha rival hasta su casa.
	view.rules = LudoRules.new(2)
	view.rules.positions[0][0] = 4
	view.rules.positions[1][0] = 44
	for player in range(2):
		var piece: Token3D = view.tokens[player][0]
		piece.global_position = (
			view._token_position(player, 0, view.rules.positions[player][0]) + Vector3.UP * 0.1
		)
		piece.linear_velocity = Vector3.ZERO
	view.rules.apply_roll(1)
	view._choose_token(0)
	_check(view.rules.positions[1][0] == LudoRules.YARD, "captura lógica")
	await _ticks(360)
	var captured: Token3D = view.tokens[1][0]
	var yard: Vector3 = view._yard_position(1, 0)
	_check(
		(
			(
				Vector2(captured.global_position.x - yard.x, captured.global_position.z - yard.z)
				. length()
			)
			< 0.16
		),
		"ficha capturada vuelve físicamente a casa"
	)
	_clean_save(view.save_path)
	view.queue_free()
	for count in [3, 4]:
		var instance := load("res://scenes/Ludo%d.tscn" % count).instantiate() as LudoView
		root.add_child(instance)
		await process_frame
		_check(
			instance.rules.players == count and instance.tokens[count - 1][0].visible,
			"modo %d jugadores" % count
		)
		instance.queue_free()
	if failures:
		printerr("Ludo view: %d errores" % failures)
		quit(1)
	else:
		print("Ludo view tests OK")
		quit(0)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _clean_save(path: String) -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
