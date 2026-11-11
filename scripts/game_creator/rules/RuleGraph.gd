# RuleGraph.gd
# Contenedor de nodos de reglas y conexiones entre ellos.
class_name RuleGraph
extends Resource

@export var graph_name: String = "Grafo de Reglas"
@export var nodes: Array[RuleNode] = []
# Conexiones: lista de diccionarios {from_guid, from_port, to_guid, to_port}
@export var connections: Array[Dictionary] = []

func _init(p_name: String = ""):
	graph_name = p_name if p_name != "" else "Grafo de Reglas"

# Agrega un nodo al grafo.
func add_node(node: RuleNode) -> void:
	nodes.append(node)

# Remueve un nodo por GUID.
func remove_node(guid: String) -> void:
	for i in range(nodes.size() - 1, -1, -1):
		if nodes[i].guid == guid:
			nodes.remove_at(i)
	# Remover conexiones que hagan referencia a este nodo.
	for i in range(connections.size() - 1, -1, -1):
		if connections[i].get("from_guid") == guid or connections[i].get("to_guid") == guid:
			connections.remove_at(i)

# Obtiene un nodo por GUID.
func get_node(guid: String) -> RuleNode:
	for node in nodes:
		if node.guid == guid:
			return node
	return null

# Agrega una conexión entre nodos.
func add_connection(from_guid: String, from_port: String, to_guid: String, to_port: String) -> void:
	connections.append({
		"from_guid": from_guid,
		"from_port": from_port,
		"to_guid": to_guid,
		"to_port": to_port,
	})

# Serializa el grafo a Dictionary.
func to_dict() -> Dictionary:
	return {
		"graph_name": graph_name,
		"nodes": [n.to_dict() for n in nodes],
		"connections": connections,
	}

# Deserializa desde Dictionary.
func from_dict(data: Dictionary) -> void:
	graph_name = data.has("graph_name") ? data["graph_name"] : graph_name
	nodes.clear()
	connections.clear()
	for nd in data.get("nodes", []):
		var node: RuleNode = _instantiate_node(nd.get("type", ""))
		if node != null:
			node.from_dict(nd)
			nodes.append(node)
	for conn in data.get("connections", []):
		connections.append(conn)

# Instancia un nodo por su nombre de clase.
func _instantiate_node(class_name: String) -> RuleNode:
	match class_name:
		"RuleEventNode": return RuleEventNode.new()
		"RuleActionNode": return RuleActionNode.new()
		"RuleConditionNode": return RuleConditionNode.new()
		_: return null
