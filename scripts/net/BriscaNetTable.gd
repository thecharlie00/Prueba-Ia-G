extends NetTable
class_name BriscaNetTable
## Mesa online de Brisca para dos jugadores (0 = J1, 1 = J2).
##
## Acciones:
##   {"type": "play", "card": String}

var brisca: BriscaRules
var view_node: BriscaView


func _allows(action: Dictionary, seat: int) -> bool:
	if brisca == null or brisca.phase != BriscaRules.PLAYING or seat != brisca.turn:
		return false
	if str(action.get("type", "")) != "play":
		return false
	var card := str(action.get("card", ""))
	return brisca.can_play(card)


func _apply(action: Dictionary) -> bool:
	return view_node.apply_change(action)


func _apply_event(change: Dictionary) -> bool:
	return view_node.apply_change(change)


func _on_sync(record: Dictionary) -> void:
	var replayed := BriscaRules.from_record(record)
	if replayed == null:
		return
	synced = true
	brisca = replayed
	view_node.sync_from_rules(replayed)
	_mark_synced()


func snapshot() -> Dictionary:
	return brisca.export_record() if brisca != null else {}
