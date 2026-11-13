class_name UiLayoutView
extends Control
## Dibuja un UiLayout sobre la pantalla. Tiene dos modos:
## - diseño: cada elemento se selecciona con un clic, se mueve arrastrándolo y se cambia de
##   tamaño tirando de su esquina inferior derecha; nada «funciona» todavía;
## - juego: los botones hacen su acción (sumar, restar, tirar un dado, mostrar u ocultar) y
##   los contadores tienen sus botones − y +. Trabaja sobre una copia: probar no cambia el diseño.

signal element_selected(id: int)
signal element_changed(id: int)

const HANDLE := 16.0
const SELECT_COLOR := Color("7cc6fe")

var layout: UiLayout
var design := true
var selected_id := 0
## Para cargar las imágenes de la galería (ImageImporter); sin él, las imágenes salen vacías.
var image_loader: Callable

var _nodes := {}
var _state := {}
var _drag_id := 0
var _drag_resize := false
var _drag_from := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _textures := {}


func _init() -> void:
	name = "UiLayoutView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(_place_all)
	resized.connect(queue_redraw)


# En diseño, un marco señala qué parte es la pantalla del juego.
func _draw() -> void:
	if not design:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.45), false, 2.0)


func show_layout(new_layout: UiLayout, design_mode: bool) -> void:
	layout = new_layout
	design = design_mode
	queue_redraw()
	_state.clear()
	if layout != null and not design:
		for element in layout.elements:
			_state[int(element["id"])] = {"value": int(element["value"]), "visible": true}
	rebuild()


## Valor actual de un contador en modo juego (o el inicial en diseño).
func counter_value(id: int) -> int:
	if _state.has(id):
		return int(_state[id]["value"])
	return int(layout.find(id).get("value", 0)) if layout != null else 0


func is_element_visible(id: int) -> bool:
	return bool(_state.get(id, {"visible": true})["visible"])


func node_for(id: int) -> Control:
	return _nodes.get(id) as Control


func select(id: int) -> void:
	selected_id = id
	for key in _nodes:
		var outline := (_nodes[key] as Control).get_node_or_null("Outline") as Control
		if outline != null:
			outline.queue_redraw()
	element_selected.emit(id)


func rebuild() -> void:
	for key in _nodes:
		(_nodes[key] as Control).queue_free()
	_nodes.clear()
	if layout == null:
		return
	for element in layout.elements:
		var node := _build(element)
		add_child(node)
		_nodes[int(element["id"])] = node
	_place_all()


func _place_all() -> void:
	if layout == null:
		return
	for element in layout.elements:
		var node := _nodes.get(int(element["id"])) as Control
		if node == null:
			continue
		var rect := UiLayout.rect_on(element, size)
		node.position = rect.position
		node.size = rect.size
		node.visible = design or is_element_visible(int(element["id"]))
		# El contenido se construye a tamaño de referencia y se escala entero: en la vista
		# reducida del editor se ve igual que a pantalla completa.
		var content := node.get_child(0) as Control
		content.position = Vector2.ZERO
		content.size = element["size"]
		content.scale = Vector2.ONE * _scale()


func _scale() -> float:
	return minf(size.x / UiLayout.REFERENCE.x, size.y / UiLayout.REFERENCE.y) if size.x > 0 else 1.0


# --- Construcción de cada elemento ------------------------------------------------

func _build(element: Dictionary) -> Control:
	var id := int(element["id"])
	var wrapper := _Frame.new()
	wrapper.view = self
	wrapper.element_id = id
	wrapper.name = "Element%d" % id
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP if design else Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = false
	var content := _content(element)
	content.name = "Content"
	if design:
		_ignore_mouse(content)
	wrapper.add_child(content)
	if design:
		# Encima del contenido: el marco de selección y el tirador de tamaño.
		var outline := _Outline.new()
		outline.view = self
		outline.element_id = id
		outline.name = "Outline"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrapper.add_child(outline)
	return wrapper


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_ignore_mouse(child)


func _font_size(element: Dictionary) -> int:
	return int(element["font_size"])


func _box(color_hex: String, alpha: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Color(color_hex), alpha)
	MenuStyle.pebble(box, 14)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.anti_aliasing = true
	return box


func _content(element: Dictionary) -> Control:
	var id := int(element["id"])
	var ink := Color(str(element["color"]))
	var bg := str(element["bg"])
	match str(element["type"]):
		"button":
			var button := Button.new()
			button.text = str(element["text"])
			button.clip_text = true
			var fill := Color(bg if bg != "" else "ffc83d")
			button.add_theme_stylebox_override("normal", MenuStyle.button_box(fill, false, 14, 6))
			button.add_theme_stylebox_override("hover", MenuStyle.button_box(fill.lightened(0.12), false, 14, 6))
			button.add_theme_stylebox_override("pressed", MenuStyle.button_box(fill, true, 14, 6))
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				button.add_theme_color_override(state, ink)
			button.add_theme_font_size_override("font_size", _font_size(element))
			if not design:
				button.pressed.connect(_run_action.bind(id))
			return button
		"panel":
			var panel := Panel.new()
			panel.add_theme_stylebox_override("panel", _box(bg if bg != "" else "2a2552", 0.92))
			return panel
		"image":
			var picture := TextureRect.new()
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.texture = _texture(str(element["image"]))
			if picture.texture == null:
				# Sin imagen todavía: un marco con el nombre, para poder colocarlo.
				var empty := PanelContainer.new()
				empty.add_theme_stylebox_override("panel", _box("211d40", 0.7))
				var hint := Label.new()
				hint.text = "Imagen"
				hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				empty.add_child(hint)
				return empty
			return picture
		"counter":
			var holder := PanelContainer.new()
			holder.add_theme_stylebox_override("panel", _box(bg if bg != "" else "2a2552", 0.92))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			holder.add_child(row)
			var caption := Label.new()
			caption.text = str(element["text"])
			caption.clip_text = true
			caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			caption.add_theme_color_override("font_color", ink)
			caption.add_theme_font_size_override("font_size", _font_size(element))
			row.add_child(caption)
			var minus := Button.new()
			minus.name = "Minus"
			minus.text = "−"
			minus.focus_mode = Control.FOCUS_NONE
			row.add_child(minus)
			var value := Label.new()
			value.name = "Value"
			value.text = str(counter_value(id))
			value.custom_minimum_size.x = 36
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.add_theme_color_override("font_color", ink)
			value.add_theme_font_size_override("font_size", _font_size(element) + 4)
			row.add_child(value)
			var plus := Button.new()
			plus.name = "Plus"
			plus.text = "+"
			plus.focus_mode = Control.FOCUS_NONE
			row.add_child(plus)
			if not design:
				minus.pressed.connect(change_counter.bind(id, -1))
				plus.pressed.connect(change_counter.bind(id, 1))
			return holder
	var label := Label.new()
	label.text = str(element["text"])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_size_override("font_size", _font_size(element))
	if bg != "":
		label.add_theme_stylebox_override("normal", _box(bg, 0.92))
	return label


func _texture(path: String) -> Texture2D:
	if path == "" or not image_loader.is_valid():
		return null
	if not _textures.has(path):
		_textures[path] = image_loader.call(path)
	return _textures[path]


# --- Modo juego -----------------------------------------------------------------

func change_counter(id: int, amount: int) -> void:
	if not _state.has(id):
		return
	_state[id]["value"] = clampi(int(_state[id]["value"]) + amount, -999999, 999999)
	_show_counter(id)


func _show_counter(id: int) -> void:
	var node := node_for(id)
	var value := node.find_child("Value", true, false) as Label if node != null else null
	if value != null:
		value.text = str(counter_value(id))


## Ejecuta la acción de un botón (público para los tests).
func _run_action(id: int) -> void:
	var element := layout.find(id)
	if element.is_empty() or design:
		return
	var target := int(element["target"])
	if not _state.has(target):
		return
	match str(element["action"]):
		"add":
			change_counter(target, 1)
		"sub":
			change_counter(target, -1)
		"roll":
			_state[target]["value"] = randi_range(1, 6)
			_show_counter(target)
		"toggle":
			_state[target]["visible"] = not bool(_state[target]["visible"])
			_place_all()


# --- Modo diseño: mover y cambiar de tamaño ---------------------------------------

## Empieza a arrastrar un elemento (público para los tests). `local` es el punto dentro de él.
func begin_drag(id: int, local: Vector2, at: Vector2) -> void:
	var element := layout.find(id)
	var node := node_for(id)
	if element.is_empty() or node == null or not design:
		return
	select(id)
	_drag_id = id
	_drag_resize = local.x > node.size.x - HANDLE and local.y > node.size.y - HANDLE
	_drag_from = at
	_drag_origin = element["size"] if _drag_resize else element["pos"]


func drag_to(at: Vector2) -> void:
	var element := layout.find(_drag_id) if layout != null else {}
	if element.is_empty():
		return
	var delta := (at - _drag_from) / _scale()
	if _drag_resize:
		element["size"] = (_drag_origin + delta).clamp(UiLayout.MIN_SIZE, UiLayout.REFERENCE - (element["pos"] as Vector2))
	else:
		element["pos"] = _drag_origin + delta
	layout.reanchor(element)
	_place_all()
	element_changed.emit(_drag_id)


func end_drag() -> void:
	if _drag_id != 0 and _drag_resize:
		# El texto se ajusta al tamaño nuevo.
		rebuild()
	_drag_id = 0


## Marco de cada elemento: recibe el ratón en modo diseño.
class _Frame:
	extends Control
	var view: UiLayoutView
	var element_id := 0

	func _gui_input(event: InputEvent) -> void:
		if not view.design:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				view.begin_drag(element_id, event.position, event.global_position)
			else:
				view.end_drag()
			accept_event()
		elif event is InputEventMouseMotion and view._drag_id == element_id:
			view.drag_to(event.global_position)
			accept_event()


## Selección: contorno y tirador de tamaño en la esquina inferior derecha.
class _Outline:
	extends Control
	var view: UiLayoutView
	var element_id := 0

	func _draw() -> void:
		if view.selected_id != element_id:
			return
		draw_rect(Rect2(Vector2.ZERO, size), UiLayoutView.SELECT_COLOR, false, 2.0)
		var corner := Vector2(UiLayoutView.HANDLE, UiLayoutView.HANDLE)
		draw_rect(Rect2(size - corner, corner), UiLayoutView.SELECT_COLOR, true)
