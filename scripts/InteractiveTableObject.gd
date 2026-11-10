class_name InteractiveTableObject
extends RigidBody3D

signal grabbed(object: InteractiveTableObject)
signal released(object: InteractiveTableObject)

const TABLE_SURFACE_Y := 0.806
const DONE_META := &"toon_style_applied"

@export var display_name := "Pieza"
@export var highlight_color := Color(0.36, 0.88, 0.76, 1.0)
var is_grabbed := false
# Bloqueo explícito de mesa, independiente del freeze temporal de animaciones.
var is_table_locked := false
var hovered := false
var _highlight: StandardMaterial3D
var _rim_glow: MeshInstance3D
var _rim_mat: ShaderMaterial
var _contact_shadow: MeshInstance3D
var _juice_driver: _VisualJuiceDriver
var _juice_tween: Tween
var _juice_base := Vector3.ONE
var _visual_base_pos := Vector3.ZERO
var _visual_base_rot := Vector3.ZERO
var _invalid_timer := 0.0
var _wobble_timer := 0.0
var _wobble_strength := 0.0


class _VisualJuiceDriver:
	extends Node
	var target: InteractiveTableObject

	func _process(delta: float) -> void:
		if target == null or not is_instance_valid(target):
			set_process(false)
			return
		target._tick_visual_juice(delta)


func _exit_tree() -> void:
	if _juice_tween != null and _juice_tween.is_valid():
		_juice_tween.kill()
	_juice_tween = null


func _ready() -> void:
	continuous_cd = true
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null:
		_visual_base_pos = visual.position
		_visual_base_rot = visual.rotation
	_highlight = StandardMaterial3D.new()
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.16)
	_juice_driver = _VisualJuiceDriver.new()
	_juice_driver.name = "VisualJuiceDriver"
	_juice_driver.target = self
	_juice_driver.set_process(false)
	add_child(_juice_driver)
	_setup_contact_shadow()
	_update_highlight()


func _setup_contact_shadow() -> void:
	if _contact_shadow != null:
		return
	_contact_shadow = MeshInstance3D.new()
	_contact_shadow.name = "ContactShadow"
	_contact_shadow.set_meta(DONE_META, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62)
	_contact_shadow.mesh = quad
	_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contact_shadow.material_override = TableVfx.shared_shadow_material(self)
	_contact_shadow.visible = false
	add_child(_contact_shadow)


func _ensure_rim_glow(visual: MeshInstance3D) -> void:
	if visual == null or visual.mesh == null:
		return
	if _rim_glow == null or not is_instance_valid(_rim_glow):
		_rim_glow = MeshInstance3D.new()
		_rim_glow.name = "RimGlow"
		_rim_glow.set_meta(DONE_META, true)
		_rim_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rim_mat = TableVfx.make_rim_material(Palette.SUN_LIGHT, self)
		_rim_glow.material_override = _rim_mat
		_rim_glow.visible = false
		visual.add_child(_rim_glow)
	if _rim_glow.mesh != visual.mesh:
		_rim_glow.mesh = visual.mesh


# Distancia conservadora desde el origen al extremo inferior del colisionador.
# Compatible con primitivas; no depende del mesh visual ni de su material.
func bottom_offset() -> float:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or collision.shape == null:
		return -1.0
	var shape: Shape3D = collision.shape
	var half: Vector3
	if shape is BoxShape3D:
		half = (shape as BoxShape3D).size * 0.5
	elif shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		half = Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
	elif shape is SphereShape3D:
		var radius: float = (shape as SphereShape3D).radius
		half = Vector3.ONE * radius
	elif shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		half = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	else:
		return -1.0
	var shape_transform: Transform3D = global_transform * collision.transform
	var basis: Basis = shape_transform.basis
	var extent: float = (
		absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z
	)
	return maxf(0.0, extent - (shape_transform.origin.y - global_position.y))


func set_hovered(value: bool) -> void:
	if hovered == value:
		return
	hovered = value
	_update_highlight()
	_wake_visual_process()


## Destello coral y vibración de rechazo cuando una acción o casilla no es válida.
func flash_invalid() -> void:
	_invalid_timer = 0.34
	_update_highlight()
	_wake_visual_process()


## Cabeceo pesado al asentarse sobre la mesa (trebejos de madera/resina).
func trigger_settle_wobble(strength: float = 0.09) -> void:
	if _is_reduce_motion():
		return
	_wobble_strength = clampf(strength, 0.0, 0.22)
	_wobble_timer = 0.28
	_wake_visual_process()


func _is_reduce_motion() -> bool:
	var style := get_node_or_null("/root/ToonStyle")
	return style != null and style.get("reduce_motion") == true


func _wake_visual_process() -> void:
	if _juice_driver != null and is_instance_valid(_juice_driver):
		_juice_driver.set_process(true)


func _has_extra_visual_motion() -> bool:
	return false


func _state_tint() -> Color:
	if _invalid_timer > 0.0:
		return Palette.CORAL
	if is_grabbed:
		return Palette.MINT
	return Palette.SUN_LIGHT


func _update_highlight() -> void:
	var active_state := hovered or is_grabbed or _invalid_timer > 0.0
	var tint := _state_tint()
	if _highlight != null:
		var alpha := 0.26 if _invalid_timer > 0.0 else (0.18 if is_grabbed else 0.14)
		_highlight.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual != null:
		visual.material_overlay = _highlight if active_state else null
		_ensure_rim_glow(visual)
		if _rim_glow != null and is_instance_valid(_rim_glow):
			_rim_glow.visible = active_state
			if active_state and _rim_mat != null:
				_rim_mat.set_shader_parameter("rim_color", tint)
				_rim_mat.set_shader_parameter(
					"pulse_amount", 0.0 if _is_reduce_motion() else 0.12
				)


func _tick_visual_juice(delta: float) -> void:
	var reduce := _is_reduce_motion()
	if _invalid_timer > 0.0:
		_invalid_timer = maxf(_invalid_timer - delta, 0.0)
		if _invalid_timer <= 0.0:
			_update_highlight()
	if _wobble_timer > 0.0:
		_wobble_timer = maxf(_wobble_timer - delta, 0.0)

	var visual := get_node_or_null("Visual") as Node3D
	var at_rest := true
	if visual != null:
		if reduce:
			visual.position = _visual_base_pos
			visual.rotation = _visual_base_rot
		else:
			var target_pos := _visual_base_pos
			var target_rot := _visual_base_rot
			if hovered and not is_grabbed:
				target_pos.y += 0.022
			if _invalid_timer > 0.0:
				target_pos.x += sin(_invalid_timer * TAU * 9.0) * 0.048
				at_rest = false
			if is_grabbed:
				var inv_basis := global_transform.basis.inverse()
				var local_vel := inv_basis * linear_velocity
				target_rot.z += clampf(-local_vel.x * 0.065, -0.26, 0.26)
				target_rot.x += clampf(local_vel.z * 0.065, -0.26, 0.26)
				at_rest = false
			elif _wobble_timer > 0.0:
				var decay := _wobble_timer / 0.28
				target_rot.z += sin((1.0 - decay) * TAU * 2.5) * _wobble_strength * decay
				at_rest = false
			var blend := 1.0 - exp(-18.0 * delta)
			visual.position = visual.position.lerp(target_pos, blend)
			visual.rotation = Vector3(
				lerpf(visual.rotation.x, target_rot.x, blend),
				lerpf(visual.rotation.y, target_rot.y, blend),
				lerpf(visual.rotation.z, target_rot.z, blend)
			)
			if (
				visual.position.distance_to(_visual_base_pos) > 0.0015
				or visual.rotation.distance_to(_visual_base_rot) > 0.002
			):
				at_rest = false

	_update_contact_shadow()
	if (
		not hovered
		and not is_grabbed
		and _invalid_timer <= 0.0
		and _wobble_timer <= 0.0
		and at_rest
		and not _has_extra_visual_motion()
	):
		if visual != null:
			visual.position = _visual_base_pos
			visual.rotation = _visual_base_rot
		if _contact_shadow != null:
			_contact_shadow.visible = false
		if _juice_driver != null:
			_juice_driver.set_process(false)


func _update_contact_shadow() -> void:
	if _contact_shadow == null or not is_inside_tree():
		return
	var height := global_position.y - TABLE_SURFACE_Y
	if (not is_grabbed and not hovered) or height < -0.05 or height > 3.8:
		_contact_shadow.visible = false
		return
	var lift := maxf(height, 0.0)
	if not is_grabbed and lift < 0.01:
		lift = 0.025
	_contact_shadow.visible = true
	_contact_shadow.global_position = Vector3(
		global_position.x, TABLE_SURFACE_Y, global_position.z
	)
	var spread := 1.0 + clampf(lift * 0.42, 0.0, 0.65)
	_contact_shadow.global_basis = Basis.IDENTITY.scaled(Vector3(spread, 1.0, spread))


func on_grab() -> void:
	is_grabbed = true
	sleeping = false
	_update_highlight()
	_wake_visual_process()
	# Al levantarla se estira hacia arriba; al soltarla se aplasta y rebota.
	_juice(Vector3(0.9, 1.14, 0.9))
	_sound("grab")
	grabbed.emit(self)


func on_release() -> void:
	is_grabbed = false
	_update_highlight()
	_wake_visual_process()
	_juice(Vector3(1.14, 0.84, 1.14))
	_sound("drop")
	if is_inside_tree():
		TableVfx.spawn_drop(self, global_position, 0.95, Palette.PAPER)
	released.emit(self)


func _sound(effect: String) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(effect)


## Estirar y aplastar ("squash and stretch") solo la malla visual: el colisionador y la física
## no cambian. Se desactiva con ToonStyle.reduce_motion.
func _juice(target: Vector3) -> void:
	if _is_reduce_motion():
		var still_visual := get_node_or_null("Visual") as Node3D
		if still_visual != null:
			still_visual.scale = _juice_base
		return
	var visual := get_node_or_null("Visual") as Node3D
	if visual == null or not is_inside_tree():
		return
	if _juice_tween != null and _juice_tween.is_valid():
		_juice_tween.kill()
		visual.scale = _juice_base
	_juice_base = visual.scale
	_juice_tween = create_tween()
	_juice_tween.tween_property(visual, "scale", _juice_base * target, 0.07).set_ease(Tween.EASE_OUT)
	_juice_tween.tween_property(visual, "scale", _juice_base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func set_table_locked(value: bool) -> bool:
	if value == is_table_locked:
		return true
	if is_grabbed or (freeze and not is_table_locked):
		return false
	is_table_locked = value
	if value:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = value
	if not value:
		sleeping = false
	return true


# Un impulso en vez de teletransportar el cuerpo mantiene las colisiones activas.
func rotate_object(angle: float) -> void:
	sleeping = false
	apply_torque_impulse(Vector3.UP * angle * mass)
