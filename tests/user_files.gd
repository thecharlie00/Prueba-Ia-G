extends SceneTree
## Los archivos antiguos «diceon_*» se renombran a «tablerama_*» sin pisar los nuevos.

const DIR := "user://prueba_user_files"
var _failed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)
	_write("diceon_controls.cfg", "viejo")
	_write("diceon_ludo.json", "partida")
	_write("diceon_ludo.json.bak", "copia")
	_write("diceon_chess.json", "viejo")
	_write("tablerama_chess.json", "nuevo")
	_write("otro.txt", "x")
	var moved := UserFiles.migrate_legacy(DIR)
	_check(moved == 3, "mueve los tres archivos sin equivalente nuevo (movió %d)" % moved)
	_check(_read("tablerama_controls.cfg") == "viejo", "los ajustes pasan a tablerama_controls.cfg")
	_check(_read("tablerama_ludo.json.bak") == "copia", "también las copias de seguridad")
	_check(_read("tablerama_chess.json") == "nuevo", "no pisa un archivo nuevo que ya existe")
	_check(FileAccess.file_exists(DIR + "/otro.txt"), "no toca otros archivos")
	_check(UserFiles.migrate_legacy(DIR) == 0, "una segunda pasada no hace nada")
	_check(UserFiles.SETTINGS == "user://tablerama_controls.cfg", "ruta de ajustes nueva")
	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)
	DirAccess.remove_absolute(DIR)
	if _failed:
		quit(1)
	else:
		print("user_files: ok")
		quit(0)


func _write(file: String, text: String) -> void:
	var handle := FileAccess.open(DIR + "/" + file, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func _read(file: String) -> String:
	return FileAccess.get_file_as_string(DIR + "/" + file)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
