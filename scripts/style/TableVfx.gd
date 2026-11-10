class_name TableVfx
extends Node3D
## Pool reutilizable de efectos visuales táctiles («juice») y materiales compartidos para mesas 3D.
## Diseñado para gl_compatibility sin tirones de memoria ni compilación tardía de shaders:
## - Pre-aloja anillos cartoon y CPUParticles3D de impacto (cero instantiate/queue_free en juego).
## - Comparte una única textura procedural suave para las sombras de contacto dinámicas.
## - Precalienta los shaders de borde Fresnel y flexión de carta durante la carga de la escena.

const RIM_SHADER: Shader = preload("res://shaders/interactive_rim_overlay.gdshader")
const CARD_FLEX_SHADER: Shader = preload("res://shaders/card_flex.gdshader")
const DONE_META := &"toon_style_applied"
const DROP_POOL_SIZE := 8
const HERO_POOL_SIZE := 4

static var _shadow_mat: StandardMaterial3D
static var _puff_mat: StandardMaterial3D
static var _puff_mesh: QuadMesh
static var _ring_mesh: TorusMesh
static var _star_mesh: BoxMesh

var _drop_rings: Array[MeshInstance3D] = []
var _drop_particles: Array[CPUParticles3D] = []
var _drop_cursor := 0

var _hero_roots: Array[Node3D] = []
var _hero_cursor := 0
var _warmup_frames := 0
var _warmup_node: Node3D


static func _scene_root_3d(context: Node) -> Node3D:
	if context == null or not context.is_inside_tree():
		return null
	var cur: Node = context
	var top_3d: Node3D = cur as Node3D
	while cur.get_parent() != null and not (cur.get_parent() is Window):
		cur = cur.get_parent()
		if cur is Node3D:
			top_3d = cur as Node3D
	if top_3d != null:
		return top_3d
	return context.get_tree().current_scene as Node3D


static func ensure_for(context: Node) -> TableVfx:
	var scene := _scene_root_3d(context)
	if scene == null:
		return null
	var existing := scene.get_node_or_null("TableVfx") as TableVfx
	if existing != null:
		return existing
	var pool := TableVfx.new()
	pool.name = "TableVfx"
	scene.add_child(pool)
	return pool


static func is_reduce_motion(context: Node) -> bool:
	if context == null or not context.is_inside_tree():
		return false
	var style: Node = context.get_node_or_null("/root/ToonStyle")
	return style != null and style.get("reduce_motion") == true


static func shared_shadow_material() -> StandardMaterial3D:
	if _shadow_mat != null:
		return _shadow_mat
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - half) / half
			var dy := (float(y) + 0.5 - half) / half
			var d := sqrt(dx * dx + dy * dy)
			var alpha := clampf(1.0 - smoothstep(0.22, 0.96, d), 0.0, 1.0) * 0.42
			img.set_pixel(x, y, Color(0.07, 0.06, 0.16, alpha))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.set_meta(DONE_META, true)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_shadow_mat = mat
	return _shadow_mat


static func make_rim_material(tint: Color = Palette.SUN_LIGHT) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.set_meta(DONE_META, true)
	mat.shader = RIM_SHADER
	mat.set_shader_parameter("rim_color", tint)
	mat.set_shader_parameter("rim_power", 2.6)
	mat.set_shader_parameter("fill_alpha", 0.04)
	mat.set_shader_parameter("rim_alpha", 0.78)
	mat.set_shader_parameter("pulse_speed", 3.6)
	mat.set_shader_parameter("pulse_amount", 0.12)
	return mat


static func spawn_drop(
	context: Node,
	world_pos: Vector3,
	intensity: float = 1.0,
	tint: Color = Palette.PAPER
) -> void:
	if is_reduce_motion(context):
		return
	var pool := ensure_for(context)
	if pool == null:
		return
	pool._emit_drop(world_pos, clampf(intensity, 0.4, 2.2), tint)


static func spawn_hero_impact(
	context: Node,
	world_pos: Vector3,
	tint: Color = Palette.SUN,
	trauma: float = 0.28
) -> void:
	if is_reduce_motion(context):
		return
	var pool := ensure_for(context)
	if pool == null:
		return
	pool._emit_hero(world_pos, tint)
	if trauma > 0.0 and context != null and context.is_inside_tree():
		var scene := _scene_root_3d(context)
		if scene != null:
			var cam_rig := scene.find_child("TabletopCamera3D", true, false) as TabletopCamera3D
			if cam_rig != null:
				cam_rig.add_trauma(trauma)


func _ready() -> void:
	_ensure_shared_meshes()
	_build_drop_pool()
	_build_hero_pool()
	_build_shader_warmup()


func _process(_delta: float) -> void:
	if _warmup_node != null:
		_warmup_frames += 1
		if _warmup_frames >= 3:
			_warmup_node.queue_free()
			_warmup_node = null
			set_process(false)


static func _ensure_shared_meshes() -> void:
	if _puff_mat == null:
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := float(size) * 0.5
		for y in size:
			for x in size:
				var dx := (float(x) + 0.5 - half) / half
				var dy := (float(y) + 0.5 - half) / half
				var d := sqrt(dx * dx + dy * dy)
				var a := 1.0 if d <= 0.72 else clampf(1.0 - (d - 0.72) / 0.24, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		var tex := ImageTexture.create_from_image(img)
		var mat := StandardMaterial3D.new()
		mat.set_meta(DONE_META, true)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = tex
		_puff_mat = mat
	if _puff_mesh == null:
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2(0.085, 0.085)
		_puff_mesh.material = _puff_mat
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.16
		_ring_mesh.outer_radius = 0.21
		_ring_mesh.rings = 20
		_ring_mesh.ring_segments = 8
	if _star_mesh == null:
		_star_mesh = BoxMesh.new()
		_star_mesh.size = Vector3(0.065, 0.016, 0.16)


func _build_drop_pool() -> void:
	for i in DROP_POOL_SIZE:
		var ring := MeshInstance3D.new()
		ring.name = "DropRing%d" % i
		ring.mesh = _ring_mesh
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring_mat := StandardMaterial3D.new()
		ring_mat.set_meta(DONE_META, true)
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.75)
		ring.material_override = ring_mat
		ring.visible = false
		add_child(ring)
		_drop_rings.append(ring)

		var puffs := CPUParticles3D.new()
		puffs.name = "DropPuffs%d" % i
		puffs.set_meta(DONE_META, true)
		puffs.emitting = false
		puffs.one_shot = true
		puffs.amount = 6
		puffs.lifetime = 0.34
		puffs.explosiveness = 0.94
		puffs.mesh = _puff_mesh
		puffs.direction = Vector3.UP
		puffs.spread = 82.0
		puffs.gravity = Vector3(0.0, -2.4, 0.0)
		puffs.initial_velocity_min = 0.55
		puffs.initial_velocity_max = 1.15
		puffs.scale_amount_min = 0.65
		puffs.scale_amount_max = 1.15
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.9))
		curve.add_point(Vector2(0.35, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
		puffs.scale_amount_curve = curve
		puffs.color = Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.85)
		add_child(puffs)
		_drop_particles.append(puffs)


func _build_hero_pool() -> void:
	for i in HERO_POOL_SIZE:
		var root := Node3D.new()
		root.name = "HeroBurst%d" % i
		root.visible = false
		var mat := StandardMaterial3D.new()
		mat.set_meta(DONE_META, true)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Palette.SUN
		for s in 4:
			var ray := MeshInstance3D.new()
			ray.mesh = _star_mesh
			ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ray.material_override = mat
			var angle := float(s) * PI * 0.5 + PI * 0.25
			ray.rotation.y = angle
			ray.position = Vector3(cos(angle) * 0.24, 0.02, sin(angle) * 0.24)
			root.add_child(ray)
		add_child(root)
		_hero_roots.append(root)


func _build_shader_warmup() -> void:
	_warmup_node = Node3D.new()
	_warmup_node.name = "ShaderWarmup"
	_warmup_node.position = Vector3(0.0, 0.82, 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.002, 0.002)
	var rim_warm := MeshInstance3D.new()
	rim_warm.mesh = quad
	rim_warm.material_override = make_rim_material()
	_warmup_node.add_child(rim_warm)
	var card_warm := MeshInstance3D.new()
	card_warm.mesh = quad
	var flex_mat := ShaderMaterial.new()
	flex_mat.set_meta(DONE_META, true)
	flex_mat.shader = CARD_FLEX_SHADER
	flex_mat.set_shader_parameter("card_tex", CardArt.texture("back"))
	card_warm.material_override = flex_mat
	_warmup_node.add_child(card_warm)
	add_child(_warmup_node)


func _emit_drop(world_pos: Vector3, intensity: float, tint: Color) -> void:
	if _drop_rings.is_empty():
		return
	var idx := _drop_cursor
	_drop_cursor = (_drop_cursor + 1) % DROP_POOL_SIZE
	var ground := Vector3(world_pos.x, maxf(world_pos.y, 0.808), world_pos.z)
	var ring := _drop_rings[idx]
	ring.global_position = ground
	ring.scale = Vector3.ONE * (0.35 * intensity)
	ring.visible = true
	var ring_mat := ring.material_override as StandardMaterial3D
	if ring_mat != null:
		ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.72)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.55 * intensity, 0.2, 1.55 * intensity), 0.22).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	if ring_mat != null:
		tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(func() -> void: ring.visible = false)

	var puffs := _drop_particles[idx]
	puffs.global_position = ground + Vector3(0.0, 0.02, 0.0)
	puffs.color = Color(tint.r, tint.g, tint.b, 0.85)
	puffs.restart()
	puffs.emitting = true


func _emit_hero(world_pos: Vector3, tint: Color) -> void:
	_emit_drop(world_pos, 1.45, tint)
	if _hero_roots.is_empty():
		return
	var idx := _hero_cursor
	_hero_cursor = (_hero_cursor + 1) % HERO_POOL_SIZE
	var root := _hero_roots[idx]
	root.global_position = Vector3(world_pos.x, maxf(world_pos.y, 0.815), world_pos.z)
	root.scale = Vector3.ONE * 0.25
	root.rotation.y = randf() * TAU
	root.visible = true
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).material_override is StandardMaterial3D:
			((child as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = tint
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(1.35, 1.0, 1.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(root, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.tween_callback(func() -> void: root.visible = false)
