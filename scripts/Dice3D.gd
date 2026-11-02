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


func roll() -> void:
	if is_grabbed:
		return
	_awaiting_result = true
	sleeping = false
	apply_central_impulse(
		Vector3(randf_range(-0.8, 0.8), randf_range(2.5, 3.5), randf_range(-0.8, 0.8)) * mass
	)
	apply_torque_impulse(
		Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)) * mass
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
		result_ready.emit(top_face())


func _make_pips() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("25352f")
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.035
	pip_mesh.height = 0.07
	pip_mesh.material = material
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
			pip.position = normal * 0.251 + (u * p.x + v * p.y) * 0.13
			add_child(pip)
