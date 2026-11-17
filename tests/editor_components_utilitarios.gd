extends SceneTree
## FASE 5 — Componentes utilitarios de mesa (contador, bolsa, nota, reloj).
## Prueba: crear piezas con cada componente, operar sobre ellas, verificar
## serialización y deshacer.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor: GameCreatorEditor = current_scene
	editor.table_save_path = "user://test_editor_components.json"
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Crear un contador y verificarlo.
	editor._remember("test_counter_create")
	var contador_piece := {
		"id": "", "name": "Contador puntos", "shape": "ficha",
		"color": Palette.PAPER.to_html(true), "texture": "", "label": "Puntos",
		"pattern": "liso", "cells": 8, "finish": "mate", "back": "", "notes": "",
		"shuffle": false, "tags": [], "zkind": "normal", "player": 0,
		"model": "", "msize": [0, 0, 0], "pos": [0, 0, 0], "rot": [0, 0, 0],
		"scale": 1.0, "locked": false, "mass": 1.0, "bounce": 0.1,
		"counter": {
			"value": 10, "min_value": 0, "max_value": 100, "step": 1, "label": "Puntos",
		},
	}
	var contador_ent := editor._make_piece(contador_piece)
	contador_ent.position.y = editor._surface_height(contador_ent.position, [contador_ent])
	editor._pop_in(contador_ent)
	editor.select_pieces([contador_ent])

	var counter := contador_ent.get_component("CounterComponent") as CounterComponent
	_check(counter != null, "la pieza tiene CounterComponent")
	_check(counter.value == 10, "el contador tiene valor 10 (tiene %d)" % counter.value)

	# 2. Operar sobre el contador.
	counter.add(5)
	_check(counter.value == 15, "tras sumar 5, el contador vale 15 (vale %d)" % counter.value)
	counter.sub(3)
	_check(counter.value == 12, "tras restar 3, el contador vale 12 (vale %d)" % counter.value)
	counter.set(50)
	_check(counter.value == 50, "tras poner a 50, el contador vale 50 (vale %d)" % counter.value)
	counter.reset()
	_check(counter.value == 0, "tras resetear, el contador vale 0 (vale %d)" % counter.value)

	# 3. Crear una bolsa y verificar.
	editor._remember("test_bag_create")
	var bolsa_piece := {
		"id": "", "name": "Bolsa de fichas", "shape": "disco",
		"color": Palette.LAVENDER.to_html(true), "texture": "", "label": "Bolsa",
		"pattern": "liso", "cells": 8, "finish": "mate", "back": "", "notes": "",
		"shuffle": false, "tags": [], "zkind": "normal", "player": 0,
		"model": "", "msize": [0, 0, 0], "pos": [2, 0, 0], "rot": [0, 0, 0],
		"scale": 1.0, "locked": true, "mass": 1.0, "bounce": 0.1,
		"bag": {
			"label": "Bolsa de fichas", "hidden": true, "contained_ids": [],
		},
	}
	var bolsa_ent := editor._make_piece(bolsa_piece)
	bolsa_ent.position.y = editor._surface_height(bolsa_ent.position, [bolsa_ent])
	editor._pop_in(bolsa_ent)
	editor.select_pieces([bolsa_ent])

	var bag := bolsa_ent.get_component("BagComponent") as BagComponent
	_check(bag != null, "la pieza tiene BagComponent")
	_check(bag.count() == 0, "la bolsa empieza vacía (tiene %d)" % bag.count())

	# Agregar una pieza ficticia a la bolsa.
	var ok := bag.add("pieza_ficticia_1")
	_check(ok, "se agregó una pieza a la bolsa")
	_check(bag.count() == 1, "la bolsa tiene 1 pieza (tiene %d)" % bag.count())
	var sacada := bag.draw_random()
	_check(sacada == "pieza_ficticia_1", "se sacó la pieza: «%s»" % sacada)
	_check(bag.count() == 0, "la bolsa quedó vacía (tiene %d)" % bag.count())

	# 4. Crear una nota y verificar.
	editor._remember("test_note_create")
	var nota_piece := {
		"id": "", "name": "Nota informativa", "shape": "ficha",
		"color": Palette.PAPER.to_html(true), "texture": "", "label": "Nota",
		"pattern": "liso", "cells": 8, "finish": "mate", "back": "", "notes": "",
		"shuffle": false, "tags": [], "zkind": "normal", "player": 0,
		"model": "", "msize": [0, 0, 0], "pos": [-2, 0, 0], "rot": [0, 0, 0],
		"scale": 1.0, "locked": false, "mass": 1.0, "bounce": 0.1,
		"note": {
			"text": "Esta es una nota de prueba", "show_on_hover": true,
		},
	}
	var nota_ent := editor._make_piece(nota_piece)
	nota_ent.position.y = editor._surface_height(nota_ent.position, [nota_ent])
	editor._pop_in(nota_ent)
	editor.select_pieces([nota_ent])

	var note := nota_ent.get_component("NoteComponent") as NoteComponent
	_check(note != null, "la pieza tiene NoteComponent")
	_check(note.get_text() == "Esta es una nota de prueba", "la nota dice: «%s»" % note.get_text())
	note.set_text("Nota modificada")
	_check(note.get_text() == "Nota modificada", "la nota se modificó: «%s»" % note.get_text())

	# 5. Crear un reloj y verificar.
	editor._remember("test_timer_create")
	var reloj_piece := {
		"id": "", "name": "Reloj de arena", "shape": "disco",
		"color": Palette.SUN.to_html(true), "texture": "", "label": "Reloj",
		"pattern": "liso", "cells": 8, "finish": "mate", "back": "", "notes": "",
		"shuffle": false, "tags": [], "zkind": "normal", "player": 0,
		"model": "", "msize": [0, 0, 0], "pos": [0, 0, 2], "rot": [0, 0, 0],
		"scale": 1.0, "locked": false, "mass": 1.0, "bounce": 0.1,
		"timer": {
			"label": "Reloj de arena", "duration_seconds": 30.0,
			"running": false, "time_left": 30.0, "on_finish_message": "¡Tiempo agotado!",
		},
	}
	var reloj_ent := editor._make_piece(reloj_piece)
	reloj_ent.position.y = editor._surface_height(reloj_ent.position, [reloj_ent])
	editor._pop_in(reloj_ent)
	editor.select_pieces([reloj_ent])

	var timer := reloj_ent.get_component("TimerComponent") as TimerComponent
	_check(timer != null, "la pieza tiene TimerComponent")
	_check(timer.duration_seconds == 30.0, "el reloj dura 30 segundos (dura %f)" % timer.duration_seconds)
	_check(timer.remaining() == 30.0, "el reloj tiene 30 segundos restantes (%f)" % timer.remaining())
	timer.start()
	_check(timer.running, "el reloj está corriendo")
	timer.stop()
	_check(not timer.running, "el reloj se paró")
	timer.reset()
	_check(timer.remaining() == 30.0, "tras resetear, el reloj tiene 30 segundos (%f)" % timer.remaining())

	# 6. Guardar y cargar verifica serialización de todos los componentes.
	_check(editor.save_table(), "se guarda la mesa con todos los componentes")
	editor.clear_table()
	_check(hierarchy.entities.size() == 0, "mesa vaciada tras clear")
	_check(editor.load_table(), "se carga la mesa con todos los componentes")
	_check(hierarchy.entities.size() == 4, "tras cargar hay 4 entidades (%d)" % hierarchy.entities.size())

	# Verificar que el contador conservó su valor.
	var loaded_counter := null
	for e in hierarchy.entities:
		var c := e.get_component("CounterComponent") as CounterComponent
		if c != null:
			loaded_counter = c
			break
	_check(loaded_counter != null, "se encontró el contador cargado")
	_check(loaded_counter.value == 0, "el contador cargado tiene valor 0 (tiene %d)" % loaded_counter.value)

	# Verificar que la nota conservó su texto.
	var loaded_note := null
	for e in hierarchy.entities:
		var n := e.get_component("NoteComponent") as NoteComponent
		if n != null:
			loaded_note = n
			break
	_check(loaded_note != null, "se encontró la nota cargada")
	_check(loaded_note.get_text() == "Nota modificada", "la nota cargada dice: «%s»" % loaded_note.get_text())

	# Verificar que el reloj conservó su configuración.
	var loaded_timer := null
	for e in hierarchy.entities:
		var t := e.get_component("TimerComponent") as TimerComponent
		if t != null:
			loaded_timer = t
			break
	_check(loaded_timer != null, "se encontró el reloj cargado")
	_check(loaded_timer.duration_seconds == 30.0, "el reloj cargado dura 30 segundos (%f)" % loaded_timer.duration_seconds)

	# 7. Deshacer todo.
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	editor.undo()
	_check(hierarchy.entities.size() == 0, "tras deshacer todo, la mesa está vacía (%d)" % hierarchy.entities.size())

	# Limpieza.
	for f in [editor.table_save_path, editor.table_save_path + ".bak", editor.table_save_path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	if _failed:
		quit(1)
	else:
		print("editor_components_utilitarios: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
