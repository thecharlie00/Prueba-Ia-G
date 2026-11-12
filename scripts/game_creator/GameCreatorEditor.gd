# GameCreatorEditor.gd
# Escena de entrada al Editor Universal de Juegos (Game Creator Studio).
# Workspace estilo IDE con Viewport 3D, Asset Browser, Jerarquía de Escena e Inspector.
# Permite importar imágenes y asignarlas como texturas a entidades del tablero.
class_name GameCreatorEditor
extends Control

# Nodos de UI.
# Nota: ViewportContainer se resuelve dinámicamente para evitar errores de parseo
# de tipos en Godot 4.7 cuando el nodo no está disponible en el scope actual.
@onready var _docks: HBoxContainer = $Docks
@onready var _status_bar: Label = $StatusBar/StatusLabel
var _viewport_container: Node = null

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

func _ready() -> void:
	# Asegurar que el core del editor esté disponible.
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		push_error("[GameCreatorEditor] GameCreatorCore no está registrado como autoload.")
		return

	core.enter_build_mode()
	core.state_changed.connect(_on_state_changed)

	# Inicializar importador de imágenes.
	_image_importer = ImageImporter.new()
	add_child(_image_importer)
	_image_importer.image_imported.connect(_on_image_imported)
	_image_importer.import_failed.connect(_on_import_failed)

	# Resolver el contenedor de viewport de forma defensiva.
	_viewport_container = get_node_or_null("ViewportContainer")

	_build_editor_ui()
	_update_status("Editor de juegos — Modo construcción")

	# Foco inicial.
	var btn := $Docks/LeftDock/BuildModeButton
	if btn != null:
		btn.grab_focus.call_deferred()

func _build_editor_ui() -> void:
	# Limpiar docks previos.
	for child in _docks.get_children():
		child.queue_free()

	# ========== DOCK IZQUIERDO: Herramientas + Asset Browser ==========
	var left := _make_dock("LeftDock")
	_docks.add_child(left)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left.add_child(left_col)

	# --- Modos de operación ---
	var mode_label := Label.new()
	mode_label.text = "MODO DE EDICIÓN"
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_col.add_child(mode_label)

	var build_btn := Button.new()
	build_btn.name = "BuildModeButton"
	build_btn.text = "▶ Cambiar a Prueba (Playtest)"
	build_btn.custom_minimum_size = Vector2(0, 40)
	build_btn.pressed.connect(_toggle_mode)
	left_col.add_child(build_btn)

	var test_btn := Button.new()
	test_btn.name = "PlaytestButton"
	test_btn.text = "⏸ Volver a Edición"
	test_btn.custom_minimum_size = Vector2(0, 40)
	test_btn.visible = not _build_mode
	test_btn.pressed.connect(_toggle_mode)
	left_col.add_child(test_btn)

	var separator := Control.new()
	separator.custom_minimum_size = Vector2(0, 12)
	left_col.add_child(separator)

	# --- Asset Browser ---
	var tools_label := Label.new()
	tools_label.text = "ASSET BROWSER"
	tools_label.add_theme_font_size_override("font_size", 11)
	tools_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_col.add_child(tools_label)

	var import_btn := Button.new()
	import_btn.name = "ImportImageButton"
	import_btn.text = "🖼 Importar imagen"
	import_btn.custom_minimum_size = Vector2(0, 36)
	import_btn.pressed.connect(_open_image_import_dialog)
	left_col.add_child(import_btn)

	var asset_browser := AssetBrowser.new()
	asset_browser.name = "AssetBrowser"
	asset_browser.set_image_importer(_image_importer)
	asset_browser.build_ui()
	asset_browser.image_selected.connect(_on_asset_selected)
	left_col.add_child(asset_browser)
	_asset_browser = asset_browser

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(spacer)

	var new_entity_btn := Button.new()
	new_entity_btn.text = "+ Nueva entidad"
	new_entity_btn.custom_minimum_size = Vector2(0, 36)
	new_entity_btn.pressed.connect(_spawn_example_entity)
	left_col.add_child(new_entity_btn)

	# ========== DOCK CENTRO: Jerarquía de Escena ==========
	var center := _make_dock("CenterDock")
	_docks.add_child(center)

	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 8)
	center.add_child(center_col)

	var scene_hierarchy := SceneHierarchy.new()
	scene_hierarchy.name = "SceneHierarchy"
	scene_hierarchy.build_ui()
	scene_hierarchy.entity_selected.connect(_on_entity_selected)
	center_col.add_child(scene_hierarchy)
	_scene_hierarchy = scene_hierarchy

	# ========== DOCK DERECHO: Inspector ==========
	var right := _make_dock("RightDock")
	_docks.add_child(right)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right.add_child(right_col)

	var insp_label := Label.new()
	insp_label.text = "INSPECTOR"
	insp_label.add_theme_font_size_override("font_size", 11)
	insp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right_col.add_child(insp_label)

	var inspect_target := Label.new()
	inspect_target.name = "InspectTarget"
	inspect_target.text = "Selecciona una entidad en la jerarquía."
	inspect_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_target.add_theme_font_size_override("font_size", 13)
	inspect_target.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_col.add_child(inspect_target)

	var props_well := _make_card_well("Propiedades")
	right_col.add_child(props_well)

	var props_col := VBoxContainer.new()
	props_col.add_theme_constant_override("separation", 6)
	props_well.add_child(props_col)

	var pos_lbl := Label.new()
	pos_lbl.name = "PropPosition"
	pos_lbl.text = "Posición: (0, 0, 0)"
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(pos_lbl)

	var rot_lbl := Label.new()
	rot_lbl.name = "PropRotation"
	rot_lbl.text = "Rotación: (0, 0, 0)"
	rot_lbl.add_theme_font_size_override("font_size", 12)
	rot_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(rot_lbl)

	var tex_label := Label.new()
	tex_label.text = "Textura asignada"
	tex_label.add_theme_font_size_override("font_size", 11)
	tex_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	props_col.add_child(tex_label)

	var tex_row := HBoxContainer.new()
	tex_row.add_theme_constant_override("separation", 6)
	props_col.add_child(tex_row)

	var tex_value := Label.new()
	tex_value.name = "PropTexture"
	tex_value.text = "Ninguna"
	tex_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tex_value.add_theme_font_size_override("font_size", 12)
	tex_value.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	tex_row.add_child(tex_value)

	var apply_tex_btn := Button.new()
	apply_tex_btn.name = "ApplyTextureButton"
	apply_tex_btn.text = "Aplicar textura seleccionada"
	apply_tex_btn.custom_minimum_size = Vector2(0, 32)
	apply_tex_btn.add_theme_font_size_override("font_size", 11)
	apply_tex_btn.pressed.connect(_apply_selected_texture)
	props_col.add_child(apply_tex_btn)

	# ========== DOCK INFERIOR: Consola ==========
	var bottom_dock := _make_dock("BottomDock")
	_docks.add_child(bottom_dock)

	var bottom_col := VBoxContainer.new()
	bottom_col.add_theme_constant_override("separation", 4)
	bottom_dock.add_child(bottom_col)

	var log_label := Label.new()
	log_label.text = "CONSOLA"
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom_col.add_child(log_label)

	var log_text := Label.new()
	log_text.name = "LogText"
	log_text.text = "> Editor iniciado. Importa imágenes, crea entidades y asigna texturas."
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.add_theme_font_size_override("font_size", 12)
	log_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	bottom_col.add_child(log_text)

	# FileDialog para importar imágenes.
	_file_dialog = FileDialog.new()
	_file_dialog.name = "ImageImportDialog"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.current_dir = "user://"
	_file_dialog.title = "Seleccionar imagen para importar"
	_file_dialog.set_current_as_path(false)
	var filters: Array[String] = []
	for ext in _image_importer.supported_extensions:
		filters.append("*." + ext)
	_file_dialog.filters = filters
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

func _make_dock(name: String) -> Control:
	var dock := Control.new()
	dock.name = name
	dock.custom_minimum_size = Vector2(280, 0)
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	dock.add_child(col)
	return dock

func _make_card_well(title: String) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	col.add_child(t)
	return card

func _on_state_changed(new_state: GameCreatorCore.EditorState) -> void:
	_build_mode = new_state == GameCreatorCore.EditorState.BUILD
	var build_btn := $Docks/LeftDock/BuildModeButton
	var test_btn := $Docks/LeftDock/PlaytestButton
	if build_btn != null:
		build_btn.visible = _build_mode
	if test_btn != null:
		test_btn.visible = not _build_mode
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Modo: " + ("Construcción (Build)" if _build_mode else "Prueba (Playtest)")

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
		_file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	if _image_importer == null:
		return
	var result: Dictionary = _image_importer.import_image(path)
	if result.get("success") == true:
		_asset_browser.refresh()
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Imagen importada: " + result.get("info", {}).get("file_name", path)
	else:
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Error al importar: " + str(result.get("error", "desconocido"))

func _on_image_imported(info: Dictionary) -> void:
	_asset_browser.refresh()
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Imagen registrada: " + str(info.get("file_name", ""))

func _on_import_failed(error: String) -> void:
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Error de importación: " + error

func _on_asset_selected(image_path: String) -> void:
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Imagen seleccionada: " + image_path.get_file() + " (selecciona una entidad y pulsa 'Aplicar textura')"

func _on_entity_selected(entity: PropEntity) -> void:
	_selected_entity = entity
	var target := $Docks/RightDock/InspectTarget
	if target != null:
		if entity != null:
			target.text = "Entidad: " + entity.entity_name + " (" + entity.entity_id + ")"
			_update_inspector_props(entity)
		else:
			target.text = "Selecciona una entidad en la jerarquía."
	var tex_value := $Docks/RightDock/PropTexture
	if tex_value != null:
		tex_value.text = _get_entity_texture_info(entity) if entity != null else "Ninguna"

func _update_inspector_props(entity: PropEntity) -> void:
	var pos_lbl := $Docks/RightDock/PropPosition
	var rot_lbl := $Docks/RightDock/PropRotation
	if pos_lbl != null:
		pos_lbl.text = "Posición: (" + str(entity.global_position.x) + ", " + str(entity.global_position.y) + ", " + str(entity.global_position.z) + ")"
	if rot_lbl != null:
		rot_lbl.text = "Rotación: (" + str(entity.global_rotation.x) + ", " + str(entity.global_rotation.y) + ", " + str(entity.global_rotation.z) + ")"

func _get_entity_texture_info(entity: PropEntity) -> String:
	var visual := entity.get_component("VisualComponent")
	if visual != null:
		var mesh_path: String = str(visual.get("mesh_path", ""))
		if mesh_path != "":
			return mesh_path.get_file()
	return "Ninguna"

func _apply_selected_texture() -> void:
	if _selected_entity == null:
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Error: selecciona primero una entidad en la jerarquía."
		return

	var path: String = ""
	if _asset_browser != null and _asset_browser.selected_image.has("path"):
		path = str(_asset_browser.selected_image.get("path"))
	if path == "":
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Error: selecciona primero una imagen en el Asset Browser."
		return

	var visual := _selected_entity.get_component("VisualComponent")
	if visual == null:
		visual = VisualComponent.new()
		_selected_entity.add_component(visual)

	visual.mesh_path = path
	_selected_entity.entity_name = path.get_file().get_basename()
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Textura aplicada a " + _selected_entity.entity_name + ": " + path.get_file()
	_on_entity_selected(_selected_entity)
	if _scene_hierarchy != null:
		_scene_hierarchy.refresh()

func _spawn_example_entity() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		return

	var entity := PropEntity.new()
	entity.entity_name = "Entidad de ejemplo"
	entity.global_position = Vector3(0, 1, 0)

	var visual := VisualComponent.new()
	visual.scale_factor = 1.0
	visual.color_tint = Color(0.8, 0.8, 0.8)
	entity.add_component(visual)

	var physics := PhysicsComponent.new()
	entity.add_component(physics)

	var interactive := InteractiveComponent.new()
	entity.add_component(interactive)

	if _scene_hierarchy != null:
		_scene_hierarchy.add_entity(entity)
	_selected_entity = entity
	_on_entity_selected(entity)

	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Entidad creada: " + entity.entity_name

func _update_status(message: String) -> void:
	if _status_bar != null:
		_status_bar.text = message

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		get_viewport().set_input_as_handled()
