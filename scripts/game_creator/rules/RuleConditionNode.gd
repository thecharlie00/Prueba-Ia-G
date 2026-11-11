# RuleConditionNode.gd
# Nodo condicional: evalúa una expresión booleana y ramifica el grafo.
class_name RuleConditionNode
extends RuleNode

@export var condition_expression: String = "true"

func _init(p_guid: String = "", p_name: String = "", p_expr: String = ""):
	_ = p_guid
	node_name = p_name if p_name != "" else "Condición"
	condition_expression = p_expr if p_expr != "" else "true"

func evaluate(engine: RuleEngine) -> bool:
	# Por defecto devuelve true. Las subclases especializadas sobrescriben.
	return true

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"guid": guid,
		"node_name": node_name,
		"position": [position.x, position.y],
		"type": get_class(),
		"condition_expression": condition_expression,
	}
	return d

func from_dict(data: Dictionary) -> void:
	guid = data.has("guid") ? data["guid"] : guid
	node_name = data.has("node_name") ? data["node_name"] : node_name
	condition_expression = data.has("condition_expression") ? data["condition_expression"] : condition_expression
	if data.has("position"):
		var pos: Array = data["position"]
		position = Vector2(pos[0], pos[1])
