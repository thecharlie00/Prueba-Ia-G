extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := load("res://scenes/Island.tscn").instantiate() as IslandView
	root.add_child(view)
	await process_frame
	_check(view.new_game_confirmation != null, "la nueva isla tiene confirmación")
	_check(
		view.new_game_confirmation.confirmed.is_connected(view._confirm_new_game),
		"la confirmación inicia una nueva isla"
	)
	view._new_game()
	_check(view.new_game_confirmation.visible, "se abre el diálogo de nueva isla")
	view.new_game_confirmation.hide()
	var game := view.rules
	game.phase = IslandRules.ACTION
	view._set_mode("")
	game.resources[0] = [4, 0, 0, 0, 0]
	game.resources[1] = [0, 0, 3, 0, 0]
	game.dev_ready[0][IslandRules.VICTORY_POINT] = 2
	game.dev_new[0][IslandRules.KNIGHT] = 1
	game.dev_new[1][IslandRules.MONOPOLY_CARD] = 1
	view._refresh()
	_check(game.public_score(0) == 0 and game.score(0) == 2, "puntos secretos no públicos")
	_check("J1 naranja · 0 puntos" in view.hands.text, "marcador público oculta puntos secretos")
	_check("Caballeros 1" in view.dev_status.text, "se identifica la carta nueva")
	_check(not view.privacy_locked, "privacidad opcional desactivada inicialmente")
	view._toggle_privacy()
	_check(view.privacy_locked and view.privacy_overlay.visible, "activar oculta la pantalla")
	_check(
		(
			not view.get_node("IslandUI/Panel").visible
			and not view.get_node("IslandUI/ResourceHand").visible
		),
		"la interfaz subyacente no recibe foco ni muestra la mano"
	)
	_check(root.gui_get_focus_owner() == view.privacy_ready, "foco en confirmar el traspaso")
	_check(not view.grabber.is_processing_unhandled_input(), "bloquea agarre durante el cambio")
	view._unlock_privacy()
	_check(not view.privacy_locked and view.privacy_owner == 0, "J1 confirma su mano")
	_check(view.get_node("IslandUI/Panel").visible, "vuelve a mostrarse la interfaz")
	_check(view.grabber.is_processing_unhandled_input(), "agarre reactivado")
	_check(game.propose_trade(1, [1, 0, 0, 0, 0], [0, 0, 1, 0, 0]), "proponer a J2")
	view._refresh()
	_check(view.privacy_locked and view.privacy_owner == 1, "pasar al destinatario")
	_check(
		"J2" in view.hand_heading.text and view.hand3d.items.filter(func(item: Dictionary) -> bool: return item.get("resource", -1) == 2).size() == 3,
		"mano del destinatario"
	)
	_check("Monopolio 1" in view.dev_status.text, "cartas nuevas del destinatario")
	view._unlock_privacy()
	view._respond_trade(true)
	_check(game.resources[0][2] == 1 and game.resources[1][0] == 1, "intercambio aplicado")
	_check(view.privacy_locked and view.privacy_owner == 0, "regreso al jugador del turno")
	view._unlock_privacy()
	game.phase = IslandRules.DISCARD
	game.discard_due = [0, 1, 1]
	game.discard_player = 1
	game.resources[2] = [0, 1, 0, 0, 0]
	view._refresh()
	_check(view.privacy_locked and view.privacy_owner == 1, "paso a quien descarta")
	view._unlock_privacy()
	view._resource_pressed(2)
	_check(
		game.discard_player == 2 and view.privacy_locked, "cambio entre descartes de la misma fase"
	)
	view._unlock_privacy()
	view._resource_pressed(1)
	_check(
		game.phase == IslandRules.ROBBER and view.privacy_owner == 0 and view.privacy_locked,
		"regreso para mover ladrón"
	)
	view._unlock_privacy()
	game.phase = IslandRules.ROLL
	game.turn = 1
	view._refresh()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	view._unhandled_input(key)
	_check(not view.waiting_roll, "atajo bloqueado durante el traspaso")
	view._unlock_privacy()
	view._unhandled_input(key)
	_check(view.waiting_roll, "atajo disponible tras confirmar")
	view._cancel_roll()
	view.save_path = "user://test_island_privacy.json"
	_clean_save(view.save_path)
	var file := FileAccess.open(view.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(IslandRules.new(17).export_record()))
	file.close()
	view._load_game()
	_check(view.privacy_locked and view.privacy_owner == 0, "cargar pide nueva confirmación")
	_clean_save(view.save_path)
	view._unlock_privacy()
	view._toggle_privacy()
	_check(not view.privacy_locked and not view.privacy_overlay.visible, "privacidad desactivable")
	view.queue_free()
	var four := load("res://scenes/IslandFour.tscn").instantiate() as IslandView
	root.add_child(four)
	await process_frame
	four.rules.phase = IslandRules.ACTION
	four._set_mode("")
	four.rules.resources[0] = [1, 0, 0, 0, 0]
	four.rules.resources[3] = [0, 1, 0, 0, 0]
	four._toggle_privacy()
	four._unlock_privacy()
	_check(
		four.rules.propose_trade(3, [1, 0, 0, 0, 0], [0, 1, 0, 0, 0]), "J4 puede recibir una oferta"
	)
	four._refresh()
	_check(
		four.privacy_locked and four.privacy_owner == 3 and "J4" in four.hand_heading.text,
		"traspaso y mano de J4"
	)
	four._unlock_privacy()
	four._respond_trade(false)
	_check(four.privacy_locked and four.privacy_owner == 0, "rechazo vuelve a J1")
	four.queue_free()
	if failures:
		printerr("Island privacy: %d errores" % failures)
		quit(1)
	else:
		print("Island privacy tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _clean_save(path: String) -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
