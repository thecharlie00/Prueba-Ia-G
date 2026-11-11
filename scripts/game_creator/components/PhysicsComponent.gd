# PhysicsComponent.gd
# Componente de físicas para objetos colocables (fichas, dados, cartas, miniaturas).
class_name PhysicsComponent
extends BehaviorComponent

@export var mass: float = 1.0
@export var friction: float = 0.5
@export var bounce: float = 0.1
@export var gravity_scale: float = 1.0
@export var stackable: Boolean = true
@export var collision_layer: int = 2  # "Piezas"
@export var collision_mask: int = 7   # Mesa + Piezas + Bandeja de dados
@export var rigid_body_mode: int = RigidBody3D.MODE_RIGID  # 0=Rigid,1=Static,2=Character,3=Kinematic

# Nodo RigidBody3D asociado (establecido por el editor al instanciar).
var body_node: RigidBody3D = null

func _serialize_extra(data: Dictionary) -> void:
	data["mass"] = mass
	data["friction"] = friction
	data["bounce"] = bounce
	data["gravity_scale"] = gravity_scale
	data["stackable"] = stackable
	data["collision_layer"] = collision_layer
	data["collision_mask"] = collision_mask
	data["rigid_body_mode"] = rigid_body_mode

func _deserialize_extra(data: Dictionary) -> void:
	mass = data.has("mass") ? data["mass"] : mass
	friction = data.has("friction") ? data["friction"] : friction
	bounce = data.has("bounce") ? data["bounce"] : bounce
	gravity_scale = data.has("gravity_scale") ? data["gravity_scale"] : gravity_scale
	stackable = data.has("stackable") ? data["stackable"] : stackable
	collision_layer = data.has("collision_layer") ? data["collision_layer"] : collision_layer
	collision_mask = data.has("collision_mask") ? data["collision_mask"] : collision_mask
	rigid_body_mode = data.has("rigid_body_mode") ? data["rigid_body_mode"] : rigid_body_mode

# Aplica la configuración a un RigidBody3D existente.
func apply_to_body(body: RigidBody3D) -> void:
	body_node = body
	body.mass = mass
	body.friction = friction
	body.bounce = bounce
	body.gravity_scale = gravity_scale
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	body.mode = rigid_body_mode
