class_name TabletopCamera3D
extends Node3D

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
	_view_notice.offset_top = 20
	_view_notice.offset_bottom = 56
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
			_yaw -= event.relative.x * orbit_sensitivity
			_elevation = clampf(
				_elevation + event.relative.y * orbit_sensitivity,
				deg_to_rad(min_elevation),
				deg_to_rad(max_elevation)
			)


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


func _process(delta: float) -> void:
	if _view_notice.visible and Time.get_ticks_msec() >= _notice_until:
		_view_notice.visible = false
	distance = lerpf(distance, _target_distance, 1.0 - exp(-smoothing * delta))
	_update_camera()


func _update_camera() -> void:
	var offset := (
		Vector3(sin(_yaw) * cos(_elevation), sin(_elevation), cos(_yaw) * cos(_elevation))
		* distance
	)
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
