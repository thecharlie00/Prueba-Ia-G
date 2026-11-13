# GameCreatorEditor.gd
# Escena de entrada al Editor Universal de Juegos (Game Creator Studio).
# Workspace estilo IDE con Viewport 3D, Asset Browser, Jerarquía de Escena e Inspector.
# Permite importar imágenes y asignarlas como texturas a entidades del tablero.
class_name GameCreatorEditor
extends Control

# Nodos de UI (creados por código en _build_editor_ui y guardados aquí; antes se buscaban
# por rutas que no existían).
@onready var _docks: HBoxContainer = $Docks
@onready var _status_bar: Label = $StatusBar/StatusLabel
@onready var _viewport: SubViewport = $ViewportContainer/Viewport
var _build_button: Button
var _playtest_button: Button
var _log: Label
var _inspect_target: Label
var _position_label: Label
var _rotation_label: Label
var _texture_label: Label
## Raíz 3D de las entidades, dentro de la vista previa.
var _entities_root: Node3D

# Sistemas del editor.
var _image_importer: ImageImporter = null
var _asset_browser: AssetBrowser = null
var _scene_hierarchy: SceneHierarchy = null

# Estado del editor.
var _build_mode: bool = true

# FileDialog para importar imágenes.
var _file_dialog: FileDialog = null

# Entidad actualmente seleccionada (para asignar texturas).
var _selected_entity: PropEntity = null

const DIM := Color(0.62, 0.6, 0.7)
const MENU_SCENE := "res://scenes/BotMenu.tscn"


func _ready() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		push_error("[GameCreatorEditor] GameCreatorCore no está registrado como autoload.")
		return
	core.enter_build_mode()
	core.state_changed.connect(_on_state_changed)

	_image_importer = ImageImporter.new()
	add_child(_image_importer)
	_image_importer.image_imported.connect(_on_image_imported)
	_image_importer.import_failed.connect(_on_import_failed)

	_build_preview()
	_build_editor_ui()
	_update_status("Editor de juegos · modo construcción · Esc vuelve al menú")
	_build_button.grab_focus.call_deferred()


func _exit_tree() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core != null and core.state_changed.is_connected(_on_state_changed):
		core.state_changed.disconnect(_on_state_changed)


# Vista previa 3D: una mesa, luz y cámara; las entidades se ven como fichas con su imagen.
func _build_preview() -> void:
	_viewport.own_world_3d = true
	var world := Node3D.new()
	world.name = "Preview"
	_viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Palette.INK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.74, 0.85)
	environment.environment.ambient_light_energy = 0.9
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var table := MeshInstance3D.new()
	table.name = "Table"
	var top := CylinderMesh.new()
	top.top_radius = 2.6
	top.bottom_radius = 2.6
	top.height = 0.12
	top.radial_segments = 48
	table.mesh = top
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Palette.FELT
	felt.roughness = 1.0
	table.material_override = felt
	table.position.y = -0.06
	world.add_child(table)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.4, 3.6)
	camera.fov = 45
	world.add_child(camera)
	camera.look_at(Vector3(0, 0, 0.2))
	camera.current = true
	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	world.add_child(_entities_root)


func _build_editor_ui() -> void:
	for child in _docks.get_children():
		child.queue_free()
	_docks.add_theme_constant_override("separation", 0)
	_docks.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ========== Izquierda: modo, imágenes y entidades ==========
	var left := _make_dock("LeftDock")
	_docks.add_child(left["panel"])
	var left_col: VBoxContainer = left["column"]
	left_col.add_child(_caption("MODO"))
	_build_button = _button("▶  Probar la mesa", _toggle_mode)
	_build_button.name = "BuildModeButton"
	left_col.add_child(_build_button)
	_playtest_button = _button("⏸  Volver a editar", _toggle_mode)
	_playtest_button.name = "PlaytestButton"
	_playtest_button.visible = false
	left_col.add_child(_playtest_button)

	left_col.add_child(_caption("PIEZAS"))
	var new_entity := _button("+  Nueva pieza", _spawn_example_entity)
	new_entity.name = "NewEntityButton"
	left_col.add_child(new_entity)

	left_col.add_child(_caption("IMÁGENES"))
	var import_button := _button("Importar imagen…", _open_image_import_dialog)
	import_button.name = "ImportImageButton"
	left_col.add_child(import_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_col.add_child(scroll)
	_asset_browser = AssetBrowser.new()
	_asset_browser.name = "AssetBrowser"
	_asset_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_asset_browser)
	_asset_browser.build_ui()
	_asset_browser.set_image_importer(_image_importer)
	_asset_browser.image_selected.connect(_on_asset_selected)
	var back := _button("←  Volver al menú", _back_to_menu)
	back.name = "BackButton"
	left_col.add_child(back)

	# ========== Centro: se ve la vista previa 3D; abajo, la consola ==========
	var center := VBoxContainer.new()
	center.name = "CenterDock"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_docks.add_child(center)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(gap)
	var console := PanelContainer.new()
	console.name = "BottomDock"
	center.add_child(console)
	_log = Label.new()
	_log.name = "LogText"
	_log.text = "> Crea una pieza, importa una imagen y pulsa «Poner imagen»."
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_size_override("font_size", 13)
	console.add_child(_log)

	# ========== Derecha: jerarquía e inspector ==========
	var right := _make_dock("RightDock")
	_docks.add_child(right["panel"])
	var right_col: VBoxContainer = right["column"]
	_scene_hierarchy = SceneHierarchy.new()
	_scene_hierarchy.name = "SceneHierarchy"
	_scene_hierarchy.custom_minimum_size = Vector2(0, 240)
	_scene_hierarchy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(_scene_hierarchy)
	_scene_hierarchy.entity_selected.connect(_on_entity_selected)

	right_col.add_child(_caption("INSPECTOR"))
	_inspect_target = Label.new()
	_inspect_target.name = "InspectTarget"
	_inspect_target.text = "Selecciona una pieza en la lista."
	_inspect_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_col.add_child(_inspect_target)
	_position_label = _small("Posición: —")
	_position_label.name = "PropPosition"
	right_col.add_child(_position_label)
	_rotation_label = _small("Rotación: —")
	_rotation_label.name = "PropRotation"
	right_col.add_child(_rotation_label)
	_texture_label = _small("Imagen: ninguna")
	_texture_label.name = "PropTexture"
	right_col.add_child(_texture_label)
	var apply := _button("Poner imagen seleccionada", _apply_selected_texture)
	apply.name = "ApplyTextureButton"
	right_col.add_child(apply)
	var remove := _button("Quitar pieza", _remove_selected_entity)
	remove.name = "RemoveEntityButton"
	right_col.add_child(remove)

	# Diálogo para elegir la imagen.
	_file_dialog = FileDialog.new()
	_file_dialog.name = "ImageImportDialog"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.title = "Elegir una imagen"
	var filters := PackedStringArray()
	for ext in _image_importer.supported_extensions:
		filters.append("*." + ext)
	_file_dialog.filters = PackedStringArray([", ".join(filters) + " ; Imágenes"])
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


# Panel lateral con su columna: {"panel": PanelContainer, "column": VBoxContainer}.
func _make_dock(dock_name: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = dock_name
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return {"panel": panel, "column": column}


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", DIM)
	return label


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	return button


func _say(message: String) -> void:
	if _log != null:
		_log.text = "> " + message


func _back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_state_changed(new_state: GameCreatorCore.EditorState) -> void:
	_build_mode = new_state == GameCreatorCore.EditorState.BUILD
	if _build_button == null:
		return
	_build_button.visible = _build_mode
	_playtest_button.visible = not _build_mode
	# En construcción las piezas están quietas; al probar, caen y se pueden empujar.
	for entity in _scene_hierarchy.entities:
		_set_entity_physics(entity, not _build_mode)
	_say("Modo: " + ("construcción" if _build_mode else "prueba"))
	_update_status("Editor de juegos · modo %s · Esc vuelve al menú" % ("construcción" if _build_mode else "prueba"))


func _toggle_mode() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		return
	if _build_mode:
		core.enter_playtest_mode()
	else:
		core.enter_build_mode()


func _open_image_import_dialog() -> void:
	if _file_dialog != null:
		_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	if _image_importer == null:
		return
	var result: Dictionary = _image_importer.import_image(path)
	if result.get("success") == true:
		_asset_browser.refresh()
		_say("Imagen importada: " + str(result["info"]["file_name"]))
	else:
		_say("No se pudo importar: " + str(result.get("error", "error desconocido")))


func _on_image_imported(info: Dictionary) -> void:
	_asset_browser.refresh()
	_say("Imagen importada: " + str(info.get("file_name", "")))


func _on_import_failed(error: String) -> void:
	_say("No se pudo importar: " + error)


func _on_asset_selected(image_path: String) -> void:
	_say("Imagen elegida: %s. Selecciona una pieza y pulsa «Poner imagen seleccionada»." % image_path.get_file())


func _on_entity_selected(entity: PropEntity) -> void:
	_selected_entity = entity
	if _inspect_target == null:
		return
	if entity == null:
		_inspect_target.text = "Selecciona una pieza en la lista."
		_position_label.text = "Posición: —"
		_rotation_label.text = "Rotación: —"
		_texture_label.text = "Imagen: ninguna"
		return
	_inspect_target.text = entity.entity_name
	_position_label.text = "Posición: (%.2f, %.2f, %.2f)" % [entity.position.x, entity.position.y, entity.position.z]
	_rotation_label.text = "Rotación: (%.0f°, %.0f°, %.0f°)" % [entity.rotation_degrees.x, entity.rotation_degrees.y, entity.rotation_degrees.z]
	_texture_label.text = "Imagen: " + _get_entity_texture_info(entity)


func _get_entity_texture_info(entity: PropEntity) -> String:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	if visual != null and not visual.texture_path.is_empty():
		return visual.texture_path.get_file()
	return "ninguna"


func _apply_selected_texture() -> void:
	if _selected_entity == null:
		_say("Selecciona primero una pieza en la lista.")
		return
	var path := ""
	if _asset_browser != null and _asset_browser.selected_image.has("path"):
		path = str(_asset_browser.selected_image.get("path"))
	if path.is_empty():
		_say("Elige primero una imagen de la galería.")
		return
	var visual := _selected_entity.get_component("VisualComponent") as VisualComponent
	if visual == null:
		visual = VisualComponent.new()
		_selected_entity.add_component(visual)
	visual.texture_path = path
	_selected_entity.entity_name = path.get_file().get_basename()
	_refresh_entity_visual(_selected_entity)
	_say("Imagen puesta en «%s»." % _selected_entity.entity_name)
	_on_entity_selected(_selected_entity)
	_scene_hierarchy.refresh()


func _spawn_example_entity() -> void:
	var entity := PropEntity.new()
	entity.entity_name = "Pieza %d" % (_scene_hierarchy.entities.size() + 1)
	var visual := VisualComponent.new()
	visual.color_tint = [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_GREEN, Palette.PLAYER_YELLOW][_scene_hierarchy.entities.size() % 4]
	entity.add_component(visual)
	entity.add_component(PhysicsComponent.new())
	entity.add_component(InteractiveComponent.new())
	# En la mesa de la vista previa, repartidas para que no se monten.
	var slot := _scene_hierarchy.entities.size()
	_entities_root.add_child(entity)
	entity.position = Vector3(-1.2 + (slot % 4) * 0.8, 0.06, -0.6 + ((slot / 4) % 3) * 0.9)
	_refresh_entity_visual(entity)
	_scene_hierarchy.add_entity(entity)
	_on_entity_selected(entity)
	_say("Pieza creada: " + entity.entity_name)


func _remove_selected_entity() -> void:
	if _selected_entity == null:
		_say("Selecciona primero una pieza en la lista.")
		return
	var entity := _selected_entity
	_scene_hierarchy.remove_entity(entity)
	_on_entity_selected(null)
	_say("Pieza quitada: " + entity.entity_name)
	entity.queue_free()


# Cuerpo visible de la pieza: una ficha plana con su imagen (o su color) y su cuerpo físico.
func _refresh_entity_visual(entity: PropEntity) -> void:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null:
		body = RigidBody3D.new()
		body.name = "Body"
		body.freeze = _build_mode
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 0.08, 0.84)
		shape.shape = box
		body.add_child(shape)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		var mesh := BoxMesh.new()
		mesh.size = box.size
		mesh_instance.mesh = mesh
		body.add_child(mesh_instance)
		entity.add_child(body)
	var material := StandardMaterial3D.new()
	material.roughness = 0.9
	material.albedo_color = visual.color_tint if visual != null else Color.WHITE
	if visual != null and not visual.texture_path.is_empty():
		var texture := _image_importer.load_texture(visual.texture_path)
		if texture != null:
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE
	(body.get_node("Mesh") as MeshInstance3D).material_override = material


func _set_entity_physics(entity: PropEntity, active: bool) -> void:
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null:
		return
	body.freeze = not active
	if not active:
		# Al volver a editar, cada pieza regresa a donde se colocó.
		body.transform = Transform3D.IDENTITY
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


func _update_status(message: String) -> void:
	if _status_bar != null:
		_status_bar.text = message


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_to_menu()
