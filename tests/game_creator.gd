extends SceneTree
## Editor de juegos: todos sus scripts compilan, la escena se abre, se crea una entidad, se
## importa una imagen, se aplica y la entidad sobrevive a guardarse y cargarse.

const FOLDER := "res://scripts/game_creator"
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 1. Todos los scripts cargan (un error de sintaxis deja can_instantiate en false).
	var scripts := _scripts(FOLDER)
	_check(scripts.size() >= 20, "se encuentran los scripts del editor")
	for path in scripts:
		var script := load(path) as GDScript
		_check(script != null and script.can_instantiate(), "compila %s" % path.get_file())

	# 2. La escena del editor se abre.
	var error := change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in 10:
		await process_frame
	_check(error == OK and current_scene != null and current_scene.scene_file_path.ends_with("GameCreatorEditor.tscn"), "el editor se abre")
	if current_scene == null:
		quit(1)
		return
	var editor := current_scene

	# 3. Crear una entidad y verla en la jerarquía.
	editor._spawn_example_entity()
	await process_frame
	var entity: PropEntity = editor._selected_entity
	_check(entity != null and editor._scene_hierarchy.entities.has(entity), "la entidad nueva aparece en la jerarquía")
	_check(entity.is_inside_tree(), "la entidad está en la escena")
	_check(entity.get_node_or_null("Body/Mesh") != null, "y se ve como una ficha en la vista previa")
	_check(entity.get_component("VisualComponent") != null and entity.get_component("PhysicsComponent") != null, "se encuentran sus componentes por tipo")

	# 4. Importar una imagen y aplicarla.
	var source := "user://test_creador_origen.png"
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.4, 0.2))
	image.save_png(source)
	var result: Dictionary = editor._image_importer.import_image(source)
	_check(bool(result.get("success", false)), "se importa un PNG: %s" % [result.get("error", "")])
	_check(not bool(editor._image_importer.import_image("user://notas.txt").get("success", false)), "se rechaza lo que no es imagen")
	var imported := str(result.get("path", ""))
	_check(editor._image_importer.load_texture(imported) is ImageTexture, "la imagen importada se carga como textura")
	editor._asset_browser.selected_image = result.get("info", {})
	editor._apply_selected_texture()
	_check(str(entity.get_component("VisualComponent").texture_path) == imported, "la imagen queda asignada a la entidad")

	# 5. Guardar y cargar la entidad.
	var data: Dictionary = entity.serialize()
	_check(data["components"].size() == 3 and data["components"][0]["type"] == "VisualComponent", "los componentes se guardan con su tipo")
	var copy := PropEntity.new()
	editor.add_child(copy)
	copy.deserialize(data)
	_check(copy.entity_name == entity.entity_name and copy.components.size() == 3, "la entidad se reconstruye")
	_check(str(copy.get_component("VisualComponent").texture_path) == imported, "con su imagen")

	# 6. Cambiar de modo y volver al menú.
	editor._toggle_mode()
	_check(not (entity.get_node("Body") as RigidBody3D).freeze and not paused, "al probar, las piezas tienen física y el juego no queda en pausa")
	for i in 90:
		await physics_frame
	_check((entity.get_node("Body") as RigidBody3D).global_position.y > -0.2, "y se apoyan en la mesa en vez de caer")
	editor._toggle_mode()
	_check((entity.get_node("Body") as RigidBody3D).freeze, "al volver a editar, quedan quietas")
	editor._remove_selected_entity()
	_check(editor._scene_hierarchy.entities.is_empty() and editor._selected_entity == null, "se puede quitar una pieza")
	for path in [source, imported]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor._back_to_menu()
	for i in 5:
		await process_frame
	_check(current_scene.scene_file_path == "res://scenes/BotMenu.tscn" and not paused, "se vuelve al menú principal sin pausa")
	if _failed:
		quit(1)
	else:
		print("game_creator: ok")
		quit(0)


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
