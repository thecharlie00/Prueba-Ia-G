class_name Domino3D
extends InteractiveTableObject

# Valores configurados antes de entrar al árbol; cada extremo tiene de cero a seis puntos.
@export_range(0, 6) var left_value := 0
@export_range(0, 6) var right_value := 0


func _ready() -> void:
	super._ready()
	display_name = "Dominó %d | %d" % [left_value, right_value]
	_make_face()


# Es un impulso físico, no un cambio determinista de cara: depende de las colisiones.
func flip() -> void:
	if is_grabbed or freeze:
		return
	sleeping = false
	apply_central_impulse(Vector3.UP * mass * 0.6)
	apply_torque_impulse(global_basis.x.normalized() * mass * 0.08)


func _make_face() -> void:
	var dots := {
		0: [],
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
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.013
	pip_mesh.height = 0.026
	var pip_material := StandardMaterial3D.new()
	pip_material.albedo_color = Color("24332f")
	pip_mesh.material = pip_material
	var face := Node3D.new()
	face.name = "Pips"
	$Visual.add_child(face)
	for side in range(2):
		var value: int = left_value if side == 0 else right_value
		for offset: Vector2 in dots[clampi(value, 0, 6)]:
			var pip := MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.position = Vector3(
				(-0.11 if side == 0 else 0.11) + offset.x * 0.047, 0.046, offset.y * 0.062
			)
			face.add_child(pip)
