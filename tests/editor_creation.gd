extends SceneTree
## Opciones de creación del editor de juegos: plantillas, texto en piezas, dibujos de
## tablero, acabados, zonas, dados con puntos, repetir en rejilla, numerar, mezclar, y el
## modo prueba (agarrar, lanzar dados y leer su resultado).

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor := current_scene
	editor.table_save_path = "user://test_editor_creacion.json"
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Plantillas: cada una pone su mesa y se puede deshacer.
	var expected := {"damas": 25, "recorrido": 6, "cartas": 23, "dados": 6, "directo": 20}
	for name in TableTemplates.NAMES:
		editor.load_template(name)
		_check(hierarchy.entities.size() == expected[name], "la plantilla «%s» pone %d piezas (%d)" % [name, expected[name], hierarchy.entities.size()])
	editor.undo()
	_check(hierarchy.entities.size() == expected[TableTemplates.NAMES[TableTemplates.NAMES.size() - 2]], "Ctrl+Z devuelve la mesa de antes de la plantilla")
	editor.load_template("damas")
	var board: PropEntity = hierarchy.entities[0]
	var board_visual := board.get_component("VisualComponent") as VisualComponent
	_check(board_visual.pattern == "ajedrez" and board.get_node_or_null("Body/Mesh/Face") != null, "el tablero de damas lleva su dibujo de ajedrez")
	var face := board.get_node("Body/Mesh/Face") as MeshInstance3D
	var image := (face.material_override as StandardMaterial3D).albedo_texture.get_image()
	_check(image.get_pixel(10, 10).get_luminance() > image.get_pixel(80, 10).get_luminance(), "con casillas claras y oscuras alternas")
	var piece: PropEntity = hierarchy.entities[1]
	_check(absf(piece.position.y - PieceShapes.size_of("tablero").y) < 0.002, "las fichas están sobre el tablero")

	# 2. Dibujos, casillas, texto y acabado desde el inspector.
	editor.select_pieces([board])
	for pattern in PieceShapes.PATTERNS:
		editor._edit_selection("pattern", pattern)
		var has_face: bool = board.get_node_or_null("Body/Mesh/Face") != null
		_check(has_face == (pattern != "liso"), "el dibujo «%s» se ve en la cara de arriba" % pattern)
	editor._edit_selection("pattern", "casillas")
	editor._edit_selection("cells", 12)
	_check(board_visual.cells == 12, "cambian las casillas por lado")
	editor.select_pieces([piece])
	editor._edit_selection("label", "R")
	var label := piece.get_node_or_null("Body/Mesh/Label") as Label3D
	_check(label != null and label.text == "R", "se escribe texto en la pieza")
	editor._edit_selection("label", "")
	_check(piece.get_node_or_null("Body/Mesh/Label") == null, "y se borra")
	for finish in PieceShapes.FINISHES:
		editor._edit_selection("finish", finish)
		var material := (piece.get_node("Body/Mesh") as MeshInstance3D).material_override as StandardMaterial3D
		_check(material != null, "acabado «%s»" % finish)
		if finish == "metal":
			_check(material.metallic > 0.5, "el metal brilla como metal")
		if finish == "madera":
			_check(material.albedo_texture != null, "la madera lleva veta")

	# 3. Repetir en rejilla, numerar y mezclar.
	editor.clear_table()
	var card: PropEntity = editor.add_piece("carta")
	var made: Array = editor.repeat_selection(5, 2)
	_check(made.size() == 10 and hierarchy.entities.size() == 10, "repetir 5 × 2 deja 10 cartas")
	_check(editor.selection.size() == 10, "y las selecciona")
	var xs := {}
	for entity in made:
		xs[snappedf(entity.position.x, 0.01)] = true
	_check(xs.size() == 5, "en cinco columnas")
	editor.number_selection()
	var labels: Array = made.map(func(entity: PropEntity) -> String: return (entity.get_component("VisualComponent") as VisualComponent).label)
	labels.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	_check(labels == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], "numerar escribe del 1 al 10")
	var first_card := (card.get_component("VisualComponent") as VisualComponent).label
	_check(first_card == "1", "empezando por la de arriba a la izquierda")
	var before: Array = made.map(func(entity: PropEntity) -> Vector3: return entity.position)
	seed(3)
	editor.shuffle_selection()
	var after: Array = made.map(func(entity: PropEntity) -> Vector3: return entity.position)
	_check(before != after, "mezclar cambia el orden")
	before.sort()
	after.sort()
	_check(before == after, "sin inventar sitios nuevos")
	_check(editor.repeat_selection(20, 12).is_empty(), "no se pasa del máximo de piezas")

	# 4. Zonas: se ven, no sostienen piezas y no chocan.
	editor.clear_table()
	var zone: PropEntity = editor.add_piece("zona")
	_check(zone.is_locked and (zone.get_node("Body/Shape") as CollisionShape3D).disabled, "una zona nace fija y sin choque")
	var token: PropEntity = editor.add_piece("ficha")
	token.position = zone.position
	editor._settle([token])
	_check(is_zero_approx(token.position.y), "una ficha sobre una zona se posa en la mesa")

	# 5. Dados: puntos en las seis caras y lectura de la cara de arriba.
	var die: PropEntity = editor.add_piece("dado")
	var pips := die.get_node_or_null("Body/Mesh/Pips")
	_check(pips != null and pips.get_child_count() == 21, "el dado lleva 21 puntos")
	_check(PieceLooks.die_value(Basis.IDENTITY) == 1, "boca arriba sale 1")
	_check(PieceLooks.die_value(Basis(Vector3.RIGHT, PI)) == 6, "volteado sale 6")
	_check(PieceLooks.die_value(Basis(Vector3.RIGHT, -PI / 2)) == 2, "de lado sale 2")
	_check(PieceLooks.die_value(Basis(Vector3.FORWARD, -PI / 2)) == 3 or PieceLooks.die_value(Basis(Vector3.FORWARD, PI / 2)) == 3, "y 3 en su cara")

	# 6. Guardar y cargar conserva todo lo nuevo.
	editor.select_pieces([token])
	editor._edit_selection("label", "7")
	editor._edit_selection("finish", "metal")
	_check(editor.save_table(), "se guarda")
	editor.clear_table()
	_check(editor.load_table(), "se carga")
	var loaded := editor._find_piece(token.entity_id) as PropEntity
	var loaded_visual := loaded.get_component("VisualComponent") as VisualComponent
	_check(loaded_visual.label == "7" and loaded_visual.finish == "metal", "con texto y acabado")
	var old_record := {"pieces": [{"pos": [0, 0, 0], "rot": [0, 0, 0], "shape": "ficha"}]}
	var old_pieces: Variant = TableRecord.pieces_of(old_record)
	_check(old_pieces != null and old_pieces[0]["pattern"] == "liso" and old_pieces[0]["finish"] == "mate", "las mesas de antes se cargan con valores por defecto")
	_check(TableRecord.valid_piece({"pos": [0, 0, 0], "rot": [0, 0, 0], "pattern": "raro", "finish": "oro", "cells": 999})["cells"] == PieceShapes.MAX_CELLS, "y los valores raros se corrigen")

	# 7. Modo prueba: agarrar y soltar, tirar los dados y leer el resultado.
	editor.clear_table()
	var player_die: PropEntity = editor.add_piece("dado")
	player_die.position = Vector3(0, 0, 0)
	editor._toggle_mode()
	await physics_frame
	var cam: Camera3D = editor._camera
	editor._orbit = editor._orbit_goal.duplicate()
	editor._apply_orbit()
	var body := player_die.get_node("Body") as RigidBody3D
	var at := cam.unproject_position(body.global_position + Vector3.UP * 0.17)
	_mouse(editor, at, true)
	_check(not editor._held.is_empty() and body.freeze, "al probar, un clic agarra la pieza")
	var goal := cam.unproject_position(Vector3(0.8, 0, 0.4))
	_motion(editor, goal)
	_check(body.global_position.distance_to(Vector3(0.8, 0.35, 0.4)) < 0.15, "y la lleva flotando bajo el ratón (%s)" % body.global_position)
	_mouse(editor, goal, false)
	_check(editor._held.is_empty() and not body.freeze, "al soltarla cae con la física")

	_check(player_die.position.is_zero_approx(), "sin mover su sitio de edición")
	var rolled: Array = editor.roll_dice()
	_check(rolled == [player_die], "R lanza los dados")
	var waited := 0
	while not editor._rolling.is_empty() and waited < 900:
		await physics_frame
		await process_frame
		waited += 1
	_check(editor._rolling.is_empty(), "el dado se para")
	_check(editor.last_roll.size() == 1 and editor.last_roll[0] >= 1 and editor.last_roll[0] <= 6, "y se lee lo que ha salido: %s" % [editor.last_roll])
	_check(editor.last_roll[0] == PieceLooks.die_value(body.global_transform.basis), "que es la cara de arriba")
	var center := body.global_transform * Vector3(0, 0.17, 0)
	_check(absf(center.y - 0.17) < 0.03 and Vector2(center.x, center.z).length() < 2.6, "con el dado parado sobre la mesa (%s)" % center)
	_key(editor, KEY_ESCAPE)
	_check(editor._build_mode and current_scene == editor, "Esc al probar vuelve a editar")
	_check(body.transform.is_equal_approx(Transform3D.IDENTITY), "y el dado vuelve a su sitio")

	for file in [editor.table_save_path, editor.table_save_path + ".bak", editor.table_save_path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	if _failed:
		quit(1)
	else:
		print("editor_creation: ok")
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


func _key(editor: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	editor._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
