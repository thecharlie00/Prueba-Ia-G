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

# --- Diseñador de interfaz -------------------------------------------------------
const UI_SAVE_PATH := "user://creador/interfaz.json"
const UI_SAVE_BYTES := 200000
const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
## Interfaz que el creador diseña para su juego, y la vista que la dibuja sobre la pantalla.
var ui_layout := UiLayout.new()
var ui_view: UiLayoutView
var ui_save_path := UI_SAVE_PATH
var _piece_inspector: VBoxContainer
var _ui_inspector: VBoxContainer
var _ui_name: Label
var _ui_text: LineEdit
var _ui_font: SpinBox
var _ui_value: SpinBox
var _ui_value_row: Control
var _ui_anchor: Label
var _ui_action: OptionButton
var _ui_target: OptionButton
var _ui_action_box: Control
var _ui_image_button: Button
var _resume_button: Button
var _syncing_ui := false

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
	ui_view = UiLayoutView.new()
	ui_view.image_loader = _image_importer.load_texture
	add_child(ui_view)
	move_child(ui_view, $ViewportContainer.get_index() + 1)
	ui_view.element_selected.connect(_on_ui_selected)
	ui_view.element_changed.connect(_on_ui_changed)
	ui_view.show_layout(ui_layout, true)
	_build_editor_ui()
	resized.connect(_layout_canvas)
	_layout_canvas.call_deferred()
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
	# Suelo físico: al probar, las piezas se apoyan en la mesa en vez de caer al vacío.
	var ground := StaticBody3D.new()
	ground.name = "TableBody"
	var ground_shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = 2.6
	disc.height = 0.12
	ground_shape.shape = disc
	ground.add_child(ground_shape)
	ground.position.y = -0.06
	world.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 4.0, 4.6)
	camera.fov = 42
	world.add_child(camera)
	camera.look_at(Vector3(0, 0, 0.35))
	camera.current = true
	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	world.add_child(_entities_root)


func _build_editor_ui() -> void:
	for child in _docks.get_children():
		child.queue_free()
	_docks.add_theme_constant_override("separation", 14)
	_docks.offset_left = 18
	_docks.offset_top = 18
	_docks.offset_right = -18
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

	left_col.add_child(_caption("INTERFAZ DEL JUEGO · AÑADIR"))
	var ui_grid := GridContainer.new()
	ui_grid.name = "UiPalette"
	ui_grid.columns = 3
	ui_grid.add_theme_constant_override("h_separation", 8)
	ui_grid.add_theme_constant_override("v_separation", 8)
	left_col.add_child(ui_grid)
	for type in UiLayout.TYPES:
		var add := _button(UiLayout.TYPE_NAMES[type], add_ui_element.bind(type))
		add.add_theme_font_size_override("font_size", 13)
		add.alignment = HORIZONTAL_ALIGNMENT_CENTER
		add.name = "AddUi_" + type
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.tooltip_text = "Añade a la pantalla; luego arrástralo y tira de su esquina para cambiarlo de tamaño"
		ui_grid.add_child(add)
	var ui_files := HBoxContainer.new()
	ui_files.add_theme_constant_override("separation", 8)
	left_col.add_child(ui_files)
	var save_ui := _button("Guardar", save_ui_layout)
	save_ui.name = "SaveUi"
	save_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_files.add_child(save_ui)
	var load_ui := _button("Cargar", load_ui_layout)
	load_ui.name = "LoadUi"
	load_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_files.add_child(load_ui)

	left_col.add_child(_caption("IMÁGENES"))
	var import_button := _button("Importar imagen…", _open_image_import_dialog)
	import_button.name = "ImportImageButton"
	left_col.add_child(import_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 110
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
	# Bajo los botones «Ayuda» y «Menú», que van arriba a la derecha en todas las pantallas.
	(right["panel"] as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var right_col: VBoxContainer = right["column"]
	# Hueco para los botones «Ayuda» y «Menú», que van encima en todas las pantallas.
	_scene_hierarchy = SceneHierarchy.new()
	_scene_hierarchy.name = "SceneHierarchy"
	_scene_hierarchy.custom_minimum_size = Vector2(0, 170)
	right_col.add_child(_scene_hierarchy)
	_scene_hierarchy.entity_selected.connect(_on_entity_selected)

	_piece_inspector = VBoxContainer.new()
	_piece_inspector.name = "PieceInspector"
	_piece_inspector.add_theme_constant_override("separation", 10)
	right_col.add_child(_piece_inspector)
	right_col = _piece_inspector
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

	_build_ui_inspector(right["column"])

	# Al probar, los paneles se apartan y queda este botón para volver.
	_resume_button = _button("⏸  Volver a editar", _toggle_mode)
	_resume_button.name = "ResumeEditing"
	_resume_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resume_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_resume_button.offset_left = 18
	_resume_button.offset_top = 16
	_resume_button.visible = false
	add_child(_resume_button)

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
	# Tarjeta flotante, tan alta como su contenido: la mesa se ve alrededor.
	panel.custom_minimum_size = Vector2(290, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
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
	button.custom_minimum_size = Vector2(0, 36)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	return button


# --- Diseñador de interfaz ---------------------------------------------------------

const DOCK_WIDTH := 290.0
const CANVAS_GAP := 18.0


## En construcción, la pantalla del juego se ve a escala entre los dos paneles, para que todo
## quede a mano; al probar, ocupa la ventana entera.
func _layout_canvas() -> void:
	if ui_view == null:
		return
	ui_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if not _build_mode:
		ui_view.position = Vector2.ZERO
		ui_view.size = size
		return
	var side := CANVAS_GAP * 2.0 + DOCK_WIDTH
	var room := Rect2(side, 76.0, size.x - side * 2.0, size.y - 76.0 - 96.0)
	var aspect := size.x / maxf(size.y, 1.0)
	var fitted := Vector2(room.size.x, room.size.x / aspect)
	if fitted.y > room.size.y:
		fitted = Vector2(room.size.y * aspect, room.size.y)
	ui_view.position = room.position + (room.size - fitted) * 0.5
	ui_view.size = fitted


func _build_ui_inspector(column: VBoxContainer) -> void:
	_ui_inspector = VBoxContainer.new()
	_ui_inspector.name = "UiInspector"
	_ui_inspector.add_theme_constant_override("separation", 8)
	_ui_inspector.visible = false
	column.add_child(_ui_inspector)
	_ui_inspector.add_child(_caption("ELEMENTO DE INTERFAZ"))
	_ui_name = Label.new()
	_ui_name.name = "UiName"
	_ui_inspector.add_child(_ui_name)
	_ui_text = LineEdit.new()
	_ui_text.name = "UiText"
	_ui_text.placeholder_text = "Texto"
	_ui_text.max_length = UiLayout.MAX_TEXT
	_ui_text.text_changed.connect(func(value: String) -> void: set_ui_property("text", value))
	_ui_inspector.add_child(_ui_text)
	var font_row := HBoxContainer.new()
	font_row.add_child(_caption("Tamaño de letra"))
	_ui_font = SpinBox.new()
	_ui_font.name = "UiFont"
	_ui_font.min_value = 8
	_ui_font.max_value = 96
	_ui_font.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_font.value_changed.connect(func(value: float) -> void: set_ui_property("font_size", int(value)))
	font_row.add_child(_ui_font)
	_ui_inspector.add_child(font_row)
	_ui_inspector.add_child(_small("Color del texto"))
	_ui_inspector.add_child(_swatches("color", false))
	_ui_inspector.add_child(_small("Color de fondo"))
	_ui_inspector.add_child(_swatches("bg", true))
	var value_row := HBoxContainer.new()
	value_row.add_child(_caption("Empieza en"))
	_ui_value = SpinBox.new()
	_ui_value.name = "UiValue"
	_ui_value.min_value = -9999
	_ui_value.max_value = 9999
	_ui_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_value.value_changed.connect(func(value: float) -> void: set_ui_property("value", int(value)))
	value_row.add_child(_ui_value)
	_ui_value_row = value_row
	_ui_inspector.add_child(value_row)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_box.add_child(_small("Al pulsarlo"))
	_ui_action = OptionButton.new()
	_ui_action.name = "UiAction"
	for action in UiLayout.ACTIONS:
		_ui_action.add_item(UiLayout.ACTION_NAMES[action])
	_ui_action.item_selected.connect(func(index: int) -> void: set_ui_property("action", UiLayout.ACTIONS[index]))
	action_box.add_child(_ui_action)
	_ui_target = OptionButton.new()
	_ui_target.name = "UiTarget"
	_ui_target.item_selected.connect(func(index: int) -> void: set_ui_property("target", _ui_target.get_item_id(index)))
	action_box.add_child(_ui_target)
	_ui_action_box = action_box
	_ui_inspector.add_child(action_box)
	_ui_image_button = _button("Usar imagen seleccionada", _apply_image_to_ui)
	_ui_image_button.name = "UiUseImage"
	_ui_inspector.add_child(_ui_image_button)
	_ui_anchor = _small("")
	_ui_anchor.name = "UiAnchor"
	_ui_anchor.add_theme_color_override("font_color", DIM)
	_ui_inspector.add_child(_ui_anchor)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var front := _button("Al frente", func() -> void:
		ui_layout.bring_to_front(ui_view.selected_id)
		ui_view.rebuild()
	)
	front.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(front)
	var remove := _button("Quitar", remove_ui_element)
	remove.name = "UiRemove"
	remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(remove)
	_ui_inspector.add_child(row)


# Fila de colores de la paleta; con allow_none, el primero es «sin fondo».
func _swatches(property: String, allow_none: bool) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "Swatches_" + property
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var options: Array = UiLayout.SWATCHES.duplicate()
	if allow_none:
		options.push_front("")
	for hex in options:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = "Sin fondo" if hex == "" else "#" + hex
		var box := StyleBoxFlat.new()
		box.bg_color = Color(hex) if hex != "" else Color(0, 0, 0, 0)
		box.set_corner_radius_all(13)
		box.border_color = Palette.PAPER
		box.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, box)
		if hex == "":
			swatch.text = "∅"
		swatch.pressed.connect(set_ui_property.bind(property, hex))
		flow.add_child(swatch)
	return flow


## Añade un elemento de interfaz y lo deja seleccionado. Devuelve su id (0 si no se pudo).
func add_ui_element(type: String) -> int:
	var element := ui_layout.add(type)
	if element.is_empty():
		_say("No caben más elementos de interfaz (máximo %d)." % UiLayout.MAX_ELEMENTS)
		return 0
	ui_view.rebuild()
	ui_view.select(int(element["id"]))
	_say("%s añadido: arrástralo donde quieras y tira de su esquina para cambiarlo de tamaño." % UiLayout.TYPE_NAMES[type])
	return int(element["id"])


func remove_ui_element() -> void:
	var id := ui_view.selected_id
	if ui_layout.remove(id):
		ui_view.rebuild()
		ui_view.select(0)
		_say("Elemento de interfaz quitado.")


## Cambia una propiedad del elemento seleccionado (texto, colores, acción…).
func set_ui_property(property: String, value: Variant) -> void:
	if _syncing_ui:
		return
	var element := ui_layout.find(ui_view.selected_id)
	if element.is_empty() or not element.has(property):
		return
	element[property] = value
	if property == "action":
		# El destino anterior puede no valer para la acción nueva.
		var valid := ui_layout.targets_for(str(value), int(element["id"]))
		if valid.filter(func(item: Dictionary) -> bool: return int(item["id"]) == int(element["target"])).is_empty():
			element["target"] = int(valid[0]["id"]) if not valid.is_empty() else 0
	ui_view.rebuild()
	_fill_ui_inspector(element, property != "text")


func _apply_image_to_ui() -> void:
	var path := str(_asset_browser.selected_image.get("path", "")) if _asset_browser != null else ""
	if path.is_empty():
		_say("Elige primero una imagen de la galería.")
		return
	set_ui_property("image", path)
	_say("Imagen puesta en el elemento.")


func _on_ui_selected(id: int) -> void:
	var element := ui_layout.find(id)
	_ui_inspector.visible = not element.is_empty()
	_piece_inspector.visible = element.is_empty()
	_scene_hierarchy.visible = element.is_empty()
	if not element.is_empty():
		_fill_ui_inspector(element, true)


func _on_ui_changed(id: int) -> void:
	var element := ui_layout.find(id)
	if not element.is_empty() and _ui_anchor != null:
		_ui_anchor.text = "Se sujeta %s de la pantalla." % UiLayout.ANCHOR_NAMES[int(element["anchor"])]


func _fill_ui_inspector(element: Dictionary, with_text: bool) -> void:
	_syncing_ui = true
	var type := str(element["type"])
	_ui_name.text = str(element["name"])
	if with_text:
		_ui_text.text = str(element["text"])
	_ui_text.visible = type in ["text", "button", "counter"]
	_ui_font.value = int(element["font_size"])
	_ui_font.get_parent().visible = type in ["text", "button", "counter"]
	_ui_value.value = int(element["value"])
	_ui_value_row.visible = type == "counter"
	_ui_action_box.visible = type == "button"
	_ui_image_button.visible = type == "image"
	_ui_action.select(UiLayout.ACTIONS.find(str(element["action"])))
	_ui_target.clear()
	var targets := ui_layout.targets_for(str(element["action"]), int(element["id"]))
	_ui_target.visible = str(element["action"]) != "none"
	if targets.is_empty():
		_ui_target.add_item("Añade antes un contador" if str(element["action"]) != "toggle" else "No hay otros elementos", 0)
		_ui_target.disabled = true
	else:
		_ui_target.disabled = false
		for target in targets:
			_ui_target.add_item(str(target["name"]), int(target["id"]))
			if int(target["id"]) == int(element["target"]):
				_ui_target.select(_ui_target.item_count - 1)
	_ui_anchor.text = "Se sujeta %s de la pantalla." % UiLayout.ANCHOR_NAMES[int(element["anchor"])]
	_syncing_ui = false


func save_ui_layout() -> bool:
	DirAccess.make_dir_recursive_absolute(ui_save_path.get_base_dir())
	var ok: bool = SAVE_STORE.write(ui_save_path, JSON.stringify(ui_layout.to_record()), UI_SAVE_BYTES, _decode_ui)
	_say("Interfaz guardada en este equipo." if ok else "No se pudo guardar la interfaz.")
	return ok


func load_ui_layout() -> bool:
	var loaded: Dictionary = SAVE_STORE.read_validated(ui_save_path, UI_SAVE_BYTES, _decode_ui)
	if loaded.is_empty():
		_say("No hay interfaz guardada, o el archivo no es válido; se conserva la actual.")
		return false
	ui_layout = UiLayout.from_record(loaded["record"])
	ui_view.show_layout(ui_layout, _build_mode)
	ui_view.select(0)
	_say("Interfaz cargada: %d elementos." % ui_layout.elements.size())
	return true


static func _decode_ui(record: Variant) -> Variant:
	return record if UiLayout.from_record(record) != null else null


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
	# Al probar se ve el juego como lo verá un jugador: sin paneles del editor y con la
	# interfaz diseñada funcionando.
	_docks.visible = _build_mode
	_resume_button.visible = not _build_mode
	_layout_canvas()
	ui_view.show_layout(ui_layout, _build_mode)
	if _build_mode:
		ui_view.select(0)
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
	if entity != null and ui_view != null and ui_view.selected_id != 0:
		ui_view.select(0)
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
	entity.position = Vector3(-1.2 + (slot % 4) * 0.8, 0.06, -0.5 + ((slot / 4) % 3) * 0.95)
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
