class_name HomePawn
extends CharacterBody3D
## El peón de arcilla que se mueve por la habitación: WASD, flechas o stick, o un clic en
## el suelo o en un objeto para que vaya solo. Empuja los juguetes sueltos al chocar.

signal arrived

const SPEED := 4.6
const ACCEL := 22.0
const TURN := 12.0
const PUSH := 1.6

var target := Vector3.INF
var meeple: Node3D
## Lo controla Home: false mientras hay un panel abierto.
var input_enabled := true
var _bob := 0.0
var _was_moving := false
var _squash := Vector3.ONE
var _blink := 2.0
var _step_side := 1.0
## Malla compartida de las nubecillas de polvo.
static var _dust_mesh: SphereMesh
## Escala base del muñeco (la que da el tamaño en la sala).
const BASE_SCALE := 0.82


func _ready() -> void:
	collision_layer = 1 << 1
	collision_mask = 1 | (1 << 2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)
	meeple = HomeDecor.make_meeple(HomePrefs.pawn_color())
	meeple.scale = Vector3.ONE * BASE_SCALE
	add_child(meeple)
	PawnWear.apply(meeple, HomePrefs.hat(), HomePrefs.accessory())


func set_color(color: Color) -> void:
	HomeDecor.tint_meeple(meeple, color)


## Vuelve a leer color, sombrero y complemento guardados.
func refresh_look() -> void:
	set_color(HomePrefs.pawn_color())
	PawnWear.apply(meeple, HomePrefs.hat(), HomePrefs.accessory())
	_squash = Vector3(1.15, 0.85, 1.15)


func walk_to(point: Vector3) -> void:
	target = Vector3(point.x, 0, point.z)


func stop() -> void:
	target = Vector3.INF
	velocity = Vector3.ZERO


## Dirección pedida por teclado o mando, en el plano (la cámara mira hacia -z).
func input_direction() -> Vector3:
	if not input_enabled:
		return Vector3.ZERO
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	return Vector3(v.x, 0, v.y).limit_length(1.0)


func _physics_process(delta: float) -> void:
	var wish := input_direction()
	if wish != Vector3.ZERO:
		target = Vector3.INF
	elif target != Vector3.INF:
		var to := target - Vector3(global_position.x, 0, global_position.z)
		if to.length() < 0.15:
			target = Vector3.INF
			arrived.emit()
		else:
			wish = to.normalized() * clampf(to.length() / 0.8, 0.35, 1.0)
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(wish * SPEED, ACCEL * delta)
	velocity = Vector3(flat.x, velocity.y - 30.0 * delta if not is_on_floor() else 0.0, flat.z)
	move_and_slide()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var body := hit.get_collider() as RigidBody3D
		if body != null:
			body.apply_central_impulse(-hit.get_normal() * PUSH * delta * 60.0 * 0.05 + Vector3.UP * 0.02)
	var moving := flat.length() > 0.2
	if moving:
		var facing := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, TURN * delta))
		var before := sin(_bob)
		_bob += delta * 11.0
		meeple.position.y = absf(sin(_bob)) * 0.09
		meeple.rotation.z = sin(_bob) * 0.06
		# Un paso cada vez que el balanceo cruza el centro: polvo bajo el pie.
		if signf(before) != signf(sin(_bob)):
			_step_side = -_step_side
			_puff(global_position + global_basis.x * 0.25 * _step_side)
	else:
		meeple.position.y = lerpf(meeple.position.y, 0.0, minf(1.0, 10.0 * delta))
		meeple.rotation.z = lerpf(meeple.rotation.z, 0.0, minf(1.0, 10.0 * delta))
	# Estirar al arrancar, aplastar al parar.
	if moving and not _was_moving:
		_squash = Vector3(0.9, 1.12, 0.9)
	elif _was_moving and not moving:
		_squash = Vector3(1.14, 0.84, 1.14)
	_was_moving = moving
	_squash = _squash.lerp(Vector3.ONE, minf(1.0, delta * 9.0))
	meeple.scale = _squash * BASE_SCALE
	_animate_eyes(delta)


## Saltito al usar un objeto.
func hop() -> void:
	var tween := create_tween()
	tween.tween_property(meeple, "position:y", 0.45, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(meeple, "position:y", 0.0, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void: _squash = Vector3(1.18, 0.8, 1.18))


## Parpadeo cada pocos segundos.
func _animate_eyes(delta: float) -> void:
	_blink -= delta
	var head := meeple.get_node_or_null("Head") as Node3D
	if head == null:
		return
	var closed := _blink < 0.12
	for eye in head.get_children():
		if eye is Node3D and not str(eye.name).begins_with("Wear"):
			(eye as Node3D).scale.y = 0.15 if closed else 1.0
	if _blink < 0.0:
		_blink = randf_range(2.2, 4.5)


## Nubecilla de polvo que crece y se desvanece.
func _puff(at: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dust := MeshInstance3D.new()
	if _dust_mesh == null:
		_dust_mesh = SphereMesh.new()
		_dust_mesh.radius = 0.12
		_dust_mesh.height = 0.24
		_dust_mesh.radial_segments = 16
		_dust_mesh.rings = 8
	dust.mesh = _dust_mesh
	# Copia de un material base que vive toda la sesión: así su shader no se libera al
	# pararse el peón ni se recompila (con tirón) al volver a andar.
	var material := FxMaterials.make(FxMaterials.GLOW_ALPHA, Color(1, 0.97, 0.9, 0.7))
	dust.material_override = material
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.position = Vector3(at.x, 0.08, at.z)
	parent.add_child(dust)
	var tween := dust.create_tween().set_parallel(true)
	tween.tween_property(dust, "scale", Vector3.ONE * 2.2, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(dust, "position:y", 0.3, 0.45)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(dust.queue_free)
