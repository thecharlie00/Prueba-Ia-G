class_name TableHud
extends CanvasLayer
## Interfaz integrada en la mesa (fase 1): en vez de un panel lateral fijo, cada mesa muestra
## - un cartel de turno arriba,
## - los jugadores sentados alrededor de la mesa (TableSeats),
## - una barra de acciones de juego abajo y un bocadillo con la pista del momento,
## - fichas con datos sueltos (resultado del dado, cadena del dominó…) abajo a la izquierda,
## - y un cajón ☰ con el panel original para guardar, cargar, cambiar de modo y ajustes.
##
## No sustituye al panel original: lo refleja. Los botones de la barra pulsan los originales y
## copian su texto y estado, así que la lógica de cada juego y sus tests no cambian.
##
## Uso, al final del _ready de una vista:  TableHud.attach(self)
## La vista puede definir hud_config() -> Dictionary para ajustar lo que se descubre por nombre,
## hud_seats() -> Array y hud_active_seat() -> int para los jugadores, y
## hud_seat_status(index) -> String para el texto bajo cada nombre.

## Botones que van a la barra de acciones si existen en el panel (por nombre de nodo).
const DOCK_NAMES := ["Undo", "Rewind", "Claim", "Draw", "ToHand", "Pass", "Shuffle", "Roll"]
## Etiquetas que se muestran como fichas de información.
const INFO_NAMES := ["Result", "Selection", "Selected", "Chain"]

var view: Node
var panel: Control
var status_label: Label
var title_label: Label
var hint_label: Label
var info_labels: Array[Label] = []
var actions: Array[BaseButton] = []
var seats: TableSeats

var _banner_title: Label
var _banner_status: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _dock: HBoxContainer
var _info_box: VBoxContainer
var _plaques: HBoxContainer
var _plaque_signature := ""
var _proxies: Array[BaseButton] = []
var _info_chips: Array[Label] = []
var _drawer_button: Button
var _last_hint := ""
var _hint_time := 0.0
var _seat_signature := ""
var _seat_check := 0.0


static func attach(target: Node) -> TableHud:
	var hud := TableHud.new()
	hud.name = "TableHud"
	hud.view = target
	target.add_child(hud)
	return hud


func _ready() -> void:
	layer = 4
	_discover()
	_build()
	_build_seats()
	set_drawer_open(false)


func set_drawer_open(open: bool) -> void:
	if panel != null:
		panel.visible = open
	if _drawer_button != null:
		_drawer_button.text = "✕  Cerrar" if open else "☰  Partida"


func is_drawer_open() -> bool:
	return panel != null and panel.visible


func _discover() -> void:
	var config: Dictionary = view.hud_config() if view.has_method("hud_config") else {}
	panel = config.get("panel", _find_panel())
	var root: Node = panel if panel != null else view
	status_label = config.get("status", _find_label(root, "Status"))
	title_label = config.get("title_label", _find_label(root, "Title"))
	hint_label = config.get("hint", _find_label(root, "Help"))
	if config.has("info"):
		info_labels.assign(config["info"])
	else:
		for label_name in INFO_NAMES:
			var label := _find_label(root, label_name)
			if label != null:
				info_labels.append(label)
	if config.has("actions"):
		actions.assign(config["actions"])
	elif panel != null:
		for node in panel.find_children("*", "BaseButton", true, false):
			if node.name in DOCK_NAMES and not (node is OptionButton):
				actions.append(node)
	if config.has("title"):
		_static_title = str(config["title"])


var _static_title := ""


func _find_panel() -> Control:
	for child in view.get_children():
		if child is CanvasLayer and child != self:
			for node in child.find_children("*", "PanelContainer", true, false):
				return node
	return null


func _find_label(root: Node, label_name: String) -> Label:
	if root == null:
		return null
	return root.find_child(label_name, true, false) as Label


func _build() -> void:
	var screen := Control.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)

	# Cartel de turno, arriba al centro.
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 14
	top.offset_bottom = 110
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(top)
	var banner := PanelContainer.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(banner)
	var banner_column := VBoxContainer.new()
	banner_column.add_theme_constant_override("separation", 0)
	banner_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_column)
	_banner_title = _make_label(13, Palette.LAVENDER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_column.add_child(_banner_title)
	_banner_status = _make_label(24, Palette.PAPER)
	_banner_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_status.name = "TurnText"
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		_banner_status.add_theme_font_override("font", style.DISPLAY_FONT)
	banner_column.add_child(_banner_status)

	# Botón del cajón, arriba a la derecha (Esc sigue abriendo la pausa).
	_drawer_button = Button.new()
	_drawer_button.name = "DrawerButton"
	_drawer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_drawer_button.offset_left = -170
	_drawer_button.offset_top = 16
	_drawer_button.offset_right = -18
	_drawer_button.offset_bottom = 54
	_drawer_button.tooltip_text = "Guardar, cargar, cambiar de modo y opciones"
	_drawer_button.pressed.connect(func() -> void: set_drawer_open(not is_drawer_open()))
	screen.add_child(_drawer_button)

	# Barra de acciones y bocadillo, abajo al centro.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -16
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(bottom)
	_bubble = PanelContainer.new()
	_bubble.name = "HintBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bubble_box := StyleBoxFlat.new()
	bubble_box.bg_color = Palette.PAPER
	bubble_box.border_color = Palette.INK
	bubble_box.set_border_width_all(3)
	bubble_box.set_corner_radius_all(16)
	bubble_box.content_margin_left = 16
	bubble_box.content_margin_right = 16
	bubble_box.content_margin_top = 8
	bubble_box.content_margin_bottom = 8
	bubble_box.shadow_color = Palette.INK
	bubble_box.shadow_size = 1
	bubble_box.shadow_offset = Vector2(4, 4)
	_bubble.add_theme_stylebox_override("panel", bubble_box)
	# Pista del momento bajo el cartel de turno: la parte de abajo queda para la barra de
	# acciones y la mano de cartas.
	var hint_row := CenterContainer.new()
	hint_row.name = "HintRow"
	hint_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_row.offset_top = 92
	hint_row.offset_bottom = 150
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(hint_row)
	hint_row.add_child(_bubble)
	_bubble_text = _make_label(15, Palette.INK)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size.x = 0
	_bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_child(_bubble_text)
	_dock = HBoxContainer.new()
	_dock.name = "ActionDock"
	_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	_dock.add_theme_constant_override("separation", 10)
	_dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_dock)
	for original in actions:
		var proxy := Button.new()
		proxy.name = "Act" + String(original.name)
		proxy.custom_minimum_size = Vector2(120, 46)
		proxy.add_theme_font_size_override("font_size", 17)
		proxy.toggle_mode = original.toggle_mode
		proxy.focus_mode = Control.FOCUS_NONE
		if original.toggle_mode:
			proxy.toggled.connect(func(on: bool) -> void: original.button_pressed = on)
		else:
			proxy.pressed.connect(func() -> void: original.pressed.emit())
		_dock.add_child(proxy)
		_proxies.append(proxy)

	# Fichas de información, abajo a la izquierda.
	# Fichas de los jugadores sentados del lado de la cámara (abajo a la izquierda, sobre
	# las fichas de información).
	_plaques = HBoxContainer.new()
	_plaques.name = "NearPlayers"
	_plaques.add_theme_constant_override("separation", 10)
	_plaques.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box = VBoxContainer.new()
	_info_box.name = "InfoChips"
	_info_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_box.offset_left = 18
	_info_box.offset_bottom = -18
	_info_box.offset_right = 360
	_info_box.alignment = BoxContainer.ALIGNMENT_END
	_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_info_box)
	_info_box.add_child(_plaques)
	for i in info_labels.size():
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := _make_label(13, Palette.PAPER)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.add_child(text)
		_info_box.add_child(chip)
		_info_chips.append(text)
	_sync()


func _build_seats() -> void:
	if not view.has_method("hud_seats") or not (view is Node3D):
		return
	var list: Array = view.hud_seats()
	_seat_signature = str(list)
	if list.is_empty():
		return
	if seats == null:
		seats = TableSeats.new()
		seats.name = "TableSeats"
		view.add_child(seats)
	seats.setup(_place_seats(list))
	seats.center = _table_bounds().get_center()
	_plaque_signature = ""


# Los asientos cambian si cambia el rival (persona o IA) o el número de jugadores.
func _refresh_seats(delta: float) -> void:
	_seat_check += delta
	if _seat_check < 0.5 or not view.has_method("hud_seats"):
		return
	_seat_check = 0.0
	if str(view.hud_seats()) != _seat_signature:
		_build_seats()


## Convierte asientos con "side" (north, south, east, west, o esquinas como north_east) en
## posiciones alrededor de la mesa de la escena, salvo que ya traigan "position".
func _place_seats(list: Array) -> Array:
	var bounds := _table_bounds()
	var center := bounds.get_center()
	var floor_y := bounds.position.y - 0.85
	var half := Vector2(bounds.size.x, bounds.size.z) * 0.5
	var placed := []
	for item in list:
		var seat: Dictionary = item.duplicate()
		if not seat.has("position"):
			var side := str(seat.get("side", "north"))
			var dir := Vector2.ZERO
			if side.contains("north"):
				dir.y = -1.0
			if side.contains("south"):
				dir.y = 1.0
			if side.contains("east"):
				dir.x = 1.0
			if side.contains("west"):
				dir.x = -1.0
			var offset := Vector2(dir.x * (half.x + 0.75), dir.y * (half.y + 0.75))
			if dir.x != 0.0 and dir.y != 0.0:
				offset = Vector2(dir.x * (half.x + 0.35), dir.y * (half.y + 0.35))
			seat["position"] = Vector3(center.x + offset.x, floor_y, center.z + offset.y)
		seat["look_at"] = Vector3(center.x, floor_y, center.z)
		placed.append(seat)
	return placed


func _table_bounds() -> AABB:
	var table := (view as Node).find_child("Table", true, false) as Node3D
	if table != null:
		for node in [table] + table.find_children("*", "MeshInstance3D", true, false):
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var mesh_node := node as MeshInstance3D
				return mesh_node.global_transform * mesh_node.mesh.get_aabb()
	return AABB(Vector3(-3.4, 0.68, -2.3), Vector3(6.8, 0.24, 4.6))


func _process(delta: float) -> void:
	_refresh_seats(delta)
	_sync()
	if _bubble.visible:
		_hint_time += delta


func _sync() -> void:
	var title := _static_title
	if title.is_empty() and title_label != null:
		title = title_label.text
	_banner_title.text = title.to_upper()
	_banner_title.visible = not title.is_empty()
	var status := status_label.text if status_label != null else ""
	_banner_status.text = status
	_banner_status.get_parent().get_parent().visible = not (status.is_empty() and title.is_empty())
	var hint := hint_label.text.strip_edges() if hint_label != null else ""
	if hint != _last_hint:
		_last_hint = hint
		_hint_time = 0.0
	_bubble_text.text = hint
	_bubble.visible = not hint.is_empty()
	_bubble_text.custom_minimum_size.x = minf(560.0, 9.0 * hint.length() + 20.0)
	for i in _proxies.size():
		var original := actions[i]
		var proxy := _proxies[i]
		if not is_instance_valid(original):
			proxy.visible = false
			continue
		proxy.text = original.text if original is Button else String(original.name)
		proxy.disabled = original.disabled
		proxy.visible = original.visible
		if original.toggle_mode and proxy.button_pressed != original.button_pressed:
			proxy.set_pressed_no_signal(original.button_pressed)
	for i in _info_chips.size():
		var source := info_labels[i]
		var text := source.text.strip_edges() if is_instance_valid(source) else ""
		_info_chips[i].text = text
		_info_chips[i].get_parent().visible = not text.is_empty()
	if seats != null and view.has_method("hud_active_seat"):
		var current: int = view.hud_active_seat()
		if current != seats.active:
			seats.set_active(current)
		if view.has_method("hud_seat_status"):
			for i in seats.seats.size():
				seats.set_status(i, view.hud_seat_status(i))
	_sync_plaques()


## Jugadores del lado de la cámara: ficha con su color, nombre, estado y turno.
func _sync_plaques() -> void:
	if seats == null or _plaques == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		seats.update_near(camera.global_position)
	var parts: Array[String] = []
	for i in seats.seats.size():
		if seats.near[i]:
			var status := str(view.hud_seat_status(i)) if view.has_method("hud_seat_status") else ""
			parts.append("%d|%s|%s|%s" % [i, seats.seats[i].get("name", ""), status, i == seats.active])
	var signature := ";".join(parts)
	if signature == _plaque_signature:
		return
	_plaque_signature = signature
	for child in _plaques.get_children():
		child.queue_free()
	for i in seats.seats.size():
		if seats.near[i]:
			_plaques.add_child(_make_plaque(i))
	_plaques.visible = not parts.is_empty()


func _make_plaque(index: int) -> Control:
	var seat: Dictionary = seats.seats[index]
	var on := index == seats.active
	var box := PanelContainer.new()
	box.name = "Plaque%d" % index
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SUN if on else Palette.PANEL
	style.border_color = Palette.INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.shadow_color = Palette.INK
	style.shadow_size = 1
	style.shadow_offset = Vector2(4, 4)
	style.content_margin_left = 10
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	# Cara redonda del color del jugador, como el personaje de la mesa.
	var face := Panel.new()
	face.custom_minimum_size = Vector2(38, 38)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face_style := StyleBoxFlat.new()
	face_style.bg_color = seat.get("color", Palette.SUN)
	face_style.border_color = Palette.INK
	face_style.set_border_width_all(3)
	face_style.set_corner_radius_all(19)
	face.add_theme_stylebox_override("panel", face_style)
	row.add_child(face)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var ink := Palette.INK if on else Palette.PAPER
	var name_label := _make_label(18, ink)
	var display: String = str(seat.get("name", "Jugador"))
	if bool(seat.get("bot", false)):
		display += " · bot"
	name_label.text = display
	if has_node("/root/ToonStyle"):
		name_label.add_theme_font_override("font", get_node("/root/ToonStyle").DISPLAY_FONT)
	text.add_child(name_label)
	var status := str(view.hud_seat_status(index)) if view.has_method("hud_seat_status") else ""
	if on:
		status = "Tu turno" if status.is_empty() else "Tu turno · " + status
	if not status.is_empty():
		var status_label_node := _make_label(13, Palette.INK if on else Palette.LAVENDER)
		status_label_node.text = status
		text.add_child(status_label_node)
	return box


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
