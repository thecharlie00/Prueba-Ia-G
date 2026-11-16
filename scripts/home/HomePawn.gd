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
	meeple.scale = Vector3.ONE * 0.82
	add_child(meeple)


func set_color(color: Color) -> void:
	HomeDecor.tint_meeple(meeple, color)


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
	if flat.length() > 0.2:
		var facing := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, TURN * delta))
		_bob += delta * 11.0
		meeple.position.y = absf(sin(_bob)) * 0.09
		meeple.rotation.z = sin(_bob) * 0.06
	else:
		meeple.position.y = lerpf(meeple.position.y, 0.0, minf(1.0, 10.0 * delta))
		meeple.rotation.z = lerpf(meeple.rotation.z, 0.0, minf(1.0, 10.0 * delta))
