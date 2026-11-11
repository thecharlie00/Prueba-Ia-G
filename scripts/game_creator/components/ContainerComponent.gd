# ContainerComponent.gd
# Zona lógica que alberga entidades: mano del jugador, mazo, descarte, caja de suministros.
# Define visibilidad (frente arriba/abajo) y capacidad.
extends BehaviorComponent

enum ContainerType { HAND, DECK, DISCARD, SUPPLY, ZONE }

@export var container_type: ContainerType = ContainerType.ZONE
@export var hidden_faces: Boolean = false  # true = los elementos se ven de dorso
@export var max_capacity: int = -1         # -1 = ilimitado
@export var slot_spacing: float = 0.15     # separación entre slots en metros
@export var slot_arc_angle: float = 30.0   # ángulo de abanico para manos

# Lista de entidades contenidas (referencias por entity_id).
@export var contained_ids: Array[String] = []

# Nodo Area3D / Marker3D que representa el contenedor en la escena.
var zone_node: Node3D = null

func _serialize_extra(data: Dictionary) -> void:
	data["container_type"] = container_type
	data["hidden_faces"] = hidden_faces
	data["max_capacity"] = max_capacity
	data["slot_spacing"] = slot_spacing
	data["slot_arc_angle"] = slot_arc_angle
	data["contained_ids"] = contained_ids

func _deserialize_extra(data: Dictionary) -> void:
	container_type = data.has("container_type") ? data["container_type"] : container_type
	hidden_faces = data.has("hidden_faces") ? data["hidden_faces"] : hidden_faces
	max_capacity = data.has("max_capacity") ? data["max_capacity"] : max_capacity
	slot_spacing = data.has("slot_spacing") ? data["slot_spacing"] : slot_spacing
	slot_arc_angle = data.has("slot_arc_angle") ? data["slot_arc_angle"] : slot_arc_angle
	contained_ids = data.has("contained_ids") ? data["contained_ids"] : []

# Calcula la posición de un slot dentro del contenedor según su índice.
func get_slot_position(index: int, total: int) -> Vector3:
class_name ContainerComponent
	if zone_node == null:
		return Vector3.ZERO
	match container_type:
		ContainerType.HAND:
			var angle_deg: float = -slot_arc_angle / 2.0 + (slot_arc_angle * index) / max(1, total - 1)
			var angle_rad: float = deg_to_rad(angle_deg)
			return Vector3(sin(angle_rad) * 0.5, 0.1, cos(angle_rad) * 0.5) + zone_node.global_position
		ContainerType.DECK:
			return zone_node.global_position + Vector3(0, index * 0.02, index * 0.05)
		ContainerType.DISCARD:
			return zone_node.global_position + Vector3(index * 0.01, 0.02, 0)
		_:
			return zone_node.global_position

func can_accept() -> Boolean:
	return max_capacity < 0 or contained_ids.size() < max_capacity
