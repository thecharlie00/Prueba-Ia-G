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
var _inspection_view: InspectView
var _context_hint: PanelContainer
var _context_hint_text: Label
# Solo el último agarre en mesas libres; no es un historial de reglas ni de azar.
var _grab_start_position := Vector3.ZERO
var _undo_object: InteractiveTableObject
var _undo_position := Vector3.ZERO
var _pending_undo := false


var radial_menu: RadialMenu


func _ready() -> void:
	radial_menu = RadialMenu.new()
	radial_menu.grabber = self
	add_child(radial_menu)
	var navigation := get_node_or_null("/root/SessionNavigation")
	if navigation != null:
		click_to_grab = bool(navigation.get("click_to_grab"))
	if lock_shortcut_enabled:
		_create_inspection_panel()
		_create_context_hint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_hide_inspection()
		_pending_undo = false
		_pending_recovery = null
		if is_instance_valid(_context_hint):
			_context_hint.hide()
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
				_queue_pointer_release(event.position)
				# El clic de suelta no activa el botón de la UI que haya debajo.
				get_viewport().set_input_as_handled()
			elif not click_to_grab and not event.pressed:
				# Capturar también la suelta consumida por un botón de la UI.
				if is_instance_valid(held) or _pending_press:
					_queue_pointer_release(event.position)
		if is_instance_valid(held) and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_height(height_step)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_height(-height_step)
				get_viewport().set_input_as_handled()


# Guardar el lugar exacto de suelta; un movimiento posterior del ratón no debe
# cambiar el destino antes del siguiente tick físico. Una cancelación prevalece.
func _queue_pointer_release(position: Vector2) -> void:
	var cancel := (
		get_viewport().gui_get_hovered_control() != null
		or not get_viewport().get_visible_rect().has_point(position)
	)
	if not _pending_release:
		_release_position = position
		_release_reason = "cancelled" if cancel else "released"
	elif cancel:
		_release_reason = "cancelled"
	_pending_release = true


func _adjust_height(amount: float) -> void:
	_height_adjustment = clampf(
		_height_adjustment + amount, -lift_height + 0.05, maximum_extra_height
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pending_press = true
			_press_position = event.position
		elif not click_to_grab and (is_instance_valid(held) or _pending_press):
			_queue_pointer_release(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if (
			event.keycode == KEY_Z
			and event.ctrl_pressed
			and not event.shift_pressed
			and not event.alt_pressed
			and not event.meta_pressed
			and lock_shortcut_enabled
		):
			request_movement_undo()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			return
		if event.keycode == KEY_X and (is_instance_valid(held) or _pending_press):
			# Cancelar nunca confirma una jugada, incluso entre dos ticks físicos.
			_pending_press = false
			_pending_recovery = null
			_pending_release = is_instance_valid(held)
			_release_reason = "cancelled" if _pending_release else "released"
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P and not is_instance_valid(held) and not _pending_press:
			ping(hovered.global_position if is_instance_valid(hovered) else _pointer_point())
			get_viewport().set_input_as_handled()
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
		if event.keycode == KEY_L and get_viewport().gui_get_hovered_control() != null:
			return
		apply_shortcut(event.keycode, selected)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var mouse := camera.get_viewport().get_mouse_position()
	if _pending_undo:
		_pending_undo = false
		_undo_last_movement()
	if _pending_press:
		_pending_press = false
		_update_hover(_press_position)
		if is_instance_valid(hovered):
			_begin_grab(_press_position)
	if is_instance_valid(_pending_recovery) and _pending_recovery.is_inside_tree():
		_recover_object(_pending_recovery)
	_pending_recovery = null
	if is_instance_valid(held):
		var pointer := _release_position if _pending_release else mouse
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
	_refresh_context_hint()


func _create_context_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	# Atajos visibles sobre la pieza (queja 1 de TTS): bocadillo que flota encima de lo
	# que hay bajo el ratón.
	_context_hint = PanelContainer.new()
	_context_hint.name = "ContextHint"
	_context_hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_context_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(3)
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.set_corner_radius_all(12)
	style.shadow_color = Palette.INK
	style.shadow_size = 1
	style.shadow_offset = Vector2(3, 3)
	_context_hint.add_theme_stylebox_override("panel", style)
	layer.add_child(_context_hint)
	_context_hint_text = Label.new()
	_context_hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Una sola línea: el bocadillo se ajusta al texto y flota sobre la pieza.
	_context_hint_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_context_hint_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_hint_text.add_theme_font_size_override("font_size", 14)
	_context_hint_text.add_theme_color_override("font_color", Palette.INK)
	_context_hint.add_child(_context_hint_text)
	_context_hint.hide()


func _refresh_context_hint() -> void:
	if not is_instance_valid(_context_hint):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if _inspecting or focus is LineEdit or focus is TextEdit:
		_context_hint.hide()
		return
	if is_instance_valid(held):
		_context_hint_text.text = (
			"Clic para colocar · X cancelar · Rueda ajustar altura"
			if click_to_grab
			else "Suelta para colocar · X cancelar · Rueda ajustar altura"
		)
		_show_context_hint(held)
		return
	if (
		not is_instance_valid(hovered)
		or not hovered.is_inside_tree()
		or get_viewport().gui_get_hovered_control() != null
	):
		_context_hint.hide()
		return
	if hovered.is_table_locked:
		_context_hint_text.text = "Pieza bloqueada · L desbloquear · Alt inspeccionar"
	elif hovered is Card3D:
		# La ayuda nunca incluye el valor de una carta boca abajo.
		_context_hint_text.text = "Carta · F voltear · Q/E girar · H recuperar · Alt inspeccionar"
	elif hovered is Deck3D:
		_context_hint_text.text = "Baraja · N robar · R mezclar · L bloquear · Alt inspeccionar"
	elif hovered is Dice3D and dice_shortcuts_enabled:
		_context_hint_text.text = "Dado · R/T lanzar · Q/E girar · H recuperar · L bloquear"
	elif hovered is TableUtility:
		_context_hint_text.text = (hovered as TableUtility).shortcut_hint()
	else:
		_context_hint_text.text = "Pieza · Q/E girar · H recuperar · L bloquear · Alt inspeccionar"
	_show_context_hint(hovered)


## Coloca el bocadillo de atajos justo encima de la pieza, sin salirse de la pantalla.
func _show_context_hint(object: InteractiveTableObject) -> void:
	_context_hint.show()
	_context_hint.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var point := screen * Vector2(0.5, 0.85)
	if is_instance_valid(camera) and is_instance_valid(object):
		var anchor := object.global_position + Vector3.UP * 0.45
		if not camera.is_position_behind(anchor):
			point = camera.unproject_position(anchor)
	var box := _context_hint.size
	_context_hint.position = Vector2(
		clampf(point.x - box.x * 0.5, 8.0, maxf(8.0, screen.x - box.x - 8.0)),
		clampf(point.y - box.y - 18.0, 8.0, maxf(8.0, screen.y - box.y - 8.0))
	)


func _create_inspection_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_inspection_panel = PanelContainer.new()
	_inspection_panel.name = "InspectionPanel"
	_inspection_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_inspection_panel.offset_left = -350
	_inspection_panel.offset_top = -430
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
	# Vista 3D ampliada de la pieza (fase 2: inspección 3D).
	_inspection_view = InspectView.new()
	_inspection_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_inspection_view)
	_inspection_body = Label.new()
	_inspection_body.add_theme_font_size_override("font_size", 22)
	_inspection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspection_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_inspection_body)
	_inspection_panel.hide()


func _hide_inspection() -> void:
	_inspecting = false
	if is_instance_valid(_inspection_panel):
		_inspection_panel.hide()
	if is_instance_valid(_inspection_view):
		_inspection_view.clear()


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
	var face_down: bool = hovered is Card3D and (
		hovered._flipping or hovered.global_basis.y.normalized().dot(Vector3.UP) < 0.5
	)
	if is_instance_valid(_inspection_view):
		_inspection_view.show_object(hovered, face_down)
	if hovered is Card3D:
		# Nunca mostrar el valor si el anverso no está orientado hacia arriba.
		if face_down:
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
	# Las piezas de la zona privada de otro jugador no se pueden tocar (HiddenZone3D).
	if next != null and bool(next.get_meta(&"private_hidden", false)):
		next = null
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
	_grab_start_position = held.global_position
	held.on_grab()
	# Una pieza que volaba hacia su casa recupera las colisiones al cogerla con la mano.
	if HomeSteering.is_traveling(held):
		HomeSteering.land(held)
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
		if (
			lock_shortcut_enabled
			and reason in ["released", "cancelled"]
			and held.global_position.distance_to(_grab_start_position) > 0.02
		):
			_undo_object = held
			_undo_position = _grab_start_position
		if reason == "cancelled":
			placement_message.emit("Agarre cancelado; la pieza puede quedar desplazada.")
	if is_instance_valid(snap_grid):
		snap_grid.show_candidate({})
	held = null
	if is_instance_valid(released_object):
		grab_finished.emit(released_object, _target, reason)


# Devuelve solo una pieza a donde se agarró. No revierte cartas, dados ni reglas.
func can_undo_movement() -> bool:
	return (
		lock_shortcut_enabled
		and is_instance_valid(_undo_object)
		and _undo_object.is_inside_tree()
		and not _undo_object.is_queued_for_deletion()
	)


func clear_movement_undo() -> void:
	_pending_undo = false
	_undo_object = null


func request_movement_undo() -> void:
	if not can_undo_movement():
		clear_movement_undo()
		placement_message.emit("No hay ningún movimiento de pieza para deshacer.")
		return
	if is_instance_valid(held) or _pending_press or _pending_release:
		placement_message.emit("Suelta o cancela el agarre antes de deshacer.")
		return
	_pending_undo = true


func _undo_last_movement() -> void:
	if not can_undo_movement():
		clear_movement_undo()
		placement_message.emit("La pieza anterior ya no está en la mesa.")
		return
	if is_instance_valid(held) or _pending_press or _pending_release:
		placement_message.emit("Suelta o cancela el agarre antes de deshacer.")
		return
	var object := _undo_object
	if object.freeze or (object is Dice3D and object._awaiting_result):
		placement_message.emit("Desbloquea la pieza y espera a que termine su acción.")
		return
	var shape_node := object.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null or shape_node.disabled:
		placement_message.emit("No se puede comprobar la posición anterior.")
		return
	# Un pequeño margen sobre la posición anterior evita penetrar la mesa por contacto.
	var destination := _undo_position + Vector3.UP * 0.04
	var transform := object.global_transform
	transform.origin = destination
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = transform * shape_node.transform
	query.collision_mask = ray_mask
	query.exclude = [object.get_rid()]
	query.margin = 0.005
	if not camera.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		placement_message.emit("La posición anterior está ocupada; deshacer no ha movido nada.")
		return
	object.global_position = destination
	object.linear_velocity = Vector3.ZERO
	object.angular_velocity = Vector3.ZERO
	object.sleeping = false
	clear_movement_undo()
	placement_message.emit("Pieza devuelta a su posición anterior; la física continúa.")


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
			if object == _undo_object:
				clear_movement_undo()
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


## Punto de la mesa bajo el ratón (o el centro si no hay nada debajo).
func _pointer_point() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + camera.project_ray_normal(mouse) * ray_length, ray_mask
	)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3.ZERO


## Señal visible para todos en un punto de la mesa: aro que se expande y flecha que bota.
func ping(at: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = "Ping"
	get_parent().add_child(marker)
	marker.global_position = at + Vector3.UP * 0.03
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Palette.SUN
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.material_override = material
	marker.add_child(ring)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.0
	cone.height = 0.32
	arrow.mesh = cone
	arrow.position.y = 0.75
	var arrow_material := StandardMaterial3D.new()
	arrow_material.albedo_color = Palette.SUN
	arrow.material_override = arrow_material
	marker.add_child(arrow)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("pop")
	var tween := marker.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.6, 1.1).from(Vector3.ONE * 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 1.1).from(1.0)
	var bounce := arrow.create_tween().set_loops(3)
	bounce.tween_property(arrow, "position:y", 0.45, 0.18).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(arrow, "position:y", 0.75, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(marker.queue_free)
	return marker


## Atajos sobre una pieza (teclado y menú radial comparten esta lógica).
func apply_shortcut(keycode: int, selected: InteractiveTableObject) -> void:
	if not is_instance_valid(selected) or not selected.is_inside_tree():
		return
	if selected is TableUtility and not is_instance_valid(held):
		if (selected as TableUtility).handle_shortcut(keycode):
			selection_changed.emit(selected)
			return
	match keycode:
		KEY_L:
			if (
				lock_shortcut_enabled
				and not is_instance_valid(held)
				and not _pending_press
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
			elif keycode == KEY_R and selected is Deck3D and not is_instance_valid(held):
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
