class_name PhysicsGrabber3D
extends Node

signal selection_changed(object: InteractiveTableObject)
@export var camera: Camera3D
@export_flags_3d_physics var ray_mask := 3
@export var ray_length := 100.0
@export var lift_height := 0.55
@export var spring_strength := 55.0
@export var velocity_damping := 14.0
@export var max_acceleration := 75.0
@export var max_release_speed := 5.0

var hovered: InteractiveTableObject
var held: InteractiveTableObject
var _grab_offset := Vector3.ZERO
var _drag_height := 0.0
var _target := Vector3.ZERO
var _pending_press := false
var _pending_release := false
var _press_position := Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pending_release = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pending_press = true
			_press_position = event.position
		else:
			_pending_release = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var selected := held if is_instance_valid(held) else hovered
		if not is_instance_valid(selected):
			return
		match event.keycode:
			KEY_R:
				selected.rotate_object(1.0)
			KEY_T:
				if selected is Dice3D and not is_instance_valid(held):
					selected.roll()
			KEY_F:
				if selected is Card3D and not is_instance_valid(held):
					selected.flip()
			KEY_N:
				if selected is Deck3D and not is_instance_valid(held):
					selected.draw_card()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var mouse := camera.get_viewport().get_mouse_position()
	if _pending_press:
		_pending_press = false
		_update_hover(_press_position)
		if is_instance_valid(hovered):
			_begin_grab(_press_position)
	if _pending_release:
		_pending_release = false
		_release()
	if is_instance_valid(held):
		var hit = _plane_point(mouse, _drag_height)
		if hit != null:
			_target = hit + _grab_offset
		var acceleration := (
			(_target - held.global_position) * spring_strength
			- held.linear_velocity * velocity_damping
		)
		acceleration += (
			Vector3.UP
			* float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
			* held.gravity_scale
		)
		held.apply_central_force(acceleration.limit_length(max_acceleration) * held.mass)
	else:
		held = null
		_update_hover(mouse)


func _update_hover(mouse: Vector2) -> void:
	var origin := camera.project_ray_origin(mouse)
	var end := origin + camera.project_ray_normal(mouse) * ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end, ray_mask)
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var next: InteractiveTableObject = null
	if not result.is_empty() and result.collider is InteractiveTableObject:
		next = result.collider
	if next == hovered:
		return
	if is_instance_valid(hovered):
		hovered.set_hovered(false)
	hovered = next
	if is_instance_valid(hovered):
		hovered.set_hovered(true)
	selection_changed.emit(hovered)


func _begin_grab(mouse: Vector2) -> void:
	if hovered.freeze:
		return
	held = hovered
	_drag_height = held.global_position.y + lift_height
	var point = _plane_point(mouse, _drag_height)
	if point == null:
		held = null
		return
	_grab_offset = held.global_position - point
	_grab_offset.y = 0.0
	_target = point + _grab_offset
	held.on_grab()


func _release() -> void:
	if is_instance_valid(held):
		held.linear_velocity = held.linear_velocity.limit_length(max_release_speed)
		held.on_release()
	held = null


func _plane_point(mouse: Vector2, height: float) -> Variant:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return null
	var t := (height - origin.y) / direction.y
	if t < 0.0 or t > ray_length:
		return null
	return origin + direction * t
