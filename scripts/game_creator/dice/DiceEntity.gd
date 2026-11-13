# DiceEntity.gd
# Dado físico basado en RigidBody3D con detección de cara arriba y autoridad de azar.
class_name DiceEntity
extends RigidBody3D

@export var dice_definition: DiceDefinition = null
@export var dice_tray_area: Area3D = null

# Resultado del lanzamiento una vez detenido.
var last_result: int = 0
var _is_rolling: bool = false

func _ready() -> void:
	if dice_definition == null:
		dice_definition = DiceDefinition.new()

# Lanza el dado con fuerza y torque dados (llamado por la autoridad de red/host).
func roll(force: Vector3, torque: Vector3) -> void:
	apply_central_impulse(force)
	apply_torque_impulse(torque)
	_is_rolling = true
	last_result = 0

func _physics_process(delta: float) -> void:
	if _is_rolling and linear_velocity.length() < 0.05 and angular_velocity.length() < 0.05:
		_is_rolling = false
		last_result = _detect_face_up()
		# Disparar evento en el motor de reglas (GameCreatorCore es autoload).
		if GameCreatorCore != null and GameCreatorCore.rule_engine != null:
			GameCreatorCore.rule_engine.trigger_event("OnDiceRolled", [last_result, self])

# Detecta qué cara queda hacia arriba comparando normales.
func _detect_face_up() -> int:
	if dice_definition == null or dice_definition.faces.size() == 0:
		return 0
	var up: Vector3 = Vector3.UP
	var best_index: int = 0
	var best_dot: float = -2.0
	for i in range(dice_definition.faces.size()):
		var face_normal: Vector3 = (global_transform.basis * Vector3.UP)
		var dot: float = face_normal.dot(up)
		if dot > best_dot:
			best_dot = dot
			best_index = i
	return dice_definition.faces[best_index].value
