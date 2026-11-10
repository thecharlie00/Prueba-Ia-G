extends NetTable
class_name DominoNetTable
## Mesa online de Dominó doble seis con reglas (2 jugadores: 0 = J1, 1 = J2).
##
## Acciones:
##   {"type": "play", "id": 0..27, "end": "left" | "right"}
##   {"type": "draw"}
##   {"type": "pass"}

var domino: DominoRules
var view_node: GuidedDomino


func _allows(action: Dictionary, seat: int) -> bool:
	if domino == null or domino.result != DominoRules.PLAYING or seat != domino.turn:
		return false
	var kind := str(action.get("type", ""))
	match kind:
		"play":
			var tile_id := int(action.get("id", -1))
			var end := str(action.get("end", ""))
			return end in domino.legal_ends(tile_id)
		"draw":
			return not domino.stock.is_empty() and not domino.has_play()
		"pass":
			return domino.stock.is_empty() and not domino.has_play()
		_:
			return false


func _apply(action: Dictionary) -> bool:
	return view_node.apply_change(action)


func _apply_event(change: Dictionary) -> void:
	view_node.apply_change(change)


func _on_sync(record: Dictionary) -> void:
	if not view_node.sync_from_record(record):
		return
	domino = view_node.rules
	_sync_tries = 0
	if _sync_timer != null:
		_sync_timer.stop()
	sync_received.emit()


func snapshot() -> Dictionary:
	return domino.export_record() if domino != null else {}
