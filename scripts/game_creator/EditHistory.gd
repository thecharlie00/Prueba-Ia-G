# EditHistory.gd
# Deshacer y rehacer del editor de juegos. Guarda fotos completas de la mesa (son
# pequeñas: unas decenas de piezas) en vez de órdenes inversas: así cualquier cambio,
# por raro que sea, se puede deshacer sin escribir su contrario.
class_name EditHistory
extends RefCounted

const LIMIT := 80
## Cambios seguidos de la misma clase (teclear un número, girar con la rueda) en menos de
## este tiempo se deshacen de una vez.
const MERGE_MS := 900

var _undo: Array = []
var _redo: Array = []
var _last_key := ""
var _last_ms := -100000


## Apunta el estado de ANTES de un cambio. `key` agrupa cambios seguidos de la misma clase.
func record(before: Dictionary, key := "") -> void:
	var now := Time.get_ticks_msec()
	if key != "" and key == _last_key and now - _last_ms < MERGE_MS and not _undo.is_empty():
		_last_ms = now
		_redo.clear()
		return
	_undo.append(before.duplicate(true))
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()
	_last_key = key
	_last_ms = now


## Devuelve el estado al que volver, o {} si no hay nada que deshacer.
func undo(current: Dictionary) -> Dictionary:
	if _undo.is_empty():
		return {}
	_redo.append(current.duplicate(true))
	_last_key = ""
	return _undo.pop_back()


func redo(current: Dictionary) -> Dictionary:
	if _redo.is_empty():
		return {}
	_undo.append(current.duplicate(true))
	_last_key = ""
	return _redo.pop_back()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_last_key = ""
