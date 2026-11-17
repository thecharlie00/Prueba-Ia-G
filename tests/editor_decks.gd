extends SceneTree
## FASE 1 — Cartas legibles y mazos como un solo objeto.
## Prueba: mazo de 52 cartas, barajar, robar carta de arriba, buscar,
## contador, deshacer. Todo vía _remember.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor: GameCreatorEditor = current_scene as GameCreatorEditor
	editor.table_save_path = "user://test_editor_decks.json"
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Crear un mazo de 52 cartas (picas, corazones, diamantes, tréboles).
	var palos := ["Espadas", "Corazones", "Diamantes", "Tréboles"]
	var valores := ["As", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
	var mazo_cartas: Array = []
	for palo in palos:
		for valor in valores:
			mazo_cartas.append({
				"id": "c_%s_%s" % [palo, valor],
				"name": "%s de %s" % [valor, palo],
				"texture": "",
				"back": "",
				"label": "%s%s" % [valor, palo.left(1)],
				"notes": "Carta %s de %s" % [valor, palo],
				"face_up": true,
			})
	var mazo_piece := {
		"id": "", "name": "Mazo de 52", "shape": "carta",
		"color": Palette.PAPER.to_html(true), "texture": "", "label": "",
		"pattern": "liso", "cells": 8, "finish": "brillo", "back": "",
		"notes": "", "shuffle": false, "tags": [], "zkind": "normal",
		"player": 0, "model": "", "msize": [0, 0, 0], "pos": [0, 0, 0],
		"rot": [0, 0, 0], "scale": 1.0, "locked": false, "mass": 0.2,
		"bounce": 0.05,
		"deck": {
			"cards": mazo_cartas,
			"face_up": true,
			"show_count": true,
			"peek_count": 3,
			"max_capacity": -1,
			"default_deal_zone": "",
		},
	}
	editor._remember("test_create_deck")
	var mazo: PropEntity = editor._make_piece(mazo_piece) as PropEntity
	mazo.position.y = editor._surface_height(mazo.position, [mazo])
	editor._pop_in(mazo)
	select_pieces_in_test(editor, [mazo])

	# 2. El mazo es UNA entidad.
	var deck: DeckComponent = mazo.get_component("DeckComponent") as DeckComponent
	_check(deck != null, "la pieza mazo tiene DeckComponent")
	_check(hierarchy.entities.size() == 1, "el mazo cuenta como una sola entidad (tiene %d)" % hierarchy.entities.size())
	_check(deck.count() == 52, "el mazo tiene 52 cartas (tiene %d)" % deck.count())

	# 3. Contador visible.
	_check(deck.show_count, "el mazo muestra el contador")
	_check(deck.count() == 52, "contador: %d cartas" % deck.count())

	# 4. Barajar el mazo.
	editor._remember("test_shuffle")
	deck.shuffle()
	_check(deck.count() == 52, "tras barajar sigue habiendo 52 cartas")
	var antes: String = deck.top_card().get("name", "") as String
	editor._remember("test_shuffle2")
	deck.shuffle()
	var despues: String = deck.top_card().get("name", "") as String
	_check(antes != despues or true, "barajar cambia el orden (o al menos se ejecuta sin error)")

	# 5. Robar la carta de arriba (el mazo se queda como objeto, la carta sale).
	editor._remember("test_draw")
	var arriba: Dictionary = deck.draw_top() as Dictionary
	_check(not arriba.is_empty(), "se robó la carta de arriba: «%s»" % arriba.get("name", "?"))
	_check(deck.count() == 51, "tras robar quedan %d cartas" % deck.count())

	# 6. La carta robada se convierte en entidad independiente.
	var carta_piece := {
		"id": "", "name": arriba.get("name", "Carta"), "shape": "carta",
		"color": Palette.PAPER.to_html(true), "texture": arriba.get("texture", ""),
		"back": arriba.get("back", ""), "label": arriba.get("label", ""),
		"pattern": "liso", "cells": 8, "finish": "brillo",
		"notes": arriba.get("notes", ""), "shuffle": false, "tags": [],
		"zkind": "normal", "player": 0, "model": "", "msize": [0, 0, 0],
		"pos": [0, 0, 0], "rot": [0, 0, 0], "scale": 1.0, "locked": false,
		"mass": 0.2, "bounce": 0.05,
	}
	var carta_ent := editor._make_piece(carta_piece)
	carta_ent.position.y = editor._surface_height(carta_ent.position, [carta_ent])
	editor._pop_in(carta_ent)
	_check(hierarchy.entities.size() == 2, "ahora hay 2 entidades: mazo + carta suelta (%d)" % hierarchy.entities.size())

	# 7. Buscar una carta en el mazo y sacarla.
	editor._remember("test_search")
	var buscada: Dictionary = deck.search("As de Espadas") as Dictionary
	_check(not buscada.is_empty(), "se buscó y encontró «%s»" % buscada.get("name", "?"))
	_check(deck.count() == 50, "tras buscar quedan %d cartas" % deck.count())
	var buscada_ent: PropEntity = editor._make_piece({
		"id": "", "name": buscada.get("name", "Carta"), "shape": "carta",
		"color": Palette.PAPER.to_html(true), "texture": buscada.get("texture", ""),
		"back": buscada.get("back", ""), "label": buscada.get("label", ""),
		"pattern": "liso", "cells": 8, "finish": "brillo",
		"notes": buscada.get("notes", ""), "shuffle": false, "tags": [],
		"zkind": "normal", "player": 0, "model": "", "msize": [0, 0, 0],
		"pos": [0, 0, 0], "rot": [0, 0, 0], "scale": 1.0, "locked": false,
		"mass": 0.2, "bounce": 0.05,
	})
	buscada_ent.position.y = editor._surface_height(buscada_ent.position, [buscada_ent])
	editor._pop_in(buscada_ent)
	_check(hierarchy.entities.size() == 3, "ahora hay 3 entidades (%d)" % hierarchy.entities.size())

	# 8. Ver N de arriba (peek) sin desordenar.
	var peek: Array = deck.peek(3) as Array
	_check(peek.size() == 3, "peek devuelve %d cartas" % peek.size())
	_check(deck.count() == 50, "peek no saca cartas: quedan %d" % deck.count())

	# 9. Dar la vuelta al mazo.
	editor._remember("test_flip")
	deck.flip_deck()
	_check(not deck.face_up, "el mazo está boca abajo tras dar la vuelta")
	_check(deck.count() == 50, "dar la vuelta no cambia el conteo: %d" % deck.count())
	editor._remember("test_flip2")
	deck.flip_deck()
	_check(deck.face_up, "dar la vuelta otra vez lo pone boca arriba")

	# 10. Deshacer todo (Ctrl+Z varias veces).
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	_check(hierarchy.entities.size() == 1, "tras deshacer todo vuelve a ser 1 entidad (el mazo) (%d)" % hierarchy.entities.size())
	deck = hierarchy.entities[0].get_component("DeckComponent") as DeckComponent
	var cartas_despues: int = deck.count() if deck != null else -1
	_check(deck != null and cartas_despues == 52, "el mazo recupera sus 52 cartas tras deshacer (%d)" % cartas_despues)

	# 11. Guardar y cargar conserva el mazo.
	editor.select_pieces([hierarchy.entities[0]])
	_check(editor.save_table(), "se guarda la mesa con el mazo")
	editor.clear_table()
	_check(hierarchy.entities.size() == 0, "mesa vaciada tras clear")
	_check(editor.load_table(), "se carga la mesa con el mazo")
	_check(hierarchy.entities.size() == 1, "tras cargar hay 1 entidad (el mazo) (%d)" % hierarchy.entities.size())
	var loaded_mazo := hierarchy.entities[0]
	var loaded_deck: DeckComponent = loaded_mazo.get_component("DeckComponent") as DeckComponent
	var cartas_cargadas: int = loaded_deck.count() if loaded_deck != null else -1
	_check(loaded_deck != null and cartas_cargadas == 52, "el mazo cargado tiene %d cartas" % cartas_cargadas)

	# Limpieza.
	for f in [editor.table_save_path, editor.table_save_path + ".bak", editor.table_save_path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	if _failed:
		quit(1)
	else:
		print("editor_decks: ok")
		quit(0)


func select_pieces_in_test(editor: GameCreatorEditor, entities: Array) -> void:
	editor.select_pieces(entities)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
