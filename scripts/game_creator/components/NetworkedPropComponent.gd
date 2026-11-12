# NetworkedPropComponent.gd
# Vincula automáticamente una PropEntity con Photon Fusion para replicar
# posición, rotación y autoridad de estado en tiempo real.
class_name NetworkedPropComponent
extends BehaviorComponent

@export var networked: bool = true
@export var authority_mode: int = 0  # 0=StateAuthority (host), 1=InputAuthority (cliente)
@export var sync_position: bool = true
@export var sync_rotation: bool = true
@export var sync_scale: bool = false
@export var sync_custom_state: bool = false

# Nodo de red asociado (NetworkBehaviour de Fusion) asignado por NetworkSceneManager.
var fusion_node: Node = null

# Último estado replicado (para detectar cambios y enviar red).
var _last_position: Vector3 = Vector3.ZERO
var _last_rotation: Quat = Quat.IDENTITY
var _last_scale: Vector3 = Vector3.ONE

func _serialize_extra(data: Dictionary) -> void:
	data["networked"] = networked
	data["authority_mode"] = authority_mode
	data["sync_position"] = sync_position
	data["sync_rotation"] = sync_rotation
	data["sync_scale"] = sync_scale
	data["sync_custom_state"] = sync_custom_state

func _deserialize_extra(data: Dictionary) -> void:
	networked = data.get("networked", networked)
	authority_mode = data.get("authority_mode", authority_mode)
	sync_position = data.get("sync_position", sync_position)
	sync_rotation = data.get("sync_rotation", sync_rotation)
	sync_scale = data.get("sync_scale", sync_scale)
	sync_custom_state = data.get("sync_custom_state", sync_custom_state)

# Devuelve true si hay cambios de transformación que replicar.
func has_transform_changed(entity: PropEntity) -> bool:
	if entity.global_position != _last_position:
		return true
	if entity.global_rotation != _last_rotation:
		return true
	if sync_scale and entity.global_scale != _last_scale:
		return true
	return false

# Actualiza los valores de referencia tras un envío de red.
func snapshot_transform(entity: PropEntity) -> void:
	_last_position = entity.global_position
	_last_rotation = entity.global_rotation
	_last_scale = entity.global_scale
