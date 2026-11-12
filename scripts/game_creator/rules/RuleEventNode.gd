# RuleEventNode.gd
# Nodo de evento (trigger): punto de entrada del grafo.
class_name RuleEventNode
extends RuleNode

@export var event_name: String = ""

func _init(p_guid: String = "", p_name: String = "", p_event: String = ""):
	guid = p_guid if p_guid != "" else str(Time.get_ticks_msec())
	node_name = p_name if p_name != "" else "Evento"
	event_name = p_event

func to_dict() -> Dictionary:
	return {
		"guid": guid,
		"node_name": node_name,
		"position": [position.x, position.y],
		"type": get_class(),
		"event_name": event_name,
	}

func from_dict(data: Dictionary) -> void:
	guid = data.get("guid", guid)
	node_name = data.get("node_name", node_name)
	event_name = data.get("event_name", "")
	if data.has("position"):
		var pos: Array = data["position"]
		position = Vector2(pos[0], pos[1])
