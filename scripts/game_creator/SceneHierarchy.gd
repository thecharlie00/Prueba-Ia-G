# SceneHierarchy.gd
# Árbol de jerarquía de escena que muestra las entidades del tablero.
# Permite seleccionar entidades para editarlas en el Inspector.
class_name SceneHierarchy
extends Control

# Lista de entidades conocidas.
var entities: Array[PropEntity] = []

# Entidad seleccionada actualmente.
var selected_entity: PropEntity = null

# Señal emitida cuando se selecciona una entidad.
signal entity_selected(entity: PropEntity)

var _tree: Tree = null

func _ready() -> void:
	_build_ui()

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
	title.text = "JERARQUÍA DE ESCENA"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(title)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.custom_minimum_size = Vector2(28, 28)
	add_btn.pressed.connect(_on_add_entity)
	header.add_child(add_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 1
	_tree.set_column_title(0, "Entidades")
	_tree.item_selected.connect(_on_tree_item_selected)
	col.add_child(_tree)

	var bottom_hb := HBoxContainer.new()
	bottom_hb.add_theme_constant_override("separation", 8)
	col.add_child(bottom_hb)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refrescar"
	refresh_btn.custom_minimum_size = Vector2(80, 28)
	refresh_btn.pressed.connect(_refresh)
	bottom_hb.add_child(refresh_btn)

	_refresh()

func add_entity(entity: PropEntity) -> void:
	if entity in entities:
		return
	entities.append(entity)
	_refresh()

func remove_entity(entity: PropEntity) -> void:
	entities.erase(entity)
	if selected_entity == entity:
		selected_entity = null
		entity_selected.emit(null)
	_refresh()

func get_selected() -> PropEntity:
	return selected_entity

func refresh() -> void:
	if _tree == null:
		return
	_tree.clear()

	if entities.size() == 0:
		var empty_label := Label.new()
		empty_label.text = "Sin entidades en la escena."
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_tree.add_child(empty_label)
		return

	for entity in entities:
		var name: String = entity.entity_name if entity.entity_name != "" else entity.entity_id
		var item := _tree.create_item()
		item.set_text(0, name)
		item.set_icon(0, _get_entity_icon(entity))
		item.set_metadata(0, entity)

		if selected_entity == entity:
			_tree.select(item, 0)

func _get_entity_icon(entity: PropEntity) -> Texture2D:
	# Usar un icono simple basado en si tiene VisualComponent.
	if entity.get_component("VisualComponent") != null:
		var cube: Texture2D = load("res://assets/icons/entity_3d.png")
		if cube == null:
			cube = _make_colored_icon(Color(0.4, 0.7, 1.0))
		return cube
	else:
		var logic: Texture2D = load("res://assets/icons/entity_logic.png")
		if logic == null:
			logic = _make_colored_icon(Color(0.8, 0.6, 0.4))
		return logic

func _make_colored_icon(color: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in range(16):
		for y in range(16):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var entity: PropEntity = item.get_metadata(0)
	if entity != null:
		selected_entity = entity
		entity_selected.emit(entity)

func _on_add_entity() -> void:
	# Señal para que el editor cree una nueva entidad.
	pass

func _on_entity_removed(entity: PropEntity) -> void:
	remove_entity(entity)
