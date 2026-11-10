class_name TabletopCamera3D
extends Node3D

## Vista elegida con V (queja 15 de TTS): "" libre, "top" cenital o "seat1".."seat4".
signal view_changed(view_name: String)

@export var focus := Vector3(0, 0.8, 0)
@export var distance := 8.5
@export var min_distance := 3.0
@export var max_distance := 18.0
@export var orbit_sensitivity := 0.006
@export var pan_sensitivity := 0.0015
@export var zoom_factor := 0.88
@export var smoothing := 12.0
@export_range(10.0, 85.0) var min_elevation := 15.0
@export_range(10.0, 89.0) var max_elevation := 80.0
## Asientos alrededor de la mesa para las vistas por asiento (1 abajo, 2 enfrente, 3 y 4 a
## los lados).
@export_range(0, 4) var seat_count := 4

const VIEW_ORDER := ["top", "seat1", "seat2", "seat3", "seat4", ""]
const SEAT_YAWS := [0.0, PI, PI * 0.5, -PI * 0.5]
const TOP_ELEVATION := deg_to_rad(89.0)
const SEAT_ELEVATION := deg_to_rad(48.0)

var current_view := ""
var _view_tween: Tween

var _yaw := 0.65
var _elevation := 0.8
var _target_distance: float
var _initial_focus: Vector3
var _initial_distance: float
var _initial_yaw: float
var _initial_elevation: float
# Solo durante la vida de esta escena; no cambia el guardado de partidas.
var _bookmarks: Dictionary = {}
var _view_notice: Label
var _notice_until := 0
var _trauma := 0.0
var _trauma_phase := 0.0
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_target_distance = clampf(distance, min_distance, max_distance)
	distance = _target_distance
	_initial_focus = focus
	_initial_distance = distance
	_initial_yaw = _yaw
	_initial_elevation = _elevation
	_update_camera()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_view_notice = Label.new()
	_view_notice.name = "CameraViewNotice"
	_view_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_view_notice.offset_left = -220
	_view_notice.offset_right = 220
	_view_notice.offset_top = 156
	_view_notice.offset_bottom = 192
	_view_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view_notice.add_theme_color_override("font_color", Color.WHITE)
	_view_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	_view_notice.add_theme_constant_override("shadow_offset_x", 2)
	_view_notice.add_theme_constant_override("shadow_offset_y", 2)
	_view_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_notice.visible = false
	layer.add_child(_view_notice)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus_control := get_viewport().gui_get_focus_owner()
		if focus_control is LineEdit or focus_control is TextEdit:
			return
		var grabber := get_parent().find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
		if grabber != null and (is_instance_valid(grabber.held) or grabber._pending_press):
			return
		var number_key: int = (
			event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		)
		if (
			event.keycode == KEY_V
			and not event.ctrl_pressed
			and not event.alt_pressed
			and not event.meta_pressed
		):
			cycle_view(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		elif (
			event.keycode == KEY_HOME
			and not event.ctrl_pressed
			and not event.alt_pressed
			and not event.meta_pressed
		):
			reset_view()
			get_viewport().set_input_as_handled()
		elif (
			number_key >= KEY_1
			and number_key <= KEY_3
			and not event.alt_pressed
			and not event.meta_pressed
		):
			var slot: int = number_key - KEY_1 + 1
			if event.ctrl_pressed and not event.shift_pressed:
				save_bookmark(slot)
				_notice("Vista %d guardada para esta mesa." % slot)
				get_viewport().set_input_as_handled()
			elif event.shift_pressed and not event.ctrl_pressed:
				_notice(
					(
						"Vista %d recuperada." % slot
						if load_bookmark(slot)
						else "Vista %d vacía." % slot
					)
				)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(min_distance, _target_distance * zoom_factor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(max_distance, _target_distance / zoom_factor)
	elif event is InputEventMouseMotion:
		var pan: bool = (
			(event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
			or ((event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0 and event.shift_pressed)
		)
		if pan:
			var right := camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			var backward := Vector3(-right.z, 0, right.x)
			focus += (
				(-right * event.relative.x + backward * event.relative.y)
				* distance
				* pan_sensitivity
			)
		elif (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_stop_view_tween()
			_yaw -= event.relative.x * orbit_sensitivity
			_elevation = clampf(
				_elevation + event.relative.y * orbit_sensitivity,
				deg_to_rad(min_elevation),
				deg_to_rad(max_elevation)
			)


## Vistas disponibles en orden de V: cenital, asientos y vuelta a la vista inicial.
func available_views() -> Array[String]:
	var list: Array[String] = []
	for view_name in VIEW_ORDER:
		if view_name.begins_with("seat") and int(view_name.substr(4)) > seat_count:
			continue
		list.append(view_name)
	return list


func cycle_view(direction := 1) -> String:
	var views := available_views()
	var index := views.find(current_view)
	var next: String = views[posmod(index + direction, views.size())]
	set_view(next)
	return next


static func view_title(view_name: String) -> String:
	if view_name == "top":
		return TranslationServer.translate("Vista cenital")
	if view_name.begins_with("seat"):
		return TranslationServer.translate("Asiento %s") % view_name.substr(4)
	return TranslationServer.translate("Vista inicial")


## Cambia de vista con una transición corta (instantánea si se pide o con movimiento reducido).
func set_view(view_name: String, instant := false) -> void:
	var target_yaw := _initial_yaw
	var target_elevation := _initial_elevation
	var target_distance := _initial_distance
	if view_name == "top":
		target_yaw = _seat_yaw(current_view) if current_view.begins_with("seat") else 0.0
		target_elevation = TOP_ELEVATION
		target_distance = _initial_distance * 1.05
	elif view_name.begins_with("seat"):
		target_yaw = _seat_yaw(view_name)
		target_elevation = SEAT_ELEVATION
		target_distance = _initial_distance * 0.88
	current_view = view_name
	target_yaw = _yaw + wrapf(target_yaw - _yaw, -PI, PI)
	_stop_view_tween()
	var style := get_node_or_null("/root/ToonStyle")
	if instant or (style != null and style.reduce_motion) or not is_inside_tree():
		_yaw = target_yaw
		_elevation = target_elevation
		focus = _initial_focus
		distance = target_distance
		_target_distance = target_distance
		_update_camera()
	else:
		_target_distance = target_distance
		_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_view_tween.tween_property(self, "_yaw", target_yaw, 0.45)
		_view_tween.tween_property(self, "_elevation", target_elevation, 0.45)
		_view_tween.tween_property(self, "focus", _initial_focus, 0.45)
	if _view_notice != null:
		_notice(tr("%s  ·  V cambia de vista") % view_title(view_name))
	view_changed.emit(view_name)


func _seat_yaw(view_name: String) -> float:
	var seat := clampi(int(view_name.substr(4)) - 1, 0, SEAT_YAWS.size() - 1)
	return SEAT_YAWS[seat]


func _stop_view_tween() -> void:
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
	_view_tween = null


func has_bookmark(slot: int) -> bool:
	return _bookmarks.has(slot)


func save_bookmark(slot: int) -> bool:
	if slot < 1 or slot > 3:
		return false
	# Guardamos lo que se está viendo, incluso durante el suavizado de zoom.
	_bookmarks[slot] = {"focus": focus, "distance": distance, "yaw": _yaw, "elevation": _elevation}
	return true


func load_bookmark(slot: int) -> bool:
	if not _bookmarks.has(slot):
		return false
	var view: Dictionary = _bookmarks[slot]
	focus = view["focus"]
	distance = view["distance"]
	_target_distance = distance
	_yaw = view["yaw"]
	_elevation = view["elevation"]
	_update_camera()
	return true


func reset_view() -> void:
	focus = _initial_focus
	distance = _initial_distance
	_target_distance = _initial_distance
	_yaw = _initial_yaw
	_elevation = _initial_elevation
	_update_camera()


func _notice(message: String) -> void:
	_view_notice.text = message
	_view_notice.visible = true
	_notice_until = Time.get_ticks_msec() + 2500


func add_trauma(amount: float) -> void:
	var style := get_node_or_null("/root/ToonStyle")
	if style != null and style.reduce_motion:
		_trauma = 0.0
		return
	_trauma = clampf(_trauma + maxf(amount, 0.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if _view_notice.visible and Time.get_ticks_msec() >= _notice_until:
		_view_notice.visible = false
	if _trauma > 0.0:
		var style := get_node_or_null("/root/ToonStyle")
		if style != null and style.reduce_motion:
			_trauma = 0.0
		else:
			_trauma_phase += delta * 46.0
			_trauma = maxf(_trauma - delta * 4.8, 0.0)
	distance = lerpf(distance, _target_distance, 1.0 - exp(-smoothing * delta))
	_update_camera()


func _update_camera() -> void:
	var offset := (
		Vector3(sin(_yaw) * cos(_elevation), sin(_elevation), cos(_yaw) * cos(_elevation))
		* distance
	)
	var shake := Vector3.ZERO
	if _trauma > 0.001:
		var power := _trauma * _trauma
		shake = Vector3(
			sin(_trauma_phase * 1.3) * 0.024 * power,
			cos(_trauma_phase * 1.9) * 0.036 * power,
			sin(_trauma_phase * 1.1) * 0.018 * power
		)
	camera.global_position = focus + offset + shake
	camera.look_at(focus + shake * 0.65, Vector3.UP)
