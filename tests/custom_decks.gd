extends SceneTree
## Barajas propias desde imágenes y manos ordenables en la mesa de cartas.

const SAVE_PATH := "user://test_custom_decks.json"
const FOLDER := "Prueba test"
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_labels()
	_sorting()
	await _table()
	_cleanup()
	if _failed:
		quit(1)
	else:
		print("custom_decks: ok")
		quit(0)


func _labels() -> void:
	_check(CustomDecks.is_label("img:Mi baraja/carta 1.png"), "etiqueta válida")
	_check(not CustomDecks.is_label("img:../fuera/carta.png"), "no se sale de la carpeta")
	_check(not CustomDecks.is_label("img:Mi baraja/../../x.png"), "sin rutas dentro del nombre")
	_check(not CustomDecks.is_label("img:Mi baraja/carta.exe"), "solo imágenes")
	_check(CustomDecks.pretty("img:Mi baraja/Rey.png") == "Rey (Mi baraja)", "nombre legible")


func _sorting() -> void:
	var hand := CardHand.new()
	root.add_child(hand)
	hand.set_cards(["K ♠", "7 O", "2 ♥", "A ♠", "1 O", "img:X/y.png"])
	hand.sort_cards("suit")
	_check(hand.cards == ["A ♠", "K ♠", "2 ♥", "1 O", "7 O", "img:X/y.png"], "ordenar por palo: %s" % [hand.cards])
	hand.sort_cards("rank")
	_check(hand.cards.slice(0, 2) == ["A ♠", "1 O"], "ordenar por número: %s" % [hand.cards])
	_check(hand.next_sort == "suit", "el botón alterna el orden")
	_check(hand.move_card(0, 3) and hand.cards[3] == "A ♠", "mover una carta de sitio")
	_check(not hand.move_card(0, 9), "no se mueve fuera de la mano")
	# Arrastrar en el abanico: soltar lejos de donde se pulsó cuenta como mover, no jugar.
	var played := []
	var moved := []
	hand.card_played.connect(func(index: int) -> void: played.append(index))
	hand.hand3d.item_moved.connect(func(a: int, b: int) -> void: moved.append([a, b]))
	hand.hand3d.begin_press(0, Vector2(100, 500))
	hand.hand3d.finish_press(Vector2(102, 501))
	_check(played == [0] and moved.is_empty(), "un clic sin arrastrar juega la carta")
	hand.queue_free()


func _make_images() -> void:
	var dir := CustomDecks.ROOT.path_join(FOLDER)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 3:
		var image := Image.create(64, 90, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.2 * i, 0.5, 0.8))
		image.save_png(dir.path_join("carta %d.png" % i))
	# Lo que no es imagen o tiene un nombre raro se ignora.
	var other := FileAccess.open(dir.path_join("notas.txt"), FileAccess.WRITE)
	other.store_string("no es una carta")
	other.close()


func _table() -> void:
	_make_images()
	var found := CustomDecks.scan()
	_check(found.has(FOLDER) and found[FOLDER].size() == 3, "se encuentran las 3 imágenes: %s" % [found])
	var table: CardTable = (load("res://scenes/CardTable.tscn") as PackedScene).instantiate()
	table.save_path = SAVE_PATH
	root.add_child(table)
	for i in 5:
		await process_frame
	_check(table.load_custom_decks() >= 1, "la baraja propia aparece en la mesa")
	_check(table.load_custom_decks() == 0, "no se duplica al volver a cargar")
	var deck: Deck3D = table.custom_decks[CustomDecks.deck_name(FOLDER)]
	_check(deck != null and deck._cards.size() == 3, "la baraja tiene una carta por imagen")
	var label: String = deck._cards.back()
	var texture := CardArt.texture("playing", label)
	_check(texture is ImageTexture and texture.get_width() == 64, "la cara es la imagen")
	deck.draw_card()
	await process_frame
	var card: Card3D = null
	for child in table.objects.get_children():
		if child is Card3D and child.card_label == label:
			card = child
	_check(card != null and "carta" in card.display_name and not "img:" in card.display_name, "la carta robada se llama por su imagen")
	for i in 30:
		await physics_frame
	# Guardar con la baraja propia y una de sus cartas en la mano.
	table.take_to_hand(card)
	table._save_game()
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(CardTable._decode_save(record) != null, "el guardado con baraja propia es válido")
	var forged := record.duplicate(true)
	forged["hand"].append("img:../fuera/x.png")
	_check(CardTable._decode_save(forged) == null, "se rechaza una ruta fuera de la carpeta")
	forged = record.duplicate(true)
	forged["hand"].append("img:Otra/x.png")
	_check(CardTable._decode_save(forged) == null, "se rechaza una carta de una baraja que no está")
	table.hand.set_cards([])
	table._load_game()
	await process_frame
	_check(table.hand.cards == [label], "al cargar vuelve la carta propia a la mano")
	_check(table.custom_decks.has(CustomDecks.deck_name(FOLDER)) and table.custom_decks[CustomDecks.deck_name(FOLDER)]._cards.size() == 2, "y su baraja con las otras dos")
	# M y B: la carta vuelve a su baraja propia.
	var played := table.play_from_hand(0)
	for i in 30:
		await physics_frame
	_check(table._return_card(played), "la carta propia vuelve al fondo de su baraja")
	table.queue_free()
	await process_frame


func _cleanup() -> void:
	var dir := CustomDecks.ROOT.path_join(FOLDER)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	for path in [SAVE_PATH, SAVE_PATH + ".previous", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
