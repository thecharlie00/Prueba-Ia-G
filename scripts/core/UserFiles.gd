class_name UserFiles
## Archivos del jugador en user://. Hasta la 0.1 se llamaban «diceon_*» (el nombre de
## trabajo del proyecto); ahora son «tablerama_*». migrate_legacy() renombra los antiguos
## una sola vez, al arrancar, para no perder ajustes ni partidas guardadas.

const SETTINGS := "user://tablerama_controls.cfg"
const LEGACY_PREFIX := "diceon_"
const PREFIX := "tablerama_"

static var _migrated := false


## Renombra user://diceon_* (y sus copias .bak/.tmp) a user://tablerama_*. No pisa un
## archivo nuevo que ya exista. Devuelve cuántos archivos movió.
static func migrate_legacy(dir_path := "user://") -> int:
	if _migrated and dir_path == "user://":
		return 0
	if dir_path == "user://":
		_migrated = true
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var moved := 0
	for file in dir.get_files():
		if not file.begins_with(LEGACY_PREFIX):
			continue
		var target := PREFIX + file.substr(LEGACY_PREFIX.length())
		if dir.file_exists(target):
			continue
		if dir.rename(file, target) == OK:
			moved += 1
	return moved
