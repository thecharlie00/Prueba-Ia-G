extends SceneTree
## Lo que en Tabletop Simulator pide programas aparte o enlaces a webs, aquí dentro del
## editor: mazos cortados de una hoja de cartas, una carta por imagen, reversos,
## descripciones, anclajes con giro, zonas que mezclan al probar y exportar/importar el juego
## en un solo archivo con las imágenes dentro.

const IMAGES := UiLayout.IMAGE_ROOT + "test_tts/"
const PACKAGE := "user://test_tts_juego.tablerama"
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	var editor := current_scene
	var importer: ImageImporter = editor._image_importer
	importer.import_folder = IMAGES
	importer.imported_images.clear()
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Una hoja de 4 × 2 cartas de colores se corta sola en un mazo.
	var colors := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE, Color.WHITE]
	var sheet := Image.create(400, 280, false, Image.FORMAT_RGBA8)
	for i in 8:
		sheet.fill_rect(Rect2i((i % 4) * 100, (i / 4) * 140, 100, 140), colors[i])
	var saved: Dictionary = importer.save_image(sheet, "hoja")
	_check(saved.get("success") == true, "se guarda una imagen hecha en el editor")
	var deck: Array = editor.deck_from_sheet(saved["path"], 4, 2, 7)
	_check(deck.size() == 7 and hierarchy.entities.size() == 7, "la hoja da un mazo de 7 cartas")
	var ok_colors := true
	for i in deck.size():
		var path := str(((deck[i] as PropEntity).get_component("VisualComponent") as VisualComponent).texture_path)
		var card := Image.load_from_file(path)
		ok_colors = ok_colors and card != null and card.get_size() == Vector2i(100, 140) and card.get_pixel(50, 70).is_equal_approx(colors[i])
	_check(ok_colors, "cada carta es su trozo de la hoja, en orden")
	_check(deck[1].position.y > deck[0].position.y and is_equal_approx(deck[1].position.x, deck[0].position.x), "apiladas en un mazo")
	_check((deck[0] as PropEntity).get_node_or_null("Body/Mesh/Face") != null, "con la imagen entera en la cara")
	var tiny: Dictionary = importer.save_image(Image.create(60, 60, false, Image.FORMAT_RGBA8), "diminuta")
	_check(editor.deck_from_sheet(tiny["path"], 20, 20, 3).is_empty(), "una rejilla de cartas diminutas se rechaza")

	# 2. Reverso para todo el mazo y descripción.
	var back_image := Image.create(50, 70, false, Image.FORMAT_RGBA8)
	back_image.fill(Color(0.2, 0.1, 0.4))
	var back_saved: Dictionary = importer.save_image(back_image, "reverso")
	editor._asset_browser.selected_image = back_saved["info"]
	editor.select_pieces(deck)
	editor._apply_selected_back()
	var all_backs := deck.all(func(card: PropEntity) -> bool: return card.get_node_or_null("Body/Mesh/Back") != null)
	_check(all_backs, "«Poner reverso» da dorso a todas las cartas seleccionadas")
	editor.select_pieces([deck[0]])
	editor._edit_selection("notes", "Roba dos cartas")
	editor._show_hover_info(deck[0])
	_check(editor._status_bar.text.contains("Roba dos cartas"), "al pasar el ratón se lee la descripción")

	# 3. Una carta por imagen de la galería.
	var before := hierarchy.entities.size()
	var gallery_cards: Array = editor.cards_from_gallery()
	_check(gallery_cards.size() == importer.get_imported_images().size() and hierarchy.entities.size() == before + gallery_cards.size(), "una carta por cada imagen de la galería")
	editor.undo()
	_check(hierarchy.entities.size() == before, "y se deshace de una vez")

	# 4. Anclajes: al arrastrar cerca, la pieza se pega y toma su giro.
	editor.clear_table()
	var anchor: PropEntity = editor.add_piece("anclaje")
	anchor.position = Vector3(1.0, 0, -0.5)
	anchor.rotation_degrees.y = 45
	var token: PropEntity = editor.add_piece("ficha")
	editor.select_pieces([token])
	var cam: Camera3D = editor._camera
	editor._orbit = editor._orbit_goal.duplicate()
	editor._apply_orbit()
	await process_frame
	var from := cam.unproject_position(token.global_position + Vector3.UP * 0.04)
	var near := cam.unproject_position(Vector3(1.12, 0, -0.42))
	_mouse(editor, from, true)
	_motion(editor, from.lerp(near, 0.5))
	_motion(editor, near)
	_mouse(editor, near, false)
	_check(Vector2(token.position.x, token.position.z).distance_to(Vector2(1.0, -0.5)) < 0.01, "soltada cerca del anclaje, la ficha se pega a él (%s)" % token.position)
	_check(is_equal_approx(token.rotation_degrees.y, 45.0), "y toma su giro")
	_check(is_zero_approx(token.position.y), "sin subirse encima del anclaje")

	# 5. Zonas que mezclan al probar; los anclajes no se ven al probar pero siguen atrayendo.
	var zone: PropEntity = editor.add_piece("zona")
	zone.position = Vector3(-1.0, 0, 0.6)
	editor.select_pieces([zone])
	editor._edit_selection("shuffle", true)
	_check((zone.get_component("VisualComponent") as VisualComponent).shuffle_on_play, "una zona se marca para mezclar")
	var tokens: Array = []
	for i in 4:
		var t: PropEntity = editor.add_piece("ficha")
		t.position = Vector3(-1.3 + i * 0.2, 0.0, 0.6)
		(t.get_component("VisualComponent") as VisualComponent).label = str(i + 1)
		tokens.append(t)
	seed(5)
	editor._toggle_mode()
	var moved := tokens.any(func(t: PropEntity) -> bool: return not (t.get_node("Body") as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
	_check(moved, "al empezar a probar, las piezas de la zona se mezclan")
	_check(not (anchor.get_node("Body/Mesh") as Node3D).visible, "el anclaje no se ve al probar")
	var body := token.get_node("Body") as RigidBody3D
	body.global_position = Vector3(1.15, 0.4, -0.38)
	editor._snap_body_to_anchor(token, body)
	_check(Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(1.0, -0.5)) < 0.01, "al probar, soltar cerca de un anclaje también pega")
	editor._toggle_mode()
	_check((anchor.get_node("Body/Mesh") as Node3D).visible, "y al editar vuelve a verse")

	# 6. Exportar e importar el juego entero, con imágenes dentro.
	editor.clear_table()
	deck = editor.deck_from_sheet(saved["path"], 4, 2, 3)
	editor.select_pieces(deck)
	editor._apply_selected_back()
	var ui_id: int = editor.add_ui_element("image")
	editor.set_ui_property("image", str(back_saved["path"]))
	_check(editor.export_game(PACKAGE), "se exporta el juego")
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
	_check(package["format"] == "tablerama-juego" and (package["images"] as Dictionary).size() == 4, "el archivo lleva las 4 imágenes dentro (3 caras y el reverso)")
	editor.clear_table()
	editor.ui_layout = UiLayout.new()
	var count_before := importer.get_imported_images().size()
	_check(editor.import_game(PACKAGE), "y se importa")
	_check(hierarchy.entities.size() == 3, "con sus 3 cartas")
	var card: PropEntity = hierarchy.entities[0]
	var visual := card.get_component("VisualComponent") as VisualComponent
	_check(FileAccess.file_exists(visual.texture_path) and FileAccess.file_exists(visual.back_path) and visual.texture_path != str(deck[0].get_component("VisualComponent").texture_path if is_instance_valid(deck[0]) else ""), "sus imágenes vuelven a la galería con rutas nuevas")
	_check(importer.get_imported_images().size() == count_before + 4, "las 4 imágenes están en la galería")
	_check(editor.ui_layout.elements.size() == 1 and FileAccess.file_exists(str(editor.ui_layout.elements[0]["image"])), "y la interfaz con su imagen")
	editor.undo()
	_check(hierarchy.entities.is_empty(), "importar se deshace")

	# 7. Archivos malos: no se toca nada.
	var bad := FileAccess.open("user://test_tts_malo.tablerama", FileAccess.WRITE)
	bad.store_string(JSON.stringify({"format": "otra-cosa"}))
	bad.close()
	_check(not editor.import_game("user://test_tts_malo.tablerama"), "un archivo que no es un juego se rechaza")
	bad = FileAccess.open("user://test_tts_malo.tablerama", FileAccess.WRITE)
	bad.store_string(JSON.stringify({"format": "tablerama-juego", "images": {}, "table": {"pieces": [{"pos": [0, 0, 0], "rot": [0, 0, 0], "texture": "C:/Windows/x.png"}]}}))
	bad.close()
	_check(not editor.import_game("user://test_tts_malo.tablerama") and hierarchy.entities.is_empty(), "y uno con rutas fuera del juego también")

	_cleanup()
	if _failed:
		quit(1)
	else:
		print("editor_tts: ok")
		quit(0)


func _cleanup() -> void:
	for file in DirAccess.get_files_at(IMAGES):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(IMAGES + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IMAGES))
	for file in [PACKAGE, "user://test_tts_malo.tablerama"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


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


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
