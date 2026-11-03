extends SceneTree

const STORE := preload("res://scripts/persistence/SaveStore.gd")
const CODECS := preload("res://scripts/persistence/SaveCodecs.gd")
const PATH := "user://test_recoverable_save.json"
const LIMIT := 2048
var failures := 0


func _initialize() -> void:
	_clean()
	var first := JSON.stringify({"game": "test", "turn": 1, "name": "piñón"})
	var second := JSON.stringify({"game": "test", "turn": 2})
	var third := JSON.stringify({"game": "test", "turn": 3})
	_check(STORE.write(PATH, first, LIMIT, _decode), "primer guardado")
	_check(not FileAccess.file_exists(PATH + ".previous"), "primer guardado no inventa historial")
	_check(STORE.write(PATH, second, LIMIT, _decode), "segundo guardado")
	_check(FileAccess.get_file_as_string(PATH + ".previous") == first, "copia anterior exacta")
	var result := STORE.read_validated(PATH, LIMIT, _decode)
	_check(
		not result.is_empty() and not result["backup"] and result["value"]["turn"] == 2,
		"se prefiere archivo principal válido"
	)
	_write_raw(PATH, "{archivo corrupto")
	result = STORE.read_validated(PATH, LIMIT, _decode)
	_check(
		not result.is_empty() and result["backup"] and result["value"]["turn"] == 1,
		"se recupera copia tras corrupción"
	)
	_write_raw(PATH, "x".repeat(LIMIT + 1))
	result = STORE.read_validated(PATH, LIMIT, _decode)
	_check(not result.is_empty() and result["backup"], "principal demasiado grande recurre a copia")
	_write_raw(PATH + ".previous", "{rota")
	_check(
		STORE.read_validated(PATH, LIMIT, _decode).is_empty(), "dos archivos inválidos no se cargan"
	)
	_write_raw(PATH + ".previous", first)
	_write_raw(PATH, JSON.stringify({"game": "incorrecto", "turn": 4}))
	result = STORE.read_validated(PATH, LIMIT, _decode)
	_check(not result.is_empty() and result["backup"], "valida contenido además del JSON")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_write_raw(PATH + ".pending", third)
	result = STORE.read_validated(PATH, LIMIT, _decode)
	_check(not result.is_empty() and result["value"]["turn"] == 1, "ignora temporal no confirmado")
	_check(STORE.write(PATH, third, LIMIT, _decode), "guardar tras recuperación")
	_check(
		FileAccess.get_file_as_string(PATH + ".previous") == first,
		"conserva copia sana si falta el principal"
	)
	var before := FileAccess.get_file_as_string(PATH)
	_check(not STORE.write(PATH, "invalido", LIMIT, _decode), "rechaza nuevo archivo inválido")
	_check(not STORE.write(PATH, "x".repeat(LIMIT + 1), LIMIT, _decode), "rechaza tamaño excesivo")
	_check(FileAccess.get_file_as_string(PATH) == before, "rechazos no sobrescriben principal")
	_write_raw(PATH, "corrupto otra vez")
	_check(STORE.write(PATH, second, LIMIT, _decode), "guardar con principal corrupto")
	_check(
		FileAccess.get_file_as_string(PATH + ".previous") == first,
		"no sustituye copia sana por corrupta"
	)
	# Fallo al preparar la copia: el principal sigue intacto.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".previous"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".previous"))
	before = FileAccess.get_file_as_string(PATH)
	_check(not STORE.write(PATH, third, LIMIT, _decode), "informa fallo al preparar copia")
	_check(FileAccess.get_file_as_string(PATH) == before, "fallo no destruye el guardado existente")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".previous"))
	_check(CODECS.chess(ChessRules.new().export_record()) is ChessRules, "valida ajedrez")
	_check(CODECS.checkers(CheckersRules.new().export_record()) is CheckersRules, "valida damas")
	_check(CODECS.domino(DominoRules.new().export_record()) is DominoRules, "valida dominó")
	_check(CODECS.island(IslandRules.new(3).export_record()) is IslandRules, "valida isla")
	_check(CODECS.ludo(LudoRules.new().export_record()) is LudoRules, "valida ludo")
	_clean()
	if failures:
		printerr("Save store: %d errores" % failures)
		quit(1)
	else:
		print("Save store tests OK")
		quit(0)


func _decode(record: Variant) -> Variant:
	if (
		not record is Dictionary
		or record.get("game") != "test"
		or typeof(record.get("turn")) not in [TYPE_INT, TYPE_FLOAT]
	):
		return null
	return record


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean() -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = PATH + suffix
		if (
			FileAccess.file_exists(file)
			or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(file))
		):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
