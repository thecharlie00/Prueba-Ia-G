extends SceneTree

const TEST_SAVE := "user://test_diceon_sandbox.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main.sandbox_save_path = TEST_SAVE
	var objects: Node3D = main.get_node("Objects")
	var dice: Dice3D = objects.get_node("Dice")
	var deck: Deck3D = objects.get_node("Deck")
	var token: Token3D = objects.get_node("TokenGold")
	var grid: SnapGrid3D = main.get_node("SnapGrid3D")
	grid.enabled = true
	deck.draw_card()
	deck.draw_card()
	deck.shuffle_deck()
	var order: Array[String] = deck._cards.duplicate()
	var count: int = objects.get_child_count()
	var drawn: Card3D = objects.get_child(count - 1) as Card3D
	var drawn_name: String = str(drawn.name).replace("@", "_")
	var drawn_label: String = drawn.card_label
	dice.global_position = Vector3(0.3, 2.0, -0.7)
	dice.quaternion = Quaternion(Vector3.RIGHT, PI / 2.0)
	dice.linear_velocity = Vector3(0.25, 0.5, -0.75)
	dice.angular_velocity = Vector3(0.0, 1.5, 0.0)
	dice._awaiting_result = true
	var saved_pos := dice.global_position
	var saved_rotation := dice.quaternion
	var saved_color := token.piece_color
	var record := SandboxPersistence.snapshot(objects, grid.enabled)
	_check(not record.is_empty(), "captura de objetos, incluidos nombres de cartas robadas")
	(main.get_node("UI/Margin/Panel/Content/SaveRow/Save") as Button).pressed.emit()
	_check(FileAccess.file_exists(TEST_SAVE), "el botón crea el guardado local")
	var before_file := FileAccess.get_file_as_string(TEST_SAVE)
	_check(not before_file.is_empty(), "el archivo contiene datos")

	# No sobrescribir ni reemplazar durante un agarre o un volteo.
	var grabber: PhysicsGrabber3D = main.get_node("PhysicsGrabber3D")
	grabber.held = dice
	main.call("_on_save_pressed")
	main.call("_on_load_pressed")
	_check(FileAccess.get_file_as_string(TEST_SAVE) == before_file, "no guardar mientras se agarra")
	_check(objects.get_node("Dice") == dice, "no cargar mientras se agarra")
	grabber.held = null
	var card: Card3D = objects.get_node("Card")
	card.flip()
	main.call("_on_save_pressed")
	main.call("_on_load_pressed")
	_check(FileAccess.get_file_as_string(TEST_SAVE) == before_file, "no guardar durante volteo")
	_check(objects.get_node("Card") == card, "no cargar durante volteo")
	await create_timer(card.flip_duration + 0.1).timeout

	# Cambios que la carga debe reemplazar, incluidos objetos creados después de guardar.
	deck.draw_card()
	grid.enabled = false
	(main.get_node("UI/Margin/Panel/Content/SaveRow/Load") as Button).pressed.emit()
	_check(objects.get_child_count() == count, "carga restaura cantidad de cuerpos")
	var restored_dice: Dice3D = objects.get_node_or_null("Dice") as Dice3D
	var restored_deck: Deck3D = objects.get_node_or_null("Deck") as Deck3D
	var restored_token: Token3D = objects.get_node_or_null("TokenGold") as Token3D
	var restored_drawn: Card3D = objects.get_node_or_null(NodePath(drawn_name)) as Card3D
	_check(restored_dice != null and restored_dice != dice, "carga reemplaza el dado")
	if restored_dice:
		_check(
			restored_dice.global_position.is_equal_approx(saved_pos), "posición física restaurada"
		)
		_check(absf(restored_dice.quaternion.dot(saved_rotation)) > 0.9999, "rotación restaurada")
		_check(
			restored_dice.linear_velocity.is_equal_approx(Vector3(0.25, 0.5, -0.75)),
			"velocidad restaurada"
		)
		_check(
			restored_dice.angular_velocity.is_equal_approx(Vector3(0, 1.5, 0)),
			"velocidad angular restaurada"
		)
		_check(restored_dice._awaiting_result, "tirada en curso restaurada")
		_check(not restored_dice.freeze, "el dado sigue siendo un cuerpo dinámico")
	_check(
		restored_token != null and restored_token.piece_color.is_equal_approx(saved_color),
		"color de ficha restaurado"
	)
	_check(
		restored_drawn != null and restored_drawn.card_label == drawn_label,
		"carta robada restaurada"
	)
	_check(grid.enabled, "estado del imán restaurado")
	_check(
		restored_deck != null and restored_deck._cards == order, "orden exacto del mazo restaurado"
	)
	if restored_deck:
		_check(restored_deck.cards_remaining == order.size(), "contador del mazo restaurado")
		restored_deck.draw_card()
		_check(
			(objects.get_child(objects.get_child_count() - 1) as Card3D).card_label == order[-1],
			"el robo continúa según el orden guardado"
		)
		_check(
			str(main.result_label.text).contains(str(order.size() - 1)),
			"señales del mazo restauradas"
		)
	if restored_dice:
		restored_dice.result_ready.emit(4)
		_check(str(main.result_label.text).contains("4"), "señales del dado restauradas")
		var restored_position: Vector3 = restored_dice.global_position
		for i in range(8):
			await physics_frame
		_check(
			restored_dice.global_position.distance_to(restored_position) > 0.01,
			"la simulación continúa después de cargar"
		)

	# Verificación del formato y carácter transaccional ante corrupción y datos no admitidos.
	var invalid: Dictionary = record.duplicate(true)
	invalid["objects"][0]["type"] = "res://script_externo.gd"
	_check(not SandboxPersistence.validate(invalid), "rechaza tipos y rutas desconocidas")
	invalid = record.duplicate(true)
	invalid["objects"][0]["rotation"] = [0, 0, 0, 0]
	_check(not SandboxPersistence.validate(invalid), "rechaza rotación inválida")
	invalid = record.duplicate(true)
	invalid["objects"][1]["name"] = invalid["objects"][0]["name"]
	_check(not SandboxPersistence.validate(invalid), "rechaza nombres duplicados")
	invalid = record.duplicate(true)
	invalid["objects"][0]["position"] = [0, 1000, 0]
	_check(not SandboxPersistence.validate(invalid), "rechaza posición fuera de límites")
	var saved_current_count := objects.get_child_count()
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{archivo corrupto")
	file.close()
	main.call("_on_load_pressed")
	_check(
		(
			objects.get_child_count() == saved_current_count
			and objects.get_node("Dice") == restored_dice
		),
		"carga inválida no cambia la mesa"
	)
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("x".repeat(SandboxPersistence.MAX_BYTES + 1))
	file.close()
	main.call("_on_load_pressed")
	_check(objects.get_node("Dice") == restored_dice, "archivo grande no cambia la mesa")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	main.queue_free()
	await process_frame
	if failures:
		printerr("Sandbox persistence: %d errores" % failures)
		quit(1)
	else:
		print("Sandbox persistence tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
