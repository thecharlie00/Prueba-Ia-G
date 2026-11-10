class_name RadialMenu
extends CanvasLayer
## Menú contextual radial (fase 2): clic derecho corto sobre una pieza muestra sus acciones
## en círculo, cada una con su atajo de teclado visible. Elegir una ejecuta la misma lógica
## que la tecla (PhysicsGrabber3D.apply_shortcut), así que se comporta igual en cada modo.
## Lo crea PhysicsGrabber3D; se cierra con Esc, clic derecho o clic fuera.

const RADIUS := 92.0
const BUTTON := Vector2(108, 46)

var grabber: PhysicsGrabber3D
var target: InteractiveTableObject
var actions: Array[Dictionary] = []

var _root: Control
var _press_position := Vector2.ZERO
var _press_time := 0
var _right_down := false


func _ready() -> void:
	name = "RadialMenu"
	layer = 6
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.gui_input.connect(_on_backdrop_input)
	add_child(_root)


func is_open() -> bool:
	return _root.visible


## Acciones disponibles para una pieza: {"label", "key", "keycode", "ctrl"}.
func actions_for(object: InteractiveTableObject) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if grabber != null and grabber.is_online_table():
		list.append({"label": "Señalar", "key": "P", "keycode": KEY_P})
		return list
	if object is TableUtility:
		list.append_array((object as TableUtility).radial_actions())
	if object is Dice3D and grabber.dice_shortcuts_enabled:
		list.append({"label": "Tirar", "key": "R", "keycode": KEY_R})
	if object is Deck3D:
		list.append({"label": "Robar", "key": "N", "keycode": KEY_N})
		list.append({"label": "Mezclar", "key": "R", "keycode": KEY_R})
	if object is Card3D or object is Domino3D:
		list.append({"label": "Voltear", "key": "F", "keycode": KEY_F})
	var table := grabber.get_parent()
	if object is Card3D and table != null and table.has_method("take_to_hand"):
		list.append({"label": "A la mano", "key": "M", "keycode": KEY_M})
		list.append({"label": "Al fondo", "key": "B", "keycode": KEY_B})
	list.append({"label": "Girar ↺", "key": "Q", "keycode": KEY_Q})
	list.append({"label": "Girar ↻", "key": "E", "keycode": KEY_E})
	if grabber.lock_shortcut_enabled:
		list.append(
			{"label": "Desbloquear" if object.is_table_locked else "Bloquear", "key": "L", "keycode": KEY_L}
		)
	list.append({"label": "Recuperar", "key": "H", "keycode": KEY_H})
	list.append({"label": "Señalar", "key": "P", "keycode": KEY_P})
	return list


func _input(event: InputEvent) -> void:
	if is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	if event.pressed:
		_right_down = true
		_press_position = event.position
		_press_time = Time.get_ticks_msec()
		return
	if not _right_down:
		return
	_right_down = false
	# Clic corto y sin arrastrar: arrastrar con el derecho sigue orbitando la cámara.
	var quick: bool = Time.get_ticks_msec() - _press_time < 350
	var still: bool = (event.position as Vector2).distance_to(_press_position) < 6.0
	if not quick or not still:
		return
	if is_instance_valid(grabber.held) or grabber._pending_press:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	var object := grabber.hovered
	if not is_instance_valid(object):
		return
	open(object, event.position)
	get_viewport().set_input_as_handled()


func open(object: InteractiveTableObject, at: Vector2) -> void:
	target = object
	actions = actions_for(object)
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	var screen := _root.get_viewport_rect().size
	var center := Vector2(
		clampf(at.x, RADIUS + BUTTON.x, screen.x - RADIUS - BUTTON.x),
		clampf(at.y, RADIUS + BUTTON.y, screen.y - RADIUS - BUTTON.y)
	)
	var hub := Label.new()
	hub.name = "Hub"
	hub.text = str(object.display_name).get_slice(" · ", 0)
	hub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub.add_theme_color_override("font_color", Palette.PAPER)
	hub.add_theme_color_override("font_outline_color", Palette.INK)
	hub.add_theme_constant_override("outline_size", 8)
	hub.add_theme_font_size_override("font_size", 15)
	hub.size = Vector2(160, 24)
	hub.position = center - hub.size * 0.5
	hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hub)
	var count := actions.size()
	for i in count:
		var angle := -PI / 2.0 + TAU * i / count
		var spot := center + Vector2(cos(angle), sin(angle)) * (RADIUS + 18.0)
		var button := _action_button(actions[i], i)
		button.position = spot - BUTTON * 0.5
		button.pivot_offset = BUTTON * 0.5
		_root.add_child(button)
		var style := get_node_or_null("/root/ToonStyle")
		if style == null or not style.reduce_motion:
			button.scale = Vector2.ONE * 0.3
			var tween := button.create_tween()
			tween.tween_interval(i * 0.015)
			tween.tween_property(button, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(
				Tween.EASE_OUT
			)
	_root.visible = true


func close() -> void:
	_root.visible = false
	target = null


## Ejecuta la acción i sobre la pieza del menú (también lo usan los tests).
func choose(index: int) -> void:
	if index < 0 or index >= actions.size() or not is_instance_valid(target):
		close()
		return
	var action := actions[index]
	var object := target
	close()
	var table := grabber.get_parent()
	match int(action["keycode"]):
		KEY_P:
			grabber.ping(object.global_position)
		KEY_M:
			table.take_to_hand(object)
		KEY_B:
			table._return_card(object)
		_:
			grabber.apply_shortcut(int(action["keycode"]), object)


func _action_button(action: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Action%d" % index
	button.custom_minimum_size = BUTTON
	button.size = BUTTON
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%s  %s" % [tr(action["label"]), action["key"]]
	button.tooltip_text = "%s (tecla %s)" % [action["label"], action["key"]]
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(choose.bind(index))
	return button


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		_root.accept_event()
