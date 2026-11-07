extends SceneTree
## Apilado automático, inspección 3D, dibujos guardados y marcador.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var objects: Node = main.get_node("Objects")
	var grabber: PhysicsGrabber3D = main.grabber

	# Carta sobre el mazo: entra arriba.
	var deck := objects.get_node("Deck") as Deck3D
	var card := objects.get_node("Card") as Card3D
	var before := deck._cards.size()
	var label := card.card_label
	_check(TableStacking.on_release(objects, card, deck.global_position) == "deck", "una carta sobre el mazo se apila")
	await process_frame
	_check(deck._cards.size() == before + 1 and deck._cards.back() == label, "la carta queda arriba del mazo")
	_check(not is_instance_valid(card), "la carta suelta desaparece de la mesa")

	# Dos cartas juntas forman un mazo nuevo.
	deck.draw_card()
	deck.draw_card()
	var cards: Array[Card3D] = []
	for child in objects.get_children():
		if child is Card3D:
			cards.append(child)
	_check(cards.size() == 2, "se han robado dos cartas")
	cards[0].global_position = Vector3(-2.0, 0.9, 0.8)
	cards[1].global_position = Vector3(1.0, 0.9, 1.0)
	var labels := [cards[0].card_label, cards[1].card_label]
	_check(TableStacking.on_release(objects, cards[1], cards[0].global_position) == "new_deck", "carta sobre carta forma un mazo")
	await process_frame
	var new_deck: Deck3D = null
	for child in objects.get_children():
		if child is Deck3D and child != deck:
			new_deck = child
	_check(new_deck != null and new_deck._cards == labels, "el mazo nuevo tiene las dos cartas en orden")

	# Ficha sobre ficha: se centra encima.
	var red := objects.get_node("TokenRed") as Token3D
	var blue := objects.get_node("TokenBlue") as Token3D
	_check(TableStacking.on_release(objects, blue, red.global_position + Vector3(0.1, 0, 0)) == "token", "una ficha sobre otra se apila")
	_check(Vector2(blue.global_position.x - red.global_position.x, blue.global_position.z - red.global_position.z).length() < 0.01, "la ficha queda centrada encima")

	# Inspección 3D: copia el aspecto de la pieza en su propia vista.
	if grabber._inspection_panel == null:
		grabber._create_inspection_panel()
	var view: InspectView = grabber._inspection_view
	_check(view != null, "la inspección tiene vista 3D")
	if view != null:
		var dice := objects.get_node("Dice") as Dice3D
		_check(view.show_object(dice), "la vista 3D muestra el dado")
		_check(view._pivot.get_child_count() == 1, "la copia del dado está en el estudio")
		_check(view._camera.position.z > 0.1, "la cámara se aleja según el tamaño")
		view.clear()

	# Marcador: filas por jugador, se guarda con la mesa.
	var board := main.spawn_utility("scoreboard") as Scoreboard3D
	_check(board != null, "se puede añadir un marcador")
	await physics_frame
	grabber.apply_shortcut(KEY_3, board)
	grabber.apply_shortcut(KEY_PLUS, board)
	grabber.apply_shortcut(KEY_PLUS, board)
	_check(board.scores == [0, 0, 2, 0], "el marcador suma a la fila elegida")

	# Dibujos guardados con la mesa.
	var brush: TableBrush = main.get_node("TableBrush")
	var rig: TabletopCamera3D = main.get_node("TabletopCamera3D")
	rig.set_view("top", true)
	await physics_frame
	var center := rig.camera.unproject_position(Vector3(0.3, 0.82, 0.3))
	brush.begin_stroke(center)
	brush.extend_stroke(center + Vector2(60, 10))
	brush.end_stroke()
	var exported := brush.export_strokes()
	_check(exported.size() == 1 and exported[0]["points"].size() == 2, "el trazo se puede exportar")
	_check(TableBrush.valid_strokes(JSON.parse_string(JSON.stringify(exported))), "el trazo sobrevive a JSON")
	_check(not TableBrush.valid_strokes([{"color": 9, "points": [[0, 0, 0]]}]), "se rechaza un color inexistente")
	for i in 120:
		await physics_frame
	var path := "user://test_extras_sandbox.json"
	main.sandbox_save_path = path
	main._on_save_pressed()
	brush.clear()
	board.queue_free()
	await process_frame
	main._on_load_pressed()
	await process_frame
	_check(brush.strokes.size() == 1, "al cargar vuelven los dibujos")
	var restored: Scoreboard3D = null
	for child in objects.get_children():
		if child is Scoreboard3D:
			restored = child
	_check(restored != null and restored.scores == [0, 0, 2, 0] and restored.selected == 2, "el marcador se guarda y se carga")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))

	if _failed:
		quit(1)
	else:
		print("table_extras: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
