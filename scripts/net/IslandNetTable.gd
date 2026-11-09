extends NetTable
class_name IslandNetTable
## Mesa online de la Isla de recursos: mapeo entre las acciones de la vista,
## las reglas de IslandRules y el protocolo de red.
##
## Las acciones usan el mismo diccionario que los eventos del guardado
## (formato registro), con una clave extra "seat" con la butaca que actúa:
##   {"type": "settlement", "id": vertex}  {"type": "city", "id": vertex}
##   {"type": "road", "id": edge}          {"type": "robber", "id": tile}
##   {"type": "roll", "a": x, "b": y}      {"type": "discard", "id": resource}
##   {"type": "steal", "id": victim}       {"type": "bank", "give": g, "take": t}
##   {"type": "buy"}                       {"type": "play", "id": card}
##   {"type": "plenty", "id": r}           {"type": "monopoly", "id": r}
##   {"type": "offer", "other": p, "give": [...], "take": [...]}
##   {"type": "respond", "player": p, "accept": bool}   {"type": "end"}

var island: IslandRules
var view_node: IslandView


func _allows(action: Dictionary, seat: int) -> bool:
	var kind := str(action.get("type", ""))
	match island.phase:
		IslandRules.SETUP_SETTLEMENT:
			return kind == "settlement" and seat == island.turn and island.can_settlement(int(action["id"]))
		IslandRules.SETUP_ROAD, IslandRules.FREE_ROADS:
			return kind == "road" and seat == island.turn and island.can_road(int(action["id"]))
		IslandRules.ROLL:
			return kind == "roll" and seat == island.turn
		IslandRules.DISCARD:
			return kind == "discard" and island.discard_player == seat
		IslandRules.ROBBER:
			return kind == "robber" and seat == island.turn and int(action["id"]) != island.robber_tile
		IslandRules.STEAL:
			return (
				kind == "steal"
				and seat == island.turn
				and int(action["id"]) in island.eligible_victims
			)
		IslandRules.PLENTY, IslandRules.MONOPOLY:
			return (
				kind in ["plenty", "monopoly"]
				and seat == island.turn
			)
		IslandRules.TRADE_RESPONSE:
			return (
				kind == "respond"
				and int(island.trade_offer.get("to", -1)) == seat
			)
		IslandRules.ACTION:
			if seat != island.turn:
				return false
			match kind:
				"settlement":
					return island.can_settlement(int(action["id"]))
				"city":
					return island.can_city(int(action["id"]))
				"road":
					return island.can_road(int(action["id"]))
				"bank", "buy", "play", "offer", "end":
					return true  # las reglas validarán al aplicar
				_:
					return false
		_:
			return false


func _apply(action: Dictionary) -> bool:
	return view_node.apply_change(action)


func _apply_event(change: Dictionary) -> void:
	view_node.apply_change(change)


func _on_sync(record: Dictionary) -> void:
	var replayed := IslandRules.from_record(record)
	if replayed == null:
		return
	island = replayed
	view_node.rules = replayed
	view_node._rebuild_loaded_board()
	view_node._refresh()
	sync_received.emit()


func snapshot() -> Dictionary:
	return island.export_record()
