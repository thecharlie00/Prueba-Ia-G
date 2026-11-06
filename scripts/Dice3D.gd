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


func _ready() -> void:
	super._ready()
	sleeping_state_changed.connect(_on_sleeping_changed)
	_make_pips()


func roll(impulse_scale: float = 1.0) -> void:
	if is_grabbed:
		return
	_awaiting_result = true
	sleeping = false
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
		_celebrate(top_face())
		result_ready.emit(top_face())


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
	_sound("pop")
	var style := get_node_or_null("/root/ToonStyle")
	var calm: bool = style != null and style.reduce_motion
	var label := Label3D.new()
	label.name = "ResultPop"
	label.text = str(value)
	label.font_size = 150
	label.pixel_size = 0.004
	label.modulate = Palette.SUN
	label.outline_size = 36
	label.outline_modulate = Palette.INK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	if style != null:
		label.font = style.DISPLAY_FONT
	get_parent().add_child(label)
	label.global_position = global_position + Vector3.UP * 0.65
	var tween := label.create_tween()
	if calm:
		tween.tween_interval(1.0)
	else:
		label.scale = Vector3.ONE * 0.2
		tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.16).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(label, "position:y", label.position.y + 0.35, 0.5)
		tween.tween_interval(0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
	if calm:
		return
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
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 8
	dot.rings = 4
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	dot.material = spark_material
	sparks.mesh = dot
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	colors.colors = PackedColorArray([Palette.SUN, Palette.CORAL, Palette.MINT, Palette.PLAYER_BLUE])
	sparks.color_initial_ramp = colors
	get_parent().add_child(sparks)
	sparks.global_position = global_position + Vector3.UP * 0.3
	sparks.emitting = true
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)


func _sound(effect: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(effect)
