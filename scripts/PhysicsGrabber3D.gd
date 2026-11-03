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
@export var dice_shortcuts_enabled := true
# Solo mesas libres: nunca bloquear cuerpos usados por reglas guiadas.
@export var lock_shortcut_enabled := false
# Modo opcional: un clic agarra y otro suelta, sin mantener el botón.
var click_to_grab := false

var hovered: InteractiveTableObject
var held: InteractiveTableObject
var last_selected: InteractiveTableObject
var _grab_offset := Vector3.ZERO
var _drag_height := 0.0
var _target := Vector3.ZERO
var _pending_press := false
var _pending_release := false
var _release_reason := "released"
var _press_position := Vector2.ZERO
var _release_position := Vector2.ZERO
var _height_adjustment := 0.0
var _pending_recovery: InteractiveTableObject
var _inspecting := false
var _inspection_panel: PanelContainer
var _inspection_title: Label
var _inspection_body: Label


func _ready() -> void:
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null:
		click_to_grab = bool(navigation.get("click_to_grab"))
	if lock_shortcut_enabled:
		_create_inspection_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_hide_inspection()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pending_press = false
		if is_instance_valid(held):
			_pending_release = true
			_release_reason = "cancelled"
		else:
			_pending_release = false
			_release_reason = "released"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ALT and lock_shortcut_enabled:
		if event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed:
			_inspecting = true
			_refresh_inspection()
		elif not event.pressed:
			_hide_inspection()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if click_to_grab and event.pressed and (is_instance_valid(held) or _pending_press):
				_pending_release = true
				_release_position = event.position
				# Sobre la UI se cancela el movimiento y el clic no activa el botón subyacente.
				_release_reason = (
					"cancelled" if get_viewport().gui_get_hovered_control() != null else "released"
				)
				get_viewport().set_input_as_handled()
			elif not click_to_grab and not event.pressed:
				# La suelta llega incluso cuando ocurre encima de un botón de la UI.
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
		elif not click_to_grab:
			_pending_release = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return
		if event.keycode == KEY_S and is_instance_valid(snap_grid):
			snap_grid.enabled = not snap_grid.enabled
			snap_grid.show_candidate({})
			snap_status_changed.emit(snap_grid.enabled)
			return
		var selected := held if is_instance_valid(held) else hovered
		if event.keycode == KEY_H and not is_instance_valid(selected):
			selected = last_selected
		if not is_instance_valid(selected) or not selected.is_inside_tree():
			return
		match event.keycode:
			KEY_L:
				if (
					lock_shortcut_enabled
					and not is_instance_valid(held)
					and not _pending_press
					and get_viewport().gui_get_hovered_control() == null
					and not event.ctrl_pressed
					and not event.alt_pressed
					and not event.meta_pressed
				):
					if selected.set_table_locked(not selected.is_table_locked):
						selection_changed.emit(selected)
						placement_message.emit(
							(
								"Pieza bloqueada · L para desbloquear."
								if selected.is_table_locked
								else "Pieza desbloqueada; vuelve a tener física."
							)
						)
					else:
						placement_message.emit("Espera a que termine la acción antes de bloquear.")
			KEY_H:
				_pending_recovery = selected
			KEY_R, KEY_T:
				if dice_shortcuts_enabled and selected is Dice3D and not is_instance_valid(held):
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
	if is_instance_valid(_pending_recovery) and _pending_recovery.is_inside_tree():
		_recover_object(_pending_recovery)
	_pending_recovery = null
	if is_instance_valid(held):
		var pointer := _release_position if click_to_grab and _pending_release else mouse
		var hit = _plane_point(pointer, _drag_height)
		if hit != null and (not _pending_release or _release_reason != "cancelled"):
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
		if camera.get_viewport().gui_get_hovered_control() != null:
			_clear_hover()
		else:
			_update_hover(mouse)
	if _inspecting:
		_refresh_inspection()


func _create_inspection_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_inspection_panel = PanelContainer.new()
	_inspection_panel.name = "InspectionPanel"
	_inspection_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_inspection_panel.offset_left = -350
	_inspection_panel.offset_top = -150
	_inspection_panel.offset_right = -20
	_inspection_panel.offset_bottom = -20
	_inspection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.08, 0.96)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(8)
	_inspection_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_inspection_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspection_panel.add_child(column)
	_inspection_title = Label.new()
	_inspection_title.add_theme_font_size_override("font_size", 15)
	_inspection_title.text = "INSPECCIÓN · suelta Alt para cerrar"
	_inspection_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_inspection_title)
	_inspection_body = Label.new()
	_inspection_body.add_theme_font_size_override("font_size", 28)
	_inspection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_inspection_body)
	_inspection_panel.hide()


func _hide_inspection() -> void:
	_inspecting = false
	if is_instance_valid(_inspection_panel):
		_inspection_panel.hide()


func _refresh_inspection() -> void:
	if not is_instance_valid(_inspection_panel):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if (
		not _inspecting
		or focus is LineEdit
		or focus is TextEdit
		or get_viewport().gui_get_hovered_control() != null
		or is_instance_valid(held)
		or _pending_press
		or not is_instance_valid(hovered)
		or not hovered.is_inside_tree()
	):
		_inspection_panel.hide()
		return
	if hovered is Card3D:
		# Nunca mostrar el valor si el anverso no está orientado hacia arriba.
		if hovered._flipping or hovered.global_basis.y.normalized().dot(Vector3.UP) < 0.5:
			_inspection_body.text = "Carta boca abajo"
		else:
			_inspection_body.text = "Carta: " + hovered.card_label
	elif hovered is Deck3D:
		_inspection_body.text = "%s\nQuedan %d" % [hovered.display_name, hovered.cards_remaining]
	else:
		_inspection_body.text = hovered.display_name
	_inspection_panel.show()


func _clear_hover() -> void:
	if is_instance_valid(hovered):
		hovered.set_hovered(false)
		hovered = null
		selection_changed.emit(null)


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
		last_selected = hovered
		hovered.set_hovered(true)
	selection_changed.emit(hovered)


func _begin_grab(mouse: Vector2) -> void:
	if hovered.freeze:
		if hovered.is_table_locked:
			placement_message.emit("Pieza bloqueada: apunta y pulsa L para desbloquearla.")
		return
	held = hovered
	last_selected = held
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
	if click_to_grab:
		placement_message.emit("Ficha sujeta: haz clic de nuevo para soltarla.")


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
