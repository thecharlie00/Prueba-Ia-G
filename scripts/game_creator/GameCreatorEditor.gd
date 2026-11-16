# GameCreatorEditor.gd
# Escena de entrada al Editor Universal de Juegos (Game Creator Studio).
# Mesa 3D editable (piezas con forma, color, imagen, tamaño y física), diseñador de la
# interfaz del juego, galería de imágenes, deshacer/rehacer y guardado de la mesa.
class_name GameCreatorEditor
extends Control

# Nodos de UI (creados por código en _build_editor_ui y guardados aquí).
@onready var _docks: HBoxContainer = $Docks
@onready var _status_bar: Label = $StatusBar/StatusLabel
@onready var _viewport: SubViewport = $ViewportContainer/Viewport
var _build_button: Button
var _playtest_button: Button
var _log: Label
var _inspect_target: Label
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

# Pieza principal de la selección (la que muestra el inspector) y la selección entera.
var _selected_entity: PropEntity = null
var selection: Array[PropEntity] = []

# --- Mesa: cámara, cuadrícula, arrastre, historial ---------------------------------
const TABLE_SAVE_PATH := "user://creador/mesa.json"
const TABLE_SAVE_BYTES := 400000
const TABLE_RADIUS := 2.5
const GRID_STEP := 0.1
const ROTATE_STEP := 15.0
const PICK_SLOP := 6.0
var table_save_path := TABLE_SAVE_PATH
var history := EditHistory.new()
## Imán de cuadrícula: las piezas caen en múltiplos de GRID_STEP y los giros en ROTATE_STEP.
var snap := true
var _camera: Camera3D
var _grid: MeshInstance3D
var _markers_root: Node3D
var _hover_marker: MeshInstance3D
var _hovered: PropEntity
var _clipboard: Array = []
var _id_counter := 0
## Órbita de la cámara: lo que se pide (goal) y lo que se ve, que lo persigue suave.
const ORBIT_TARGET := Vector3(0, 0, 0.35)
const ORBIT_DISTANCE := 5.84
const ORBIT_PITCH := 43.0
var _orbit_goal := {"target": ORBIT_TARGET, "yaw": 0.0, "pitch": ORBIT_PITCH, "distance": ORBIT_DISTANCE}
var _orbit := _orbit_goal.duplicate()
## Arrastre en curso: "move" (piezas), "box" (recuadro de selección), "orbit" o "pan".
var _drag := {}
var _marquee: Panel

# Inspector de piezas.
var _piece_fields: VBoxContainer
var _arrange_box: Control
var _name_edit: LineEdit
var _shape_option: OptionButton
var _spins := {}
var _lock_check: CheckBox
var _undo_button: Button
var _redo_button: Button
var _snap_check: CheckButton
var _syncing_piece := false
var _color_picker: ColorPickerButton
var _label_edit: LineEdit
var _finish_option: OptionButton
var _pattern_box: Control
var _cells_box: Control
var _back_row: Control
var _sheet_spins := {}
## Lógica del juego (blueprints) y quien la ejecuta al probar.
var logic := LogicGraph.new()
var logic_editor: LogicEditor
var _logic_runner: LogicRunner
var _logic_vars := {}
var _toast: Label
var _tags_edit: LineEdit
var _package_dialog: FileDialog
var _notes_edit: LineEdit
var _shuffle_check: CheckBox
var _pattern_option: OptionButton
var _repeat_cols: SpinBox
var _repeat_rows: SpinBox

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
const PIECE_COLORS := [
	Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_GREEN, Palette.PLAYER_YELLOW,
	Palette.PLAYER_ORANGE, Palette.PLAYER_WHITE, Palette.PIECE_DARK, Palette.LAVENDER,
	Palette.WOOD, Color("2b2b33"),
]


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
	ui_view.button_pressed.connect(_on_ui_button)
	ui_view.show_layout(ui_layout, true)
	_marquee = Panel.new()
	_marquee.name = "SelectionBox"
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marquee.visible = false
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(Palette.SUN, 0.12)
	box_style.border_color = Palette.SUN
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(4)
	_marquee.add_theme_stylebox_override("panel", box_style)
	add_child(_marquee)
	move_child(_marquee, ui_view.get_index() + 1)
	_build_editor_ui()
	resized.connect(_layout_canvas)
	_layout_canvas.call_deferred()
	_update_status()
	_refresh_piece_inspector()
	_build_button.grab_focus.call_deferred()


func _exit_tree() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core != null and core.state_changed.is_connected(_on_state_changed):
		core.state_changed.disconnect(_on_state_changed)


# Vista previa 3D: una mesa, luz y cámara; las entidades se ven como piezas con su forma.
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
	table.mesh = PieceKit.rounded_disc(2.6, 0.12, 0.04, 64)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Palette.FELT
	felt.roughness = 1.0
	table.material_override = felt
	table.position.y = -0.06
	world.add_child(table)
	# Suelo físico: al probar, las piezas se apoyan en la mesa en vez de caer al vacío.
	var ground := StaticBody3D.new()
	ground.name = "TableBody"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = 2.6
	disc.height = 0.12
	ground_shape.shape = disc
	ground.add_child(ground_shape)
	ground.position.y = -0.06
	world.add_child(ground)
	# Un borde invisible alrededor de la mesa: al probar, lo lanzado no se cae al vacío.
	var rim := StaticBody3D.new()
	rim.name = "TableRim"
	rim.collision_layer = 1
	rim.collision_mask = 0
	var segments := 32
	for i in segments:
		var angle := TAU * float(i) / segments
		var wall := CollisionShape3D.new()
		var slab := BoxShape3D.new()
		slab.size = Vector3(2.6 * TAU / segments + 0.05, 0.6, 0.1)
		wall.shape = slab
		wall.position = Vector3(sin(angle) * 2.65, 0.3, cos(angle) * 2.65)
		wall.rotation.y = angle
		rim.add_child(wall)
	world.add_child(rim)
	_grid = MeshInstance3D.new()
	_grid.name = "SnapGrid"
	_grid.mesh = _grid_mesh()
	_grid.material_override = _line_material(Color(Palette.PAPER, 0.16), false)
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.position.y = 0.003
	world.add_child(_grid)
	_camera = Camera3D.new()
	_camera.name = "EditorCamera"
	_camera.fov = 42
	world.add_child(_camera)
	_camera.current = true
	_apply_orbit()
	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	world.add_child(_entities_root)
	_markers_root = Node3D.new()
	_markers_root.name = "SelectionMarkers"
	world.add_child(_markers_root)
	_hover_marker = _make_marker(Color(Palette.PAPER, 0.55))
	_hover_marker.name = "HoverMarker"


## Líneas de la cuadrícula, recortadas al círculo de la mesa; cada 0,5 una más marcada.
func _grid_mesh() -> ArrayMesh:
	var lines := PackedVector3Array()
	var count := int(TABLE_RADIUS / GRID_STEP)
	for i in range(-count, count + 1):
		var offset := i * GRID_STEP
		var half := sqrt(maxf(TABLE_RADIUS * TABLE_RADIUS - offset * offset, 0.0))
		if half < 0.01:
			continue
		var repeats := 2 if i % 5 == 0 else 1
		for r in repeats:
			var lift := r * 0.001
			lines.append_array([Vector3(offset, lift, -half), Vector3(offset, lift, half)])
			lines.append_array([Vector3(-half, lift, offset), Vector3(half, lift, offset)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


static func _line_material(color: Color, on_top: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = on_top
	material.set_meta(&"toon_style_applied", true)
	return material


var _cube_lines: ArrayMesh

## Esquinas de una caja unidad (como corchetes): el marco de selección de una pieza.
func _bracket_mesh() -> ArrayMesh:
	if _cube_lines != null:
		return _cube_lines
	var lines := PackedVector3Array()
	var arm := 0.28
	for x in [-0.5, 0.5]:
		for y in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				var corner := Vector3(x, y, z)
				lines.append_array([corner, corner - Vector3(signf(x) * arm, 0, 0)])
				lines.append_array([corner, corner - Vector3(0, signf(y) * arm, 0)])
				lines.append_array([corner, corner - Vector3(0, 0, signf(z) * arm)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	_cube_lines = ArrayMesh.new()
	_cube_lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return _cube_lines


func _make_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.mesh = _bracket_mesh()
	marker.material_override = _line_material(color, true)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	# Un aro en la base, que se ve bien aunque la pieza sea pequeña.
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = PieceKit.torus(0.64, 0.1, 40)
	ring.material_override = _line_material(color, false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = -0.5
	marker.add_child(ring)
	_markers_root.add_child(marker)
	return marker


func _build_editor_ui() -> void:
	for child in _docks.get_children():
		child.queue_free()
	_docks.add_theme_constant_override("separation", 14)
	_docks.offset_left = 18
	_docks.offset_top = 18
	_docks.offset_right = -18
	_docks.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ========== Izquierda: modo, herramientas y pestañas ==========
	var left := _make_dock("LeftDock")
	# Panel izquierdo tan alto como la ventana: las pestañas se desplazan si no caben.
	(left["panel"] as Control).size_flags_vertical = Control.SIZE_FILL
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

	var tools := HBoxContainer.new()
	tools.name = "EditTools"
	tools.add_theme_constant_override("separation", 6)
	left_col.add_child(tools)
	_undo_button = _tool_button("↶", "Deshacer · Ctrl+Z", undo)
	_undo_button.name = "UndoButton"
	tools.add_child(_undo_button)
	_redo_button = _tool_button("↷", "Rehacer · Ctrl+Y", redo)
	_redo_button.name = "RedoButton"
	tools.add_child(_redo_button)
	_snap_check = CheckButton.new()
	_snap_check.name = "SnapToggle"
	_snap_check.text = "Imán"
	_snap_check.tooltip_text = "Cuadrícula magnética · G"
	_snap_check.button_pressed = snap
	_snap_check.focus_mode = Control.FOCUS_NONE
	_snap_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snap_check.toggled.connect(set_snap)
	tools.add_child(_snap_check)

	var logic_button := _button("🧩  Lógica del juego…", open_logic_editor)
	logic_button.name = "OpenLogic"
	logic_button.tooltip_text = "Blueprints: eventos, acciones y bloques GDScript que dan reglas al juego"
	left_col.add_child(logic_button)

	var tabs := TabContainer.new()
	tabs.name = "EditorTabs"
	tabs.add_theme_font_size_override("font_size", 14)
	tabs.add_theme_constant_override("side_margin", 0)
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	tabs.custom_minimum_size = Vector2(0, 240)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(tabs)

	# Pestaña «Piezas»: formas que se pueden poner y la mesa entera.
	var pieces_tab := _tab_column("Piezas")
	tabs.add_child(pieces_tab.get_parent().get_parent())
	pieces_tab.add_child(_caption("AÑADIR A LA MESA"))
	var shapes := GridContainer.new()
	shapes.name = "ShapePalette"
	shapes.columns = 2
	shapes.add_theme_constant_override("h_separation", 8)
	shapes.add_theme_constant_override("v_separation", 8)
	pieces_tab.add_child(shapes)
	for shape in PieceShapes.SHAPES:
		var add := _button("%s  %s" % [PieceShapes.ICONS[shape], tr(PieceShapes.NAMES[shape])], add_piece.bind(shape))
		add.name = "AddPiece_" + shape
		add.add_theme_font_size_override("font_size", 14)
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.tooltip_text = "Pon una pieza nueva en el centro de la mesa"
		shapes.add_child(add)
	var new_entity := _button("+  Nueva pieza", _spawn_example_entity)
	new_entity.name = "NewEntityButton"
	new_entity.visible = false
	pieces_tab.add_child(new_entity)
	pieces_tab.add_child(_caption("PLANTILLAS"))
	var templates := GridContainer.new()
	templates.name = "TemplatePalette"
	templates.columns = 2
	templates.add_theme_constant_override("h_separation", 8)
	templates.add_theme_constant_override("v_separation", 8)
	pieces_tab.add_child(templates)
	for template in TableTemplates.NAMES:
		var start := _button(TableTemplates.TITLES[template], load_template.bind(template))
		start.name = "Template_" + template
		start.tooltip_text = TableTemplates.HINTS[template]
		start.add_theme_font_size_override("font_size", 14)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		templates.add_child(start)
	pieces_tab.add_child(_caption("LA MESA"))
	var table_files := HBoxContainer.new()
	table_files.add_theme_constant_override("separation", 8)
	pieces_tab.add_child(table_files)
	for entry in [["Guardar", "SaveTable", save_table], ["Cargar", "LoadTable", load_table], ["Vaciar", "ClearTable", clear_table]]:
		var file_button := _button(entry[0], entry[2])
		file_button.name = entry[1]
		file_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		file_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		table_files.add_child(file_button)

	var share_row := VBoxContainer.new()
	share_row.add_theme_constant_override("separation", 8)
	pieces_tab.add_child(share_row)
	for entry in [["Exportar juego…", "ExportGame", _open_export_dialog, "Un solo archivo con la mesa, la interfaz y todas las imágenes, para compartirlo"], ["Importar juego…", "ImportGame", _open_import_dialog, "Abre un juego exportado (.tablerama)"]]:
		var share := _button(entry[0], entry[2])
		share.name = entry[1]
		share.tooltip_text = entry[3]
		share.alignment = HORIZONTAL_ALIGNMENT_CENTER
		share.add_theme_font_size_override("font_size", 14)
		share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		share_row.add_child(share)

	# Pestaña «Interfaz»: lo que el jugador verá encima de la mesa.
	var ui_tab := _tab_column("Interfaz")
	tabs.add_child(ui_tab.get_parent().get_parent())
	ui_tab.add_child(_caption("INTERFAZ DEL JUEGO · AÑADIR"))
	var ui_grid := GridContainer.new()
	ui_grid.name = "UiPalette"
	ui_grid.columns = 2
	ui_grid.add_theme_constant_override("h_separation", 8)
	ui_grid.add_theme_constant_override("v_separation", 8)
	ui_tab.add_child(ui_grid)
	for type in UiLayout.TYPES:
		var add := _button(UiLayout.TYPE_NAMES[type], add_ui_element.bind(type))
		add.add_theme_font_size_override("font_size", 14)
		add.alignment = HORIZONTAL_ALIGNMENT_CENTER
		add.name = "AddUi_" + type
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.tooltip_text = "Añade a la pantalla; luego arrástralo y tira de su esquina para cambiarlo de tamaño"
		ui_grid.add_child(add)
	var ui_files := HBoxContainer.new()
	ui_files.add_theme_constant_override("separation", 8)
	ui_tab.add_child(ui_files)
	var save_ui := _button("Guardar", save_ui_layout)
	save_ui.name = "SaveUi"
	save_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_files.add_child(save_ui)
	var load_ui := _button("Cargar", load_ui_layout)
	load_ui.name = "LoadUi"
	load_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_files.add_child(load_ui)

	# Pestaña «Imágenes»: galería para piezas y elementos de interfaz.
	var images_tab := _tab_column("Imágenes")
	tabs.add_child(images_tab.get_parent().get_parent())
	var import_button := _button("Importar imagen…", _open_image_import_dialog)
	import_button.name = "ImportImageButton"
	images_tab.add_child(import_button)
	_asset_browser = AssetBrowser.new()
	_asset_browser.name = "AssetBrowser"
	_asset_browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	images_tab.add_child(_asset_browser)
	_asset_browser.build_ui()
	_asset_browser.set_image_importer(_image_importer)
	_asset_browser.image_selected.connect(_on_asset_selected)
	images_tab.add_child(_caption("CARTAS DESDE IMÁGENES"))
	images_tab.add_child(_small("Una hoja con las cartas en rejilla (como las de Tabletop Simulator) se corta sola en cartas."))
	var sheet_grid := GridContainer.new()
	sheet_grid.name = "SheetGrid"
	sheet_grid.columns = 1
	sheet_grid.add_theme_constant_override("h_separation", 6)
	images_tab.add_child(sheet_grid)
	for entry in [["Columnas", "SheetCols", 10, 1, 20], ["Filas", "SheetRows", 7, 1, 20], ["Cartas", "SheetCount", 69, 1, 200]]:
		var spin := SpinBox.new()
		spin.name = entry[1]
		spin.min_value = entry[3]
		spin.max_value = entry[4]
		spin.value = entry[2]
		spin.select_all_on_focus = true
		sheet_grid.add_child(_labelled(entry[0], spin))
		_sheet_spins[entry[1]] = spin
	var from_sheet := _button("Mazo desde la hoja elegida", func() -> void:
		deck_from_sheet(str(_asset_browser.selected_image.get("path", "")), int(_sheet_spins["SheetCols"].value), int(_sheet_spins["SheetRows"].value), int(_sheet_spins["SheetCount"].value))
	)
	from_sheet.name = "DeckFromSheet"
	images_tab.add_child(from_sheet)
	var from_gallery := _button("Una carta por imagen", cards_from_gallery)
	from_gallery.name = "CardsFromGallery"
	from_gallery.tooltip_text = "Un mazo con una carta por cada imagen de la galería"
	images_tab.add_child(from_gallery)

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
	_log.text = "> Añade una pieza, arrástrala por la mesa y cámbiala desde el inspector."
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.add_theme_font_size_override("font_size", 13)
	console.add_child(_log)

	# ========== Derecha: piezas de la mesa e inspector (con desplazamiento) ==========
	var right_holder := VBoxContainer.new()
	right_holder.name = "RightHolder"
	right_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_docks.add_child(right_holder)
	# Hueco para los botones «Ayuda» y «Menú», que van arriba a la derecha en todas las pantallas.
	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = 52
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_holder.add_child(top_gap)
	var right := _make_dock("RightDock")
	(right["panel"] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_holder.add_child(right["panel"])
	var right_scroll := ScrollContainer.new()
	right_scroll.name = "InspectorScroll"
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_margin: MarginContainer = (right["column"] as Control).get_parent()
	right_margin.remove_child(right["column"])
	right_margin.add_child(right_scroll)
	var right_col: VBoxContainer = right["column"]
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_col)
	_scene_hierarchy = SceneHierarchy.new()
	_scene_hierarchy.name = "SceneHierarchy"
	_scene_hierarchy.custom_minimum_size = Vector2(0, 150)
	right_col.add_child(_scene_hierarchy)
	_scene_hierarchy.selection_changed.connect(_on_hierarchy_selection)
	_scene_hierarchy.add_requested.connect(add_piece.bind(PieceShapes.DEFAULT))

	_piece_inspector = VBoxContainer.new()
	_piece_inspector.name = "PieceInspector"
	_piece_inspector.add_theme_constant_override("separation", 8)
	right_col.add_child(_piece_inspector)
	_build_piece_inspector(_piece_inspector)
	_build_ui_inspector(right_col)

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


## Columna dentro de una pestaña; el nombre del contenedor es el título de la pestaña.
func _tab_column(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	return column


## Un control con su nombre encima, que ocupa media fila de una rejilla.
func _labelled(title: String, control: Control) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _small(title)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", DIM)
	cell.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = 0
	cell.add_child(control)
	return cell


func _tool_button(icon: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = icon
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(44, 36)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	return button


func _build_piece_inspector(column: VBoxContainer) -> void:
	column.add_child(_caption("INSPECTOR"))
	_inspect_target = Label.new()
	_inspect_target.name = "InspectTarget"
	_inspect_target.text = "Selecciona una pieza en la mesa o en la lista."
	_inspect_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_inspect_target)
	_piece_fields = VBoxContainer.new()
	_piece_fields.name = "PieceFields"
	_piece_fields.add_theme_constant_override("separation", 8)
	column.add_child(_piece_fields)
	var fields := _piece_fields
	_name_edit = LineEdit.new()
	_name_edit.name = "PieceName"
	_name_edit.placeholder_text = "Nombre de la pieza"
	_name_edit.max_length = TableRecord.MAX_NAME
	_name_edit.text_changed.connect(_on_name_changed)
	fields.add_child(_name_edit)
	_shape_option = OptionButton.new()
	_shape_option.name = "PieceShape"
	for shape in PieceShapes.SHAPES:
		_shape_option.add_item("%s  %s" % [PieceShapes.ICONS[shape], tr(PieceShapes.NAMES[shape])])
	_shape_option.item_selected.connect(func(index: int) -> void: _edit_selection("shape", PieceShapes.SHAPES[index]))
	fields.add_child(_shape_option)
	_label_edit = LineEdit.new()
	_label_edit.name = "PieceLabel"
	_label_edit.placeholder_text = "Texto en la pieza"
	_label_edit.max_length = TableRecord.MAX_LABEL
	_label_edit.text_changed.connect(func(text: String) -> void: _edit_selection("label", text))
	fields.add_child(_label_edit)
	var looks := GridContainer.new()
	looks.name = "PieceLooks"
	looks.columns = 2
	looks.add_theme_constant_override("h_separation", 8)
	looks.add_theme_constant_override("v_separation", 4)
	fields.add_child(looks)
	_finish_option = OptionButton.new()
	_finish_option.name = "PieceFinish"
	_finish_option.clip_text = true
	_finish_option.tooltip_text = "Acabado"
	for finish in PieceShapes.FINISHES:
		_finish_option.add_item(PieceShapes.FINISH_NAMES[finish])
	_finish_option.item_selected.connect(func(index: int) -> void: _edit_selection("finish", PieceShapes.FINISHES[index]))
	looks.add_child(_labelled("Acabado", _finish_option))
	# Dibujo de la cara de arriba (tableros, cartas, fichas, zonas) y casillas por lado.
	_pattern_option = OptionButton.new()
	_pattern_option.name = "PiecePattern"
	_pattern_option.clip_text = true
	_pattern_option.tooltip_text = "Dibujo de la cara de arriba"
	for pattern in PieceShapes.PATTERNS:
		_pattern_option.add_item(PieceShapes.PATTERN_NAMES[pattern])
	_pattern_option.item_selected.connect(func(index: int) -> void: _edit_selection("pattern", PieceShapes.PATTERNS[index]))
	var pattern_cell := _labelled("Dibujo", _pattern_option)
	looks.add_child(pattern_cell)
	var cells := SpinBox.new()
	cells.name = "Piece_cells"
	cells.min_value = PieceShapes.MIN_CELLS
	cells.max_value = PieceShapes.MAX_CELLS
	cells.tooltip_text = "Casillas por lado"
	cells.select_all_on_focus = true
	cells.value_changed.connect(func(value: float) -> void: _edit_selection("cells", int(value)))
	var cells_cell := _labelled("Casillas", cells)
	looks.add_child(cells_cell)
	_spins["cells"] = cells
	_pattern_box = pattern_cell
	_cells_box = cells_cell
	fields.add_child(_small("Color"))
	var colors := HFlowContainer.new()
	colors.name = "PieceSwatches"
	colors.add_theme_constant_override("h_separation", 6)
	colors.add_theme_constant_override("v_separation", 6)
	for color in PIECE_COLORS:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(26, 26)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = "#" + (color as Color).to_html(false)
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(13)
		box.border_color = Palette.PAPER
		box.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, box)
		swatch.pressed.connect(_edit_selection.bind("color", color))
		colors.add_child(swatch)
	var picker := ColorPickerButton.new()
	_color_picker = picker
	picker.name = "PieceColorPicker"
	picker.custom_minimum_size = Vector2(42, 26)
	picker.tooltip_text = "Otro color"
	picker.edit_alpha = false
	picker.color_changed.connect(func(color: Color) -> void: _edit_selection("color", color))
	colors.add_child(picker)
	fields.add_child(colors)

	var grid := GridContainer.new()
	grid.name = "PieceTransform"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	fields.add_child(grid)
	for entry in [
		["x", "X", -TABLE_RADIUS, TABLE_RADIUS, 0.01, ""],
		["z", "Z", -TABLE_RADIUS, TABLE_RADIUS, 0.01, ""],
		["y", "Altura", 0.0, TableRecord.LIMIT_Y, 0.01, ""],
		["turn", "Giro", -360.0, 360.0, 1.0, "°"],
		["scale", "Tamaño", PieceShapes.MIN_SCALE * 100.0, PieceShapes.MAX_SCALE * 100.0, 5.0, "%"],
		["mass", "Peso", 0.05, 50.0, 0.05, ""],
	]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _small(entry[1])
		label.add_theme_color_override("font_color", DIM)
		cell.add_child(label)
		var spin := SpinBox.new()
		spin.name = "Piece_" + entry[0]
		spin.min_value = entry[2]
		spin.max_value = entry[3]
		spin.step = entry[4]
		spin.suffix = entry[5]
		spin.allow_greater = entry[0] == "turn"
		spin.allow_lesser = entry[0] == "turn"
		spin.select_all_on_focus = true
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_edit_selection_number.bind(entry[0]))
		cell.add_child(spin)
		grid.add_child(cell)
		_spins[entry[0]] = spin
	_shuffle_check = CheckBox.new()
	_shuffle_check.name = "ZoneShuffle"
	_shuffle_check.text = "Mezclar lo de dentro al probar"
	_shuffle_check.toggled.connect(func(on: bool) -> void: _edit_selection("shuffle", on))
	fields.add_child(_shuffle_check)
	_lock_check = CheckBox.new()
	_lock_check.name = "PieceLocked"
	_lock_check.text = "Fija: no se mueve al probar"
	_lock_check.toggled.connect(func(on: bool) -> void: _edit_selection("locked", on))
	fields.add_child(_lock_check)
	_texture_label = _small("Imagen: ninguna")
	_texture_label.name = "PropTexture"
	fields.add_child(_texture_label)
	var image_row := HBoxContainer.new()
	image_row.add_theme_constant_override("separation", 8)
	fields.add_child(image_row)
	var apply := _button("Poner imagen", _apply_selected_texture)
	apply.name = "ApplyTextureButton"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_row.add_child(apply)
	var clear_image := _button("Sin imagen", _edit_selection.bind("texture", ""))
	clear_image.name = "ClearTextureButton"
	clear_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_row.add_child(clear_image)
	_back_row = HBoxContainer.new()
	_back_row.add_theme_constant_override("separation", 8)
	fields.add_child(_back_row)
	var set_back := _button("Poner reverso", _apply_selected_back)
	set_back.name = "ApplyBackButton"
	set_back.tooltip_text = "La imagen elegida en la galería, en la cara de abajo (se ve al voltear)"
	set_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_row.add_child(set_back)
	var clear_back := _button("Sin reverso", _edit_selection.bind("back", ""))
	clear_back.name = "ClearBackButton"
	clear_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_row.add_child(clear_back)
	_notes_edit = LineEdit.new()
	_notes_edit.name = "PieceNotes"
	_notes_edit.placeholder_text = "Descripción para los jugadores"
	_notes_edit.tooltip_text = "Se ve al pasar el ratón por la pieza"
	_notes_edit.max_length = TableRecord.MAX_NOTES
	_notes_edit.text_changed.connect(func(text: String) -> void: _edit_selection("notes", text))
	fields.add_child(_notes_edit)
	_tags_edit = LineEdit.new()
	_tags_edit.name = "PieceTags"
	_tags_edit.placeholder_text = "Etiquetas: rojo, carta, jugador1…"
	_tags_edit.tooltip_text = "Separadas por comas. La lógica puede elegir piezas por etiqueta."
	_tags_edit.text_submitted.connect(func(_t: String) -> void: _edit_selection("tags", _tags_edit.text))
	_tags_edit.focus_exited.connect(func() -> void: _edit_selection("tags", _tags_edit.text))
	fields.add_child(_tags_edit)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	fields.add_child(actions)
	var duplicate := _button("Duplicar", duplicate_selection)
	duplicate.name = "DuplicateButton"
	duplicate.tooltip_text = "Ctrl+D"
	duplicate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(duplicate)
	var remove := _button("Quitar", _remove_selected_entity)
	remove.name = "RemoveEntityButton"
	remove.tooltip_text = "Supr"
	remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(remove)

	# Ordenar varias piezas a la vez.
	var arrange := VBoxContainer.new()
	arrange.name = "ArrangeTools"
	arrange.add_theme_constant_override("separation", 6)
	fields.add_child(arrange)
	_arrange_box = arrange
	arrange.add_child(_caption("ORDENAR LA SELECCIÓN"))
	var arrange_row := HBoxContainer.new()
	arrange_row.add_theme_constant_override("separation", 6)
	arrange.add_child(arrange_row)
	for entry in [["En fila", "ArrangeRow", arrange_row_selection], ["Apilar", "ArrangeStack", stack_selection], ["Centrar", "ArrangeCenter", center_selection]]:
		var tool := _button(entry[0], entry[2])
		tool.name = entry[1]
		tool.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tool.add_theme_font_size_override("font_size", 13)
		tool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arrange_row.add_child(tool)
	var extra_row := HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 6)
	arrange.add_child(extra_row)
	for entry in [["Numerar", "ArrangeNumber", number_selection, "Escribe 1, 2, 3… en las piezas, de izquierda a derecha"], ["Mezclar", "ArrangeShuffle", shuffle_selection, "Baraja las posiciones de las piezas (un mazo, unas fichas)"]]:
		var tool := _button(entry[0], entry[2])
		tool.name = entry[1]
		tool.tooltip_text = entry[3]
		tool.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tool.add_theme_font_size_override("font_size", 13)
		tool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		extra_row.add_child(tool)

	# Repetir la pieza en una rejilla (filas de fichas, cartas de un palo…).
	fields.add_child(_caption("REPETIR EN REJILLA"))
	var repeat_row := GridContainer.new()
	repeat_row.name = "RepeatRow"
	repeat_row.columns = 2
	repeat_row.add_theme_constant_override("h_separation", 8)
	fields.add_child(repeat_row)
	_repeat_cols = SpinBox.new()
	_repeat_cols.name = "RepeatCols"
	_repeat_cols.min_value = 1
	_repeat_cols.max_value = 12
	_repeat_cols.value = 4
	_repeat_cols.select_all_on_focus = true
	repeat_row.add_child(_labelled("Columnas", _repeat_cols))
	_repeat_rows = SpinBox.new()
	_repeat_rows.name = "RepeatRows"
	_repeat_rows.min_value = 1
	_repeat_rows.max_value = 12
	_repeat_rows.value = 1
	_repeat_rows.select_all_on_focus = true
	repeat_row.add_child(_labelled("Filas", _repeat_rows))
	var repeat := _button("Repetir", func() -> void: repeat_selection(int(_repeat_cols.value), int(_repeat_rows.value)))
	repeat.name = "RepeatButton"
	repeat.alignment = HORIZONTAL_ALIGNMENT_CENTER
	fields.add_child(repeat)


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
		_say(tr("No caben más elementos de interfaz (máximo %d).") % UiLayout.MAX_ELEMENTS)
		return 0
	ui_view.rebuild()
	ui_view.select(int(element["id"]))
	_say(tr("%s añadido: arrástralo donde quieras y tira de su esquina para cambiarlo de tamaño.") % UiLayout.TYPE_NAMES[type])
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
	_say(tr("Interfaz cargada: %d elementos.") % ui_layout.elements.size())
	return true


static func _decode_ui(record: Variant) -> Variant:
	return record if UiLayout.from_record(record) != null else null


func _say(message: String) -> void:
	if _log != null:
		_log.text = "> " + tr(message)


func _back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SessionNavigation.home_scene())


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
	_drag = {}
	_held = {}
	_rolling.clear()
	_hovered = null
	_marquee.visible = false
	_layout_canvas()
	ui_view.show_layout(ui_layout, _build_mode)
	if _build_mode:
		ui_view.select(0)
	# En construcción las piezas están quietas; al probar, caen y se pueden empujar.
	for entity in _scene_hierarchy.entities:
		_set_entity_physics(entity, not _build_mode)
		# Los anclajes sólo se ven al editar; al probar siguen atrayendo piezas.
		if _is_anchor(entity):
			(entity.get_node("Body/Mesh") as Node3D).visible = _build_mode
	if not _build_mode:
		shuffle_zones()
		_start_logic()
	else:
		_stop_logic()
		if _toast != null:
			_toast.modulate.a = 0.0
	_grid.visible = snap and _build_mode
	_markers_root.visible = _build_mode
	_say("Modo: " + ("construcción" if _build_mode else "prueba"))
	_update_status()


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
	_say(tr("Imagen elegida: %s. Selecciona una pieza y pulsa «Poner imagen».") % image_path.get_file())


# ===================================================================================
# Selección
# ===================================================================================

## Compatibilidad: seleccionar una sola pieza (o ninguna con null).
func _on_entity_selected(entity: PropEntity) -> void:
	select_pieces([entity] if entity != null else [])


func _on_hierarchy_selection(entities: Array) -> void:
	select_pieces(entities, false)


## Deja seleccionadas estas piezas; la última es la principal (la del inspector).
func select_pieces(entities: Array, sync_list := true) -> void:
	selection.clear()
	for entity in entities:
		if entity is PropEntity and is_instance_valid(entity) and entity.is_inside_tree() and not selection.has(entity):
			selection.append(entity)
	_selected_entity = selection.back() if not selection.is_empty() else null
	if not selection.is_empty() and ui_view != null and ui_view.selected_id != 0:
		ui_view.select(0)
	if sync_list and _scene_hierarchy != null:
		_scene_hierarchy.show_selection(selection)
	_refresh_markers()
	_refresh_piece_inspector()
	_update_status()


func _toggle_in_selection(entity: PropEntity) -> void:
	var list := selection.duplicate()
	if list.has(entity):
		list.erase(entity)
	else:
		list.append(entity)
	select_pieces(list)


func select_all() -> void:
	select_pieces(_scene_hierarchy.entities)


func _refresh_piece_inspector() -> void:
	if _inspect_target == null:
		return
	_syncing_piece = true
	_piece_fields.visible = _selected_entity != null
	if _selected_entity == null:
		_inspect_target.text = "Selecciona una pieza en la mesa o en la lista."
		_texture_label.text = "Imagen: ninguna"
		_syncing_piece = false
		return
	var entity := _selected_entity
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	_inspect_target.text = entity.entity_name if selection.size() == 1 else tr("%d piezas seleccionadas · los cambios van a todas") % selection.size()
	if _name_edit.text != entity.entity_name:
		_name_edit.text = entity.entity_name
	_name_edit.editable = selection.size() == 1
	_shape_option.select(PieceShapes.SHAPES.find(visual.shape if visual != null else PieceShapes.DEFAULT))
	(_spins["x"] as SpinBox).set_value_no_signal(entity.position.x)
	(_spins["z"] as SpinBox).set_value_no_signal(entity.position.z)
	(_spins["y"] as SpinBox).set_value_no_signal(entity.position.y)
	(_spins["turn"] as SpinBox).set_value_no_signal(roundf(entity.rotation_degrees.y))
	(_spins["scale"] as SpinBox).set_value_no_signal(roundf((visual.scale_factor if visual != null else 1.0) * 100.0))
	(_spins["mass"] as SpinBox).set_value_no_signal(physics.mass if physics != null else 1.0)
	_lock_check.set_pressed_no_signal(entity.is_locked)
	_color_picker.color = visual.color_tint if visual != null else Color.WHITE
	if _label_edit.text != visual.label:
		_label_edit.text = visual.label
	_finish_option.select(maxi(0, PieceShapes.FINISHES.find(visual.finish)))
	_pattern_box.visible = visual.shape in PieceShapes.FLAT
	_cells_box.visible = visual.shape in PieceShapes.FLAT and visual.pattern != "liso"
	_back_row.visible = visual.shape in PieceShapes.FLAT and visual.shape != PieceShapes.ZONE
	_shuffle_check.visible = visual.shape == PieceShapes.ZONE
	_shuffle_check.set_pressed_no_signal(visual.shuffle_on_play)
	if _notes_edit.text != visual.notes:
		_notes_edit.text = visual.notes
	if not _tags_edit.has_focus():
		_tags_edit.text = ", ".join(entity.tags)
	_pattern_option.select(maxi(0, PieceShapes.PATTERNS.find(visual.pattern)))
	(_spins["cells"] as SpinBox).set_value_no_signal(visual.cells)
	_texture_label.text = "Imagen: " + _get_entity_texture_info(entity)
	_arrange_box.visible = selection.size() > 1
	_syncing_piece = false


func _get_entity_texture_info(entity: PropEntity) -> String:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	if visual != null and not visual.texture_path.is_empty():
		return visual.texture_path.get_file()
	return "ninguna"


# ===================================================================================
# Crear, cambiar y quitar piezas (todo pasa por el historial)
# ===================================================================================

## Pon una pieza nueva de esta forma cerca del centro, sin montarla encima de otra.
func add_piece(shape: String) -> PropEntity:
	_remember("add")
	var count := _scene_hierarchy.entities.size()
	var piece := {
		"id": "", "name": "%s %d" % [tr(PieceShapes.NAMES[PieceShapes.valid(shape)]), count + 1],
		"shape": PieceShapes.valid(shape), "color": (PIECE_COLORS[count % 4] as Color).to_html(true),
		"texture": "", "label": "", "pattern": "liso", "cells": 8, "finish": "mate",
		"pos": _free_spot(), "rot": Vector3.ZERO, "scale": 1.0,
		"locked": shape in ["tablero", PieceShapes.ZONE], "mass": 1.0, "bounce": 0.1,
	}
	match shape:
		PieceShapes.ANCHOR:
			piece["color"] = Palette.SUN.to_html(true)
			piece["locked"] = true
		"tablero":
			piece["color"] = TableTemplates.BOARD_COLOR.to_html(true)
			piece["pos"] = Vector3.ZERO
			piece["pattern"] = "casillas"
		PieceShapes.ZONE:
			piece["color"] = Palette.LAVENDER.to_html(true)
			piece["label"] = tr("ZONA")
		"dado":
			piece["color"] = Palette.PAPER.to_html(true)
		"carta":
			piece["mass"] = 0.2
	if _scene_hierarchy.entities.size() >= TableRecord.MAX_PIECES:
		_say(tr("No caben más piezas (máximo %d).") % TableRecord.MAX_PIECES)
		return null
	var entity := _make_piece(piece)
	entity.position.y = _surface_height(entity.position, [entity])
	_pop_in(entity)
	select_pieces([entity])
	_play("pop")
	_say(tr("Pieza creada: %s. Arrástrala por la mesa; Q/E la giran.") % entity.entity_name)
	return entity


## Pone una mesa de partida (sustituye a la actual; Ctrl+Z la recupera).
func load_template(name: String) -> void:
	var pieces := TableTemplates.pieces(name)
	if pieces.is_empty():
		return
	_remember("template")
	_rebuild_table(pieces)
	_apply_logic(TableTemplates.logic(name))
	for entity in _scene_hierarchy.entities:
		_pop_in(entity)
	_play("pop")
	focus_all()
	_say(tr("Plantilla «%s» puesta. Cámbiala a tu gusto; Ctrl+Z recupera la mesa de antes.") % tr(TableTemplates.TITLES[name]))


## Copias de la pieza principal en una rejilla de `cols` × `rows`, empezando en ella.
func repeat_selection(cols: int, rows: int) -> Array:
	if _selected_entity == null or cols * rows <= 1:
		return []
	var room := TableRecord.MAX_PIECES - _scene_hierarchy.entities.size()
	if cols * rows - 1 > room:
		_say(tr("No caben tantas piezas (quedan %d).") % room)
		return []
	_remember("repeat")
	var source := _selected_entity
	var visual := source.get_component("VisualComponent") as VisualComponent
	var size := PieceShapes.size_of(visual.shape, visual.scale_factor)
	var step := Vector2(size.x + 0.06, size.z + 0.06)
	var record: Dictionary = TableRecord.valid_piece(TableRecord.piece_record(source))
	var made: Array = [source]
	for row in rows:
		for col in cols:
			if row == 0 and col == 0:
				continue
			var piece := record.duplicate()
			piece["id"] = ""
			piece["name"] = "%s %d" % [source.entity_name, made.size() + 1]
			var at: Vector3 = source.position + Vector3(col * step.x, 0, row * step.y)
			piece["pos"] = _clamp_to_table(Vector3(at.x, source.position.y, at.z))
			made.append(_make_piece(piece))
	for entity in made:
		if entity != source:
			entity.position.y = _surface_height(entity.position, [entity]) + _rest_offset(entity)
			_pop_in(entity)
	select_pieces(made)
	_play("pop")
	_say(tr("Repetida en %d × %d: %d piezas.") % [cols, rows, made.size()])
	return made


## Escribe 1, 2, 3… en las piezas seleccionadas, de izquierda a derecha y de fondo a frente.
func number_selection() -> void:
	if selection.is_empty():
		return
	_remember("number")
	var ordered := selection.duplicate()
	ordered.sort_custom(func(a: PropEntity, b: PropEntity) -> bool:
		if absf(a.position.z - b.position.z) > 0.05:
			return a.position.z < b.position.z
		if absf(a.position.x - b.position.x) > 0.01:
			return a.position.x < b.position.x
		return a.position.y < b.position.y
	)
	for i in ordered.size():
		var visual := (ordered[i] as PropEntity).get_component("VisualComponent") as VisualComponent
		visual.label = str(i + 1)
		_refresh_entity_visual(ordered[i])
	_bump(ordered)
	_refresh_piece_inspector()
	_say(tr("Numeradas del 1 al %d.") % ordered.size())


## Baraja las posiciones de las piezas seleccionadas entre ellas (mazos, fichas ocultas).
func shuffle_selection() -> void:
	if selection.size() < 2:
		return
	_remember("shuffle")
	var spots: Array = selection.map(func(entity: PropEntity) -> Transform3D: return entity.transform)
	spots.shuffle()
	for i in selection.size():
		(selection[i] as PropEntity).transform = spots[i]
	_bump(selection)
	_play("card")
	_say(tr("Mezcladas: %d.") % selection.size())


## Compatibilidad con el botón de antes: una ficha nueva.
func _spawn_example_entity() -> void:
	add_piece(PieceShapes.DEFAULT)


## Hueco libre en espiral alrededor del centro.
func _free_spot() -> Vector3:
	for ring in 8:
		var steps := maxi(1, ring * 6)
		for i in steps:
			var angle := TAU * float(i) / steps
			var spot := Vector3(cos(angle), 0, sin(angle)) * ring * 0.55
			spot = Vector3(snappedf(spot.x, GRID_STEP), 0, snappedf(spot.z, GRID_STEP))
			var free := true
			for entity in _scene_hierarchy.entities:
				if Vector2(entity.position.x - spot.x, entity.position.z - spot.z).length() < 0.5 and entity.position.y < 0.2:
					var visual := entity.get_component("VisualComponent") as VisualComponent
					if visual == null or not (visual.shape == "tablero" or visual.shape in PieceShapes.MARKERS):
						free = false
						break
			if free:
				return spot
	return Vector3.ZERO


func _make_piece(piece: Dictionary) -> PropEntity:
	var entity := PropEntity.new()
	TableRecord.apply_piece(entity, piece)
	if entity.entity_id == "" or _find_piece(entity.entity_id) != null or str(piece.get("id", "")) == "":
		entity.entity_id = _new_id()
	_entities_root.add_child(entity)
	_refresh_entity_visual(entity)
	_set_entity_physics(entity, not _build_mode)
	_scene_hierarchy.add_entity(entity)
	return entity


func _new_id() -> String:
	_id_counter += 1
	var id := "p%d" % _id_counter
	while _find_piece(id) != null:
		_id_counter += 1
		id = "p%d" % _id_counter
	return id


func _find_piece(id: String) -> PropEntity:
	for entity in _scene_hierarchy.entities:
		if is_instance_valid(entity) and entity.entity_id == id:
			return entity
	return null


func _remove_selected_entity() -> void:
	if selection.is_empty():
		_say("Selecciona primero una pieza.")
		return
	_remember("remove")
	var gone := selection.duplicate()
	var label := _selected_entity.entity_name if gone.size() == 1 else tr("%d piezas") % gone.size()
	select_pieces([])
	for entity in gone:
		_scene_hierarchy.remove_entity(entity)
		entity.queue_free()
	_play("drop")
	_say(tr("Quitado: %s.") % label)
	_update_status()


func duplicate_selection() -> void:
	if selection.is_empty():
		_say("Selecciona primero una pieza.")
		return
	_remember("duplicate")
	var copies := _paste_records(_records_of(selection), Vector3(GRID_STEP * 3, 0, GRID_STEP * 3))
	_say(tr("Duplicado: %d.") % copies.size() if copies.size() > 1 else "Duplicada: %s." % copies[0].entity_name)


func copy_selection() -> void:
	if selection.is_empty():
		return
	_clipboard = _records_of(selection)
	_say("Copiado. Ctrl+V lo pega.")


func paste_clipboard() -> void:
	if _clipboard.is_empty():
		_say("No hay nada copiado.")
		return
	_remember("paste")
	_paste_records(_clipboard, Vector3(GRID_STEP * 4, 0, 0))
	_say("Pegado.")


func _records_of(entities: Array) -> Array:
	var records: Array = []
	for entity in entities:
		records.append(TableRecord.valid_piece(TableRecord.piece_record(entity)))
	return records


func _paste_records(records: Array, offset: Vector3) -> Array:
	var made: Array = []
	for record in records:
		var piece: Dictionary = record.duplicate()
		piece["id"] = ""
		var target: Vector3 = piece["pos"] + offset
		piece["pos"] = _clamp_to_table(target)
		made.append(_make_piece(piece))
	for entity in made:
		var p: Vector3 = entity.position
		entity.position.y = (_surface_height(p, made) + _rest_offset(entity)) if p.y < 0.01 + _rest_offset(entity) else p.y
		_pop_in(entity)
	select_pieces(made)
	_play("pop")
	return made


## Cambia una propiedad en todas las piezas seleccionadas.
func _edit_selection(property: String, value: Variant) -> void:
	if _syncing_piece or selection.is_empty():
		return
	_remember("edit:" + property)
	for entity in selection:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
		match property:
			"shape":
				visual.shape = PieceShapes.valid(str(value))
			"color":
				visual.color_tint = value
			"texture":
				visual.texture_path = str(value)
			"locked":
				entity.is_locked = bool(value)
			"scale":
				visual.scale_factor = clampf(float(value), PieceShapes.MIN_SCALE, PieceShapes.MAX_SCALE)
			"mass":
				physics.mass = clampf(float(value), 0.05, 50.0)
			"label":
				visual.label = str(value).left(TableRecord.MAX_LABEL)
			"finish":
				visual.finish = str(value) if str(value) in PieceShapes.FINISHES else "mate"
			"pattern":
				visual.pattern = str(value) if str(value) in PieceShapes.PATTERNS else "liso"
			"cells":
				visual.cells = clampi(int(value), PieceShapes.MIN_CELLS, PieceShapes.MAX_CELLS)
			"back":
				visual.back_path = str(value)
			"notes":
				visual.notes = str(value).left(TableRecord.MAX_NOTES)
			"shuffle":
				visual.shuffle_on_play = bool(value)
			"tags":
				entity.tags.assign(TableRecord.clean_tags(value))
		_refresh_entity_visual(entity)
	if property in ["shape", "scale"]:
		_settle(selection)
	_scene_hierarchy.refresh()
	_refresh_markers()
	_refresh_piece_inspector()


func _edit_selection_number(value: float, field: String) -> void:
	if _syncing_piece or selection.is_empty():
		return
	match field:
		"scale":
			_edit_selection("scale", value / 100.0)
			return
		"mass":
			_edit_selection("mass", value)
			return
	_remember("edit:" + field)
	for entity in selection:
		match field:
			"x":
				entity.position.x = clampf(value, -TableRecord.LIMIT_XZ, TableRecord.LIMIT_XZ)
			"z":
				entity.position.z = clampf(value, -TableRecord.LIMIT_XZ, TableRecord.LIMIT_XZ)
			"y":
				entity.position.y = clampf(value, 0.0, TableRecord.LIMIT_Y)
			"turn":
				entity.rotation_degrees.y = wrapf(value, -180.0, 180.0)
	_refresh_markers()
	_refresh_piece_inspector()


func _on_name_changed(text: String) -> void:
	if _syncing_piece or _selected_entity == null or selection.size() != 1:
		return
	_remember("edit:name")
	_selected_entity.entity_name = text.strip_edges() if text.strip_edges() != "" else tr("Pieza")
	_inspect_target.text = _selected_entity.entity_name
	_scene_hierarchy.refresh()


func _apply_selected_texture() -> void:
	if selection.is_empty():
		_say("Selecciona primero una pieza.")
		return
	var path := ""
	if _asset_browser != null and _asset_browser.selected_image.has("path"):
		path = str(_asset_browser.selected_image.get("path"))
	if path.is_empty():
		_say("Elige primero una imagen de la galería (pestaña Imágenes).")
		return
	_edit_selection("texture", path)
	if selection.size() == 1:
		_selected_entity.entity_name = path.get_file().get_basename().left(TableRecord.MAX_NAME)
		_scene_hierarchy.refresh()
		_refresh_piece_inspector()
	_say(tr("Imagen puesta en «%s».") % _selected_entity.entity_name)


func _apply_selected_back() -> void:
	if selection.is_empty():
		_say("Selecciona primero una pieza.")
		return
	var path := str(_asset_browser.selected_image.get("path", "")) if _asset_browser != null else ""
	if path.is_empty():
		_say("Elige primero una imagen de la galería (pestaña Imágenes).")
		return
	_edit_selection("back", path)
	_say(tr("Reverso puesto en %d piezas.") % selection.size())


# ===================================================================================
# Lógica del juego (blueprints)
# ===================================================================================

func open_logic_editor() -> void:
	if logic_editor == null:
		logic_editor = LogicEditor.new()
		logic_editor.name = "LogicEditor"
		logic_editor.before_change = _remember
		logic_editor.zones_provider = _zone_options
		logic_editor.buttons_provider = _ui_options.bind("button")
		logic_editor.counters_provider = _ui_options.bind("counter")
		logic_editor.elements_provider = _ui_options.bind("")
		logic_editor.closed.connect(func() -> void:
			_say(tr("Lógica: %d bloques. Pulsa «Probar la mesa» para verla funcionar.") % logic.nodes.size())
		)
		add_child(logic_editor)
	logic_editor.open_with(logic)


func _zone_options() -> Array:
	var result: Array = []
	for entity in _scene_hierarchy.entities:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		if visual != null and visual.shape == PieceShapes.ZONE:
			var shown := entity.entity_name if visual.label == "" else "%s (%s)" % [entity.entity_name, visual.label]
			result.append([entity.entity_id, shown])
	return result


func _ui_options(type: String) -> Array:
	var result: Array = []
	for element in ui_layout.elements:
		if type == "" or str(element["type"]) == type:
			result.append([int(element["id"]), str(element["name"]) + (" · " + str(element["text"]) if str(element["text"]) != "" else "")])
	return result


func _start_logic() -> void:
	_logic_vars.clear()
	if logic.is_empty():
		return
	_logic_runner = LogicRunner.new(logic, self)
	_logic_runner.start()
	for id in _logic_runner.errors:
		logic_message(tr("Un bloque GDScript tiene un error: ") + str(_logic_runner.errors[id]))
		break


func _stop_logic() -> void:
	if _logic_runner != null:
		_logic_runner.stop()
		_logic_runner = null


func _fire_logic(type: String, matches := Callable(), data := {}) -> void:
	if _logic_runner != null and not _build_mode:
		_logic_runner.fire(type, matches, data)


func _on_ui_button(id: int) -> void:
	_fire_logic("ev_boton", func(p: Dictionary) -> bool: return int(p["boton"]) == id)


# --- Lo que la lógica (y «mesa» en los bloques GDScript) puede hacer en la mesa -------

## Id de una zona a partir de su id, su nombre o su texto (sin distinguir mayúsculas).
func logic_zone_id(name_or_id: String) -> String:
	var wanted := name_or_id.strip_edges().to_lower()
	if wanted == "":
		return ""
	for entity in _scene_hierarchy.entities:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		if visual == null or visual.shape != PieceShapes.ZONE:
			continue
		if entity.entity_id.to_lower() == wanted or entity.entity_name.to_lower() == wanted or visual.label.to_lower() == wanted:
			return entity.entity_id
	return ""


func logic_zone_names() -> Array:
	return _zone_options().map(func(item: Array) -> String: return _find_piece(item[0]).entity_name)


## Ids de las piezas de una zona (o de toda la mesa sin zona), de arriba abajo; con
## etiqueta, sólo las que la tienen.
func logic_pieces(zone_id: String, tag: String) -> Array:
	zone_id = logic_zone_id(zone_id) if zone_id != "" else ""
	var zone := _find_piece(zone_id) if zone_id != "" else null
	if zone_id != "" and zone == null:
		return []
	var wanted := tag.strip_edges().to_lower()
	var found: Array = []
	for entity in _scene_hierarchy.entities:
		if _is_zone(entity):
			continue
		if wanted != "" and not wanted in entity.tags:
			continue
		if zone != null and not _inside_zone(zone, _piece_transform(entity).origin):
			continue
		found.append(entity)
	found.sort_custom(func(x: PropEntity, y: PropEntity) -> bool: return _piece_transform(x).origin.y > _piece_transform(y).origin.y)
	return found.map(func(entity: PropEntity) -> String: return entity.entity_id)


func _inside_zone(zone: PropEntity, point: Vector3) -> bool:
	var visual := zone.get_component("VisualComponent") as VisualComponent
	var size := PieceShapes.size_of(visual.shape, visual.scale_factor)
	var local: Vector3 = zone.global_transform.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5


## Zona en la que está una pieza ("" si ninguna).
func logic_zone_of(piece_id: String) -> String:
	var entity := _find_piece(piece_id)
	if entity == null:
		return ""
	for zone in _scene_hierarchy.entities:
		var visual := zone.get_component("VisualComponent") as VisualComponent
		if visual != null and visual.shape == PieceShapes.ZONE and _inside_zone(zone, _piece_transform(entity).origin):
			return zone.entity_name
	return ""


func logic_piece_name(piece_id: String) -> String:
	var entity := _find_piece(piece_id)
	return entity.entity_name if entity != null else ""


func logic_piece_tags(piece_id: String) -> Array:
	var entity := _find_piece(piece_id)
	return Array(entity.tags) if entity != null else []


func logic_piece_label(piece_id: String) -> String:
	var entity := _find_piece(piece_id)
	return (entity.get_component("VisualComponent") as VisualComponent).label if entity != null else ""


func logic_piece_color(piece_id: String) -> Color:
	var entity := _find_piece(piece_id)
	return (entity.get_component("VisualComponent") as VisualComponent).color_tint if entity != null else Color.WHITE


func logic_set_label(piece_id: String, text: String) -> void:
	var entity := _find_piece(piece_id)
	if entity == null:
		return
	(entity.get_component("VisualComponent") as VisualComponent).label = text.left(TableRecord.MAX_LABEL)
	_refresh_entity_visual(entity)


## Lleva una pieza a una zona, al siguiente hueco libre (en fila, boca arriba si era carta).
func logic_move(piece_id: String, zone_id: String) -> void:
	var entity := _find_piece(piece_id)
	var zone := _find_piece(logic_zone_id(zone_id))
	if entity == null or zone == null or _is_zone(entity):
		return
	var already := logic_pieces(zone.entity_id, "").filter(func(id: String) -> bool: return id != piece_id).size()
	_place_in_zone(entity, zone, already)


func _place_in_zone(entity: PropEntity, zone: PropEntity, slot: int) -> void:
	var zone_visual := zone.get_component("VisualComponent") as VisualComponent
	var zone_size := PieceShapes.size_of(zone_visual.shape, zone_visual.scale_factor)
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var size := PieceShapes.size_of(visual.shape, visual.scale_factor)
	var step := size.x + 0.04
	var per_row := maxi(1, int(zone_size.x / step))
	var row := slot / per_row
	var col := slot % per_row
	var used := minf(per_row, 1e9) * step
	var local := Vector3(-used * 0.5 + step * (col + 0.5), 0, -zone_size.z * 0.5 + (size.z + 0.04) * (row + 0.5))
	local.z = clampf(local.z, -zone_size.z * 0.5, zone_size.z * 0.5)
	var target: Vector3 = zone.global_transform * local
	var body := entity.get_node_or_null("Body") as RigidBody3D
	var basis := Basis(Vector3.UP, zone.rotation.y)
	if body != null and not _build_mode:
		body.global_transform = Transform3D(basis, target + Vector3.UP * (0.12 + row * 0.02))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = entity.is_locked
		body.sleeping = false
	else:
		entity.position = target
		entity.rotation = Vector3(0, zone.rotation.y, 0)


## Pasa las `count` piezas de arriba de una zona a otra. Devuelve cuántas se movieron.
func logic_deal(count: int, from_zone: String, to_zone: String, tag := "") -> int:
	var to := _find_piece(logic_zone_id(to_zone))
	if to == null:
		return 0
	var source := logic_pieces(from_zone, tag)
	var moving := source.slice(0, clampi(count, 0, source.size()))
	var already := logic_pieces(to.entity_id, "").filter(func(id: String) -> bool: return not id in moving).size()
	for i in moving.size():
		_place_in_zone(_find_piece(moving[i]), to, already + i)
	if not moving.is_empty():
		_play("card")
	return moving.size()


func logic_shuffle(zone_id: String) -> void:
	var zone := _find_piece(logic_zone_id(zone_id))
	if zone != null:
		_shuffle_zone(zone)


func logic_flip(piece_id: String) -> void:
	var entity := _find_piece(piece_id)
	if entity == null or _is_zone(entity):
		return
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null or _build_mode:
		return
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var xform := body.global_transform
	var center := xform * (Vector3.UP * PieceShapes.size_of(visual.shape, visual.scale_factor).y * 0.5)
	xform = Transform3D.IDENTITY.translated(center) * Transform3D(Basis(Vector3.BACK, PI), Vector3.ZERO) * Transform3D.IDENTITY.translated(-center) * xform
	xform.origin.y += 0.1
	body.global_transform = xform
	body.freeze = entity.is_locked
	body.sleeping = false


func _ui_id(name_or_id: Variant) -> int:
	if name_or_id is int or name_or_id is float:
		return int(name_or_id)
	var wanted := str(name_or_id).strip_edges().to_lower()
	for element in ui_layout.elements:
		if str(element["name"]).to_lower() == wanted or str(element["text"]).to_lower() == wanted:
			return int(element["id"])
	return 0


func logic_counter(name_or_id: Variant) -> int:
	return ui_view.counter_value(_ui_id(name_or_id)) if ui_view != null else 0


func logic_set_counter(name_or_id: Variant, value: int) -> void:
	if ui_view != null:
		ui_view.set_counter(_ui_id(name_or_id), value)


func logic_show_element(name_or_id: Variant, visible_now: bool) -> void:
	if ui_view != null:
		ui_view.set_element_visible(_ui_id(name_or_id), visible_now)


func logic_variable(name: String) -> Variant:
	return _logic_vars.get(name.strip_edges().to_lower())


func logic_store(name: String, value: Variant) -> void:
	if _logic_vars.size() < 500 or _logic_vars.has(name.strip_edges().to_lower()):
		_logic_vars[name.strip_edges().to_lower()] = value


## Un aviso grande y breve en el centro de arriba (y en la barra de abajo).
var last_message := ""

func logic_message(text: String) -> void:
	last_message = text.left(300)
	_update_status(last_message)
	if _toast == null:
		_toast = Label.new()
		_toast.name = "LogicToast"
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.add_theme_font_size_override("font_size", 30)
		_toast.add_theme_color_override("font_color", Palette.PAPER)
		_toast.add_theme_color_override("font_outline_color", Palette.INK)
		_toast.add_theme_constant_override("outline_size", 12)
		_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_toast.offset_left = -420
		_toast.offset_right = 420
		_toast.offset_top = 70
		_toast.offset_bottom = 170
		add_child(_toast)
	_toast.text = last_message
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE
	_toast.pivot_offset = Vector2(420, 50)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_toast, "scale", Vector2(1.08, 1.08), 0.08)
		tween.tween_property(_toast, "scale", Vector2.ONE, 0.18)
		tween.tween_interval(2.2)
		tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


# ===================================================================================
# Mazos desde imágenes (sin plantillas ni programas aparte)
# ===================================================================================

## Corta una hoja de cartas en rejilla (`cols` × `rows`, las `count` primeras) y pone el mazo.
func deck_from_sheet(path: String, cols: int, rows: int, count: int) -> Array:
	if path.is_empty():
		_say("Elige primero una imagen de la galería (pestaña Imágenes).")
		return []
	var sheet := Image.load_from_file(path)
	if sheet == null:
		_say("No se pudo abrir la imagen.")
		return []
	cols = clampi(cols, 1, 20)
	rows = clampi(rows, 1, 20)
	count = clampi(count, 1, cols * rows)
	var cell := Vector2i(sheet.get_width() / cols, sheet.get_height() / rows)
	if cell.x < 8 or cell.y < 8:
		_say("Las cartas saldrían demasiado pequeñas: revisa columnas y filas.")
		return []
	var room := TableRecord.MAX_PIECES - _scene_hierarchy.entities.size()
	if count > room:
		_say(tr("No caben tantas piezas (quedan %d).") % room)
		return []
	var paths: Array = []
	var base := path.get_file().get_basename()
	for i in count:
		var region := Rect2i(Vector2i(i % cols, i / cols) * cell, cell)
		var card := sheet.get_region(region)
		var saved := _image_importer.save_image(card, "%s_%02d" % [base, i + 1])
		if saved.get("success") == true:
			paths.append(saved["path"])
	_asset_browser.refresh()
	return _spawn_deck(paths, base)


## Un mazo con una carta por imagen de la galería.
func cards_from_gallery() -> Array:
	var paths: Array = []
	for info in _image_importer.get_imported_images():
		paths.append(info["path"])
	if paths.is_empty():
		_say("La galería está vacía: importa antes alguna imagen.")
		return []
	var room := TableRecord.MAX_PIECES - _scene_hierarchy.entities.size()
	return _spawn_deck(paths.slice(0, room), tr("Carta"))


## Pone una carta por imagen, apiladas en un hueco libre y seleccionadas.
func _spawn_deck(paths: Array, base: String) -> Array:
	if paths.is_empty():
		return []
	_remember("deck")
	var spot := _free_spot()
	var height := _surface_height(spot, [])
	var thickness := PieceShapes.size_of("carta").y
	var made: Array = []
	for i in paths.size():
		var path: String = paths[i]
		var piece := {
			"id": "", "name": "%s %d" % [base.left(30), i + 1], "shape": "carta", "color": Palette.PAPER.to_html(true),
			"texture": path, "label": "", "pattern": "liso", "cells": 8, "finish": "brillo", "back": "", "notes": "",
			"pos": Vector3(spot.x, height + thickness * i, spot.z), "rot": Vector3.ZERO, "scale": 1.0,
			"locked": false, "mass": 0.2, "bounce": 0.05,
		}
		made.append(_make_piece(piece))
	select_pieces(made)
	_bump(made)
	_play("card")
	_say(tr("Mazo de %d cartas. Elige una imagen y pulsa «Poner reverso» para darles dorso.") % made.size())
	return made


# ===================================================================================
# Exportar e importar el juego entero (mesa, interfaz e imágenes en un solo archivo)
# ===================================================================================

const PACKAGE_FORMAT := "tablerama-juego"
const PACKAGE_VERSION := 1
const PACKAGE_MAX_BYTES := 64 * 1024 * 1024
const EXPORT_FOLDER := "user://creador/exportados/"


func _open_export_dialog() -> void:
	_open_package_dialog(true)


func _open_import_dialog() -> void:
	_open_package_dialog(false)


func _open_package_dialog(saving: bool) -> void:
	DirAccess.make_dir_recursive_absolute(EXPORT_FOLDER)
	if _package_dialog != null:
		_package_dialog.queue_free()
	_package_dialog = FileDialog.new()
	_package_dialog.name = "PackageDialog"
	_package_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_package_dialog.use_native_dialog = true
	_package_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	_package_dialog.title = tr("Exportar juego") if saving else tr("Importar juego")
	_package_dialog.filters = PackedStringArray(["*.tablerama ; Juego de Tablerama"])
	_package_dialog.current_dir = ProjectSettings.globalize_path(EXPORT_FOLDER)
	if saving:
		_package_dialog.current_file = "mi_juego.tablerama"
	_package_dialog.file_selected.connect(func(path: String) -> void:
		if saving:
			export_game(path)
		else:
			import_game(path)
	)
	add_child(_package_dialog)
	_package_dialog.popup_centered_ratio(0.7)


## Escribe el juego entero en un archivo: mesa, interfaz e imágenes dentro (no depende de
## enlaces a webs que luego se rompen).
func export_game(path: String) -> bool:
	if not path.ends_with(".tablerama"):
		path += ".tablerama"
	var table := table_state()
	var ui := ui_layout.to_record()
	var images := {}
	var used: Array = []
	for piece in table["pieces"]:
		for key in ["texture", "back"]:
			if str(piece[key]) != "":
				used.append(str(piece[key]))
	for element in ui.get("elements", []):
		if element is Dictionary and str(element.get("image", "")) != "":
			used.append(str(element["image"]))
	for image_path in used:
		if images.has(image_path) or not FileAccess.file_exists(image_path):
			continue
		images[image_path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(image_path))
	var package := {
		"format": PACKAGE_FORMAT,
		"version": PACKAGE_VERSION,
		"table": table,
		"ui": ui,
		"images": images,
	}
	var text := JSON.stringify(package)
	if text.length() > PACKAGE_MAX_BYTES:
		_say("El juego es demasiado grande para exportarlo (más de 64 MB de imágenes).")
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_say("No se pudo escribir el archivo.")
		return false
	file.store_string(text)
	file.close()
	_say(tr("Juego exportado: %s (%d piezas, %d imágenes).") % [path.get_file(), (table["pieces"] as Array).size(), images.size()])
	return true


## Abre un juego exportado: guarda sus imágenes en la galería y pone su mesa e interfaz.
## Si algo no cuadra, no se toca nada de lo actual.
func import_game(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_say("No se encuentra el archivo.")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > PACKAGE_MAX_BYTES:
		_say("El archivo no se puede abrir o es demasiado grande.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("format") != PACKAGE_FORMAT or not parsed.get("images") is Dictionary:
		_say("Ese archivo no es un juego de Tablerama.")
		return false
	if TableRecord.pieces_of(parsed.get("table")) == null:
		_say("El juego tiene piezas que no son válidas; no se ha cargado.")
		return false
	# Las imágenes vuelven a la galería con nombres nuevos; las rutas se corrigen.
	var remap := {}
	for old_path in parsed["images"]:
		var bytes := Marshalls.base64_to_raw(str(parsed["images"][old_path]))
		var image := Image.new()
		var ok := image.load_png_from_buffer(bytes) == OK
		if not ok:
			ok = image.load_jpg_from_buffer(bytes) == OK
		if not ok:
			ok = image.load_webp_from_buffer(bytes) == OK
		if not ok:
			continue
		var saved := _image_importer.save_image(image, str(old_path).get_file())
		if saved.get("success") == true:
			remap[str(old_path)] = saved["path"]
	var table: Dictionary = (parsed["table"] as Dictionary).duplicate(true)
	for piece in table["pieces"]:
		if piece is Dictionary:
			for key in ["texture", "back"]:
				var image_path := str(piece.get(key, ""))
				if image_path != "":
					piece[key] = remap.get(image_path, "")
	var pieces: Variant = TableRecord.pieces_of(table)
	if pieces == null:
		_say("El juego tiene piezas que no son válidas; no se ha cargado.")
		return false
	var ui_record: Variant = parsed.get("ui")
	if ui_record is Dictionary:
		ui_record = (ui_record as Dictionary).duplicate(true)
		for element in ui_record.get("elements", []):
			if element is Dictionary and str(element.get("image", "")) != "":
				element["image"] = remap.get(str(element["image"]), "")
	var layout := UiLayout.from_record(ui_record) if ui_record is Dictionary else null
	var imported_logic := LogicGraph.from_record((parsed["table"] as Dictionary).get("logic"))
	if imported_logic == null:
		_say("La lógica del juego no es válida; no se ha cargado.")
		return false
	_remember("import")
	_rebuild_table(pieces)
	logic = imported_logic
	if logic.has_code():
		_say("Este juego trae bloques GDScript: se ejecutan aislados, sin acceso a tus archivos.")
	if layout != null:
		ui_layout = layout
		ui_view.show_layout(ui_layout, _build_mode)
		ui_view.select(0)
	_asset_browser.refresh()
	focus_all()
	var note := tr(" Trae bloques GDScript, que se ejecutan aislados.") if logic.has_code() else ""
	_say(tr("Juego importado: %d piezas y %d imágenes.") % [(pieces as Array).size(), remap.size()] + note)
	return true


## Gira la selección sobre su eje vertical.
func rotate_selection(degrees: float) -> void:
	if selection.is_empty():
		return
	_remember("rotate")
	for entity in selection:
		var turn := entity.rotation_degrees.y + degrees
		entity.rotation_degrees.y = wrapf(snappedf(turn, absf(degrees)) if snap else turn, -180.0, 180.0)
	_bump(selection)
	_refresh_markers()
	_refresh_piece_inspector()


## Da la vuelta a la selección (cartas boca abajo, fichas del revés).
func flip_selection() -> void:
	if selection.is_empty():
		return
	_remember("flip")
	for entity in selection:
		entity.rotation_degrees.z = 180.0 if absf(entity.rotation_degrees.z) < 90.0 else 0.0
		# La pieza volteada sigue apoyada: el giro se hace sobre su centro.
		var visual := entity.get_component("VisualComponent") as VisualComponent
		var height := PieceShapes.size_of(visual.shape, visual.scale_factor).y
		entity.position.y += height if entity.rotation_degrees.z > 90.0 else -height
		entity.position.y = maxf(entity.position.y, 0.0)
	_bump(selection)
	_play("card")
	_refresh_markers()
	_refresh_piece_inspector()


func nudge_selection(offset: Vector3) -> void:
	if selection.is_empty():
		return
	_remember("nudge")
	for entity in selection:
		var target := _clamp_to_table(entity.position + Vector3(offset.x, 0, offset.z))
		target.y = clampf(entity.position.y + offset.y, 0.0, TableRecord.LIMIT_Y)
		entity.position = target
	_refresh_markers()
	_refresh_piece_inspector()


func scale_selection(factor: float) -> void:
	if selection.is_empty():
		return
	var visual := _selected_entity.get_component("VisualComponent") as VisualComponent
	_edit_selection("scale", snappedf(visual.scale_factor * factor, 0.05))
	_bump(selection)


## Las piezas en fila a lo largo de X, con su hueco, en la Z media.
func arrange_row_selection() -> void:
	if selection.size() < 2:
		return
	_remember("arrange")
	var ordered := selection.duplicate()
	ordered.sort_custom(func(a: PropEntity, b: PropEntity) -> bool: return a.position.x < b.position.x)
	var widths: Array[float] = []
	var total := 0.0
	var center := Vector3.ZERO
	for entity in ordered:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		var size := PieceShapes.size_of(visual.shape, visual.scale_factor)
		widths.append(size.x)
		total += size.x
		center += entity.position
	center /= ordered.size()
	var gap := 0.08
	total += gap * (ordered.size() - 1)
	var x := center.x - total * 0.5
	for i in ordered.size():
		var entity: PropEntity = ordered[i]
		entity.position = _clamp_to_table(Vector3(x + widths[i] * 0.5, 0, center.z))
		x += widths[i] + gap
	_settle(ordered)
	_bump(ordered)
	_play("drop")
	_say("En fila.")


## Una pila sobre la pieza principal (mazos de cartas, torres de fichas).
func stack_selection() -> void:
	if selection.size() < 2:
		return
	_remember("arrange")
	var base := selection[0]
	var height := base.position.y
	for entity in selection:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		entity.position = Vector3(base.position.x, height, base.position.z)
		entity.rotation_degrees = Vector3(0, base.rotation_degrees.y, 0)
		height += PieceShapes.size_of(visual.shape, visual.scale_factor).y
	_bump(selection)
	_play("card")
	_say(tr("Apiladas: %d.") % selection.size())


## Lleva el grupo seleccionado al centro de la mesa sin deshacer su forma.
func center_selection() -> void:
	if selection.is_empty():
		return
	_remember("arrange")
	var center := Vector3.ZERO
	for entity in selection:
		center += entity.position
	center /= selection.size()
	var shift := Vector3(-center.x, 0, -center.z)
	if snap:
		shift = Vector3(snappedf(shift.x, GRID_STEP), 0, snappedf(shift.z, GRID_STEP))
	for entity in selection:
		entity.position += shift
	_bump(selection)
	_say("Centrado.")


# ===================================================================================
# Historial, guardado y carga de la mesa
# ===================================================================================

func table_state() -> Dictionary:
	var state := TableRecord.table_record(_scene_hierarchy.entities)
	state["logic"] = logic.to_record()
	return state


## Pone la lógica guardada en `state` (o una vacía); la vista de bloques, si está abierta, se rehace.
func _apply_logic(record: Variant) -> void:
	var loaded := LogicGraph.from_record(record)
	logic = loaded if loaded != null else LogicGraph.new()
	if logic_editor != null and logic_editor.visible:
		logic_editor.open_with(logic)


## Foto para el historial: la mesa y qué estaba seleccionado.
func _snapshot() -> Dictionary:
	var state := table_state()
	state["selection"] = selection.map(func(entity: PropEntity) -> String: return entity.entity_id)
	return state


## Apunta el estado de antes de un cambio para poder deshacerlo.
func _remember(key: String) -> void:
	# Teclear un número, girar o empujar con las flechas varias veces seguidas se deshace de una vez.
	var merge := key.begins_with("edit:") or key in ["rotate", "nudge"]
	history.record(_snapshot(), key if merge else "")
	_update_history_buttons.call_deferred()


func undo() -> void:
	var state := history.undo(_snapshot())
	if state.is_empty():
		_say("No hay nada que deshacer.")
		return
	_restore(state)
	_say("Deshecho.")


func redo() -> void:
	var state := history.redo(_snapshot())
	if state.is_empty():
		_say("No hay nada que rehacer.")
		return
	_restore(state)
	_say("Rehecho.")


## Pone la mesa como en `state`, conservando la selección si las piezas siguen ahí.
func _restore(state: Dictionary) -> void:
	var pieces: Variant = TableRecord.pieces_of(state)
	if pieces == null:
		return
	var keep: Array = state.get("selection", []) if state.get("selection") is Array else []
	_rebuild_table(pieces)
	_apply_logic(state.get("logic"))
	var reselect: Array = []
	for id in keep:
		var entity := _find_piece(str(id))
		if entity != null:
			reselect.append(entity)
	select_pieces(reselect)
	_update_history_buttons()


func _rebuild_table(pieces: Array) -> void:
	select_pieces([])
	for entity in _scene_hierarchy.entities.duplicate():
		_scene_hierarchy.remove_entity(entity)
		_entities_root.remove_child(entity)
		entity.queue_free()
	for piece in pieces:
		_make_piece(piece)
	_update_status()


func save_table() -> bool:
	DirAccess.make_dir_recursive_absolute(table_save_path.get_base_dir())
	var ok: bool = SAVE_STORE.write(table_save_path, JSON.stringify(table_state()), TABLE_SAVE_BYTES, _decode_table)
	_say(tr("Mesa guardada: %d piezas.") % _scene_hierarchy.entities.size() if ok else "No se pudo guardar la mesa.")
	return ok


func load_table() -> bool:
	var loaded: Dictionary = SAVE_STORE.read_validated(table_save_path, TABLE_SAVE_BYTES, _decode_table)
	if loaded.is_empty():
		_say("No hay mesa guardada, o el archivo no es válido; se conserva la actual.")
		return false
	_remember("load")
	_rebuild_table(TableRecord.pieces_of(loaded["record"]))
	_apply_logic(loaded["record"].get("logic"))
	_say(tr("Mesa cargada: %d piezas.") % _scene_hierarchy.entities.size())
	return true


func clear_table() -> void:
	if _scene_hierarchy.entities.is_empty():
		return
	_remember("clear")
	_rebuild_table([])
	_say("Mesa vacía. Ctrl+Z la recupera.")


static func _decode_table(record: Variant) -> Variant:
	if TableRecord.pieces_of(record) == null or LogicGraph.from_record(record.get("logic")) == null:
		return null
	return record


func _update_history_buttons() -> void:
	if _undo_button != null:
		_undo_button.disabled = not history.can_undo()
		_redo_button.disabled = not history.can_redo()


func set_snap(on: bool) -> void:
	snap = on
	if _snap_check != null:
		_snap_check.set_pressed_no_signal(on)
	if _grid != null:
		_grid.visible = on and _build_mode
	_update_status()


# ===================================================================================
# Aspecto y física de cada pieza
# ===================================================================================

# Cuerpo visible de la pieza: su forma (con su color, acabado, imagen o dibujo, texto y,
# en los dados, sus puntos) y su cuerpo físico.
func _refresh_entity_visual(entity: PropEntity) -> void:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	if visual == null:
		visual = VisualComponent.new()
		entity.add_component(visual)
	var shape_name := PieceShapes.valid(visual.shape)
	var size := PieceShapes.size_of(shape_name, visual.scale_factor)
	var zone := shape_name in PieceShapes.MARKERS
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null:
		body = RigidBody3D.new()
		body.name = "Body"
		body.freeze = _build_mode
		# Congelada se mueve como cinemática: al agarrarla en la prueba empuja a las demás.
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		# Capa 2: piezas. Chocan con la mesa (1) y entre sí.
		body.collision_layer = 2
		body.collision_mask = 3
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		body.add_child(shape)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		body.add_child(mesh_instance)
		entity.add_child(body)
	var shape_node := body.get_node("Shape") as CollisionShape3D
	shape_node.shape = PieceShapes.collision_for(shape_name, visual.scale_factor)
	shape_node.position.y = size.y * 0.5
	# Las zonas son marcas en la mesa: no chocan con nada.
	shape_node.disabled = zone
	var mesh_node := body.get_node("Mesh") as MeshInstance3D
	mesh_node.mesh = PieceShapes.mesh_for(shape_name, visual.scale_factor)
	mesh_node.position.y = size.y * 0.5
	for extra in ["Face", "Back", "Label", "Pips"]:
		var old := mesh_node.get_node_or_null(extra)
		if old != null:
			mesh_node.remove_child(old)
			old.queue_free()

	var texture: Texture2D = null
	if not visual.texture_path.is_empty():
		texture = _image_importer.load_texture(visual.texture_path)
	var pattern := PieceLooks.pattern_texture(visual.pattern, visual.cells, visual.color_tint) if shape_name in PieceShapes.FLAT else null
	var material := StandardMaterial3D.new()
	material.albedo_color = visual.color_tint
	if zone:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(visual.color_tint, 0.38)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif texture != null and not shape_name in PieceShapes.FLAT:
		# Dados, bloques y peones: la imagen envuelve la pieza.
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / maxf(size.x, 0.01)
	elif visual.finish == "madera":
		material.albedo_texture = PieceLooks.wood_texture()
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 1.6
	mesh_node.material_override = material
	_style_piece_material(mesh_node, material, visual.finish)

	# La cara de arriba de las piezas planas: la imagen o el dibujo, enteros y sin deformar.
	var face_texture: Texture2D = texture if texture != null and shape_name in PieceShapes.FLAT else pattern
	if face_texture != null:
		var face := MeshInstance3D.new()
		face.name = "Face"
		var quad := PlaneMesh.new()
		var inset := minf(size.x, size.z) * (0.03 if shape_name == "tablero" else 0.08)
		quad.size = Vector2(size.x - inset * 2.0, size.z - inset * 2.0)
		face.mesh = quad
		var face_material := StandardMaterial3D.new()
		face_material.albedo_texture = face_texture
		face_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		face_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		face_material.roughness = 1.0
		face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		face_material.set_meta(&"toon_style_applied", true)
		face.material_override = face_material
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.position.y = size.y * 0.5 + 0.0015
		mesh_node.add_child(face)

	# El reverso (cartas, losetas): se ve al voltear la pieza.
	if shape_name in PieceShapes.FLAT and visual.back_path != "":
		var back_texture := _image_importer.load_texture(visual.back_path)
		if back_texture != null:
			var back := MeshInstance3D.new()
			back.name = "Back"
			var back_quad := PlaneMesh.new()
			var back_inset := minf(size.x, size.z) * 0.08
			back_quad.size = Vector2(size.x - back_inset * 2.0, size.z - back_inset * 2.0)
			back.mesh = back_quad
			var back_material := StandardMaterial3D.new()
			back_material.albedo_texture = back_texture
			back_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			back_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			back_material.roughness = 1.0
			back_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			back_material.set_meta(&"toon_style_applied", true)
			back.material_override = back_material
			back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			back.position.y = -size.y * 0.5 - 0.0015
			back.rotation_degrees.z = 180
			mesh_node.add_child(back)

	if visual.label.strip_edges() != "":
		var label := Label3D.new()
		label.name = "Label"
		label.text = visual.label
		label.font_size = 96
		label.outline_size = 18
		var under := visual.color_tint if face_texture == null else Palette.PAPER
		label.modulate = PieceLooks.ink_for(under)
		label.outline_modulate = Color(PieceLooks.ink_for(label.modulate), 0.0 if zone else 0.35)
		var room := minf(size.x, size.z) if not zone else size.z * 0.6
		var letters := maxf(1.0, float(visual.label.length()))
		label.pixel_size = clampf(room * 0.7 / (96.0 * maxf(1.0, letters * 0.55)), 0.0004, 0.01)
		label.rotation_degrees.x = -90
		label.position.y = size.y * 0.5 + 0.003
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		mesh_node.add_child(label)

	if shape_name == "dado" and texture == null:
		PieceLooks.add_pips(mesh_node, size.x, PieceLooks.ink_for(visual.color_tint))

	# Los dados ruedan con gracia y se paran pronto; el resto se asienta sin patinar.
	body.linear_damp = 0.8 if shape_name == "dado" else 0.4
	body.angular_damp = 1.6 if shape_name == "dado" else 0.8
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	if physics != null:
		body.mass = physics.mass
		var physics_material := PhysicsMaterial.new()
		physics_material.bounce = physics.bounce
		physics_material.friction = physics.friction
		body.physics_material_override = physics_material


## Estilo de juguete (como el resto del juego) y, encima, el acabado elegido.
func _style_piece_material(mesh_node: MeshInstance3D, material: StandardMaterial3D, finish: String) -> void:
	var toon := get_node_or_null("/root/ToonStyle")
	if toon != null and toon.has_method("_style_mesh"):
		toon._style_mesh(mesh_node)
	material.set_meta(&"toon_style_applied", true)
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	match finish:
		"plastico":
			material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			material.roughness = 0.38
		"brillo":
			material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			material.roughness = 0.2
			material.clearcoat_enabled = true
			material.clearcoat = 0.8
		"metal":
			material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			material.metallic = 0.85
			material.roughness = 0.32
		_:
			material.roughness = 1.0


## Zonas y anclajes: marcas en la mesa que no chocan ni sostienen piezas.
func _is_zone(entity: PropEntity) -> bool:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	return visual != null and visual.shape in PieceShapes.MARKERS


func _is_anchor(entity: PropEntity) -> bool:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	return visual != null and visual.shape == PieceShapes.ANCHOR


## Anclaje más cercano a `at` (en planta) dentro de su radio, o null.
func _anchor_near(at: Vector3, ignore: Array = []) -> PropEntity:
	var best: PropEntity = null
	var best_distance := PieceShapes.ANCHOR_RADIUS
	for entity in _scene_hierarchy.entities:
		if not _is_anchor(entity) or ignore.has(entity):
			continue
		var distance := Vector2(entity.position.x - at.x, entity.position.z - at.z).length()
		if distance <= best_distance:
			best_distance = distance
			best = entity
	return best


func _set_entity_physics(entity: PropEntity, active: bool) -> void:
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null:
		return
	# Las piezas fijas (tableros, decorados) no se mueven tampoco al probar.
	body.freeze = not active or entity.is_locked or _is_zone(entity)
	if not active:
		# Al volver a editar, cada pieza regresa a donde se colocó.
		body.transform = Transform3D.IDENTITY
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


## Aparece con un pequeño salto.
func _pop_in(entity: PropEntity) -> void:
	var mesh := entity.get_node_or_null("Body/Mesh") as Node3D
	if mesh == null or not is_inside_tree():
		return
	mesh.scale = Vector3.ONE * 0.4
	var tween := create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Aplastar y estirar al soltar o girar: el cambio se nota.
func _bump(entities: Array) -> void:
	if not is_inside_tree():
		return
	for entity in entities:
		var mesh := (entity as Node).get_node_or_null("Body/Mesh") as Node3D
		if mesh == null:
			continue
		var tween := create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.08, 0.86, 1.08), 0.06)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play(sound: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(sound)


func _refresh_markers() -> void:
	if _markers_root == null:
		return
	var markers: Array = _markers_root.get_children().filter(func(node: Node) -> bool: return node != _hover_marker)
	while markers.size() < selection.size():
		markers.append(_make_marker(Palette.SUN))
	for i in markers.size():
		var marker: MeshInstance3D = markers[i]
		marker.visible = i < selection.size()
		if marker.visible:
			_fit_marker(marker, selection[i])
	_hover_marker.visible = _hovered != null and is_instance_valid(_hovered) and not selection.has(_hovered) and _drag.is_empty()
	if _hover_marker.visible:
		_fit_marker(_hover_marker, _hovered)


func _fit_marker(marker: MeshInstance3D, entity: PropEntity) -> void:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var size := PieceShapes.size_of(visual.shape, visual.scale_factor) + Vector3.ONE * 0.06
	var local := Transform3D(Basis.from_scale(size), Vector3(0, size.y * 0.5 - 0.03, 0))
	marker.global_transform = entity.global_transform * local


# ===================================================================================
# Geometría: qué pieza hay bajo el ratón y a qué altura se apoya algo
# ===================================================================================

func _ray(screen: Vector2) -> Array:
	return [_camera.project_ray_origin(screen), _camera.project_ray_normal(screen)]


## Pieza más cercana bajo este punto de la pantalla (o null).
func piece_at(screen: Vector2) -> PropEntity:
	var ray := _ray(screen)
	var best: PropEntity = null
	var best_distance := INF
	for entity in _scene_hierarchy.entities:
		var hit: Variant = _hit_piece(entity, ray[0], ray[1])
		if hit != null:
			var distance := (ray[0] as Vector3).distance_to(hit)
			# Una zona sólo se elige si no hay ninguna pieza encima.
			if _is_zone(entity):
				distance += 100.0
			if distance < best_distance:
				best_distance = distance
				best = entity
	return best


func _hit_piece(entity: PropEntity, from: Vector3, direction: Vector3) -> Variant:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var size := PieceShapes.size_of(visual.shape, visual.scale_factor)
	var xform := _piece_transform(entity)
	var inverse := xform.affine_inverse()
	var local_from := inverse * from
	var local_dir := (inverse.basis * direction).normalized()
	var box := AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size)
	var hit: Variant = box.intersects_ray(local_from, local_dir)
	return xform * (hit as Vector3) if hit != null else null


## Dónde está la pieza de verdad: al probar, su cuerpo físico se ha movido de su sitio.
func _piece_transform(entity: PropEntity) -> Transform3D:
	var body := entity.get_node_or_null("Body") as Node3D
	return body.global_transform if body != null and body.is_inside_tree() else entity.global_transform


## Punto de la mesa (plano y = height) bajo el ratón.
func table_point(screen: Vector2, height := 0.0) -> Variant:
	var ray := _ray(screen)
	return Plane(Vector3.UP, height).intersects_ray(ray[0], ray[1])


## Altura a la que se apoya algo en (x, z): la mesa o la cara de arriba de otra pieza.
func _surface_height(at: Vector3, ignore: Array) -> float:
	var top := 0.0
	var from := Vector3(at.x, TableRecord.LIMIT_Y + 1.0, at.z)
	for entity in _scene_hierarchy.entities:
		if ignore.has(entity) or _is_zone(entity):
			continue
		var hit: Variant = _hit_piece(entity, from, Vector3.DOWN)
		if hit != null:
			top = maxf(top, (hit as Vector3).y)
	return top


## Asienta las piezas sobre lo que tengan debajo (tras cambiar su forma o moverlas).
func _settle(entities: Array) -> void:
	for entity in entities:
		entity.position.y = _surface_height(entity.position, entities) + _rest_offset(entity)


func _clamp_to_table(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	if flat.length() > TABLE_RADIUS:
		flat = flat.normalized() * TABLE_RADIUS
	return Vector3(flat.x, point.y, flat.y)


# ===================================================================================
# Ratón y teclado
# ===================================================================================

func _gui_input(event: InputEvent) -> void:
	if logic_editor != null and logic_editor.visible:
		return
	if not _build_mode:
		_playtest_input(event)
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var additive := event.ctrl_pressed or event.shift_pressed or event.meta_pressed
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					focus_selection()
					accept_event()
					return
				get_viewport().gui_release_focus()
				var piece := piece_at(event.position)
				if ui_view != null and ui_view.selected_id != 0:
					ui_view.select(0)
				if piece == null:
					if not additive:
						select_pieces([])
					_drag = {"kind": "box", "start": event.position, "additive": additive, "base": selection.duplicate()}
				else:
					if additive:
						_toggle_in_selection(piece)
						if not selection.has(piece):
							accept_event()
							return
					elif not selection.has(piece):
						select_pieces([piece])
					else:
						_selected_entity = piece
						_refresh_piece_inspector()
					_begin_move(event.position, piece, event.alt_pressed)
				accept_event()
			else:
				_end_drag()
				accept_event()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				var pan := event.button_index == MOUSE_BUTTON_MIDDLE or event.shift_pressed
				_drag = {"kind": "pan" if pan else "orbit", "last": event.position}
			elif _drag.get("kind", "") in ["orbit", "pan"]:
				_drag = {}
			accept_event()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not event.pressed:
				return
			var up := event.button_index == MOUSE_BUTTON_WHEEL_UP
			if _drag.get("kind", "") == "move":
				# Con piezas agarradas, la rueda las gira.
				rotate_selection(ROTATE_STEP if up else -ROTATE_STEP)
			else:
				zoom_camera(0.88 if up else 1.14)
			accept_event()


func _begin_move(screen: Vector2, piece: PropEntity, clone: bool) -> void:
	var grab: Variant = table_point(screen, piece.position.y)
	if grab == null:
		return
	if piece.is_locked:
		_say(tr("«%s» está fija: desmarca «Fija» en el inspector para moverla.") % piece.entity_name)
		_drag = {}
		return
	_drag = {
		"kind": "move", "start": screen, "grab": grab, "piece": piece, "moved": false,
		"clone": clone, "before": _snapshot(),
		"origins": selection.map(func(entity: PropEntity) -> Vector3: return entity.position),
	}


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	var kind: String = _drag.get("kind", "")
	match kind:
		"move":
			_drag_move(event.position)
		"box":
			var rect := Rect2(_drag["start"], Vector2.ZERO).expand(event.position)
			_marquee.visible = rect.size.length() > PICK_SLOP
			_marquee.position = rect.position
			_marquee.size = rect.size
			if _marquee.visible:
				_select_in_box(rect)
		"orbit":
			var delta: Vector2 = event.position - _drag["last"]
			_drag["last"] = event.position
			orbit_camera(-delta.x * 0.4, delta.y * 0.3)
		"pan":
			var delta: Vector2 = event.position - _drag["last"]
			_drag["last"] = event.position
			pan_camera(delta)
		_:
			var piece := piece_at(event.position)
			if piece != _hovered:
				_hovered = piece
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if piece != null else Control.CURSOR_ARROW
				_refresh_markers()
				_show_hover_info(piece)


func _drag_move(screen: Vector2) -> void:
	if not _drag["moved"]:
		if screen.distance_to(_drag["start"]) < PICK_SLOP:
			return
		_drag["moved"] = true
		history.record(_drag["before"])
		_update_history_buttons()
		if _drag["clone"]:
			# Alt + arrastrar: se arrastra una copia y el original se queda.
			var lead := selection.find(_drag["piece"])
			var copies := _paste_records(_records_of(selection), Vector3.ZERO)
			_drag["piece"] = copies[lead]
			_drag["origins"] = selection.map(func(entity: PropEntity) -> Vector3: return entity.position)
		_play("grab")
	var point: Variant = table_point(screen, (_drag["grab"] as Vector3).y)
	if point == null:
		return
	var lead_index := selection.find(_drag["piece"])
	var lead_origin: Vector3 = _drag["origins"][lead_index]
	var shift: Vector3 = (point as Vector3) - (_drag["grab"] as Vector3)
	var target := lead_origin + Vector3(shift.x, 0, shift.z)
	if snap and not Input.is_key_pressed(KEY_SHIFT):
		target = Vector3(snappedf(target.x, GRID_STEP), target.y, snappedf(target.z, GRID_STEP))
	target = _clamp_to_table(target)
	# Cerca de un anclaje, la pieza se pega a él y toma su giro.
	var lead_piece: PropEntity = _drag["piece"]
	var anchor := _anchor_near(target, selection) if not _is_zone(lead_piece) else null
	if anchor != null:
		target = Vector3(anchor.position.x, target.y, anchor.position.z)
		if selection.size() == 1:
			lead_piece.rotation_degrees.y = anchor.rotation_degrees.y
	var move := target - lead_origin
	# El grupo viaja entero y se posa donde se posa la pieza que se agarró.
	var lead_entity: PropEntity = _drag["piece"]
	var base := _surface_height(target, selection) + _rest_offset(lead_entity)
	for i in selection.size():
		var entity: PropEntity = selection[i]
		var origin: Vector3 = _drag["origins"][i]
		var goal := _clamp_to_table(Vector3(origin.x + move.x, 0, origin.z + move.z))
		goal.y = maxf(base + origin.y - lead_origin.y, 0.0)
		entity.position = goal
	_refresh_markers()
	_refresh_piece_inspector()


## Una pieza volteada gira sobre su origen: para seguir apoyada sube su propio alto.
func _rest_offset(entity: PropEntity) -> float:
	if absf(entity.rotation_degrees.z) < 90.0 and absf(entity.rotation_degrees.x) < 90.0:
		return 0.0
	var visual := entity.get_component("VisualComponent") as VisualComponent
	return PieceShapes.size_of(visual.shape, visual.scale_factor).y


func _end_drag() -> void:
	var kind: String = _drag.get("kind", "")
	if kind == "move" and _drag.get("moved", false):
		_bump(selection)
		_play("drop")
		_say(tr("Colocada en (%.1f, %.1f).") % [_selected_entity.position.x, _selected_entity.position.z] if selection.size() == 1 else tr("%d piezas movidas.") % selection.size())
	_marquee.visible = false
	_drag = {}
	_refresh_markers()


func _select_in_box(rect: Rect2) -> void:
	var chosen: Array = (_drag["base"] as Array).duplicate() if _drag.get("additive", false) else []
	for entity in _scene_hierarchy.entities:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		var center: Vector3 = entity.global_position + Vector3.UP * PieceShapes.size_of(visual.shape, visual.scale_factor).y * 0.5
		if _camera.is_position_behind(center):
			continue
		if rect.has_point(_camera.unproject_position(center)) and not chosen.has(entity):
			chosen.append(entity)
	select_pieces(chosen)


func _unhandled_input(event: InputEvent) -> void:
	# Con los bloques abiertos, sus atajos son suyos (Supr borra bloques, no piezas).
	if logic_editor != null and logic_editor.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _build_mode:
			_toggle_mode()
			return
		if not selection.is_empty():
			select_pieces([])
			return
		_back_to_menu()
		return
	if not event is InputEventKey or not event.pressed:
		return
	if not _build_mode:
		var play_key := event as InputEventKey
		match play_key.keycode:
			KEY_R:
				roll_dice()
			KEY_F:
				flip_in_play()
			KEY_HOME:
				reset_camera()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var digit := str(play_key.keycode - KEY_0)
				_fire_logic("ev_tecla", func(p: Dictionary) -> bool: return str(p["tecla"]) == digit)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var key := event as InputEventKey
	var ctrl := key.ctrl_pressed or key.meta_pressed
	var handled := true
	match key.keycode:
		KEY_Z when ctrl:
			if key.shift_pressed:
				redo()
			else:
				undo()
		KEY_Y when ctrl:
			redo()
		KEY_D when ctrl:
			duplicate_selection()
		KEY_C when ctrl:
			copy_selection()
		KEY_V when ctrl:
			paste_clipboard()
		KEY_A when ctrl:
			select_all()
		KEY_S when ctrl:
			save_table()
		KEY_DELETE, KEY_BACKSPACE:
			_remove_selected_entity()
		KEY_Q:
			rotate_selection(-(5.0 if key.shift_pressed else ROTATE_STEP))
		KEY_E:
			rotate_selection(5.0 if key.shift_pressed else ROTATE_STEP)
		KEY_F:
			flip_selection()
		KEY_G:
			set_snap(not snap)
			_say("Imán activado" if snap else "Imán desactivado")
		KEY_C:
			focus_selection()
		KEY_HOME:
			reset_camera()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var step := GRID_STEP * (5.0 if key.shift_pressed else 1.0)
			var screen_dir := {KEY_LEFT: Vector2(-1, 0), KEY_RIGHT: Vector2(1, 0), KEY_UP: Vector2(0, -1), KEY_DOWN: Vector2(0, 1)}[key.keycode] as Vector2
			nudge_selection(_screen_to_table_dir(screen_dir) * step)
		KEY_PAGEUP:
			nudge_selection(Vector3(0, GRID_STEP * 0.5, 0))
		KEY_PAGEDOWN:
			nudge_selection(Vector3(0, -GRID_STEP * 0.5, 0))
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			scale_selection(1.1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			scale_selection(1.0 / 1.1)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Las flechas mueven según se ve la mesa: «arriba» es hacia el fondo de la pantalla.
func _screen_to_table_dir(screen_dir: Vector2) -> Vector3:
	var yaw := deg_to_rad(float(_orbit_goal["yaw"]))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var dir := right * screen_dir.x - forward * screen_dir.y
	# Ejes limpios: con el imán, el paso cae siempre en la cuadrícula.
	if absf(dir.x) >= absf(dir.z):
		return Vector3(signf(dir.x), 0, 0)
	return Vector3(0, 0, signf(dir.z))


# ===================================================================================
# Modo prueba: agarrar y lanzar piezas, tirar dados, voltear
# ===================================================================================

## Pieza agarrada al probar: {"entity", "body", "height", "velocity", "last"}.
var _held := {}
## Dados lanzados que aún ruedan.
var _rolling: Array = []
var _roll_started := 0

func _playtest_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					if button.double_click:
						var die := piece_at(button.position)
						if die != null and _shape_of(die) == "dado":
							roll_dice([die])
							accept_event()
							return
					_grab_in_play(button.position)
				else:
					_release_in_play()
				accept_event()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if button.pressed:
					var pan := button.button_index == MOUSE_BUTTON_MIDDLE or button.shift_pressed
					_drag = {"kind": "pan" if pan else "orbit", "last": button.position}
				else:
					_drag = {}
				accept_event()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if not button.pressed:
					return
				var up := button.button_index == MOUSE_BUTTON_WHEEL_UP
				if not _held.is_empty():
					var body: RigidBody3D = _held["body"]
					body.rotate_y(deg_to_rad(ROTATE_STEP if up else -ROTATE_STEP))
				else:
					zoom_camera(0.88 if up else 1.14)
				accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		match _drag.get("kind", ""):
			"orbit":
				var delta: Vector2 = motion.position - _drag["last"]
				_drag["last"] = motion.position
				orbit_camera(-delta.x * 0.4, delta.y * 0.3)
				return
			"pan":
				var delta: Vector2 = motion.position - _drag["last"]
				_drag["last"] = motion.position
				pan_camera(delta)
				return
		if not _held.is_empty():
			_carry_in_play(motion.position)
		else:
			var piece := piece_at(motion.position)
			if piece != _hovered:
				_show_hover_info(piece)
			_hovered = piece
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if piece != null and _movable_in_play(piece) else Control.CURSOR_ARROW


## Al pasar el ratón: el nombre de la pieza y su descripción en la barra de abajo.
func _show_hover_info(piece: PropEntity) -> void:
	if piece == null:
		if _build_mode or (_rolling.is_empty() and last_roll.is_empty()):
			_update_status()
		return
	var visual := piece.get_component("VisualComponent") as VisualComponent
	var text := piece.entity_name
	if visual != null and visual.notes.strip_edges() != "":
		text += " — " + visual.notes
	_update_status(text)


func _shape_of(entity: PropEntity) -> String:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	return visual.shape if visual != null else PieceShapes.DEFAULT


func _movable_in_play(entity: PropEntity) -> bool:
	return not entity.is_locked and not _is_zone(entity)


## Agarra la pieza bajo el ratón: flota un poco y sigue al cursor.
func _grab_in_play(screen: Vector2) -> void:
	var piece := piece_at(screen)
	if piece == null or not _movable_in_play(piece):
		return
	var body := piece.get_node_or_null("Body") as RigidBody3D
	if body == null:
		return
	body.freeze = true
	_held = {"entity": piece, "body": body, "velocity": Vector3.ZERO, "last": body.global_position, "time": Time.get_ticks_msec()}
	_rolling.erase(piece)
	_play("grab")
	_carry_in_play(screen)


func _carry_in_play(screen: Vector2) -> void:
	var body: RigidBody3D = _held["body"]
	var entity: PropEntity = _held["entity"]
	var point: Variant = table_point(screen, 0.0)
	if point == null:
		return
	var target := _clamp_to_table(point as Vector3)
	target.y = _surface_height(target, [entity]) + 0.35
	var now := Time.get_ticks_msec()
	var seconds := maxf((now - int(_held["time"])) / 1000.0, 0.001)
	_held["velocity"] = ((target - (_held["last"] as Vector3)) / maxf(seconds, 0.03)).limit_length(3.0)
	_held["last"] = target
	_held["time"] = now
	var xform := body.global_transform
	xform.origin = target + Vector3.UP * 0.0
	body.global_transform = xform


## Suelta la pieza: cae con la física y conserva algo del impulso (se puede lanzar).
func _release_in_play() -> void:
	if _held.is_empty():
		return
	var body: RigidBody3D = _held["body"]
	body.freeze = false
	# Sólo se lanza si el ratón aún se movía al soltar.
	var fresh := Time.get_ticks_msec() - int(_held["time"]) < 90
	body.linear_velocity = (_held["velocity"] as Vector3) * 0.5 if fresh else Vector3.ZERO
	var entity: PropEntity = _held["entity"]
	_held = {}
	_snap_body_to_anchor(entity, body)
	_play("drop")
	for zone in _scene_hierarchy.entities:
		var zone_visual := zone.get_component("VisualComponent") as VisualComponent
		if zone_visual != null and zone_visual.shape == PieceShapes.ZONE and _inside_zone(zone, body.global_position):
			var zone_id := zone.entity_id
			_fire_logic("ev_soltar", func(p: Dictionary) -> bool: return logic_zone_id(str(p["zona"])) == zone_id, {"pieza": entity.entity_id})
	if _shape_of(entity) == "dado":
		_watch_dice([entity])


## Al soltar cerca de un anclaje, la pieza cae justo encima y con su giro (sin volcarla).
func _snap_body_to_anchor(entity: PropEntity, body: RigidBody3D) -> void:
	var anchor := _anchor_near(body.global_position, [entity])
	if anchor == null:
		return
	var flipped := body.global_transform.basis.y.dot(Vector3.UP) < 0.0
	var basis := Basis(Vector3.UP, anchor.rotation.y)
	if flipped:
		basis = basis * Basis(Vector3.BACK, PI)
	body.global_transform = Transform3D(basis, Vector3(anchor.position.x, body.global_position.y, anchor.position.z))
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


## Zonas «mezclar al probar»: las piezas de dentro se barajan de sitio al empezar.
func shuffle_zones() -> int:
	var shuffled := 0
	for zone in _scene_hierarchy.entities:
		var visual := zone.get_component("VisualComponent") as VisualComponent
		if visual != null and visual.shape == PieceShapes.ZONE and visual.shuffle_on_play:
			shuffled += _shuffle_zone(zone)
	return shuffled


## Baraja de sitio las piezas que hay dentro de una zona. Devuelve cuántas.
func _shuffle_zone(zone: PropEntity) -> int:
	var inside: Array = logic_pieces(zone.entity_id, "").map(func(id: String) -> PropEntity: return _find_piece(id))
	if inside.size() < 2:
		return 0
	var spots: Array = inside.map(func(entity: PropEntity) -> Transform3D: return (entity.get_node("Body") as Node3D).global_transform)
	spots.shuffle()
	for i in inside.size():
		((inside[i] as Node).get_node("Body") as Node3D).global_transform = spots[i]
	_play("card")
	return inside.size()


## Lanza los dados: el agarrado o señalado, o todos los que no estén fijos.
func roll_dice(dice: Array = []) -> Array:
	if dice.is_empty():
		if not _held.is_empty() and _shape_of(_held["entity"]) == "dado":
			dice = [_held["entity"]]
		elif _hovered != null and is_instance_valid(_hovered) and _shape_of(_hovered) == "dado":
			dice = [_hovered]
		else:
			for entity in _scene_hierarchy.entities:
				if _shape_of(entity) == "dado" and not entity.is_locked:
					dice.append(entity)
	if dice.is_empty():
		_update_status(tr("No hay dados en la mesa."))
		return []
	if not _held.is_empty() and dice.has(_held["entity"]):
		_held = {}
	for die in dice:
		var body := (die as Node).get_node_or_null("Body") as RigidBody3D
		if body == null:
			continue
		body.freeze = false
		body.sleeping = false
		# Hacia arriba y un poco hacia el centro de la mesa, girando: rueda pero no se escapa.
		var inward := -Vector3(body.global_position.x, 0, body.global_position.z).limit_length(1.0) * 0.6
		var throw := Vector3(randf_range(-0.6, 0.6), randf_range(3.0, 3.8), randf_range(-0.6, 0.6)) + inward
		body.linear_velocity = throw
		body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	_play("dice")
	_watch_dice(dice)
	return dice


func _watch_dice(dice: Array) -> void:
	_roll_started = Time.get_ticks_msec()
	for die in dice:
		if not _rolling.has(die):
			_rolling.append(die)
	_update_status(tr("Rodando…"))


## Cuando los dados se paran, se dice qué ha salido.
func _check_rolling() -> void:
	if _rolling.is_empty() or _build_mode or Time.get_ticks_msec() - _roll_started < 500:
		return
	var values: Array[int] = []
	for die in _rolling:
		if not is_instance_valid(die):
			continue
		var body := (die as Node).get_node_or_null("Body") as RigidBody3D
		if body == null:
			continue
		if body.linear_velocity.length() > 0.05 or body.angular_velocity.length() > 0.1:
			return
		values.append(PieceLooks.die_value(body.global_transform.basis))
	_rolling.clear()
	last_roll = values
	if values.is_empty():
		return
	var total := 0
	for value in values:
		total += value
	var shown := " + ".join(values.map(func(value: int) -> String: return str(value)))
	_update_status((tr("Dados: %s = %d") % [shown, total]) if values.size() > 1 else (tr("Dado: %d") % total))
	_play("turn")
	_fire_logic("ev_dados", Callable(), {"total": float(total), "valores": Array(values)})


## Una pieza que se cae de la mesa al probar vuelve a su sitio desde un poco más arriba.
func _rescue_fallen() -> void:
	for entity in _scene_hierarchy.entities:
		var body := entity.get_node_or_null("Body") as RigidBody3D
		if body == null or body.freeze or body.global_position.y > -1.0:
			continue
		body.global_transform = Transform3D(entity.global_transform.basis, entity.global_position + Vector3.UP * 0.6)
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		if _rolling.has(entity):
			_roll_started = Time.get_ticks_msec()
		_play("pop")


## Último resultado de dados que se ha leído al probar.
var last_roll: Array[int] = []


## Da la vuelta a la pieza agarrada o señalada (al probar).
func flip_in_play() -> void:
	var entity: PropEntity = _held["entity"] if not _held.is_empty() else _hovered
	if entity == null or not is_instance_valid(entity) or not _movable_in_play(entity):
		return
	var body := entity.get_node_or_null("Body") as RigidBody3D
	if body == null:
		return
	var xform := body.global_transform
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var center := xform * (Vector3.UP * PieceShapes.size_of(visual.shape, visual.scale_factor).y * 0.5)
	var flip := Transform3D(Basis(Vector3.BACK, PI), Vector3.ZERO)
	xform = Transform3D.IDENTITY.translated(center) * flip * Transform3D.IDENTITY.translated(-center) * xform
	xform.origin.y += 0.25
	body.global_transform = xform
	if _held.is_empty():
		body.freeze = false
		body.sleeping = false
	_play("card")


# ===================================================================================
# Cámara: orbitar, acercar, desplazar y enfocar
# ===================================================================================

func orbit_camera(yaw_delta: float, pitch_delta: float) -> void:
	_orbit_goal["yaw"] = float(_orbit_goal["yaw"]) + yaw_delta
	_orbit_goal["pitch"] = clampf(float(_orbit_goal["pitch"]) + pitch_delta, 12.0, 88.0)


func zoom_camera(factor: float) -> void:
	_orbit_goal["distance"] = clampf(float(_orbit_goal["distance"]) * factor, 1.6, 11.0)


func pan_camera(delta: Vector2) -> void:
	var scale := float(_orbit_goal["distance"]) * 0.0016
	var yaw := deg_to_rad(float(_orbit_goal["yaw"]))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var target: Vector3 = _orbit_goal["target"] - right * delta.x * scale + forward * delta.y * scale
	_orbit_goal["target"] = _clamp_to_table(target)


## Encuadra toda la mesa con piezas.
func focus_all() -> void:
	if _scene_hierarchy.entities.is_empty():
		reset_camera()
		return
	var keep := selection.duplicate()
	selection.assign(_scene_hierarchy.entities)
	focus_selection()
	selection.assign(keep)
	_orbit_goal["distance"] = clampf(float(_orbit_goal["distance"]) * 0.75, 3.0, 8.0)


func focus_selection() -> void:
	if selection.is_empty():
		return
	var center := Vector3.ZERO
	var reach := 0.0
	for entity in selection:
		center += entity.global_position
	center /= selection.size()
	for entity in selection:
		var visual := entity.get_component("VisualComponent") as VisualComponent
		reach = maxf(reach, entity.global_position.distance_to(center) + PieceShapes.size_of(visual.shape, visual.scale_factor).length())
	_orbit_goal["target"] = center
	_orbit_goal["distance"] = clampf(reach * 3.2, 1.6, 11.0)
	_say("Cámara en la selección · Inicio la recoloca.")


func reset_camera() -> void:
	_orbit_goal = {"target": ORBIT_TARGET, "yaw": 0.0, "pitch": ORBIT_PITCH, "distance": ORBIT_DISTANCE}


func _apply_orbit() -> void:
	var yaw := deg_to_rad(float(_orbit["yaw"]))
	var pitch := deg_to_rad(float(_orbit["pitch"]))
	var target: Vector3 = _orbit["target"]
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(_orbit["distance"])
	_camera.position = target + offset
	_camera.look_at(target)


func _process(delta: float) -> void:
	if _camera == null:
		return
	var weight := 1.0 - exp(-delta * 12.0)
	var changed := false
	for key in ["yaw", "pitch", "distance"]:
		var goal := float(_orbit_goal[key])
		var now := float(_orbit[key])
		if absf(goal - now) > 0.001:
			_orbit[key] = lerpf(now, goal, weight)
			changed = true
	var goal_target: Vector3 = _orbit_goal["target"]
	if (_orbit["target"] as Vector3).distance_to(goal_target) > 0.0005:
		_orbit["target"] = (_orbit["target"] as Vector3).lerp(goal_target, weight)
		changed = true
	if changed:
		_apply_orbit()
	if _build_mode and not selection.is_empty():
		_refresh_markers()
	if not _build_mode:
		_rescue_fallen()
		if not _rolling.is_empty():
			_check_rolling()


func _update_status(message := "") -> void:
	if _status_bar == null:
		return
	if message != "":
		_status_bar.text = message
		return
	if not _build_mode:
		_status_bar.text = tr("Probando · arrastra y lanza piezas · R o doble clic: tirar dados · F: voltear · Esc: volver a editar")
		return
	var template := "Editor de juegos · %d piezas · %d seleccionadas · imán activado · F1 ayuda" if snap else "Editor de juegos · %d piezas · %d seleccionadas · imán apagado · F1 ayuda"
	_status_bar.text = tr(template) % [_scene_hierarchy.entities.size() if _scene_hierarchy != null else 0, selection.size()]


## Texto de la ayuda (F1) en esta pantalla.
func help_text() -> String:
	return "\n".join([
		tr("PIEZAS"),
		tr("Clic: seleccionar · Ctrl/Mayús+clic: añadir a la selección · arrastrar en vacío: recuadro."),
		tr("Arrastrar: mover (se apilan solas) · Alt+arrastrar: copia · Mayús: sin imán."),
		tr("Q/E: girar (Mayús: 5°) · Rueda al arrastrar: girar · F: voltear · +/−: tamaño."),
		tr("Flechas: mover un paso · RePág/AvPág: subir y bajar · G: imán."),
		tr("Ctrl+D duplicar · Ctrl+C/V copiar y pegar · Supr quitar · Ctrl+A todo."),
		tr("Ctrl+Z deshacer · Ctrl+Y rehacer · Ctrl+S guardar la mesa."),
		"",
		tr("CREAR"),
		tr("Plantillas: damas, carrera, cartas y dados, listas para cambiar."),
		tr("Inspector: texto en la pieza, dibujo del tablero y casillas, acabado, repetir en rejilla."),
		tr("Con varias piezas: en fila, apilar, centrar, numerar y mezclar."),
		tr("Anclajes: las piezas soltadas cerca se pegan con su giro. Zonas: pueden mezclar lo de dentro al probar."),
		tr("Imágenes: corta una hoja de cartas en un mazo, o una carta por imagen; «Poner reverso» les da dorso."),
		tr("Exportar juego: un solo archivo con todo, imágenes incluidas, para compartirlo."),
		tr("Lógica del juego: blueprints con eventos, flujo, acciones, datos y bloques GDScript (con «mesa»)."),
		"",
		tr("PROBAR"),
		tr("Arrastrar: agarrar y lanzar · R o doble clic en un dado: tirar · F: voltear · Esc: volver a editar."),
		"",
		tr("CÁMARA"),
		tr("Botón derecho: orbitar · Central o Mayús+derecho: desplazar · Rueda: zoom."),
		tr("C o doble clic: enfocar la selección · Inicio: recolocar."),
		"",
		tr("Esc: soltar la selección y, sin selección, volver al menú · F1: esta ayuda."),
	])
