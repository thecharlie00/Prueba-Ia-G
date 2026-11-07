class_name InspectView
extends SubViewportContainer
## Vista 3D ampliada para la inspección (Alt): una copia del aspecto de la pieza que gira
## despacio en un pequeño estudio con luz propia. Las cartas solo se balancean, sin dar la
## vuelta, para no enseñar la cara oculta.

const SIZE := 260

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _target: InteractiveTableObject
var _wobble_only := false
var _time := 0.0


func _init() -> void:
	name = "InspectView"
	stretch = true
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	world.add_child(_camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_energy = 1.1
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.45
	world.add_child(fill)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(1, 0.96, 0.9)
	environment.environment.ambient_light_energy = 0.55
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.add_child(environment)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	world.add_child(_pivot)


## Muestra la pieza. face_down: carta boca abajo (solo se ve el reverso).
func show_object(object: InteractiveTableObject, face_down := false) -> bool:
	if object == _target and _pivot.get_child_count() > 0:
		return true
	_target = object
	for child in _pivot.get_children():
		child.queue_free()
	var visual := object.get_node_or_null("Visual") as Node3D
	if visual == null:
		return false
	var copy := visual.duplicate() as Node3D
	copy.transform = Transform3D(visual.transform.basis, visual.transform.origin)
	var holder := Node3D.new()
	holder.add_child(copy)
	_pivot.add_child(holder)
	var bounds := _bounds(copy)
	holder.position = -bounds.get_center()
	_wobble_only = object is Card3D or object is Deck3D or object is Note3D
	var radius := maxf(bounds.size.length() * 0.5, 0.05)
	if _wobble_only:
		# La cara de arriba mira a la cámara; boca abajo, el reverso.
		_pivot.rotation = Vector3(-PI * 0.5 if face_down else PI * 0.5, 0, 0)
	else:
		_pivot.rotation = Vector3(0.35, 0, 0)
	_camera.position = Vector3(0, 0, radius / tan(deg_to_rad(_camera.fov * 0.5)) * 1.12)
	_time = 0.0
	return true


func clear() -> void:
	_target = null
	for child in _pivot.get_children():
		child.queue_free()


func _process(delta: float) -> void:
	if not visible or _pivot.get_child_count() == 0:
		return
	_time += delta
	if _wobble_only:
		_pivot.rotation.y = sin(_time * 1.3) * 0.35
	else:
		_pivot.rotation.y += delta * 0.9


func _bounds(node: Node3D) -> AABB:
	var total := AABB()
	var first := true
	for mesh in node.find_children("*", "VisualInstance3D", true, false) + [node]:
		var instance := mesh as VisualInstance3D
		if instance == null:
			continue
		var box := instance.get_aabb()
		if box.size == Vector3.ZERO:
			continue
		var relative := node.global_transform.affine_inverse() * instance.global_transform if node.is_inside_tree() else _relative(node, instance)
		box = relative * box
		total = box if first else total.merge(box)
		first = false
	return total if not first else AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))


func _relative(root: Node3D, child: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = child
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return root.transform * result
