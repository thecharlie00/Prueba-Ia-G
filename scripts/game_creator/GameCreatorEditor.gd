# GameCreatorEditor.gd
# Escena de entrada al Editor Universal de Juegos (Game Creator Studio).
# Inicializa el GameCreatorCore (autoload) y construye el workspace estilo IDE
# con Viewport 3D, Inspector, Jerarquía de Escena, Asset Browser e importador de imágenes.
class_name GameCreatorEditor
extends Control

@onready var _viewport_container: ViewportContainer = $ViewportContainer
@onready var _docks: HBoxContainer = $Docks
@onready var _status_bar: Label = $StatusBar/StatusLabel

# Importador de imágenes.
var _image_importer: ImageImporter = null

# Estado del editor.
var _build_mode: Boolean = true

# FileDialog para seleccionar imágenes.
var _file_dialog: FileDialog = null

# Panel de imágenes importadas.
var _images_list: VBoxContainer = null
var _images_scroll: ScrollContainer = null

func _ready() -> void:
	# Asegurar que el core del editor esté disponible.
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		push_error("[GameCreatorEditor] GameCreatorCore no está registrado como autoload.")
		return

	core.enter_build_mode()
	core.state_changed.connect(_on_state_changed)

	# Inicializar el importador de imágenes como hijo.
	_image_importer = ImageImporter.new()
	add_child(_image_importer)
	_image_importer.image_imported.connect(_on_image_imported)
	_image_importer.import_failed.connect(_on_import_failed)

	_build_editor_ui()
	_update_status("Editor de juegos — Modo construcción")

	# Foco inicial.
	var btn := $Docks/LeftDock/BuildModeButton
	if btn != null:
		btn.grab_focus.call_deferred()

func _build_editor_ui() -> void:
	# Limpiar contenido previo de los docks.
	for child in _docks.get_children():
		child.queue_free()

	# Dock izquierdo: Modos, herramientas e importación de imágenes.
	var left := _make_dock("LeftDock")
	_docks.add_child(left)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left.add_child(left_col)

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
	test_btn.visible = false
	test_btn.pressed.connect(_toggle_mode)
	left_col.add_child(test_btn)

	var separator := Control.new()
	separator.custom_minimum_size = Vector2(0, 12)
	left_col.add_child(separator)

	var tools_label := Label.new()
	tools_label.text = "ASSETS"
	tools_label.add_theme_font_size_override("font_size", 11)
	tools_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_col.add_child(tools_label)

	var import_btn := Button.new()
	import_btn.name = "ImportImageButton"
	import_btn.text = "🖼 Importar imagen"
	import_btn.custom_minimum_size = Vector2(0, 36)
	import_btn.pressed.connect(_open_image_import_dialog)
	left_col.add_child(import_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(spacer)

	var new_entity_btn := Button.new()
	new_entity_btn.text = "+ Nueva entidad"
	new_entity_btn.custom_minimum_size = Vector2(0, 36)
	new_entity_btn.pressed.connect(func() -> void: _spawn_example_entity())
	left_col.add_child(new_entity_btn)

	# Dock derecho: Inspector de propiedades.
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
	inspect_target.text = "Selecciona una entidad en el viewport."
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
	pos_lbl.text = "Posición: (0, 0, 0)"
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(pos_lbl)

	var rot_lbl := Label.new()
	rot_lbl.text = "Rotación: (0, 0, 0)"
	rot_lbl.add_theme_font_size_override("font_size", 12)
	rot_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(rot_lbl)

	var images_lbl := Label.new()
	images_lbl.text = "Imágenes importadas"
	images_lbl.add_theme_font_size_override("font_size", 11)
	images_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	props_col.add_child(images_lbl)

	# Dock inferior: consola / log.
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
	log_text.text = "> Editor iniciado. Construye tu tablero, configura reglas y prueba."
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.add_theme_font_size_override("font_size", 12)
	log_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	bottom_col.add_child(log_text)

	# FileDialog para importar imágenes (oculto por defecto).
	_file_dialog = FileDialog.new()
	_file_dialog.name = "ImageImportDialog"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.current_dir = "user://"
	_file_dialog.title = "Seleccionar imagen para importar"
	_file_dialog.set_current_as_path(false)
	# Filtros de imagen.
	var filters: Array[String] = []
	for ext in _image_importer.supported_extensions:
		filters.append("*." + ext)
	_file_dialog.filters = filters
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

	# Panel de imágenes importadas en el inspector (debajo de propiedades).
	var images_well := _make_card_well("Galería de imágenes")
	props_col.add_child(images_well)

	var images_col := VBoxContainer.new()
	images_col.add_theme_constant_override("separation", 4)
	images_well.add_child(images_col)

	var images_header := HBoxContainer.new()
	images_header.add_theme_constant_override("separation", 8)
	images_col.add_child(images_header)

	var gallery_label := Label.new()
	gallery_label.text = "Disponibles en el proyecto"
	gallery_label.add_theme_font_size_override("font_size", 11)
	gallery_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	images_header.add_child(gallery_label)

	_images_scroll = ScrollContainer.new()
	_images_scroll.custom_minimum_size = Vector2(0, 140)
	_images_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_images_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	images_col.add_child(_images_scroll)

	_images_list = VBoxContainer.new()
	_images_list.add_theme_constant_override("separation", 4)
	_images_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_images_scroll.add_child(_images_list)

	_refresh_images_gallery()

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
	_build_mode = (new_state == GameCreatorCore.EditorState.BUILD)
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
		_refresh_images_gallery()
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Imagen importada: " + result.get("info", {}).get("file_name", path)
	else:
		var log := $Docks/BottomDock/LogText
		if log != null:
			log.text = "> Error al importar: " + str(result.get("error", "desconocido"))

func _on_image_imported(info: Dictionary) -> void:
	_refresh_images_gallery()
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Imagen registrada: " + str(info.get("file_name", ""))

func _on_import_failed(error: String) -> void:
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Error de importación: " + error

func _refresh_images_gallery() -> void:
	if _images_list == null or _image_importer == null:
		return
	# Limpiar lista actual.
	for child in _images_list.get_children():
		child.queue_free()

	var images: Array[Dictionary] = _image_importer.get_imported_images()
	if images.size() == 0:
		var empty := Label.new()
		empty.text = "Sin imágenes importadas aún."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_images_list.add_child(empty)
		return

	for info in images:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var thumb := TextureRect.new()
		var tex := _image_importer.load_texture(str(info.get("path", "")))
		if tex != null:
			thumb.texture = tex
		thumb.custom_minimum_size = Vector2(32, 32)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumb)

		var info_col := VBoxContainer.new()
		info_col.add_theme_constant_override("separation", 2)
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = str(info.get("file_name", ""))
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		info_col.add_child(name_lbl)

		var dim_lbl := Label.new()
		dim_lbl.text = str(info.get("width", 0)) + " x " + str(info.get("height", 0)) + " · " + _format_size(str(info.get("size_bytes", 0)))
		dim_lbl.add_theme_font_size_override("font_size", 10)
		dim_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		info_col.add_child(dim_lbl)

		row.add_child(info_col)

		var use_btn := Button.new()
		use_btn.text = "Usar"
		use_btn.custom_minimum_size = Vector2(50, 28)
		use_btn.pressed.connect(_on_use_image.bind(str(info.get("path", ""))))
		row.add_child(use_btn)

		_images_list.add_child(row)

func _format_size(size_str: String) -> String:
	var size: int = size_str.to_int()
	if size < 1024:
		return str(size) + " B"
	elif size < 1048576:
		return str(size / 1024).substr(0, 4) + " KB"
	else:
		return str(size / 1048576).substr(0, 4) + " MB"

func _on_use_image(path: String) -> void:
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Imagen seleccionada para usar: " + path.get_file()
	# Aquí se podría abrir un selector de entidad para asignar la textura.

func _spawn_example_entity() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		return
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Entidad de ejemplo creada (usa el Inspector para configurarla)."

func _update_status(message: String) -> void:
	if _status_bar != null:
		_status_bar.text = message

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		get_viewport().set_input_as_handled()
