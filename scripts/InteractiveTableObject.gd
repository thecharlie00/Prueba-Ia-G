class_name InteractiveTableObject
extends RigidBody3D

signal grabbed(object: InteractiveTableObject)
signal released(object: InteractiveTableObject)

@export var display_name := "Pieza"
@export var highlight_color := Color(0.36, 0.88, 0.76, 1.0)
var is_grabbed := false
# Bloqueo explícito de mesa, independiente del freeze temporal de animaciones.
var is_table_locked := false
var hovered := false
var _highlight: StandardMaterial3D
var _juice_tween: Tween
var _juice_base := Vector3.ONE


func _ready() -> void:
	continuous_cd = true
	_highlight = StandardMaterial3D.new()
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight.albedo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.25)
	_update_highlight()


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


func _update_highlight() -> void:
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual:
		visual.material_overlay = _highlight if (hovered or is_grabbed) else null


func on_grab() -> void:
	is_grabbed = true
	sleeping = false
	_update_highlight()
	# Al levantarla se estira hacia arriba; al soltarla se aplasta y rebota.
	_juice(Vector3(0.9, 1.14, 0.9))
	grabbed.emit(self)


func on_release() -> void:
	is_grabbed = false
	_update_highlight()
	_juice(Vector3(1.14, 0.84, 1.14))
	released.emit(self)


## Estirar y aplastar ("squash and stretch") solo la malla visual: el colisionador y la física
## no cambian. Se desactiva con ToonStyle.reduce_motion.
func _juice(target: Vector3) -> void:
	var style := get_node_or_null("/root/ToonStyle")
	if style != null and style.reduce_motion:
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
