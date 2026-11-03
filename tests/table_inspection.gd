extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := load("res://scenes/CardTable.tscn").instantiate() as CardTable
	root.add_child(view)
	await physics_frame
	view.english.draw_card()
	var card := view.objects.get_child(2) as Card3D
	var grabber := view.grabber
	grabber.hovered = card
	grabber._input(_alt(true))
	_check(grabber._inspection_panel.visible, "Alt inspecciona carta señalada")
	_check(grabber._inspection_body.text.contains(card.card_label), "anverso visible ampliado")
	card.quaternion = Quaternion(Vector3.FORWARD, PI)
	grabber._refresh_inspection()
	_check(grabber._inspection_body.text == "Carta boca abajo", "reverso no revela valor")
	view._on_selection_changed(card)
	_check(not view.status_label.text.contains(card.card_label), "selección tampoco revela valor")
	card.quaternion = Quaternion.IDENTITY
	card.flip()
	grabber._refresh_inspection()
	_check(grabber._inspection_body.text == "Carta boca abajo", "no revela carta durante volteo")
	grabber.hovered = view.english
	var before := view.english.angular_velocity
	var modified_key := InputEventKey.new()
	modified_key.keycode = KEY_E
	modified_key.alt_pressed = true
	modified_key.pressed = true
	grabber._unhandled_input(modified_key)
	_check(view.english.angular_velocity == before, "Alt no activa giros ni otras acciones")
	grabber.hovered = null
	grabber._refresh_inspection()
	_check(not grabber._inspection_panel.visible, "al dejar de señalar se oculta")
	grabber.hovered = card
	grabber._input(_alt(false))
	_check(not grabber._inspection_panel.visible, "al soltar Alt se oculta")
	grabber._input(_alt(true))
	grabber.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(
		not grabber._inspection_panel.visible and not grabber._inspecting, "pérdida de foco cierra"
	)
	grabber._input(_alt(true))
	grabber.notification(Node.NOTIFICATION_PAUSED)
	_check(not grabber._inspection_panel.visible, "pausa cierra inspección")
	grabber.held = view.english
	grabber._input(_alt(true))
	_check(not grabber._inspection_panel.visible, "no interfiere con agarre")
	grabber.held = null
	var text := LineEdit.new()
	root.add_child(text)
	text.grab_focus()
	grabber._input(_alt(true))
	_check(not grabber._inspection_panel.visible, "no interfiere al escribir")
	text.release_focus()
	text.queue_free()
	grabber._hide_inspection()
	view.queue_free()
	await process_frame
	var guided: Node = load("res://scenes/GuidedDomino.tscn").instantiate()
	root.add_child(guided)
	await process_frame
	var guided_grabber := guided.get_node("PhysicsGrabber3D") as PhysicsGrabber3D
	_check(
		guided_grabber._inspection_panel == null, "no invade modos con reglas o información privada"
	)
	guided.queue_free()
	await process_frame
	if failures:
		printerr("Table inspection: %d errores" % failures)
		quit(1)
	else:
		print("Table inspection tests OK")
		quit(0)


func _alt(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ALT
	event.pressed = pressed
	return event


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
