# LogicGraph.gd
# La lógica de un juego como grafo: bloques (con su tipo, posición y parámetros) y cables
# entre una salida y una entrada. Se guarda en JSON junto a la mesa y se comprueba al cargar.
class_name LogicGraph
extends RefCounted

const MAX_NODES := 300
const MAX_LINKS := 900
const MAX_CODE := 4000
const MAX_TEXT := 200

## id → {"id", "type", "pos": Vector2, "params": {}}
var nodes := {}
## [{"from", "out", "to", "in"}]
var links: Array = []
var _next_id := 1


func add_node(type: String, pos := Vector2.ZERO) -> int:
	if not LogicNodes.has(type) or nodes.size() >= MAX_NODES:
		return 0
	var id := _next_id
	_next_id += 1
	nodes[id] = {"id": id, "type": type, "pos": pos, "params": LogicNodes.default_params(type)}
	return id


func remove_node(id: int) -> void:
	nodes.erase(id)
	links = links.filter(func(link: Dictionary) -> bool: return link["from"] != id and link["to"] != id)


## Une la salida `out` de `from` con la entrada `in` de `to`. Una entrada de valor sólo
## tiene un cable (el nuevo sustituye al anterior); una salida de flujo, también.
func connect_ports(from: int, out: String, to: int, input: String) -> bool:
	if not nodes.has(from) or not nodes.has(to) or from == to or links.size() >= MAX_LINKS:
		return false
	var out_type := LogicNodes.port_type(LogicNodes.outputs(nodes[from]["type"]), out)
	var in_type := LogicNodes.port_type(LogicNodes.inputs(nodes[to]["type"]), input)
	if out_type < 0 or in_type < 0 or not LogicNodes.compatible(out_type, in_type):
		return false
	if in_type == LogicNodes.EXEC:
		links = links.filter(func(link: Dictionary) -> bool: return not (link["from"] == from and link["out"] == out))
	else:
		links = links.filter(func(link: Dictionary) -> bool: return not (link["to"] == to and link["in"] == input))
	links.append({"from": from, "out": out, "to": to, "in": input})
	return true


func disconnect_ports(from: int, out: String, to: int, input: String) -> void:
	links = links.filter(func(link: Dictionary) -> bool:
		return not (link["from"] == from and link["out"] == out and link["to"] == to and link["in"] == input))


## Cable que llega a una entrada (o {}).
func link_into(to: int, input: String) -> Dictionary:
	for link in links:
		if link["to"] == to and link["in"] == input:
			return link
	return {}


## Bloques que siguen a una salida de flujo.
func next_of(from: int, out: String) -> Array:
	var result: Array = []
	for link in links:
		if link["from"] == from and link["out"] == out:
			result.append(link["to"])
	return result


func events(type: String) -> Array:
	return nodes.values().filter(func(node: Dictionary) -> bool: return node["type"] == type)


func is_empty() -> bool:
	return nodes.is_empty()


func has_code() -> bool:
	return nodes.values().any(func(node: Dictionary) -> bool: return LogicNodes.DEFS[node["type"]]["cat"] == "codigo")


# --- Guardar y cargar ---------------------------------------------------------------

func to_record() -> Dictionary:
	var list: Array = []
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		var node: Dictionary = nodes[id]
		list.append({"id": id, "type": node["type"], "pos": [snappedf(node["pos"].x, 1.0), snappedf(node["pos"].y, 1.0)], "params": node["params"].duplicate()})
	return {"version": 1, "nodes": list, "links": links.map(func(link: Dictionary) -> Array: return [link["from"], link["out"], link["to"], link["in"]])}


## Grafo limpio desde datos guardados, o null si algo no cuadra.
static func from_record(data: Variant) -> LogicGraph:
	var graph := LogicGraph.new()
	if data == null:
		return graph
	if not data is Dictionary or not data.get("nodes") is Array or not data.get("links") is Array:
		return null
	if (data["nodes"] as Array).size() > MAX_NODES or (data["links"] as Array).size() > MAX_LINKS:
		return null
	for item in data["nodes"]:
		if not item is Dictionary:
			return null
		var type := str(item.get("type", ""))
		var id_value: Variant = item.get("id")
		var pos: Variant = item.get("pos")
		if not LogicNodes.has(type) or not (id_value is int or id_value is float) or not pos is Array or (pos as Array).size() != 2:
			return null
		var id := int(id_value)
		if id < 1 or id > 100000 or graph.nodes.has(id):
			return null
		var params := _clean_params(type, item.get("params", {}))
		if params.is_empty() and not LogicNodes.params(type).is_empty():
			return null
		graph.nodes[id] = {"id": id, "type": type, "pos": Vector2(clampf(float(pos[0]), -20000, 20000), clampf(float(pos[1]), -20000, 20000)), "params": params}
		graph._next_id = maxi(graph._next_id, id + 1)
	for item in data["links"]:
		if not item is Array or (item as Array).size() != 4:
			return null
		if not graph.connect_ports(int(item[0]), str(item[1]), int(item[2]), str(item[3])):
			return null
	return graph


static func _clean_params(type: String, raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var result := {}
	for param in LogicNodes.params(type):
		var name: String = param[0]
		var kind: String = param[1]
		var value: Variant = raw.get(name, param[3])
		match kind:
			"number", "button", "counter", "element":
				if not (value is int or value is float) or not is_finite(float(value)):
					return {}
				value = clampf(float(value), -1000000, 1000000) if kind == "number" else int(value)
			"bool":
				value = value == true
			"code", "note":
				if not value is String or (value as String).length() > MAX_CODE:
					return {}
			"key":
				value = str(value) if str(value) in LogicNodes.KEYS else "1"
			_:
				if kind.begins_with("choice:"):
					value = str(value) if str(value) in LogicNodes.choice_options(kind) else str(param[3])
				else:
					value = str(value).left(MAX_TEXT)
		result[name] = value
	return result
