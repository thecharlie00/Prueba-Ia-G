extends SceneTree
## Modelos 3D (.obj y .glb), archivos arrastrados a la ventana y zonas de mano y ocultas.

const OBJ := "user://test_modelo.obj"
const GLB := "user://test_modelo.glb"
const PACKAGE := "user://test_modelos.tablerama"
var _failed := false
var _made: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1. Un .obj (una pirámide de base cuadrada, con índices negativos en una cara).
	var obj := "v -1 0 -1\nv 1 0 -1\nv 1 0 1\nv -1 0 1\nv 0 3 0\nf 1 2 3 4\nf 1 5 2\nf 2 5 3\nf 3 5 4\nf -2 -1 -5\n"
	var mesh := ModelLoader.parse_obj(obj)
	_check(mesh != null and mesh.get_surface_count() == 1, "se lee un .obj")
	_check(ModelLoader.parse_obj("v 0 0 0\nf 1 2 3") == null, "un .obj con caras rotas se rechaza")
	_write(OBJ, obj.to_utf8_buffer())

	# 2. Un .glb hecho aquí con una caja de color.
	var scene := Node3D.new()
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(2, 1, 4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	box_mesh.material = material
	box.mesh = box_mesh
	scene.add_child(box)
	box.owner = scene
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	_check(document.append_from_scene(scene, state) == OK and document.write_to_filesystem(state, GLB) == OK, "se escribe un .glb de prueba")
	scene.free()

	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor := current_scene

	# 3. Ponerlos en la mesa: encajados (lado mayor 0,5), con la base en la mesa.
	var pyramid: PropEntity = editor.add_model_piece(OBJ)
	_check(pyramid != null and pyramid.get_node_or_null("Body/Mesh/Model") != null, "un .obj se pone en la mesa")
	var size := PieceShapes.piece_size(pyramid.get_component("VisualComponent") as VisualComponent)
	_check(is_equal_approx(maxf(size.x, maxf(size.y, size.z)), ModelLoader.FIT) and is_equal_approx(size.y, 0.5), "encajado a 0,5 por su lado mayor: %s" % size)
	_track(pyramid)
	var crate: PropEntity = editor.add_model_piece(GLB)
	_check(crate != null, "un .glb se pone en la mesa")
	_track(crate)
	var crate_size := PieceShapes.piece_size(crate.get_component("VisualComponent") as VisualComponent)
	_check(is_equal_approx(crate_size.z, 0.5) and is_equal_approx(crate_size.x, 0.25), "con su proporción: %s" % crate_size)
	var meshes: Array = crate.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.any(func(m: MeshInstance3D) -> bool: return m.mesh != null and m.mesh.surface_get_material(0) != null), "y con sus materiales")
	editor.select_pieces([crate])
	editor.scale_selection(2.0)
	_check(is_equal_approx(PieceShapes.piece_size(crate.get_component("VisualComponent") as VisualComponent).z, 1.0), "un modelo cambia de tamaño")
	var token: PropEntity = editor.add_piece("ficha")
	token.position = crate.position
	editor._settle([token])
	_check(absf(token.position.y - PieceShapes.piece_size(crate.get_component("VisualComponent") as VisualComponent).y) < 0.01, "una pieza se apila encima de un modelo (%.3f)" % token.position.y)
	_check(editor.add_model_piece("user://no_existe.glb") == null, "un modelo que no existe no rompe nada")

	# 4. Arrastrar archivos a la ventana.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	image.save_png("user://test_arrastrada.png")
	var before: int = editor._scene_hierarchy.entities.size()
	var images_before: int = editor._image_importer.get_imported_images().size()
	var used: int = editor.handle_dropped_files(PackedStringArray(["user://test_arrastrada.png", OBJ, "user://nota.txt"]))
	_check(used == 2, "de tres archivos arrastrados se usan la imagen y el modelo")
	_check(editor._image_importer.get_imported_images().size() == images_before + 1, "la imagen va a la galería")
	_check(editor._scene_hierarchy.entities.size() == before + 1, "y el modelo a la mesa")
	_track(editor._scene_hierarchy.entities.back())
	var imported_image: String = editor._image_importer.get_imported_images().back()["path"]

	# 5. Los modelos viajan dentro del juego exportado.
	_check(editor.export_game(PACKAGE), "se exporta con modelos")
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
	_check((package.get("models", {}) as Dictionary).size() == 3, "el archivo lleva los tres modelos")
	editor.clear_table()
	_check(editor.import_game(PACKAGE), "y se importa")
	var models: Array = editor._scene_hierarchy.entities.filter(func(e: PropEntity) -> bool: return (e.get_component("VisualComponent") as VisualComponent).shape == PieceShapes.MODEL)
	_check(models.size() == 3 and models.all(func(e: PropEntity) -> bool: return e.get_node_or_null("Body/Mesh/Model") != null), "con sus modelos en la mesa")
	for entity in models:
		_track(entity)

	# 6. Zonas: la de mano ordena en fila boca arriba; la oculta se tapa al probar.
	editor.clear_table()
	editor.logic = LogicGraph.new()
	var hand: PropEntity = editor.add_piece("zona")
	hand.position = Vector3(0, 0, 0.9)
	editor.select_pieces([hand])
	editor._edit_selection("zone_kind", "mano")
	editor._edit_selection("scale", 1.8)
	var hidden: PropEntity = editor.add_piece("zona")
	hidden.position = Vector3(-1.2, 0, -0.6)
	editor.select_pieces([hidden])
	editor._edit_selection("zone_kind", "oculta")
	var cards: Array = []
	for i in range(3):
		var card: PropEntity = editor.add_piece("carta")
		card.position = Vector3(0.9 - i * 0.6, 0, -0.9)
		cards.append(card)
	editor._toggle_mode()
	_check(hidden.get_node_or_null("HiddenCover") != null, "al probar, la zona oculta lleva su tapa")
	_check(hand.get_node_or_null("HiddenCover") == null, "la de mano no")
	_check(editor.logic_deal(3, "", hand.entity_id) == 3, "se reparten 3 cartas a la mano")
	var xs: Array = editor.logic_pieces(hand.entity_id, "").map(func(id: String) -> float: return (hand.global_transform.affine_inverse() * editor._piece_transform(editor._find_piece(id)).origin).x)
	xs.sort()
	_check(xs.size() == 3 and xs[1] - xs[0] > 0.3 and xs[2] - xs[1] > 0.3, "en fila y separadas: %s" % [xs])
	editor._toggle_mode()
	_check(hidden.get_node_or_null("HiddenCover") == null or hidden.get_node("HiddenCover").is_queued_for_deletion(), "al editar, la tapa se quita")
	var record: Dictionary = TableRecord.valid_piece(TableRecord.piece_record(hand))
	_check(record["zkind"] == "mano", "el tipo de zona se guarda")

	for path in [OBJ, GLB, PACKAGE, "user://test_arrastrada.png", imported_image]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for path in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failed:
		quit(1)
	else:
		print("editor_models: ok")
		quit(0)


func _track(entity: PropEntity) -> void:
	if entity == null:
		return
	var path := (entity.get_component("VisualComponent") as VisualComponent).mesh_path
	if path != "" and not path in _made:
		_made.append(path)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
