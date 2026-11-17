extends SceneTree
## FASE 3 — Exportar/importar juegos .tablerama con validación estricta.
## Prueba: exportar mesa con mazo y lógica, importar de vuelta, verificar
## integridad. También prueba que rutas inválidas y código GDScript prohibido
## se rechazan sin tocar la mesa actual.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor: GameCreatorEditor = current_scene as GameCreatorEditor
	editor.table_save_path = "user://test_editor_export_import.json"
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Crear un mazo de 3 cartas (sin imágenes reales, rutas vacías).
	var cartas: Array = []
	for i in range(3):
		cartas.append({
			"id": "carta_%d" % i,
			"name": "Carta %d" % (i + 1),
			"texture": "",
			"back": "",
			"label": str(i + 1),
			"notes": "Carta número %d" % (i + 1),
			"face_up": true,
		})
	var mazo_piece := {
		"id": "", "name": "Mazo test", "shape": "carta",
		"color": Palette.PAPER.to_html(true), "texture": "", "label": "",
		"pattern": "liso", "cells": 8, "finish": "brillo", "back": "",
		"notes": "", "shuffle": false, "tags": [], "zkind": "normal",
		"player": 0, "model": "", "msize": [0, 0, 0], "pos": [0, 0, 0],
		"rot": [0, 0, 0], "scale": 1.0, "locked": false, "mass": 0.2,
		"bounce": 0.05,
		"deck": {
			"cards": cartas,
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
	editor.select_pieces([mazo])

	# 2. Añadir una zona como destino para repartir.
	var zona_piece := {
		"id": "", "name": "Zona destino", "shape": "zona",
		"color": Palette.LAVENDER.to_html(true), "texture": "", "label": "Destino",
		"pattern": "liso", "cells": 8, "finish": "mate", "back": "",
		"notes": "", "shuffle": false, "tags": [], "zkind": "normal",
		"player": 0, "model": "", "msize": [0, 0, 0], "pos": [2, 0, 0],
		"rot": [0, 0, 0], "scale": 1.0, "locked": true, "mass": 1.0,
		"bounce": 0.1,
	}
	editor._remember("test_create_zone")
	var zona: PropEntity = editor._make_piece(zona_piece) as PropEntity
	zona.position.y = editor._surface_height(zona.position, [zona])
	editor._pop_in(zona)
	editor.select_pieces([mazo, zona])

	# 3. Guardar la mesa.
	_check(editor.save_table(), "se guarda la mesa con mazo y zona")
	_check(hierarchy.entities.size() == 2, "hay 2 entidades: mazo + zona (%d)" % hierarchy.entities.size())

	# 4. Exportar a .tablerama.
	var export_path := "user://test_export_import.tablerama"
	_check(editor.export_game(export_path), "se exporta el juego a .tablerama")
	var f := FileAccess.open(export_path, FileAccess.READ)
	_check(f != null, "el archivo exportado existe y se puede abrir")
	var size := f.get_length() if f != null else 0
	f.close()
	_check(size > 0, "el archivo exportado no está vacío (%d bytes)" % size)

	# 5. Vaciar y importar de vuelta.
	editor.clear_table()
	_check(hierarchy.entities.size() == 0, "mesa vaciada tras clear")
	_check(editor.import_game(export_path), "se importa el juego de vuelta")
	_check(hierarchy.entities.size() == 2, "tras importar hay 2 entidades (%d)" % hierarchy.entities.size())

	# 6. Verificar que el mazo conserva sus cartas.
	var imported_mazo: PropEntity = null
	for e in hierarchy.entities:
		var v := e.get_component("VisualComponent") as VisualComponent
		if v != null and v.shape == "carta" and e.entity_name == "Mazo test":
			imported_mazo = e
			break
	_check(imported_mazo != null, "se encontró el mazo importado")
	var imported_deck: DeckComponent = imported_mazo.get_component("DeckComponent") as DeckComponent
	_check(imported_deck != null, "el mazo importado tiene DeckComponent")
	_check(imported_deck.count() == 3, "el mazo importado tiene %d cartas" % imported_deck.count())
	var carta0: Dictionary = imported_deck.top_card() as Dictionary
	_check(carta0.get("name", "") == "Carta 3", "la carta de arriba es «Carta 3» (es «%s»)" % carta0.get("name", "?"))

	# 7. Verificar que la zona conserva sus datos.
	var imported_zona: PropEntity = null
	for e in hierarchy.entities:
		var v := e.get_component("VisualComponent") as VisualComponent
		if v != null and v.shape == "zona" and e.entity_name == "Zona destino":
			imported_zona = e
			break
	_check(imported_zona != null, "se encontró la zona importada")
	var zona_visual := imported_zona.get_component("VisualComponent") as VisualComponent
	_check(zona_visual.label == "Destino", "la zona conserva su etiqueta: «%s»" % zona_visual.label)

	# 8. Validación estricta: archivo con rutas inválidas (http://) debe rechazarse.
	var bad_path := "user://test_bad_path.tablerama"
	var bad_package := {
		"format": "tablerama-juego",
		"version": 1,
		"table": {
			"pieces": [{
				"id": "bad1", "name": "Pieza mala", "shape": "carta",
				"color": "ffffffff", "texture": "http://evil.com/image.png",
				"back": "", "label": "", "pattern": "liso", "cells": 8,
				"finish": "mate", "notes": "", "shuffle": false, "tags": [],
				"zkind": "normal", "player": 0, "model": "", "msize": [0, 0, 0],
				"pos": [0, 0, 0], "rot": [0, 0, 0], "scale": 1.0, "locked": false,
				"mass": 1.0, "bounce": 0.1,
			}],
		},
		"ui": {"elements": []},
		"images": {},
		"models": {},
	}
	var bad_text := JSON.stringify(bad_package)
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_file.store_string(bad_text)
	bad_file.close()
	# La mesa debe seguir con 2 entidades (no se tocó).
	_check(hierarchy.entities.size() == 2, "la mesa no se tocó antes de validar la ruta inválida")
	_check(not editor.import_game(bad_path), "se rechaza importación con ruta http:// inválida")
	_check(hierarchy.entities.size() == 2, "la mesa sigue con 2 entidades tras rechazar ruta inválida (%d)" % hierarchy.entities.size())

	# 9. Validación estricta: código GDScript prohibido (OS, FileAccess) debe rechazarse.
	var code_bad := "var x = OS.get_name()\nreturn x"
	var gd_bad_package := {
		"format": "tablerama-juego",
		"version": 1,
		"table": {
			"pieces": [],
			"logic": {
				"nodes": {
					"1": {
						"id": 1, "type": "gd_bloque", "pos": [0, 0],
						"params": {"codigo": code_bad},
					},
				},
				"links": [],
			},
		},
		"ui": {"elements": []},
		"images": {},
		"models": {},
	}
	var gd_bad_text := JSON.stringify(gd_bad_package)
	var gd_bad_path := "user://test_gd_bad.tablerama"
	var gd_file := FileAccess.open(gd_bad_path, FileAccess.WRITE)
	gd_file.store_string(gd_bad_text)
	gd_file.close()
	_check(not editor.import_game(gd_bad_path), "se rechaza código GDScript prohibido (OS.get_name)")
	_check(hierarchy.entities.size() == 2, "la mesa sigue intacta tras rechazar código prohibido (%d)" % hierarchy.entities.size())


	# 10. Validación estricta: código GDScript permitido debe aceptarse.
	var code_ok := "var total = 0\nfor p in mesa.piezas_en_zona(\"\"):\n\ttotal += 1\nreturn total"
	var gd_ok_package := {
		"format": "tablerama-juego",
		"version": 1,
		"table": {
			"pieces": [],
			"logic": {
				"nodes": {
					"1": {
						"id": 1, "type": "gd_bloque", "pos": [0, 0],
						"params": {"codigo": code_ok},
					},
				},
				"links": [],
			},
		},
		"ui": {"elements": []},
		"images": {},
		"models": {},
	}
	var gd_ok_text := JSON.stringify(gd_ok_package)
	var gd_ok_path := "user://test_gd_ok.tablerama"
	var gd_ok_file := FileAccess.open(gd_ok_path, FileAccess.WRITE)
	gd_ok_file.store_string(gd_ok_text)
	gd_ok_file.close()
	_check(editor.import_game(gd_ok_path), "se acepta código GDScript válido en sandbox")
	_check(hierarchy.entities.size() == 2, "la mesa sigue con 2 entidades tras importar código válido (%d)" % hierarchy.entities.size())

	# Limpieza de archivos temporales.
	for fpath in [export_path, bad_path, gd_bad_path, gd_ok_path,
				  editor.table_save_path, editor.table_save_path + ".bak", editor.table_save_path + ".tmp"]:
		if FileAccess.file_exists(fpath):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fpath))

	if _failed:
		quit(1)
	else:
		print("editor_export_import: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
