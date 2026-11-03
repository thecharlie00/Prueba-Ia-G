extends SceneTree

const STORE := preload("res://scripts/persistence/SaveStore.gd")
const PATH := "user://test_cards_save.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean()
	var view := (load("res://scenes/CardTable.tscn") as PackedScene).instantiate() as CardTable
	view.save_path = PATH
	root.add_child(view)
	await physics_frame
	view.english.shuffle_deck()
	view.english.draw_card()
	view.spanish.draw_card()
	var english_order: Array[String] = view.english._cards.duplicate()
	var spanish_order: Array[String] = view.spanish._cards.duplicate()
	var first_card := view.objects.get_child(2) as Card3D
	first_card.global_position = Vector3(0.3, 1.5, 0.6)
	first_card.quaternion = Quaternion(Vector3.FORWARD, PI)
	var first_label := first_card.card_label
	(view.get_node("UI/Panel/Margin/Content/SaveRow/Save") as Button).pressed.emit()
	_check(FileAccess.file_exists(PATH), "primer guardado de mesa")
	_check(not FileAccess.file_exists(PATH + ".previous"), "primera escritura sin copia")
	var saved := STORE.read_validated(PATH, CardTable.MAX_SAVE_BYTES, CardTable._decode_save)
	_check(not saved.is_empty(), "guardado válido")
	view.english.draw_card()
	view._save_game()
	_check(FileAccess.file_exists(PATH + ".previous"), "segunda escritura conserva copia")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ interrumpido")
	file.close()
	(view.get_node("UI/Panel/Margin/Content/SaveRow/Load") as Button).pressed.emit()
	_check(view.status_label.text.contains("copia anterior"), "avisa de recuperación")
	_check(view.objects.get_child_count() == 4, "restaura ambos mazos y cartas")
	_check(
		view.english._cards == english_order and view.spanish._cards == spanish_order,
		"orden de mazos"
	)
	var restored := view.objects.get_child(2) as Card3D
	_check(restored.card_label == first_label, "restaura identidad")
	_check(
		restored.global_position.distance_to(Vector3(0.3, 1.5, 0.6)) < 0.001, "restaura posición"
	)
	_check(
		absf(restored.quaternion.dot(Quaternion(Vector3.FORWARD, PI))) > 0.999,
		"restaura orientación"
	)
	var expected: String = view.english._cards.back()
	(view.get_node("UI/Panel/Margin/Content/English/Draw") as Button).pressed.emit()
	var drawn := view.objects.get_child(view.objects.get_child_count() - 1) as Card3D
	_check(
		drawn.card_label == expected and view.english.cards_remaining == 50,
		"botón roba del mazo restaurado"
	)
	_check(view.english._initial_count == 52 and view.english.spread_draws, "reparto restaurado")
	# La validación no acepta cartas duplicadas, omitidas ni mazos cambiados.
	var malformed: Dictionary = saved["record"].duplicate(true)
	malformed["table"]["objects"][0]["cards"][0] = "carta inventada"
	_check(CardTable._decode_save(malformed) == null, "rechaza contenido inventado")
	malformed = saved["record"].duplicate(true)
	malformed["table"]["objects"].pop_back()
	_check(CardTable._decode_save(malformed) == null, "rechaza cartas omitidas")
	# Si no hay ninguna copia utilizable la carga no debe reemplazar cuerpos.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".previous"))
	var count := view.objects.get_child_count()
	view._load_game()
	_check(
		view.objects.get_child_count() == count and view.english._cards.size() == 50,
		"conserva mesa sin guardados válidos"
	)
	drawn.flip()
	view._save_game()
	_check(view.status_label.text.contains("volteo"), "espera un volteo antes de guardar")
	await create_timer(0.5).timeout
	while view.english.cards_remaining > 0:
		view.english.draw_card()
	while view.spanish.cards_remaining > 0:
		view.spanish.draw_card()
	_check(view.objects.get_child_count() == 94, "se pueden robar las 92 cartas")
	view._save_game()
	_check(view.status_label.text.contains("guardada"), "guarda las dos barajas agotadas")
	view._load_game()
	_check(
		(
			view.objects.get_child_count() == 94
			and view.english.cards_remaining == 0
			and view.spanish.cards_remaining == 0
		),
		"carga la mesa completa sin duplicar ni perder cartas"
	)
	view.queue_free()
	await process_frame
	_clean()
	if failures:
		printerr("Card table persistence: %d errores" % failures)
		quit(1)
	else:
		print("Card table persistence OK")
		quit(0)


func _clean() -> void:
	for suffix in ["", ".pending", ".previous", ".previous.pending"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
