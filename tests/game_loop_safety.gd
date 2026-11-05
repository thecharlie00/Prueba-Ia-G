extends SceneTree

var failures := 0
var actions := 0
var allowed := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_confirmation_helper()
	await _test_scene_actions()
	await _test_guide_and_cancel()
	await _test_context_hints()
	if failures:
		printerr("Game loop safety: %d errores" % failures)
		quit(1)
	else:
		print("Game loop safety tests OK")
		quit(0)


func _test_confirmation_helper() -> void:
	var guard := ConfirmAction.new()
	root.add_child(guard)
	guard.request("Prueba", "Descartar", _action, _allowed)
	_check(guard.dialog.visible, "solicitud abre confirmación")
	guard.dialog.canceled.emit()
	guard.dialog.hide()
	guard.dialog.confirmed.emit()
	_check(actions == 0, "cancelar invalida callback")
	guard.request("Prueba", "Descartar", _action, _allowed)
	allowed = false
	guard.dialog.confirmed.emit()
	_check(actions == 0, "revalida condición al confirmar")
	guard.request("Prueba", "Descartar", _action, _allowed)
	_check(not guard.dialog.visible, "condición impide apertura")
	allowed = true
	guard.request("Prueba", "Descartar", _action, _allowed)
	guard.dialog.confirmed.emit()
	guard.dialog.confirmed.emit()
	_check(actions == 1, "confirmación solo ejecuta una vez")
	guard.queue_free()
	await process_frame


func _test_scene_actions() -> void:
	var scenes := {
		"Main": ["res://scenes/Main.tscn", "UI/Margin/Panel/Content/Reset"],
		"Cards": ["res://scenes/CardTable.tscn", "UI/Panel/Margin/Content/SaveRow/Load"],
		"Chess": ["res://scenes/Chess.tscn", "UI/Panel/Margin/Content/Reset"],
		"Checkers": ["res://scenes/Checkers.tscn", "UI/Panel/Margin/Content/Load"],
		"GuidedChess": ["res://scenes/GuidedPhysicalChess.tscn", "UI/Panel/Margin/Content/Free"],
		"GuidedCheckers":
		["res://scenes/GuidedPhysicalCheckers.tscn", "UI/Panel/Margin/Content/Free"],
		"Domino": ["res://scenes/GuidedDomino.tscn", "UI/Panel/Margin/Content/SaveRow/Load"],
	}
	for name in scenes:
		var data: Array = scenes[name]
		change_scene_to_file(data[0])
		await _frames()
		var view := current_scene
		var guard := view.get("confirm_action") as ConfirmAction
		var button := view.get_node(data[1]) as Button
		button.pressed.emit()
		_check(guard.dialog.visible, name + " pide confirmación")
		guard.dialog.canceled.emit()
		guard.dialog.hide()
		await _frames()
		_check(current_scene == view, name + " cancelar conserva escena")
	for path in ["res://scenes/Ludo.tscn", "res://scenes/Island.tscn"]:
		change_scene_to_file(path)
		await _frames()
		var view := current_scene
		view.call("_request_load")
		var guard := view.get("confirm_action") as ConfirmAction
		_check(guard.dialog.visible, path + " cargar pide confirmación")
		view.set("waiting_roll", true)
		guard.dialog.confirmed.emit()
		_check(
			not guard.dialog.visible and current_scene == view,
			path + " no carga si comienza tirada durante confirmación"
		)
		view.call("_new_game")
		var reset_dialog := view.get("new_game_confirmation") as ConfirmationDialog
		_check(not reset_dialog.visible, path + " no reinicia durante tirada")
		view.set("waiting_roll", false)
		view.call("_new_game")
		_check(reset_dialog.visible, path + " pide confirmación al reiniciar")
		view.set("waiting_roll", true)
		reset_dialog.confirmed.emit()
		reset_dialog.hide()
		await _frames()
		_check(current_scene == view, path + " revalida tirada al reiniciar")
		view.set("waiting_roll", false)


func _test_guide_and_cancel() -> void:
	change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
	await _frames()
	await physics_frame
	var view := current_scene as GuidedPhysicalCheckers
	var nav := root.get_node("SessionNavigation")
	var piece := view._token_at_square(44)
	var before: Array[int] = view.rules.board.duplicate()
	view.grabber.hovered = piece
	view.grabber._begin_grab(view.grabber.camera.unproject_position(piece.global_position))
	_check(view.grabber.held == piece, "agarra ficha antes de cancelar")
	var free_button := view.get_node("UI/Panel/Margin/Content/Free") as Button
	free_button.pressed.emit()
	_check(not view.confirm_action.dialog.visible, "no cambia mesa con ficha agarrada")
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	view.grabber._unhandled_input(key)
	view.grabber._physics_process(1.0 / 60.0)
	_check(view.grabber.held == null, "X libera ficha")
	_check(view.rules.board == before, "X no confirma la jugada")
	free_button.pressed.emit()
	_check(view.confirm_action.dialog.visible, "cambio pide confirmación")
	view.grabber._pending_press = true
	view.confirm_action.dialog.confirmed.emit()
	_check(current_scene == view, "cambio revalida agarre pendiente")
	view.grabber._pending_press = true
	view.grabber._unhandled_input(key)
	_check(not view.grabber._pending_press, "X cancela clic pendiente")
	view.grabber.hovered = piece
	view.grabber._begin_grab(view.grabber.camera.unproject_position(piece.global_position))
	nav.call("_toggle_help")
	_check(nav.controls_dialog.visible and view.grabber.held == null, "ayuda cancela agarre")
	_check(view.rules.board == before, "abrir ayuda no confirma jugada")
	_check(nav.controls_dialog.dialog_text.contains("X:"), "ayuda explica cancelar")
	_check(not nav.controls_dialog.dialog_text.contains("L:"), "ayuda omite bloqueo en mesa guiada")
	nav.controls_dialog.hide()
	var help_key := InputEventKey.new()
	help_key.keycode = KEY_F1
	help_key.pressed = true
	nav.call("_unhandled_input", help_key)
	_check(nav.controls_dialog.visible, "F1 abre la ayuda de controles")
	nav.controls_dialog.hide()


func _test_context_hints() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await _frames()
	var grabber := current_scene.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	var card := current_scene.get_node("Objects/Card") as Card3D
	grabber.set_physics_process(false)
	grabber.hovered = card
	card.card_label = "SECRETO"
	grabber._refresh_context_hint()
	_check(grabber._context_hint.visible, "hay ayuda contextual sobre una carta")
	_check(grabber._context_hint_text.text.contains("F voltear"), "ayuda muestra acción de carta")
	_check(not grabber._context_hint_text.text.contains("SECRETO"), "ayuda no revela carta")
	grabber._inspecting = true
	grabber._refresh_context_hint()
	_check(not grabber._context_hint.visible, "la ayuda no tapa la inspección")
	grabber._inspecting = false
	grabber.held = card
	grabber._refresh_context_hint()
	_check(grabber._context_hint_text.text.contains("X cancelar"), "ayuda del agarre")
	grabber.held = null
	grabber.hovered = null
	grabber._refresh_context_hint()
	_check(not grabber._context_hint.visible, "ayuda desaparece al dejar de señalar")


func _action() -> void:
	actions += 1


func _allowed() -> bool:
	return allowed


func _frames() -> void:
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
