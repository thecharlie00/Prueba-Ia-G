extends SceneTree
## Mano de cartas: robar a la mano, jugar, recoger de la mesa, guardar/cargar y validación.

const SAVE_PATH := "user://test_card_hand.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in [SAVE_PATH, SAVE_PATH + ".previous"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var table: CardTable = (load("res://scenes/CardTable.tscn") as PackedScene).instantiate()
	table.save_path = SAVE_PATH
	root.add_child(table)
	for i in 3:
		await process_frame

	if table.hand == null or not table.hand.cards.is_empty():
		_fail("La mesa debe empezar con la mano vacía.")
		return
	var english_top: String = table.english._cards.back()
	if not table.draw_to_hand(true) or table.hand.cards != [english_top]:
		_fail("Robar a la mano debe pasar la carta de arriba del mazo a la mano.")
		return
	if table.english.cards_remaining != 51:
		_fail("El mazo inglés debe quedar con 51 cartas.")
		return
	table.draw_to_hand(false)
	table.draw_to_hand(false)
	if table.hand.cards.size() != 3 or table.spanish.cards_remaining != 38:
		_fail("Robar de la española también va a la mano.")
		return
	if table.hand.hand3d.card_nodes().size() != 3:
		_fail("La mano 3D debe tener una carta por etiqueta.")
		return

	var played: Card3D = table.play_from_hand(0)
	await process_frame
	if played == null or played.card_label != english_top or table.hand.cards.size() != 2:
		_fail("Jugar desde la mano debe poner esa carta en la mesa y quitarla de la mano.")
		return
	if played.get_parent() != table.objects:
		_fail("La carta jugada debe estar en la mesa.")
		return
	for i in 20:
		await physics_frame
	if not table.take_to_hand(played) or table.hand.cards.back() != english_top:
		_fail("M sobre una carta de la mesa debe devolverla a la mano.")
		return
	await process_frame
	if is_instance_valid(played):
		_fail("La carta recogida debe desaparecer de la mesa.")
		return

	var saved_hand := table.hand.cards.duplicate()
	table._save_game()
	table.hand.set_cards([])
	table.draw_to_hand(true)
	table._load_game()
	await process_frame
	if table.hand.cards != saved_hand:
		_fail("Cargar debe restaurar la mano guardada: %s" % [table.hand.cards])
		return
	if table.english.cards_remaining != 51 or table.spanish.cards_remaining != 38:
		_fail("Cargar debe restaurar los mazos sin las cartas de la mano.")
		return

	# Una carta que está a la vez en la mano y en un mazo invalida el guardado.
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	var duplicated: Array = record["hand"].duplicate()
	for piece in record["table"]["objects"]:
		if piece["type"] == "deck" and not piece["cards"].is_empty():
			duplicated.append(piece["cards"][0])
			break
	record["hand"] = duplicated
	if CardTable._decode_save(record) != null:
		_fail("Una carta repetida entre mano y mazo debe rechazarse.")
		return
	record["hand"] = saved_hand
	record["version"] = 1
	if CardTable._decode_save(record) != null:
		_fail("Un guardado de versión 1 no puede traer mano.")
		return

	print("Card hand tests OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
