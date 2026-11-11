# PropEntity.gd
# Entidad base colocable en el tablero. Es un Node3D vacío al que se le acoplan
# BehaviorComponent(s) para darle funcionalidad (física, contenedor, interacción, red, etc.).
# Soporta serialización completa a Dictionary para guardado, carga y empaquetado de mods.
class_name PropEntity
extends Node3D

# Identificador único global de la entidad dentro de la escena/mod.
@export var entity_id: String = ""

# Nombre legible mostrado en la jerarquía e Inspector.
@export var entity_name: String = "Nueva Entidad"

# Si la entidad está bloqueada (no se puede seleccionar ni mover en edición).
@export var is_locked: Boolean = false

# Etiquetas para búsqueda y filtrado en el Asset Browser.
@export var tags: Array[String] = []

# Lista de componentes comportamentales acoplados.
@export var components: Array[BehaviorComponent] = []

# Señal emitida cuando se agrega o remueve un componente.
signal component_added(component: BehaviorComponent)
signal component_removed(component: BehaviorComponent)
signal entity_selected(entity: PropEntity)
signal entity_deselected(entity: PropEntity)

# Estado interno de selección del editor.
var _is_selected: Boolean = false

func _init(p_entity_id: String = "", p_entity_name: String = ""):
	entity_id = p_entity_id if p_entity_id != "" else str(Time.get_ticks_msec())
	entity_name = p_entity_name if p_entity_name != "" else "Nueva Entidad"

# Agrega un componente a la entidad.
func add_component(component: BehaviorComponent) -> void:
	if component in components:
		return
	component.owner = self
	components.append(component)
	add_child(component)
	component_added.emit(component)

# Remueve un componente de la entidad.
func remove_component(component: BehaviorComponent) -> void:
	if not component in components:
		return
	components.erase(component)
	remove_child(component)
	component.owner = null
	component_removed.emit(component)

# Obtiene el primer componente del tipo dado (por nombre de clase).
func get_component(p_component_class: String) -> BehaviorComponent:
	for comp in components:
		if comp.get_class() == p_component_class:
			return comp
	return null

# Obtiene todos los componentes de una clase dada.
func get_components(p_component_class: String) -> Array[BehaviorComponent]:
	var result: Array[BehaviorComponent] = []
	for comp in components:
		if comp.get_class() == p_component_class:
			result.append(comp)
	return result

# Serializa la entidad completa a Dictionary.
func serialize() -> Dictionary:
	var comps_data: Array = []
	for comp in components:
		comps_data.append(comp.serialize())
	return {
		"entity_id": entity_id,
		"entity_name": entity_name,
		"is_locked": is_locked,
		"tags": tags,
		"position": global_position,
		"rotation": global_rotation,
		"scale": global_scale,
		"components": comps_data,
	}

# Deserializa desde un Dictionary.
func deserialize(data: Dictionary) -> void:
	entity_id = data.has("entity_id") ? data["entity_id"] : entity_id
	entity_name = data.has("entity_name") ? data["entity_name"] : entity_name
	is_locked = data.has("is_locked") ? data["is_locked"] : is_locked
	tags = data.has("tags") ? data["tags"] : tags
	global_position = data.has("position") ? data["position"] : global_position
	global_rotation = data.has("rotation") ? data["rotation"] : global_rotation
	global_scale = data.has("scale") ? data["scale"] : global_scale

	# Reconstruir componentes.
	for comp_data in data.get("components", []):
		var comp_type: String = comp_data.get("type", "")
		var comp: BehaviorComponent = _instantiate_component(comp_type)
		if comp != null:
			comp.deserialize(comp_data)
			add_component(comp)

# Instancia un BehaviorComponent por su nombre de clase.
func _instantiate_component(p_component_class: String) -> BehaviorComponent:
	match p_component_class:
		"PhysicsComponent": return PhysicsComponent.new()
		"ContainerComponent": return ContainerComponent.new()
		"InteractiveComponent": return InteractiveComponent.new()
		"NetworkedPropComponent": return NetworkedPropComponent.new()
		"VisualComponent": return VisualComponent.new()
		_: return null

# Marca la entidad como seleccionada/deseleccionada en el editor.
func set_selected(selected: Boolean) -> void:
	if _is_selected == selected:
		return
	_is_selected = selected
	if selected:
		entity_selected.emit(self)
	else:
		entity_deselected.emit(self)

func is_selected() -> Boolean:
	return _is_selected
