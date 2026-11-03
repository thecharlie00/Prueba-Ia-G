class_name InteractiveTableObject
extends RigidBody3D

signal grabbed(object: InteractiveTableObject)
signal released(object: InteractiveTableObject)

@export var display_name := "Pieza"
@export var highlight_color := Color(0.36, 0.88, 0.76, 1.0)
var is_grabbed := false
var hovered := false
var _highlight: StandardMaterial3D


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
	grabbed.emit(self)


func on_release() -> void:
	is_grabbed = false
	_update_highlight()
	released.emit(self)


# Un impulso en vez de teletransportar el cuerpo mantiene las colisiones activas.
func rotate_object(angle: float) -> void:
	sleeping = false
	apply_torque_impulse(Vector3.UP * angle * mass)
