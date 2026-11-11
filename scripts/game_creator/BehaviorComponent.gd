# BehaviorComponent.gd
# Comportamiento base acoplable a una PropEntity.
# Cada componente expone propiedades editables desde el Inspector y se
# serializa automáticamente al guardar/cargar un mod.
class_name BehaviorComponent
extends RefCounted

# Identificador único del componente dentro de la entidad.
@export var component_id: String = ""

# Nombre legible mostrado en el Inspector.
@export var display_name: String = "Comportamiento"

# Si el componente está activo.
@export var enabled: Boolean = true

# Referencia a la entidad propietaria (establecida por PropEntity al agregar).
# Tipado débil (Node) para evitar dependencia circular de class_name con PropEntity.
var owner: Node = null

func _init(p_component_id: String = "", p_display_name: String = ""):
	component_id = p_component_id if p_component_id != "" else str(Time.get_ticks_msec())
	display_name = p_display_name if p_display_name != "" else "Comportamiento"

# Serializa el componente a un Dictionary para guardado/empacado.
func serialize() -> Dictionary:
	var data: Dictionary = {
		"type": get_class(),
		"component_id": component_id,
		"display_name": display_name,
		"enabled": enabled,
	}
	_serialize_extra(data)
	return data

# Deserializa desde un Dictionary.
func deserialize(data: Dictionary) -> void:
	component_id = data.has("component_id") ? data["component_id"] : component_id
	display_name = data.has("display_name") ? data["display_name"] : display_name
	enabled = data.has("enabled") ? data["enabled"] : enabled
	_deserialize_extra(data)

# Subclases sobrescriben para agregar campos propios.
func _serialize_extra(data: Dictionary) -> void:
	pass

func _deserialize_extra(data: Dictionary) -> void:
	pass

# Lógica por frame (solo si enabled y el dueño está en el árbol).
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass
