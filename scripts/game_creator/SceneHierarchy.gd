# SceneHierarchy.gd
# Lista de las piezas de la mesa. Se pueden elegir varias (Ctrl/Mayús+clic); cada una
# lleva un punto de su color y un candado si está fija.
class_name SceneHierarchy
extends VBoxContainer

# Lista de entidades conocidas.
var entities: Array[PropEntity] = []

# Pieza principal seleccionada (la última elegida).
var selected_entity: PropEntity = null
var _selected: Array = []

## Compatibilidad: una pieza (o null).
signal entity_selected(entity: PropEntity)
## Selección completa tras un cambio hecho en la lista.
signal selection_changed(entities: Array)
## Se pulsó «+»: el editor pone una pieza nueva.
signal add_requested

var _tree: Tree = null
var _count: Label = null
var _syncing := false
var _pending := false
var _icons := {}


func _ready() -> void:
	build_ui()


func build_ui() -> void:
	for child in get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	var title := Label.new()
	title.text = "PIEZAS EN LA MESA"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.62, 0.6, 0.7))
	header.add_child(title)
	_count = Label.new()
	_count.name = "PieceCount"
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", Color(0.62, 0.6, 0.7))
	header.add_child(_count)
	var add_btn := Button.new()
	add_btn.name = "AddPieceQuick"
	add_btn.text = "+"
	add_btn.tooltip_text = "Nueva ficha"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.custom_minimum_size = Vector2(30, 30)
	add_btn.pressed.connect(func() -> void: add_requested.emit())
	header.add_child(add_btn)

	_tree = Tree.new()
	_tree.name = "PieceList"
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 1
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_MULTI
	_tree.multi_selected.connect(_on_multi_selected)
	add_child(_tree)
	refresh()


func add_entity(entity: PropEntity) -> void:
	if entity in entities:
		return
	entities.append(entity)
	refresh()


func remove_entity(entity: PropEntity) -> void:
	entities.erase(entity)
	_selected.erase(entity)
	if selected_entity == entity:
		selected_entity = _selected.back() if not _selected.is_empty() else null
		entity_selected.emit(selected_entity)
	refresh()


func get_selected() -> PropEntity:
	return selected_entity


## Marca en la lista la selección hecha fuera (en la mesa) sin volver a avisar.
func show_selection(list: Array) -> void:
	_selected = list.duplicate()
	selected_entity = _selected.back() if not _selected.is_empty() else null
	refresh()


func refresh() -> void:
	if _tree == null:
		return
	_syncing = true
	_tree.clear()
	var tree_root := _tree.create_item()
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		var label: String = entity.entity_name if entity.entity_name != "" else entity.entity_id
		if entity.is_locked:
			label += "  🔒"
		var item := _tree.create_item(tree_root)
		item.set_text(0, label)
		item.set_icon(0, _icon_for(entity))
		item.set_metadata(0, entity)
		if _selected.has(entity):
			item.select(0)
			if entity == selected_entity:
				_tree.scroll_to_item(item)
	if _count != null:
		_count.text = str(entities.size())
	_syncing = false


func _icon_for(entity: PropEntity) -> Texture2D:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var color := visual.color_tint if visual != null else Color(0.8, 0.6, 0.4)
	var key := color.to_html()
	if not _icons.has(key):
		var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		for y in 14:
			for x in 14:
				var d := Vector2(x - 6.5, y - 6.5).length()
				img.set_pixel(x, y, Color(color, clampf(6.8 - d, 0.0, 1.0)))
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


# Tree avisa una vez por fila; se junta todo en un solo cambio al final del cuadro.
func _on_multi_selected(_item: TreeItem, _column: int, _selected_now: bool) -> void:
	if _syncing or _pending:
		return
	_pending = true
	_emit_selection.call_deferred()


func _emit_selection() -> void:
	_pending = false
	var chosen: Array = []
	var item := _tree.get_next_selected(null)
	while item != null:
		var entity: PropEntity = item.get_metadata(0)
		if entity != null and is_instance_valid(entity):
			chosen.append(entity)
		item = _tree.get_next_selected(item)
	# La que tiene el foco del árbol pasa a ser la principal.
	var focused := _tree.get_selected()
	if focused != null and chosen.has(focused.get_metadata(0)):
		chosen.erase(focused.get_metadata(0))
		chosen.append(focused.get_metadata(0))
	_selected = chosen
	selected_entity = chosen.back() if not chosen.is_empty() else null
	selection_changed.emit(chosen)
	entity_selected.emit(selected_entity)
