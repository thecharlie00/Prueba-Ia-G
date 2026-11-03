extends SceneTree

const AtomicSave = preload("res://scripts/AtomicSaveFile.gd")
const SAVE_PATH := "user://test_diceon_atomic_save.json"
const BLOCKED_PATH := "user://test_diceon_atomic_save_blocked.json"
const SAVE_TEMP_PREFIX := "test_diceon_atomic_save.json."
const BLOCKED_TEMP_PREFIX := "test_diceon_atomic_save_blocked.json."

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_cleanup()
	_check(AtomicSave.write_text(SAVE_PATH, "first"), "initial write succeeds")
	_check(
		FileAccess.get_file_as_string(SAVE_PATH) == "first",
		"initial contents are present"
	)
	_check(AtomicSave.write_text(SAVE_PATH, "replacement"), "existing file is replaced")
	_check(
		FileAccess.get_file_as_string(SAVE_PATH) == "replacement",
		"replacement contents are present"
	)
	_check(not _has_temporary_files(SAVE_TEMP_PREFIX), "temporary file is renamed away")

	_check(DirAccess.make_dir_absolute(BLOCKED_PATH) == OK, "create blocked destination")
	_check(
		not AtomicSave.write_text(BLOCKED_PATH, "must not replace"),
		"replacement failure is reported"
	)
	_check(
		DirAccess.dir_exists_absolute(BLOCKED_PATH),
		"failed replacement preserves the destination"
	)
	_check(
		not _has_temporary_files(BLOCKED_TEMP_PREFIX),
		"failed replacement removes its temporary file"
	)

	_cleanup()
	if failures > 0:
		printerr("Atomic save: %d failures" % failures)
		quit(1)
	else:
		print("Atomic save tests OK")
		quit(0)


func _cleanup() -> void:
	for path in [SAVE_PATH, BLOCKED_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(BLOCKED_PATH):
		DirAccess.remove_absolute(BLOCKED_PATH)
	for file_name in DirAccess.get_files_at("user://"):
		if (
			file_name.begins_with(SAVE_TEMP_PREFIX)
			or file_name.begins_with(BLOCKED_TEMP_PREFIX)
		) and file_name.ends_with(".tmp"):
			DirAccess.remove_absolute("user://" + file_name)


func _has_temporary_files(prefix: String) -> bool:
	for file_name in DirAccess.get_files_at("user://"):
		if file_name.begins_with(prefix) and file_name.ends_with(".tmp"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
