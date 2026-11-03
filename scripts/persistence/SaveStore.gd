class_name SaveStore
extends RefCounted


# Los temporales están junto al destino. La copia .previous conserva el último
# guardado validado; no se considera comprometido un archivo .pending.
static func write(path: String, text: String, max_bytes: int, decode: Callable) -> bool:
	var bytes := text.to_utf8_buffer()
	if bytes.size() > max_bytes or _decode_text(text, decode).is_empty():
		return false
	var pending := path + ".pending"
	var previous := path + ".previous"
	var previous_pending := previous + ".pending"
	if not _write_bytes(pending, bytes):
		_remove_file(pending)
		return false
	# No reemplazar una copia sana con un archivo principal ya corrupto.
	var old := _read_one(path, max_bytes, decode)
	if not old.is_empty():
		if not _write_bytes(previous_pending, str(old["text"]).to_utf8_buffer()):
			_remove_file(previous_pending)
			_remove_file(pending)
			return false
		if not _rename_file(previous_pending, previous):
			_remove_file(previous_pending)
			_remove_file(pending)
			return false
	# En algunas plataformas rename borra primero el destino. La copia validada
	# permanece disponible si la operación o el proceso se interrumpe aquí.
	if not _rename_file(pending, path):
		_remove_file(pending)
		return false
	return true


static func read_validated(path: String, max_bytes: int, decode: Callable) -> Dictionary:
	var result := _read_one(path, max_bytes, decode)
	if not result.is_empty():
		result["backup"] = false
		return result
	result = _read_one(path + ".previous", max_bytes, decode)
	if not result.is_empty():
		result["backup"] = true
	return result


static func _read_one(path: String, max_bytes: int, decode: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > max_bytes:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var result := _decode_text(text, decode)
	if not result.is_empty():
		result["text"] = text
	return result


static func _decode_text(text: String, decode: Callable) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var value: Variant = decode.call(json.data)
	if value == null:
		return {}
	return {"value": value, "record": json.data}


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK


static func _rename_file(from: String, to: String) -> bool:
	return (
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to)
		)
		== OK
	)


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
