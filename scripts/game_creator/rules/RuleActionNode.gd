# RuleActionNode.gd
# Nodo de acción: realiza una operación (mover objeto, cambiar puntuación, etc.).
class_name RuleActionNode
extends RuleNode

@export var action_name: String = "Acción"

func _init(p_guid: String = "", p_name: String = "", p_action: String = ""):
	guid = p_guid if p_guid != "" else str(Time.get_ticks_msec())
	node_name = p_name if p_name != "" else "Acción"
	action_name = p_action if p_action != "" else "Acción"

func to_dict() -> Dictionary:
	return {
		"guid": guid,
		"node_name": node_name,
		"position": [position.x, position.y],
		"type": get_class(),
		"action_name": action_name,
	}

func from_dict(data: Dictionary) -> void:
	guid = data.get("guid", guid)
	node_name = data.get("node_name", node_name)
	action_name = data.get("action_name", action_name)
	if data.has("position"):
		var pos: Array = data["position"]
		position = Vector2(pos[0], pos[1])
