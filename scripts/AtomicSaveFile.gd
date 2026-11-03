class_name AtomicSaveFile
extends RefCounted


static func write_text(path: String, contents: String) -> bool:
	var temporary_path := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	if FileAccess.file_exists(temporary_path):
		return false
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_temporary(temporary_path)
		return false
	if DirAccess.rename_absolute(temporary_path, path) != OK:
		_remove_temporary(temporary_path)
		return false
	return true


static func _remove_temporary(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
