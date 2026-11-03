class_name PhysicsGrabber3D
extends Node

signal selection_changed(object: InteractiveTableObject)
signal grab_started(object: InteractiveTableObject)
signal grab_finished(object: InteractiveTableObject, target: Vector3, reason: String)
signal snap_status_changed(enabled: bool)
signal placement_message(message: String)
@export var camera: Camera3D
@export var snap_grid: SnapGrid3D
@export_flags_3d_physics var ray_mask := 3
@export var ray_length := 100.0
@export var lift_height := 0.18
@export var height_step := 0.15
@export var maximum_extra_height := 2.0
@export var recovery_surface_y := 0.8
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
var _release_reason := "released"
var _press_position := Vector2.ZERO
var _height_adjustment := 0.0
var _pending_recovery: InteractiveTableObject


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pending_press = false
		if is_instance_valid(held):
			_pending_release = true
			_release_reason = "cancelled"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# La liberación debe llegar también si termina encima de un botón de la UI.
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_instance_valid(held) or _pending_press:
				_pending_release = true
		if is_instance_valid(held) and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_height(height_step)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_height(-height_step)
				get_viewport().set_input_as_handled()


func _adjust_height(amount: float) -> void:
	_height_adjustment = clampf(
		_height_adjustment + amount, -lift_height + 0.05, maximum_extra_height
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pending_press = true
			_press_position = event.position
		else:
			_pending_release = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and is_instance_valid(snap_grid):
			snap_grid.enabled = not snap_grid.enabled
			snap_grid.show_candidate({})
			snap_status_changed.emit(snap_grid.enabled)
			return
		var selected := held if is_instance_valid(held) else hovered
		if not is_instance_valid(selected):
			return
		match event.keycode:
			KEY_H:
				_pending_recovery = selected
			KEY_R, KEY_T:
				if selected is Dice3D and not is_instance_valid(held):
					selected.roll()
				elif event.keycode == KEY_R and selected is Deck3D and not is_instance_valid(held):
					selected.shuffle_deck()
			KEY_E:
				selected.rotate_object(0.7)
			KEY_Q:
				selected.rotate_object(-0.7)
			KEY_F:
				if (selected is Card3D or selected is Domino3D) and not is_instance_valid(held):
					selected.flip()
			KEY_N:
				if selected is Deck3D and not is_instance_valid(held):
					selected.draw_card()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var mouse := camera.get_viewport().get_mouse_position()
	if _pending_press:
		_pending_press = false
		_update_hover(_press_position)
		if is_instance_valid(hovered):
			_begin_grab(_press_position)
	if is_instance_valid(_pending_recovery):
		_recover_object(_pending_recovery)
	_pending_recovery = null
	if is_instance_valid(held):
		var hit = _plane_point(mouse, _drag_height)
		if hit != null:
			_target = hit + _grab_offset
			_target.y = _target_height(held, _target)
			_drag_height = lerpf(_drag_height, _target.y, 1.0 - exp(-8.0 * delta))
		if is_instance_valid(snap_grid):
			snap_grid.show_candidate(snap_grid.candidate(held, _target))
	if _pending_release:
		_pending_release = false
		_release(_release_reason)
		_release_reason = "released"
	if is_instance_valid(held):
		_apply_held_force()
	else:
		held = null
		_update_hover(mouse)


func _apply_held_force() -> void:
	if not is_instance_valid(held):
		return
	var acceleration := (
		(_target - held.global_position) * spring_strength - held.linear_velocity * velocity_damping
	)
	acceleration += (
		Vector3.UP
		* float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		* held.gravity_scale
	)
	held.apply_central_force(acceleration.limit_length(max_acceleration) * held.mass)


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
	_height_adjustment = 0.0
	_drag_height = held.global_position.y + lift_height
	var point = _plane_point(mouse, _drag_height)
	if point == null:
		held = null
		return
	_grab_offset = held.global_position - point
	_grab_offset.y = 0.0
	_target = point + _grab_offset
	held.on_grab()
	grab_started.emit(held)


func _release(reason: String = "released") -> void:
	var released_object: InteractiveTableObject = held
	if is_instance_valid(held):
		var result: Dictionary = {}
		if reason == "released" and is_instance_valid(snap_grid):
			result = snap_grid.candidate(held, _target)
		if not result.is_empty() and result["valid"]:
			held.global_position = result["position"]
			held.linear_velocity = Vector3.ZERO
			held.angular_velocity = Vector3.ZERO
			placement_message.emit("Pieza colocada en la cuadrícula.")
		else:
			held.linear_velocity = held.linear_velocity.limit_length(max_release_speed)
			if not result.is_empty():
				placement_message.emit("Casilla ocupada: colocación libre.")
		held.on_release()
	if is_instance_valid(snap_grid):
		snap_grid.show_candidate({})
	held = null
	if is_instance_valid(released_object):
		grab_finished.emit(released_object, _target, reason)


# El objetivo sigue la superficie situada bajo el cursor, incluidos otros cuerpos.
func _target_height(object: InteractiveTableObject, desired: Vector3) -> float:
	var bottom: float = object.bottom_offset()
	if bottom < 0.0:
		return _drag_height
	var start := Vector3(desired.x, maxf(_drag_height, object.global_position.y) + 3.0, desired.z)
	var end := Vector3(desired.x, -10.0, desired.z)
	var query := PhysicsRayQueryParameters3D.create(start, end, ray_mask)
	query.exclude = [object.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _drag_height
	var surface: Vector3 = hit["position"]
	return surface.y + bottom + maxf(0.05, lift_height + _height_adjustment)


# H recupera una pieza en una posición libre. Es una acción explícita, no física.
func _recover_object(object: InteractiveTableObject) -> bool:
	if object.freeze:
		placement_message.emit("La pieza está ocupada; espera para recuperarla.")
		return false
	var shape_node := object.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var bottom: float = object.bottom_offset()
	if shape_node == null or shape_node.shape == null or bottom < 0.0:
		placement_message.emit("No se puede recuperar esta forma de colisión.")
		return false
	var shape_transform: Transform3D = object.global_transform * shape_node.transform
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.collision_mask = ray_mask
	query.exclude = [object.get_rid()]
	query.margin = 0.005
	for point in [
		Vector2(0.0, 0.5),
		Vector2(0.0, -1.4),
		Vector2(1.1, -1.4),
		Vector2(-2.4, 0.0),
		Vector2(2.5, 1.5)
	]:
		var destination := Vector3(point.x, recovery_surface_y + bottom + 0.04, point.y)
		query.transform = shape_transform
		query.transform.origin += destination - object.global_position
		if camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			var was_held: bool = object == held
			if was_held:
				object.on_release()
				held = null
				if is_instance_valid(snap_grid):
					snap_grid.show_candidate({})
			object.global_position = destination
			object.linear_velocity = Vector3.ZERO
			object.angular_velocity = Vector3.ZERO
			object.sleeping = false
			if was_held:
				grab_finished.emit(object, destination, "recovered")
			placement_message.emit("Pieza recuperada sobre la mesa.")
			return true
	placement_message.emit("No hay espacio libre para recuperar la pieza.")
	return false


func _plane_point(mouse: Vector2, height: float) -> Variant:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return null
	var t := (height - origin.y) / direction.y
	if t < 0.0 or t > ray_length:
		return null
	return origin + direction * t
