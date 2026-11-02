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
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_target_distance = clampf(distance, min_distance, max_distance)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(min_distance, _target_distance * zoom_factor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(max_distance, _target_distance / zoom_factor)
	elif event is InputEventMouseMotion:
		var pan : bool = (
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


func _process(delta: float) -> void:
	distance = lerpf(distance, _target_distance, 1.0 - exp(-smoothing * delta))
	_update_camera()


func _update_camera() -> void:
	var offset := (
		Vector3(sin(_yaw) * cos(_elevation), sin(_elevation), cos(_yaw) * cos(_elevation))
		* distance
	)
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)
