# AssetBrowser.gd
# Panel de navegador de assets con miniaturas para el Game Creator Studio.
# Muestra las imágenes importadas en un grid navegable y permite seleccionarlas
# para asignarlas a entidades del tablero (VisualComponent, CardData, DiceFace, etc.).
class_name AssetBrowser
extends VBoxContainer

# Importador de imágenes (referencia opcional).
var image_importer: ImageImporter = null

# Tamaño de las miniaturas en el grid.
var thumbnail_size: Vector2 = Vector2(80, 80)

# Imagen actualmente seleccionada.
var selected_image: Dictionary = {}

# Señal emitida cuando el usuario selecciona una imagen para usarla.
signal image_selected(image_path: String)

# Señal emitida cuando el usuario arrastra una imagen desde el navegador.
signal image_drag_started(image_path: String)

var _grid: GridContainer = null

func _ready() -> void:
	_refresh()

# Establece el importador de imágenes asociado.
func set_image_importer(importer: ImageImporter) -> void:
	image_importer = importer
	_refresh()

# Refresca la galería de miniaturas desde el importador.
func refresh() -> void:
	_refresh()

func _refresh() -> void:
	if _grid == null:
		return
	# Limpiar grid.
	for child in _grid.get_children():
		child.queue_free()

	if image_importer == null:
		return

	var images: Array[Dictionary] = image_importer.get_imported_images()
	if images.size() == 0:
		var empty_label := Label.new()
		empty_label.text = "Sin imágenes importadas."
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_grid.add_child(empty_label)
		return

	for info in images:
		var path: String = str(info.get("path", ""))
		var file_name: String = str(info.get("file_name", ""))

		# Un contenedor (no un Control suelto) para que la tarjeta ocupe su sitio en la rejilla.
		var card := VBoxContainer.new()
		card.custom_minimum_size = thumbnail_size
		card.add_theme_constant_override("separation", 4)
		var col := card

		# Miniatura.
		var thumb := TextureRect.new()
		var tex := image_importer.load_texture(path)
		if tex != null:
			thumb.texture = tex
		thumb.custom_minimum_size = Vector2(64, 64)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(thumb)

		# Nombre del archivo.
		var name_lbl := Label.new()
		name_lbl.text = file_name
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size = Vector2(thumbnail_size.x, 0)
		col.add_child(name_lbl)

		# Botón de selección.
		var btn := Button.new()
		btn.text = "Seleccionar"
		btn.custom_minimum_size = Vector2(0, 24)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_image_selected.bind(path))
		col.add_child(btn)

		# Tooltip con dimensiones.
		card.tooltip_text = file_name + "\n" + str(info.get("width", 0)) + " x " + str(info.get("height", 0))

		_grid.add_child(card)

func _on_image_selected(path: String) -> void:
	if image_importer != null:
		selected_image = image_importer.find_image(path.get_file())
	image_selected.emit(path)

# Crea la estructura de UI del navegador (llamado desde GameCreatorEditor).
func build_ui() -> void:
	# Limpiar hijos existentes.
	for child in get_children():
		child.queue_free()

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)

	var title := Label.new()
	title.text = "GALERÍA"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(title)

	var refresh_btn := Button.new()
	refresh_btn.text = "⟳"
	refresh_btn.custom_minimum_size = Vector2(28, 28)
	refresh_btn.pressed.connect(_refresh)
	header.add_child(refresh_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var images_label := Label.new()
	images_label.text = "Imágenes del proyecto"
	images_label.add_theme_font_size_override("font_size", 11)
	images_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	col.add_child(images_label)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	col.add_child(_grid)

	_refresh()
