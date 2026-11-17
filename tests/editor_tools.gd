extends SceneTree
## Herramientas de edición de la mesa del editor de juegos: formas, selección múltiple,
## arrastrar con imán y apilado, girar, voltear, duplicar, copiar y pegar, ordenar,
## deshacer/rehacer, guardar y cargar la mesa, piezas fijas, atajos y cámara.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor := current_scene
	editor.table_save_path = "user://test_editor_mesa.json"
	_remove(editor.table_save_path)

	# 1. Todas las formas se pueden poner y tienen malla y cuerpo con su tamaño.
	var shapes: Array = PieceShapes.SHAPES.filter(func(shape: String) -> bool: return shape != PieceShapes.MODEL)
	for shape in shapes:
		var made: PropEntity = editor.add_piece(shape)
		var visual := made.get_component("VisualComponent") as VisualComponent
		_check(visual.shape == shape and made.get_node_or_null("Body/Mesh") != null, "se pone una pieza «%s»" % shape)
	_check(editor._scene_hierarchy.entities.size() == shapes.size(), "todas aparecen en la lista")
	var board: PropEntity = editor._scene_hierarchy.entities.filter(func(e: PropEntity) -> bool: return (e.get_component("VisualComponent") as VisualComponent).shape == "tablero")[0]
	_check(board.is_locked, "el tablero nace fijo")
	editor.clear_table()
	_check(editor._scene_hierarchy.entities.is_empty(), "«Vaciar» deja la mesa vacía")
	editor.undo()
	_check(editor._scene_hierarchy.entities.size() == shapes.size(), "y Ctrl+Z la recupera entera")
	editor.clear_table()
	editor.history.clear()

	# 2. Una ficha sobre un tablero se apoya encima, no dentro.
	var base: PropEntity = editor.add_piece("tablero")
	var token: PropEntity = editor.add_piece("ficha")
	var board_top := PieceShapes.size_of("tablero").y
	_check(absf(token.position.y - board_top) < 0.002, "una pieza nueva se posa sobre el tablero (%.3f)" % token.position.y)
	_check(editor.selection == [token] and editor._selected_entity == token, "y queda seleccionada")

	# 3. Arrastrar con el ratón: mueve con imán y se apila sobre otras piezas.
	await process_frame
	var cam: Camera3D = editor._camera
	editor._orbit = editor._orbit_goal.duplicate()
	editor._apply_orbit()
	var origin := token.position
	var start := cam.unproject_position(token.global_position + Vector3.UP * 0.05)
	_check(editor.piece_at(start) == token, "la pieza se encuentra bajo el ratón")
	var goal := cam.unproject_position(Vector3(0.83, board_top, -0.41))
	_mouse(editor, start, true)
	_motion(editor, start.lerp(goal, 0.5))
	_motion(editor, goal)
	_mouse(editor, goal, false)
	var p := token.position
	_check(is_equal_approx(p.x, snappedf(p.x, 0.1)) and is_equal_approx(p.z, snappedf(p.z, 0.1)), "al arrastrar cae en la cuadrícula: %s" % p)
	_check(absf(p.x - 0.8) < 0.11 and absf(p.z + 0.4) < 0.11, "y donde se soltó")
	editor.undo()
	token = editor._find_piece(token.entity_id)
	_check(token != null and token.position.distance_to(origin) < 0.002, "el arrastre se deshace y la ficha vuelve a su sitio")
	editor.redo()
	token = editor._find_piece(token.entity_id)
	base = editor._find_piece(base.entity_id)
	_check(absf(token.position.x - 0.8) < 0.11, "y se rehace")
	_check(editor.selection == [token], "con la selección que había")

	var die: PropEntity = editor.add_piece("dado")
	editor.select_pieces([die])
	var die_from := cam.unproject_position(die.global_position + Vector3.UP * 0.17)
	var onto := cam.unproject_position(token.global_position + Vector3.UP * 0.05)
	_mouse(editor, die_from, true)
	_motion(editor, die_from.lerp(onto, 0.5))
	_motion(editor, onto)
	_mouse(editor, onto, false)
	_check(die.position.y > board_top + 0.07, "soltado encima de la ficha, el dado se apila (%.3f)" % die.position.y)

	# 4. Girar, voltear, tamaño, color y forma (con imán, el giro va de 15 en 15).
	editor.select_pieces([token])
	editor.rotate_selection(15.0)
	editor.rotate_selection(15.0)
	_check(is_equal_approx(token.rotation_degrees.y, 30.0), "Q/E giran 15°")
	editor.flip_selection()
	_check(absf(token.rotation_degrees.z) > 90.0 and token.position.y > board_top, "F voltea la pieza y sigue apoyada")
	editor.flip_selection()
	editor._edit_selection("color", Palette.PLAYER_GREEN)
	_check((token.get_component("VisualComponent") as VisualComponent).color_tint == Palette.PLAYER_GREEN, "cambia el color")
	editor._edit_selection("shape", "carta")
	_check((token.get_component("VisualComponent") as VisualComponent).shape == "carta", "cambia la forma")
	editor.scale_selection(2.0)
	_check(absf((token.get_component("VisualComponent") as VisualComponent).scale_factor - 2.0) < 0.06, "cambia el tamaño")
	var spin: SpinBox = editor._spins["x"]
	spin.value = -1.2
	_check(is_equal_approx(token.position.x, -1.2), "los números del inspector mueven la pieza")

	# 5. Selección múltiple: recuadro, Ctrl+clic, duplicar, copiar y pegar, ordenar.
	editor.select_pieces([])
	editor._drag = {"kind": "box", "start": Vector2.ZERO, "additive": false, "base": []}
	editor._select_in_box(Rect2(Vector2.ZERO, editor.size))
	_check(editor.selection.size() == editor._scene_hierarchy.entities.size(), "el recuadro selecciona todo lo que abarca")
	editor._drag = {}
	editor.select_pieces([token])
	editor._toggle_in_selection(die)
	_check(editor.selection == [token, die] and editor._selected_entity == die, "Ctrl+clic añade a la selección")
	var before: int = editor._scene_hierarchy.entities.size()
	editor.duplicate_selection()
	_check(editor._scene_hierarchy.entities.size() == before + 2 and editor.selection.size() == 2, "duplicar copia las dos y selecciona las copias")
	var ids := {}
	for entity in editor._scene_hierarchy.entities:
		ids[entity.entity_id] = true
	_check(ids.size() == editor._scene_hierarchy.entities.size(), "cada pieza tiene un id distinto")
	editor.copy_selection()
	editor.paste_clipboard()
	_check(editor._scene_hierarchy.entities.size() == before + 4, "copiar y pegar")
	editor.arrange_row_selection()
	var a: PropEntity = editor.selection[0]
	var b: PropEntity = editor.selection[1]
	_check(is_equal_approx(a.position.z, b.position.z) and absf(a.position.x - b.position.x) > 0.2, "«En fila» las alinea con hueco")
	editor.stack_selection()
	_check(is_equal_approx(a.position.x, b.position.x) and absf(a.position.y - b.position.y) > 0.01, "«Apilar» las pone una encima de otra")
	editor._remove_selected_entity()
	_check(editor._scene_hierarchy.entities.size() == before + 2 and editor.selection.is_empty(), "Supr quita toda la selección")

	# 6. La lista también selecciona varias.
	var hierarchy: SceneHierarchy = editor._scene_hierarchy
	hierarchy.selection_changed.emit([base, die])
	_check(editor.selection == [base, die], "elegir en la lista selecciona en la mesa")

	# 7. Atajos de teclado.
	var count: int = hierarchy.entities.size()
	editor.select_pieces([die])
	_key(editor, KEY_D, true)
	_check(hierarchy.entities.size() == count + 1, "Ctrl+D duplica")
	_key(editor, KEY_Z, true)
	_check(hierarchy.entities.size() == count, "Ctrl+Z deshace")
	die = editor._find_piece(die.entity_id)
	base = editor._find_piece(base.entity_id)
	_check(editor.selection == [die], "y vuelve a seleccionar lo de antes")
	_key(editor, KEY_Y, true)
	_check(hierarchy.entities.size() == count + 1, "Ctrl+Y rehace")
	die = editor._find_piece(die.entity_id)
	base = editor._find_piece(base.entity_id)
	var turn: float = editor._selected_entity.rotation_degrees.y
	_key(editor, KEY_E, false)
	_check(is_equal_approx(wrapf(editor._selected_entity.rotation_degrees.y - turn, -180, 180), 15.0), "E gira")
	_key(editor, KEY_G, false)
	_check(not editor.snap and not editor._grid.visible, "G apaga el imán y la cuadrícula")
	_key(editor, KEY_G, false)
	_key(editor, KEY_DELETE, false)
	_check(hierarchy.entities.size() == count, "Supr quita")

	# 8. Piezas fijas: no se arrastran y no caen al probar.
	editor.select_pieces([base])
	var base_from := cam.unproject_position(base.global_position + Vector3(1.6, 0.02, 1.6))
	if editor.piece_at(base_from) == base:
		_mouse(editor, base_from, true)
		_check(editor._drag.is_empty(), "una pieza fija no se arrastra")
		_mouse(editor, base_from, false)
	editor._toggle_mode()
	_check((base.get_node("Body") as RigidBody3D).freeze and not (die.get_node("Body") as RigidBody3D).freeze, "al probar, la fija no se mueve y las demás sí")
	editor._toggle_mode()

	# 9. Guardar y cargar la mesa; un archivo malo no rompe nada.
	var saved_count: int = hierarchy.entities.size()
	_check(editor.save_table(), "se guarda la mesa")
	editor.clear_table()
	_check(editor.load_table() and hierarchy.entities.size() == saved_count, "y se carga con todas sus piezas")
	var loaded_die: PropEntity = editor._find_piece(die.entity_id)
	_check(loaded_die != null and (loaded_die.get_component("VisualComponent") as VisualComponent).shape == "dado", "con su forma")
	_check(TableRecord.pieces_of({"pieces": [{"pos": [0, 0, 99], "rot": [0, 0, 0]}]}) == null, "se rechazan piezas fuera de la mesa")
	_check(TableRecord.pieces_of({"pieces": [{"pos": [0, 0, 0], "rot": [0, 0, 0], "texture": "C:/secreto.png"}]}) == null, "y rutas de imagen raras")
	_check(TableRecord.pieces_of({"pieces": "x"}) == null, "y registros sin piezas")

	# 10. Cámara y ayuda.
	var distance: float = editor._orbit_goal["distance"]
	editor.zoom_camera(0.5)
	_check(float(editor._orbit_goal["distance"]) < distance, "la rueda acerca la cámara")
	editor.orbit_camera(40, 10)
	_check(not is_zero_approx(float(editor._orbit_goal["yaw"])), "el botón derecho orbita")
	editor.select_pieces([loaded_die])
	editor.focus_selection()
	_check((editor._orbit_goal["target"] as Vector3).distance_to(loaded_die.global_position) < 0.01, "C enfoca la selección")
	editor.reset_camera()
	_check(is_zero_approx(float(editor._orbit_goal["yaw"])), "Inicio recoloca la cámara")
	_check(editor.help_text().contains("Ctrl+Z"), "F1 explica los atajos del editor")
	_key(editor, KEY_ESCAPE, false)
	_check(editor.selection.is_empty() and current_scene == editor, "Esc suelta la selección sin salir")

	_remove(editor.table_save_path)
	if _failed:
		quit(1)
	else:
		print("editor_tools: ok")
		quit(0)


func _mouse(editor: Control, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	editor._gui_input(event)


func _motion(editor: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	editor._gui_input(event)


func _key(editor: Control, keycode: Key, ctrl: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.ctrl_pressed = ctrl
	if keycode == KEY_ESCAPE:
		event.physical_keycode = KEY_ESCAPE
	editor._unhandled_input(event)


func _remove(path: String) -> void:
	for file in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
