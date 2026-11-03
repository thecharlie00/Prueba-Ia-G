extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view := (load("res://scenes/CardTable.tscn") as PackedScene).instantiate() as CardTable
	root.add_child(view)
	await physics_frame
	_check(
		view.english.cards_remaining == 52 and view.spanish.cards_remaining == 40,
		"dos barajas completas"
	)
	_check(_unique(view.english._cards) == 52, "52 cartas inglesas distintas")
	_check(_unique(view.spanish._cards) == 40, "40 cartas españolas distintas")
	_check("A ♠" in view.english._cards and "K ♣" in view.english._cards, "rangos y palos ingleses")
	_check(
		"1 O" in view.spanish._cards and "12 B" in view.spanish._cards, "rangos y palos españoles"
	)
	_check(
		"8 O" not in view.spanish._cards and "9 C" not in view.spanish._cards,
		"baraja española de 40 sin ochos ni nueves"
	)
	var original: Array[String] = view.english._cards.duplicate()
	var sorted_before := original.duplicate()
	(view.get_node("UI/Panel/Margin/Content/English/Shuffle") as Button).pressed.emit()
	var sorted_after := view.english._cards.duplicate()
	sorted_before.sort()
	sorted_after.sort()
	_check(sorted_after == sorted_before, "mezclar conserva las cartas")
	var positions: Array[Vector3] = []
	var expected: String = view.english._cards.back()
	for i in range(6):
		(view.get_node("UI/Panel/Margin/Content/English/Draw") as Button).pressed.emit()
		var card := view.objects.get_child(view.objects.get_child_count() - 1) as Card3D
		_check(
			card != null and not card.freeze and card.collision_mask == 3, "carta robada es física"
		)
		if i == 0:
			_check(card.card_label == expected, "se conserva identidad de la carta")
			_check(
				(card.get_node("Visual/FaceLabel") as Label3D).text == expected,
				"anverso identifica carta"
			)
			_check(
				(card.get_node("Visual/Corner0") as Label3D).text == expected,
				"esquinas identifican carta"
			)
		positions.append(card.global_position)
	_check(view.english.cards_remaining == 46, "el mazo reduce cantidad")
	for i in range(positions.size()):
		for j in range(i):
			_check(
				positions[i].distance_to(positions[j]) > 0.6,
				"primeras cartas aparecen en puntos distintos"
			)
	(view.get_node("UI/Panel/Margin/Content/Spanish/Draw") as Button).pressed.emit()
	_check(view.spanish.cards_remaining == 39, "robo español independiente")
	view._on_selection_changed(null)
	_check(
		view.status_label.text.contains("46") and view.status_label.text.contains("39"),
		"contador actualizado"
	)
	var card_count := view.objects.get_child_count()
	view.english.on_grab()
	view.english.draw_card()
	_check(view.objects.get_child_count() == card_count, "no robar de un mazo agarrado")
	view.english.on_release()
	view.spanish._cards.clear()
	view.spanish.cards_remaining = 0
	view.spanish.draw_card()
	_check(view.objects.get_child_count() == card_count, "no robar de un mazo vacío")
	view.queue_free()
	await process_frame
	if failures:
		printerr("Card table: %d errores" % failures)
		quit(1)
	else:
		print("Card table tests OK")
		quit(0)


func _unique(cards: Array[String]) -> int:
	var values := {}
	for card in cards:
		values[card] = true
	return values.size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FALLO: " + message)
