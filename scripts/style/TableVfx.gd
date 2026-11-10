class_name TableVfx
extends Node3D
## Pool reutilizable de efectos visuales táctiles («juice») y materiales compartidos para mesas 3D.
## Todos los recursos compartidos se alojan en metadatos del nodo autoload `/root/ToonStyle`
## (nunca en `static var` de clases globales) para que Godot libere sus RIDs antes de cerrar
## RenderingServer al salir en modo headless o escritorio.

const RIM_SHADER_PATH := "res://shaders/interactive_rim_overlay.gdshader"
const CARD_FLEX_SHADER_PATH := "res://shaders/card_flex.gdshader"
const DONE_META := &"toon_style_applied"
const CACHE_META := &"tablerama_art_cache"
const DROP_POOL_SIZE := 8
const HERO_POOL_SIZE := 4

var _drop_rings: Array[MeshInstance3D] = []
var _drop_particles: Array[CPUParticles3D] = []
var _drop_cursor := 0

var _hero_roots: Array[Node3D] = []
var _hero_cursor := 0
var _active_tweens: Array[Tween] = []
var _warmup_frames := 0
var _warmup_node: Node3D


## Devuelve el diccionario de caché ligado al ciclo de vida del SceneTree (vía /root/ToonStyle).
static func shared_cache(context: Node = null) -> Dictionary:
	var tree: SceneTree = null
	if context != null and context.is_inside_tree():
		tree = context.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var holder: Node = tree.root.get_node_or_null("ToonStyle")
	if holder == null:
		holder = tree.root
	if holder.has_meta(CACHE_META):
		var cached: Variant = holder.get_meta(CACHE_META)
		if cached is Dictionary:
			return cached as Dictionary
	var fresh: Dictionary = {}
	holder.set_meta(CACHE_META, fresh)
	return fresh


static func rim_shader(context: Node = null) -> Shader:
	var cache := shared_cache(context)
	if cache.has("rim_shader"):
		return cache["rim_shader"] as Shader
	var sh := load(RIM_SHADER_PATH) as Shader
	cache["rim_shader"] = sh
	return sh


static func card_flex_shader(context: Node = null) -> Shader:
	var cache := shared_cache(context)
	if cache.has("card_flex_shader"):
		return cache["card_flex_shader"] as Shader
	var sh := load(CARD_FLEX_SHADER_PATH) as Shader
	cache["card_flex_shader"] = sh
	return sh


static func shared_card_quad(context: Node = null) -> QuadMesh:
	var cache := shared_cache(context)
	if cache.has("card_quad"):
		return cache["card_quad"] as QuadMesh
	var qm := QuadMesh.new()
	qm.size = Vector2(0.68, 0.96)
	qm.subdivide_width = 8
	qm.subdivide_depth = 12
	cache["card_quad"] = qm
	return qm


static func shared_shadow_material(context: Node = null) -> StandardMaterial3D:
	var cache := shared_cache(context)
	if cache.has("shadow_mat"):
		return cache["shadow_mat"] as StandardMaterial3D
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
	cache["shadow_mat"] = mat
	return mat


static func make_rim_material(tint: Color = Palette.SUN_LIGHT, context: Node = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.set_meta(DONE_META, true)
	mat.shader = rim_shader(context)
	mat.set_shader_parameter("rim_color", tint)
	mat.set_shader_parameter("rim_power", 2.6)
	mat.set_shader_parameter("fill_alpha", 0.04)
	mat.set_shader_parameter("rim_alpha", 0.78)
	mat.set_shader_parameter("pulse_speed", 3.6)
	mat.set_shader_parameter("pulse_amount", 0.12)
	return mat


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
	var meshes := _ensure_shared_meshes()
	_build_drop_pool(meshes)
	_build_hero_pool(meshes)
	_build_shader_warmup()


func _exit_tree() -> void:
	for tw in _active_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_active_tweens.clear()


func _process(_delta: float) -> void:
	if _warmup_node != null:
		_warmup_frames += 1
		if _warmup_frames >= 3:
			_warmup_node.queue_free()
			_warmup_node = null
			set_process(false)


func _ensure_shared_meshes() -> Dictionary:
	var cache := shared_cache(self)
	if not cache.has("puff_mesh"):
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
		var puff_mesh := QuadMesh.new()
		puff_mesh.size = Vector2(0.085, 0.085)
		puff_mesh.material = mat
		cache["puff_mesh"] = puff_mesh
	if not cache.has("ring_mesh"):
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.16
		ring_mesh.outer_radius = 0.21
		ring_mesh.rings = 20
		ring_mesh.ring_segments = 8
		cache["ring_mesh"] = ring_mesh
	if not cache.has("star_mesh"):
		var star_mesh := BoxMesh.new()
		star_mesh.size = Vector3(0.065, 0.016, 0.16)
		cache["star_mesh"] = star_mesh
	return cache


func _build_drop_pool(meshes: Dictionary) -> void:
	var ring_mesh: TorusMesh = meshes["ring_mesh"] as TorusMesh
	var puff_mesh: QuadMesh = meshes["puff_mesh"] as QuadMesh
	for i in DROP_POOL_SIZE:
		var ring := MeshInstance3D.new()
		ring.name = "DropRing%d" % i
		ring.mesh = ring_mesh
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
		puffs.mesh = puff_mesh
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


func _build_hero_pool(meshes: Dictionary) -> void:
	var star_mesh: BoxMesh = meshes["star_mesh"] as BoxMesh
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
			ray.mesh = star_mesh
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
	rim_warm.material_override = make_rim_material(Palette.SUN_LIGHT, self)
	_warmup_node.add_child(rim_warm)
	var card_warm := MeshInstance3D.new()
	card_warm.mesh = quad
	var flex_mat := ShaderMaterial.new()
	flex_mat.set_meta(DONE_META, true)
	flex_mat.shader = card_flex_shader(self)
	flex_mat.set_shader_parameter("card_tex", CardArt.texture("back"))
	card_warm.material_override = flex_mat
	_warmup_node.add_child(card_warm)
	add_child(_warmup_node)


func _track_tween() -> Tween:
	var kept: Array[Tween] = []
	for existing in _active_tweens:
		if existing != null and existing.is_valid() and existing.is_running():
			kept.append(existing)
	_active_tweens = kept
	var tw := create_tween()
	_active_tweens.append(tw)
	return tw


func _emit_drop(world_pos: Vector3, intensity: float, tint: Color) -> void:
	if _drop_rings.is_empty() or not is_inside_tree():
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
	var tw := _track_tween()
	tw.tween_property(ring, "scale", Vector3(1.45 * intensity, 0.25, 1.45 * intensity), 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3.ZERO, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.visible = false
	)

	var puffs := _drop_particles[idx]
	puffs.global_position = ground + Vector3(0.0, 0.02, 0.0)
	puffs.color = Color(tint.r, tint.g, tint.b, 0.85)
	puffs.restart()
	puffs.emitting = true


func _emit_hero(world_pos: Vector3, tint: Color) -> void:
	_emit_drop(world_pos, 1.45, tint)
	if _hero_roots.is_empty() or not is_inside_tree():
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
	var tw := _track_tween()
	tw.tween_property(root, "scale", Vector3(1.35, 1.0, 1.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(root, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tw.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.visible = false
	)
