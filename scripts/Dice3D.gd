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


## Una vez por partida basta: los shaders y los glifos quedan preparados.
static var _effects_warmed := false


func _ready() -> void:
	super._ready()
	sleeping_state_changed.connect(_on_sleeping_changed)
	_make_pips()
	if not _effects_warmed and DisplayServer.get_name() != "headless":
		_effects_warmed = true
		_warm_up_effects.call_deferred()


func roll(impulse_scale: float = 1.0) -> void:
	if is_grabbed:
		return
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


## Al quedar quieto: el número salta encima del dado y salen chispas de colores
## (sin chispas ni salto con "Reducir animaciones").
func _celebrate(value: int) -> void:
	if not is_inside_tree():
		return
	var meter := get_node_or_null("/root/PerfMeter")
	if meter == null or meter.dice_part_enabled("sound"):
		_sound("pop")
	var style := get_node_or_null("/root/ToonStyle")
	var calm: bool = style != null and style.reduce_motion
	var host := _effects_host()
	# Número dibujado con la interfaz 2D siguiendo al dado (DicePop), uno por dado.
	if not is_instance_valid(_pop):
		_pop = DicePop.new()
		DicePop.layer_for(host).add_child(_pop)
	_pop.show_value(value, self, calm)
	if calm:
		return
	if meter != null and not meter.dice_part_enabled("sparks"):
		return
	var sparks := _make_sparks()
	host.add_child(sparks)
	sparks.global_position = global_position + Vector3.UP * 0.3
	sparks.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)


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


static func _make_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.name = "ResultSparks"
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 16
	sparks.lifetime = 0.7
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.6
	sparks.initial_velocity_max = 2.8
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.2
	sparks.mesh = _spark_mesh()
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	colors.colors = PackedColorArray([Palette.SUN, Palette.CORAL, Palette.MINT, Palette.PLAYER_BLUE])
	sparks.color_initial_ramp = colors
	return sparks


static func _spark_mesh() -> SphereMesh:
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 8
	dot.rings = 4
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	dot.material = spark_material
	return dot


## Precalentado: la primera vez que se dibujan el número y las chispas el driver compila sus
## shaders y se generan los glifos, y eso congelaba el juego un momento justo al salir el
## resultado. Se dibujan una vez, casi invisibles, al cargar la mesa.
func _warm_up_effects() -> void:
	var host := _effects_host()
	var sparks := _make_sparks()
	sparks.amount = 1
	sparks.scale_amount_min = 0.01
	sparks.scale_amount_max = 0.01
	host.add_child(sparks)
	sparks.global_position = global_position
	sparks.emitting = true
	for i in 3:
		await get_tree().process_frame
	sparks.queue_free()


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
