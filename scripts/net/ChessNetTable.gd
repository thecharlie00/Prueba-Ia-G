extends NetTable
class_name ChessNetTable
## Mesa online de Ajedrez físico con reglas (2 jugadores: 0 = blancas, 1 = negras).
##
## Acciones:
##   {"type": "move", "from": int, "to": int, "promotion": int}
##   {"type": "claim", "from": int, "to": int, "promotion": int}

var chess: ChessRules
var view_node: GuidedPhysicalChess


func _active_seat() -> int:
	if chess == null:
		return -1
	return 0 if chess.turn == ChessRules.WHITE else 1


func _allows(action: Dictionary, seat: int) -> bool:
	if chess == null or chess.status() not in ["playing", "check"]:
		return false
	if seat != _active_seat():
		return false
	var kind := str(action.get("type", ""))
	if kind == "move":
		var from_sq := int(action.get("from", -1))
		var to_sq := int(action.get("to", -1))
		for m in chess.legal_moves_from(from_sq):
			if int(m["to"]) == to_sq:
				return true
		return false
	if kind == "claim":
		return true
	return false


func _apply(action: Dictionary) -> bool:
	var ok := view_node.apply_change(action)
	if ok:
		chess = view_node.rules
	return ok


func _apply_event(change: Dictionary) -> bool:
	var ok := view_node.apply_change(change)
	if ok:
		chess = view_node.rules
	return ok


func _on_sync(record: Dictionary) -> void:
	if not view_node.sync_from_record(record):
		return
	chess = view_node.rules
	_mark_synced()


func snapshot() -> Dictionary:
	return view_node.rules.export_record() if view_node != null and view_node.rules != null else {}
