extends SceneTree

const PATH := "user://test_table_tools.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	await _test_sandbox_lock()
	await _test_card_return()
	await _test_guarded_modes()
	_clean()
	if failures:
		printerr("Table tools: %d errores" % failures)
		quit(1)
	else:
		print("Table tools tests OK")
		quit(0)


func _test_sandbox_lock() -> void:
	var view: Node = load("res://scenes/Main.tscn").instantiate()
	view.sandbox_save_path = PATH
	root.add_child(view)
	await physics_frame
	var grabber: PhysicsGrabber3D = view.grabber
	var die := view.get_node("Objects/Dice") as Dice3D
	_check(grabber.lock_shortcut_enabled, "bloqueo activado en mesa libre")
	grabber.hovered = die
	grabber._unhandled_input(_key(KEY_L))
	_check(die.is_table_locked and die.freeze, "L bloquea el cuerpo")
	var position := die.global_position
	die.apply_central_impulse(Vector3(4, 4, 0))
	for i in range(5):
		await physics_frame
	_check(die.global_position.distance_to(position) < 0.002, "pieza bloqueada no se desplaza")
	grabber.hovered = die
	grabber._begin_grab(Vector2.ZERO)
	_check(grabber.held == null, "no se agarra pieza bloqueada")
	view._on_save_pressed()
	_check(FileAccess.file_exists(PATH), "se puede guardar una mesa con piezas bloqueadas")
	grabber._unhandled_input(_key(KEY_L))
	_check(not die.is_table_locked and not die.freeze, "L devuelve la física")
	view._on_load_pressed()
	var restored := view.get_node("Objects/Dice") as Dice3D
	_check(restored.is_table_locked and restored.freeze, "carga conserva bloqueo")
	_check(grabber.last_selected == null, "carga descarta selección anterior")
	grabber.hovered = restored
	grabber._unhandled_input(_key(KEY_L))
	_check(not restored.is_table_locked and not restored.freeze, "se puede desbloquear tras cargar")
	# Versiones anteriores sin el campo siguen siendo compatibles.
	var record := SandboxPersistence.snapshot(view.get_node("Objects"), false)
	for piece in record["objects"]:
		piece.erase("locked")
	_check(SandboxPersistence.validate(record), "guardado antiguo sin bloqueo sigue siendo válido")
	record["objects"][0]["locked"] = "sí"
	_check(not SandboxPersistence.validate(record), "rechaza bloqueo de tipo inválido")
	view.queue_free()
	await process_frame


func _test_card_return() -> void:
	var view := load("res://scenes/CardTable.tscn").instantiate() as CardTable
	view.save_path = PATH
	root.add_child(view)
	await physics_frame
	view.english.draw_card()
	var card := view.objects.get_child(2) as Card3D
	var label := card.card_label
	var next: String = view.english._cards.back()
	view.grabber.hovered = card
	view.grabber.last_selected = card
	view._unhandled_input(_key(KEY_B))
	_check(view.objects.get_child_count() == 2, "B retira la carta elegida")
	_check(
		view.english._cards.front() == label and view.english._cards.back() == next,
		"vuelve al fondo sin mezclar"
	)
	_check(view.grabber.last_selected == null, "no queda selección de carta eliminada")
	view.spanish.draw_card()
	card = view.objects.get_child(2) as Card3D
	var spanish_label := card.card_label
	_check(card.set_table_locked(true), "se bloquea carta")
	_check(not view._return_card(card), "no devuelve carta bloqueada")
	view._save_game()
	_check(view.status_label.text.contains("guardada"), "guarda carta bloqueada")
	view._load_game()
	card = view.objects.get_child(2) as Card3D
	_check(card.is_table_locked and card.card_label == spanish_label, "carga carta bloqueada")
	card.set_table_locked(false)
	view.spanish.set_table_locked(true)
	_check(not view._return_card(card), "no devuelve carta a mazo bloqueado")
	view.spanish.set_table_locked(false)
	_check(view._return_card(card), "devuelve carta española a su baraja")
	_check(
		view.spanish._cards.front() == spanish_label and view.spanish.cards_remaining == 40,
		"recupera identidad sin duplicar"
	)
	view._save_game()
	_check(view.status_label.text.contains("guardada"), "mesa devuelta sigue siendo válida")
	view.queue_free()
	await process_frame


func _test_guarded_modes() -> void:
	for scene in [
		"GuidedPhysicalChess", "GuidedPhysicalCheckers", "GuidedDomino", "Island", "Ludo"
	]:
		var view: Node = load("res://scenes/%s.tscn" % scene).instantiate()
		root.add_child(view)
		await process_frame
		var grabber := view.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
		_check(not grabber.lock_shortcut_enabled, scene + " no permite bloqueo manual")
		view.queue_free()
		await process_frame
	for scene in ["PhysicalChess", "PhysicalCheckers", "PhysicalDomino"]:
		var view: Node = load("res://scenes/%s.tscn" % scene).instantiate()
		root.add_child(view)
		await process_frame
		var grabber := view.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
		_check(grabber.lock_shortcut_enabled, scene + " permite bloqueo manual")
		view.queue_free()
		await process_frame


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key


func _clean() -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = PATH + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
