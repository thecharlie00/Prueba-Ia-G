extends NetTable
class_name LudoNetTable
## Mesa online de Ludo (2, 3 y 4 jugadores) y Parchís (2 y 4 jugadores).
##
## Acciones:
##   {"type": "roll", "value": 1..6, "seat": int}
##   {"type": "move", "token": 0..3, "seat": int}

var ludo: LudoRules
var view_node: LudoView


func _allows(action: Dictionary, seat: int) -> bool:
	if ludo == null or seat != ludo.turn:
		return false
	var kind := str(action.get("type", ""))
	match ludo.phase:
		LudoRules.ROLL:
			var val := int(action.get("value", 0))
			return kind == "roll" and val >= 1 and val <= 6
		LudoRules.MOVE:
			var tok := int(action.get("token", -1))
			return kind == "move" and tok in ludo.legal_tokens()
		_:
			return false


func _apply(action: Dictionary) -> bool:
	return view_node.apply_change(action)


func _apply_event(change: Dictionary) -> void:
	view_node.apply_change(change)


func _on_sync(record: Dictionary) -> void:
	var replayed := LudoRules.from_record(record)
	if replayed == null:
		return
	ludo = replayed
	view_node.rules = replayed
	view_node.sync_from_rules()
	_sync_tries = 0
	if _sync_timer != null:
		_sync_timer.stop()
	sync_received.emit()


func snapshot() -> Dictionary:
	return ludo.export_record() if ludo != null else {}
