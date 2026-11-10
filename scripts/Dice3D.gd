class_name Dice3D
extends InteractiveTableObject

signal result_ready(value: int)
# Valores opuestos suman 7. Las marcas visuales usan este mismo mapa.
const FACES := {
	Vector3.UP: 1,
	Vector3.DOWN: 6,
	Vector3.RIGHT: 2,
	Vector3.LEFT: 5,
	Vector3.FORWARD: 3,
	Vector3.BACK: 4
}
var _awaiting_result := false
var _pop: DicePop
var _forced_active := false
var _forced_value := 0
var _forced_elapsed := 0.0
var _forced_duration := 0.62
var _forced_start_pos := Vector3.ZERO
var _forced_rest_pos := Vector3.ZERO
var _forced_end_basis := Basis.IDENTITY
var _forced_spin_axis := Vector3(0.75, 0.35, 0.56).normalized()


func _ready() -> void:
	super._ready()
	sleeping_state_changed.connect(_on_sleeping_changed)
	_make_pips()


func _process(delta: float) -> void:
	if not _forced_active:
		return
	_forced_elapsed += delta
	var u := clampf(_forced_elapsed / maxf(_forced_duration, 0.05), 0.0, 1.0)
	var pos := _forced_start_pos.lerp(_forced_rest_pos, u)
	var arc := 0.0
	if u < 0.74:
		arc = 0.48 * sin(PI * (u / 0.74))
	else:
		arc = 0.08 * sin(PI * ((u - 0.74) / 0.26))
	pos.y = lerpf(_forced_start_pos.y, _forced_rest_pos.y, u) + arc
	var inv := 1.0 - u
	var remaining_angle := (inv * inv * inv) * TAU * 2.0
	var spin := Basis(_forced_spin_axis, remaining_angle)
	global_transform = Transform3D((spin * _forced_end_basis).orthonormalized(), pos)
	if u >= 1.0:
		finish_forced_roll(true)


func is_forced_rolling() -> bool:
	return _forced_active


## Lanza el dado con una animación 3D determinista en la bandeja que aterriza
## exactamente en `value` (1..6) y muestra ese mismo número en DicePop.
func roll_to_value(value: int, rest_pos: Vector3, duration: float = 0.62) -> void:
	if value < 1 or value > 6:
		return
	_awaiting_result = false
	_forced_active = true
	_forced_value = value
	_forced_elapsed = 0.0
	_forced_duration = maxf(duration, 0.05)
	_forced_rest_pos = rest_pos
	_forced_start_pos = rest_pos + Vector3(
		randf_range(-0.14, 0.14), 0.22, randf_range(-0.14, 0.14)
	)
	var end_yaw := randf_range(-PI, PI)
	_forced_end_basis = basis_for_top_face(value, end_yaw)
	_forced_spin_axis = Vector3(
		randf_range(0.55, 0.95),
		randf_range(0.25, 0.55),
		randf_range(0.45, 0.85)
	).normalized()
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(
		(Basis(_forced_spin_axis, TAU * 2.0) * _forced_end_basis).orthonormalized(),
		_forced_start_pos
	)
	_note("dado: lanzado")
	_sound("dice")


func finish_forced_roll(celebrate: bool = true) -> void:
	if not _forced_active:
		return
	var val := _forced_value
	var final_xf := Transform3D(_forced_end_basis, _forced_rest_pos)
	_forced_active = false
	_forced_value = 0
	_awaiting_result = false
	freeze = false
	global_transform = final_xf
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_inside_tree():
		PhysicsServer3D.body_set_state(
			get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, final_xf
		)
		PhysicsServer3D.body_set_state(
			get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO
		)
		PhysicsServer3D.body_set_state(
			get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO
		)
	sleeping = true
	if celebrate and val >= 1 and val <= 6:
		var meter := get_node_or_null("/root/PerfMeter")
		if meter == null or meter.dice_part_enabled("pop"):
			_celebrate(val)
		elif meter.dice_part_enabled("sound"):
			_sound("pop")
		if meter == null or meter.dice_part_enabled("signal"):
			result_ready.emit(val)


func cancel_forced_roll() -> void:
	if not _forced_active:
		return
	_forced_active = false
	_forced_value = 0
	_awaiting_result = false
	freeze = false


## Garantiza que el número flotante (DicePop) coincida con la cara final leída
## (por ejemplo, si el segundo dado golpeó al primero después de detenerse).
func ensure_celebrated(value: int) -> void:
	if value < 1 or value > 6:
		return
	if not is_instance_valid(_pop) or _pop.text_value != value:
		var meter := get_node_or_null("/root/PerfMeter")
		if meter == null or meter.dice_part_enabled("pop"):
			_celebrate(value)


func roll(impulse_scale: float = 1.0) -> void:
	if is_grabbed:
		return
	if _forced_active:
		cancel_forced_roll()
	_awaiting_result = true
	sleeping = false
	_note("dado: lanzado")
	_sound("dice")
	apply_central_impulse(
		(
			Vector3(randf_range(-0.8, 0.8), randf_range(2.5, 3.5), randf_range(-0.8, 0.8))
			* mass
			* impulse_scale
		)
	)
	apply_torque_impulse(
		(
			Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
			* mass
			* impulse_scale
		)
	)


func top_face() -> int:
	var best_dot := -INF
	var value := 0
	for normal: Vector3 in FACES:
		var dot: float = (global_basis.orthonormalized() * normal).dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			value = FACES[normal]
	return value


static func basis_for_top_face(value: int, yaw_angle: float = 0.0) -> Basis:
	var target_normal := Vector3.UP
	for normal: Vector3 in FACES:
		if FACES[normal] == value:
			target_normal = normal
			break
	var align := Basis.IDENTITY
	var axis := target_normal.cross(Vector3.UP)
	if axis.length() < 0.001:
		if target_normal.dot(Vector3.UP) < 0.0:
			align = Basis(Vector3.RIGHT, PI)
	else:
		align = Basis(axis.normalized(), target_normal.angle_to(Vector3.UP))
	return (Basis(Vector3.UP, yaw_angle) * align).orthonormalized()


## Snapear el dado para mostrar una cara específica (conservando su giro horizontal).
func set_top_face(value: int) -> void:
	if value < 1 or value > 6:
		return
	var new_basis := basis_for_top_face(value, global_rotation.y)
	global_basis = new_basis
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if is_inside_tree():
		PhysicsServer3D.body_set_state(
			get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			Transform3D(new_basis, global_position)
		)
		PhysicsServer3D.body_set_state(
			get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO
		)
		PhysicsServer3D.body_set_state(
			get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO
		)


func _on_sleeping_changed() -> void:
	if sleeping and _awaiting_result and not is_grabbed:
		_awaiting_result = false
		var meter := get_node_or_null("/root/PerfMeter")
		var t0 := Time.get_ticks_usec()
		if meter == null or meter.dice_part_enabled("pop"):
			_celebrate(top_face())
		elif meter.dice_part_enabled("sound"):
			_sound("pop")
		var t1 := Time.get_ticks_usec()
		if meter == null or meter.dice_part_enabled("signal"):
			result_ready.emit(top_face())
		var t2 := Time.get_ticks_usec()
		_note("dado: resultado", " (número %.1f ms, avisos %.1f ms)" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0])


func _make_pips() -> void:
	# Cubo redondeado de papel con puntos de tinta (docs/ARTE.md). El colisionador sigue
	# siendo la caja de 0,5 m de la escena.
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual != null:
		visual.mesh = PieceKit.rounded_box(Vector3.ONE * 0.5, 0.1)
		var body := visual.material_override as StandardMaterial3D
		if body != null:
			body.albedo_color = Color("fff8ec")
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2a2552")
	var pip_mesh := PieceKit.dot(0.048, 0.022)
	var pip_parent: Node3D = visual if visual != null else self
	var layouts := {
		1: [Vector2(0, 0)],
		2: [Vector2(-1, -1), Vector2(1, 1)],
		3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6:
		[
			Vector2(-1, -1),
			Vector2(1, -1),
			Vector2(-1, 0),
			Vector2(1, 0),
			Vector2(-1, 1),
			Vector2(1, 1)
		]
	}
	for normal: Vector3 in FACES:
		var u: Vector3 = Vector3.RIGHT if absf(normal.y) > 0.5 else Vector3.UP
		var v: Vector3 = normal.cross(u)
		for p in layouts[FACES[normal]]:
			var pip := MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.material_override = material
			# Gota de tinta orientada hacia fuera de la cara, un poco hundida.
			pip.basis = Basis(Quaternion(Vector3.UP, normal))
			pip.position = normal * 0.243 + (u * p.x + v * p.y) * 0.125
			pip_parent.add_child(pip)


## Al quedar quieto: suena y el número del resultado salta en el centro de la pantalla
## (sin salto con "Reducir animaciones").
func _celebrate(value: int) -> void:
	if not is_inside_tree():
		return
	var meter := get_node_or_null("/root/PerfMeter")
	if meter == null or meter.dice_part_enabled("sound"):
		_sound("pop")
	var style := get_node_or_null("/root/ToonStyle")
	var calm: bool = style != null and style.reduce_motion
	var host := _effects_host()
	# Número dibujado con la interfaz 2D (DicePop), uno por dado.
	if not is_instance_valid(_pop):
		_pop = DicePop.new()
		DicePop.layer_for(host).add_child(_pop)
	_pop.show_value(value, self, calm)


## Los efectos van a la raíz de la escena, no junto a las piezas: así guardar y el
## rebobinado no se encuentran nodos que no son piezas mientras dura la celebración.
func _effects_host() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.is_ancestor_of(self):
		return scene
	# Sin escena actual (tests, herramientas): la raíz de la mesa, nunca $Objects.
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node if node != self else get_parent()


func _exit_tree() -> void:
	if is_instance_valid(_pop) and _pop.get_parent() != self:
		_pop.queue_free()


func _note(event: String, cost := "") -> void:
	var meter := get_node_or_null("/root/PerfMeter")
	if meter != null:
		meter.note(event, cost)


func _sound(effect: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(effect)
