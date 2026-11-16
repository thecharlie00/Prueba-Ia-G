# LogicEditor.gd
# Editor visual de la lógica del juego (blueprints): bloques que se arrastran desde la paleta
# o con clic derecho, cables entre sus puertos y parámetros dentro de cada bloque. Los
# bloques GDScript traen un editor de código con colores y avisan de errores al escribir.
class_name LogicEditor
extends Control

signal closed

## Grafo que se edita (se comparte con el editor de juegos).
var graph: LogicGraph
## Se llama ANTES de cada cambio, con una clave (para deshacer).
var before_change: Callable
## Listas para los desplegables: devuelven [[id, nombre], …].
var zones_provider: Callable
var buttons_provider: Callable
var counters_provider: Callable
var elements_provider: Callable

var graph_edit: GraphEdit
var _palette: VBoxContainer
var _search: LineEdit
var _popup: PopupMenu
var _popup_at := Vector2.ZERO
## Cable soltado en vacío: {"node": id, "port": nombre, "type": tipo, "output": bool}.
var _pending_wire := {}
var _param_controls := {}
var _error_labels := {}
var _building := false

const PANEL := Color("231f45")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	back.add_theme_stylebox_override("panel", style)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)
	var title := Label.new()
	title.text = "LÓGICA DEL JUEGO"
	title.add_theme_font_size_override("font_size", 20)
	bar.add_child(title)
	var hint := Label.new()
	hint.text = "Arrastra bloques, une sus puntos con cables · clic derecho: añadir · Supr: borrar · Ctrl+D: duplicar"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.73, 0.85))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.clip_text = true
	bar.add_child(hint)
	var arrange := Button.new()
	arrange.name = "ArrangeLogic"
	arrange.text = "Ordenar"
	arrange.tooltip_text = "Coloca los bloques en columnas según sus cables"
	arrange.pressed.connect(arrange_blocks)
	bar.add_child(arrange)
	var check := Button.new()
	check.name = "CheckLogic"
	check.text = "Comprobar"
	check.tooltip_text = "Revisa los bloques GDScript y los eventos"
	check.pressed.connect(check_all)
	bar.add_child(check)
	var api_help := Button.new()
	api_help.name = "ApiHelp"
	api_help.text = "Ayuda de «mesa»"
	api_help.pressed.connect(_show_api_help)
	bar.add_child(api_help)
	var close := Button.new()
	close.name = "CloseLogic"
	close.text = "Cerrar · Esc"
	close.pressed.connect(close_editor)
	bar.add_child(close)
	# Hueco para «Ayuda» y «Menú», que van siempre arriba a la derecha.
	var room := Control.new()
	room.custom_minimum_size.x = 300
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(room)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	var palette_scroll := ScrollContainer.new()
	palette_scroll.custom_minimum_size = Vector2(250, 0)
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(palette_scroll)
	_palette = VBoxContainer.new()
	_palette.name = "LogicPalette"
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette.add_theme_constant_override("separation", 6)
	palette_scroll.add_child(_palette)
	_search = LineEdit.new()
	_search.name = "LogicSearch"
	_search.placeholder_text = "Buscar bloque…"
	_search.text_changed.connect(func(_text: String) -> void: _fill_palette())
	_palette.add_child(_search)

	graph_edit = GraphEdit.new()
	graph_edit.name = "LogicGraphEdit"
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true
	graph_edit.minimap_enabled = true
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = 20
	split.add_child(graph_edit)
	for from in [LogicNodes.NUM, LogicNodes.BOOL, LogicNodes.TEXT, LogicNodes.PIECE, LogicNodes.LIST]:
		graph_edit.add_valid_connection_type(from, LogicNodes.ANY)
		graph_edit.add_valid_connection_type(LogicNodes.ANY, from)
	graph_edit.add_valid_connection_type(LogicNodes.NUM, LogicNodes.TEXT)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_request)
	graph_edit.duplicate_nodes_request.connect(_duplicate_selected)
	graph_edit.end_node_move.connect(_on_moved)
	graph_edit.popup_request.connect(_on_popup_request)
	graph_edit.connection_to_empty.connect(_on_connection_to_empty)
	graph_edit.connection_from_empty.connect(_on_connection_from_empty)

	_popup = PopupMenu.new()
	_popup.name = "AddBlockMenu"
	_popup.id_pressed.connect(_on_popup_id)
	add_child(_popup)
	_fill_palette()


func open_with(logic: LogicGraph) -> void:
	graph = logic
	visible = true
	rebuild()
	check_all()


func close_editor() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_editor()


# --- Paleta y menú de añadir --------------------------------------------------------

func _fill_palette() -> void:
	for child in _palette.get_children():
		if child != _search:
			child.queue_free()
	var filter := _search.text.strip_edges().to_lower()
	for category in LogicNodes.CATEGORIES:
		var types: Array = LogicNodes.DEFS.keys().filter(func(type: String) -> bool:
			return LogicNodes.DEFS[type]["cat"] == category and (filter == "" or tr(LogicNodes.DEFS[type]["title"]).to_lower().contains(filter)))
		if types.is_empty():
			continue
		var header := Label.new()
		header.text = tr(LogicNodes.CATEGORY_NAMES[category]).to_upper()
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", LogicNodes.CATEGORY_COLORS[category])
		_palette.add_child(header)
		for type in types:
			var add := Button.new()
			add.name = "Add_" + type
			add.text = LogicNodes.DEFS[type]["title"]
			add.tooltip_text = LogicNodes.DEFS[type].get("help", "")
			add.alignment = HORIZONTAL_ALIGNMENT_LEFT
			add.add_theme_font_size_override("font_size", 13)
			add.pressed.connect(func() -> void: add_block(type, _view_center()))
			_palette.add_child(add)


func _on_popup_request(at: Vector2) -> void:
	_pending_wire = {}
	_show_add_menu(at)


## Soltar un cable en vacío abre el menú sólo con los bloques que encajan, y los une.
func _on_connection_to_empty(from: StringName, from_port: int, at: Vector2) -> void:
	var id := int(str(from))
	var ports := LogicNodes.outputs(graph.nodes[id]["type"])
	_pending_wire = {"node": id, "port": ports[from_port][0], "type": ports[from_port][1], "output": true}
	_show_add_menu(at)


func _on_connection_from_empty(to: StringName, to_port: int, at: Vector2) -> void:
	var id := int(str(to))
	var ports := LogicNodes.inputs(graph.nodes[id]["type"])
	_pending_wire = {"node": id, "port": ports[to_port][0], "type": ports[to_port][1], "output": false}
	_show_add_menu(at)


## Puerto del bloque `type` que encaja con el cable pendiente ("" si ninguno).
func _matching_port(type: String) -> String:
	if _pending_wire.is_empty():
		return ""
	var wire_type: int = _pending_wire["type"]
	if _pending_wire["output"]:
		for port in LogicNodes.inputs(type):
			if LogicNodes.compatible(wire_type, port[1]):
				return port[0]
	else:
		for port in LogicNodes.outputs(type):
			if LogicNodes.compatible(port[1], wire_type):
				return port[0]
	return ""


func _show_add_menu(at: Vector2) -> void:
	_popup_at = (at + graph_edit.scroll_offset) / graph_edit.zoom
	_popup.clear()
	var index := 0
	for category in LogicNodes.CATEGORIES:
		var types: Array = LogicNodes.DEFS.keys().filter(func(type: String) -> bool:
			return LogicNodes.DEFS[type]["cat"] == category and (_pending_wire.is_empty() or _matching_port(type) != ""))
		if types.is_empty():
			continue
		_popup.add_separator(tr(LogicNodes.CATEGORY_NAMES[category]))
		for type in types:
			_popup.add_item(tr(LogicNodes.DEFS[type]["title"]), index)
			_popup.set_item_metadata(_popup.get_item_index(index), type)
			index += 1
	_popup.position = Vector2i(get_screen_position() + graph_edit.position + at)
	_popup.popup()


func _on_popup_id(id: int) -> void:
	add_block_for_wire(str(_popup.get_item_metadata(_popup.get_item_index(id))), _popup_at)


## Añade un bloque y, si había un cable soltado en vacío, lo une a él.
func add_block_for_wire(type: String, at: Vector2) -> int:
	var port := _matching_port(type)
	var wire := _pending_wire
	_pending_wire = {}
	var added := add_block(type, at)
	if added == 0 or wire.is_empty() or port == "":
		return added
	if wire["output"]:
		graph.connect_ports(wire["node"], wire["port"], added, port)
	else:
		graph.connect_ports(added, port, wire["node"], wire["port"])
	_sync_links()
	return added


func _view_center() -> Vector2:
	return (graph_edit.scroll_offset + graph_edit.size * 0.5) / graph_edit.zoom - Vector2(110, 60)


## Añade un bloque y lo deja seleccionado. Devuelve su id.
func add_block(type: String, at: Vector2) -> int:
	if graph == null:
		return 0
	_change("logic_add")
	var id := graph.add_node(type, at.snapped(Vector2(20, 20)))
	if id == 0:
		return 0
	var node := _make_node(graph.nodes[id])
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.selected = false
	node.selected = true
	return id


# --- Construcción de los bloques ----------------------------------------------------

func rebuild() -> void:
	_building = true
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()
	_param_controls.clear()
	_error_labels.clear()
	for node in graph.nodes.values():
		_make_node(node)
	_sync_links()
	_building = false


func _make_node(data: Dictionary) -> GraphNode:
	var id := int(data["id"])
	var type: String = data["type"]
	var def: Dictionary = LogicNodes.DEFS[type]
	var node := GraphNode.new()
	node.name = str(id)
	node.title = def["title"]
	node.tooltip_text = def.get("help", "")
	node.position_offset = data["pos"]
	node.resizable = false
	var title_box := StyleBoxFlat.new()
	title_box.bg_color = LogicNodes.CATEGORY_COLORS[def["cat"]].darkened(0.15)
	title_box.set_corner_radius_all(6)
	title_box.corner_radius_bottom_left = 0
	title_box.corner_radius_bottom_right = 0
	title_box.content_margin_left = 10
	title_box.content_margin_right = 10
	title_box.content_margin_top = 4
	title_box.content_margin_bottom = 4
	node.add_theme_stylebox_override("titlebar", title_box)
	var selected_box := title_box.duplicate() as StyleBoxFlat
	selected_box.bg_color = LogicNodes.CATEGORY_COLORS[def["cat"]].lightened(0.1)
	node.add_theme_stylebox_override("titlebar_selected", selected_box)
	graph_edit.add_child(node)

	var inputs: Array = def["in"]
	var outputs: Array = def["out"]
	var rows := maxi(inputs.size(), outputs.size())
	for row in rows:
		var line := HBoxContainer.new()
		line.custom_minimum_size.y = 26
		var left := Label.new()
		left.text = _port_label(inputs[row]) if row < inputs.size() else ""
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_font_size_override("font_size", 13)
		line.add_child(left)
		var right := Label.new()
		right.text = _port_label(outputs[row]) if row < outputs.size() else ""
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_theme_font_size_override("font_size", 13)
		line.add_child(right)
		node.add_child(line)
		var has_in := row < inputs.size()
		var has_out := row < outputs.size()
		var in_type: int = inputs[row][1] if has_in else 0
		var out_type: int = outputs[row][1] if has_out else 0
		node.set_slot(row, has_in, in_type, LogicNodes.TYPE_COLORS[in_type], has_out, out_type, LogicNodes.TYPE_COLORS[out_type])
	for param in def["params"]:
		node.add_child(_param_control(id, param))
	if def["cat"] == "codigo":
		var error := Label.new()
		error.name = "CodeStatus"
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		error.custom_minimum_size.x = 340
		error.add_theme_font_size_override("font_size", 12)
		node.add_child(error)
		_error_labels[id] = error
		_check_code(id)
	return node


func _port_label(port: Array) -> String:
	if port[1] == LogicNodes.EXEC:
		return "▶" if str(port[2]) == "" else "▶ " + tr(port[2])
	return tr(port[2])


func _param_control(id: int, param: Array) -> Control:
	var name: String = param[0]
	var kind: String = param[1]
	var value: Variant = graph.nodes[id]["params"].get(name, param[3])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if kind != "code" and kind != "note":
		var label := Label.new()
		label.text = tr(param[2])
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.75, 0.73, 0.85))
		box.add_child(label)
	var control: Control
	match kind:
		"number":
			var spin := SpinBox.new()
			spin.min_value = -1000000
			spin.max_value = 1000000
			spin.step = 0.01 if name == "segundos" else 1.0
			spin.value = float(value)
			spin.custom_minimum_size.x = 150
			spin.value_changed.connect(func(v: float) -> void: _set_param(id, name, v))
			control = spin
		"bool":
			var check := CheckBox.new()
			check.text = tr("Sí")
			check.button_pressed = value == true
			check.toggled.connect(func(v: bool) -> void: _set_param(id, name, v))
			control = check
		"text", "tag":
			var edit := LineEdit.new()
			edit.text = str(value)
			edit.custom_minimum_size.x = 170
			edit.placeholder_text = tr("etiqueta") if kind == "tag" else ""
			edit.text_changed.connect(func(v: String) -> void: _set_param(id, name, v))
			control = edit
		"key":
			control = _options(LogicNodes.KEYS.map(func(k: String) -> Array: return [k, k]), str(value), func(v: Variant) -> void: _set_param(id, name, str(v)))
		"zone":
			var zones: Array = [["", tr("(ninguna)")]] + (zones_provider.call() if zones_provider.is_valid() else [])
			control = _options(zones, str(value), func(v: Variant) -> void: _set_param(id, name, str(v)))
		"button", "counter", "element":
			var provider: Callable = {"button": buttons_provider, "counter": counters_provider, "element": elements_provider}[kind]
			var items: Array = [[0, tr("(ninguno)")]] + (provider.call() if provider.is_valid() else [])
			control = _options(items, int(value), func(v: Variant) -> void: _set_param(id, name, int(v)))
		"note":
			var note := TextEdit.new()
			note.text = str(value)
			note.custom_minimum_size = Vector2(260, 90)
			note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			note.text_changed.connect(func() -> void: _set_param(id, name, note.text))
			control = note
		"code":
			var code := CodeEdit.new()
			code.name = "Code"
			code.text = str(value)
			code.custom_minimum_size = Vector2(380, 170)
			code.gutters_draw_line_numbers = true
			code.indent_automatic = true
			code.auto_brace_completion_enabled = true
			code.syntax_highlighter = _highlighter()
			code.add_theme_font_size_override("font_size", 13)
			code.text_changed.connect(func() -> void:
				_set_param(id, name, code.text)
				_check_code(id)
			)
			control = code
		_:
			if kind.begins_with("choice:"):
				var options: Array = LogicNodes.choice_options(kind).map(func(o: String) -> Array: return [o, o])
				control = _options(options, str(value), func(v: Variant) -> void: _set_param(id, name, str(v)))
			else:
				control = Label.new()
	control.name = "Param_" + name
	box.add_child(control)
	_param_controls["%d:%s" % [id, name]] = control
	return box


func _options(items: Array, current: Variant, on_change: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.x = 170
	option.clip_text = true
	var selected := -1
	for item in items:
		option.add_item(str(item[1]))
		option.set_item_metadata(option.item_count - 1, item[0])
		if str(item[0]) == str(current):
			selected = option.item_count - 1
	# Una zona guardada por su nombre (plantillas) también se reconoce.
	if selected < 0:
		for i in option.item_count:
			if option.get_item_text(i) == str(current):
				selected = i
	option.select(maxi(selected, 0))
	option.item_selected.connect(func(index: int) -> void: on_change.call(option.get_item_metadata(index)))
	return option


func _highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color("9be7c4")
	h.symbol_color = Color("c9c5ef")
	h.function_color = Color("7fb3ff")
	h.member_variable_color = Color("e6e1ff")
	for keyword in GdSandbox.KEYWORDS:
		h.add_keyword_color(keyword, Color("ff8fa3"))
	h.add_keyword_color("mesa", Color("ffd36b"))
	h.add_color_region("\"", "\"", Color("ffe39b"))
	h.add_color_region("'", "'", Color("ffe39b"))
	h.add_color_region("#", "", Color("8b87b3"), true)
	return h


# --- Cambios ------------------------------------------------------------------------

func _change(key: String) -> void:
	if not _building and before_change.is_valid():
		before_change.call(key)


func _set_param(id: int, name: String, value: Variant) -> void:
	if _building or not graph.nodes.has(id):
		return
	_change("logic_param:%d:%s" % [id, name])
	graph.nodes[id]["params"][name] = value


func _check_code(id: int) -> String:
	if not _error_labels.has(id) or not graph.nodes.has(id):
		return ""
	var problem := GdSandbox.check(str(graph.nodes[id]["params"].get("codigo", "")))
	var label: Label = _error_labels[id]
	label.text = ("✓ " + tr("Código válido")) if problem == "" else ("⚠ " + problem)
	label.add_theme_color_override("font_color", Color("5fd0a0") if problem == "" else Color("ff8f80"))
	return problem


## Comprueba todo: código y que haya algún evento. Devuelve los problemas.
func check_all() -> Array:
	var problems: Array = []
	for id in _error_labels:
		var problem := _check_code(int(id))
		if problem != "":
			problems.append(problem)
	if graph != null and not graph.is_empty() and not graph.nodes.values().any(func(n: Dictionary) -> bool: return LogicNodes.is_event(n["type"])):
		problems.append(tr("No hay ningún evento: la lógica no empezará nunca."))
	return problems


func _sync_links() -> void:
	graph_edit.clear_connections()
	var linked := {}
	for link in graph.links:
		var from_type: String = graph.nodes[link["from"]]["type"]
		var to_type: String = graph.nodes[link["to"]]["type"]
		graph_edit.connect_node(str(link["from"]), LogicNodes.port_index(LogicNodes.outputs(from_type), link["out"]),
			str(link["to"]), LogicNodes.port_index(LogicNodes.inputs(to_type), link["in"]))
		linked["%d:%s" % [link["to"], link["in"]]] = true
	# Una entrada con cable no usa su valor escrito: se apaga para que se note.
	for key in _param_controls:
		var control: Control = _param_controls[key]
		var off := linked.has(key)
		control.modulate.a = 0.35 if off else 1.0
		if control is BaseButton:
			(control as BaseButton).disabled = off
		elif control is SpinBox:
			(control as SpinBox).editable = not off
		elif control is LineEdit:
			(control as LineEdit).editable = not off


func _port_name(node_name: StringName, port: int, output: bool) -> String:
	var type: String = graph.nodes[int(str(node_name))]["type"]
	var ports: Array = LogicNodes.outputs(type) if output else LogicNodes.inputs(type)
	return ports[port][0] if port >= 0 and port < ports.size() else ""


func _on_connection_request(from: StringName, from_port: int, to: StringName, to_port: int) -> void:
	var out := _port_name(from, from_port, true)
	var input := _port_name(to, to_port, false)
	var out_type := LogicNodes.port_type(LogicNodes.outputs(graph.nodes[int(str(from))]["type"]), out)
	var in_type := LogicNodes.port_type(LogicNodes.inputs(graph.nodes[int(str(to))]["type"]), input)
	# Sólo cuenta (y se puede deshacer) si el cable vale.
	if from == to or out_type < 0 or in_type < 0 or not LogicNodes.compatible(out_type, in_type):
		return
	_change("logic_link")
	graph.connect_ports(int(str(from)), out, int(str(to)), input)
	_sync_links()


func _on_disconnection_request(from: StringName, from_port: int, to: StringName, to_port: int) -> void:
	_change("logic_unlink")
	graph.disconnect_ports(int(str(from)), _port_name(from, from_port, true), int(str(to)), _port_name(to, to_port, false))
	_sync_links()


func _on_delete_request(names: Array) -> void:
	if names.is_empty():
		return
	_change("logic_delete")
	for name in names:
		var id := int(str(name))
		graph.remove_node(id)
		var node := graph_edit.get_node_or_null(NodePath(str(name)))
		if node != null:
			graph_edit.remove_child(node)
			node.queue_free()
		_error_labels.erase(id)
	for key in _param_controls.keys():
		if not graph.nodes.has(int(str(key).get_slice(":", 0))):
			_param_controls.erase(key)
	_sync_links()


func delete_selected() -> void:
	_on_delete_request(_selected_names())


func _selected_names() -> Array:
	var names: Array = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected:
			names.append(child.name)
	return names


func _duplicate_selected() -> void:
	var names := _selected_names()
	if names.is_empty():
		return
	_change("logic_duplicate")
	var mapping := {}
	for name in names:
		var source: Dictionary = graph.nodes[int(str(name))]
		var id := graph.add_node(source["type"], source["pos"] + Vector2(40, 40))
		if id == 0:
			continue
		graph.nodes[id]["params"] = source["params"].duplicate(true)
		mapping[int(str(name))] = id
	# Los cables entre bloques copiados también se copian.
	for link in graph.links.duplicate():
		if mapping.has(link["from"]) and mapping.has(link["to"]):
			graph.connect_ports(mapping[link["from"]], link["out"], mapping[link["to"]], link["in"])
	rebuild()
	for id in mapping.values():
		var node := graph_edit.get_node_or_null(NodePath(str(id))) as GraphNode
		if node != null:
			node.selected = true


func _on_moved() -> void:
	_change("logic_move")
	for child in graph_edit.get_children():
		if child is GraphNode and graph.nodes.has(int(str(child.name))):
			graph.nodes[int(str(child.name))]["pos"] = (child as GraphNode).position_offset


## Ordena los bloques automáticamente (los seleccionados, o todos si no hay selección).
func arrange_blocks() -> void:
	_change("logic_arrange")
	var any_selected := not _selected_names().is_empty()
	if not any_selected:
		for child in graph_edit.get_children():
			if child is GraphNode:
				child.selected = true
	graph_edit.arrange_nodes()
	for child in graph_edit.get_children():
		if child is GraphNode:
			if graph.nodes.has(int(str(child.name))):
				graph.nodes[int(str(child.name))]["pos"] = (child as GraphNode).position_offset
			if not any_selected:
				child.selected = false


func _show_api_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = tr("Lo que puede hacer un bloque GDScript")
	dialog.dialog_text = tr("Entradas: a y b. Devuelve un valor con return. Bucles: for x in lista, o for i in mesa.rango(n).") + "\n\n" + TableApi.HELP
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(720, 460))
