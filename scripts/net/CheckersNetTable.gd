extends NetTable
class_name CheckersNetTable
## Mesa online de Damas físicas con reglas (2 jugadores: 0 = blancas, 1 = oscuras).
##
## Acciones:
##   {"type": "move", "from": int, "to": int}

var checkers: CheckersRules
var view_node: GuidedPhysicalCheckers


func _active_seat() -> int:
	if checkers == null:
		return -1
	return 0 if checkers.turn == CheckersRules.WHITE else 1


func _allows(action: Dictionary, seat: int) -> bool:
	if checkers == null or checkers.status() != "playing":
		return false
	if seat != _active_seat():
		return false
	if str(action.get("type", "")) != "move":
		return false
	var from_sq := int(action.get("from", -1))
	var to_sq := int(action.get("to", -1))
	for m in checkers.legal_moves_from(from_sq):
		if int(m["to"]) == to_sq:
			return true
	return false


func _apply(action: Dictionary) -> bool:
	var ok := view_node.apply_change(action)
	if ok:
		checkers = view_node.rules
	return ok


func _apply_event(change: Dictionary) -> bool:
	var ok := view_node.apply_change(change)
	if ok:
		checkers = view_node.rules
	return ok


func _on_sync(record: Dictionary) -> void:
	if not view_node.sync_from_record(record):
		return
	checkers = view_node.rules
	_mark_synced()


func snapshot() -> Dictionary:
	return view_node.rules.export_record() if view_node != null and view_node.rules != null else {}
