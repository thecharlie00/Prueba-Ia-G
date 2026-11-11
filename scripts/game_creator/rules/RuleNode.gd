# RuleNode.gd
# Nodo base del grafo de lógica visual. Cada nodo tiene un GUID único y puede
# tener puertos de entrada/salida de ejecución y de valor.
class_name RuleNode
extends Resource

@export var guid: String = ""
@export var node_name: String = "Nodo"
@export var position: Vector2 = Vector2.ZERO  # posición en el editor visual de nodos

func _init(p_guid: String = "", p_name: String = ""):
	guid = p_guid if p_guid != "" else str(Time.get_ticks_msec())
	node_name = p_name if p_name != "" else "Nodo"

# Ejecuta el nodo dentro del motor de reglas.
# input_args: argumentos recibidos desde nodos predecesores.
# Devuelve un Array de Variant para pasar a nodos sucesores (puede estar vacío).
func execute(engine: RuleEngine, input_args: Array) -> Array:
	return input_args

# Serialización específica (llamada por RuleGraph).
func to_dict() -> Dictionary:
	return {
		"guid": guid,
		"node_name": node_name,
		"position": [position.x, position.y],
		"type": get_class(),
	}

func from_dict(data: Dictionary) -> void:
	guid = data.has("guid") ? data["guid"] : guid
	node_name = data.has("node_name") ? data["node_name"] : node_name
	if data.has("position"):
		var pos: Array = data["position"]
		position = Vector2(pos[0], pos[1])
