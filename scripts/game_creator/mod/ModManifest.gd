# ModManifest.gd
# Metadatos para exportación e importación de creaciones de la comunidad (.gmod).
# Incluye lista de dependencias (mod_ids requeridos) para validación antes de instalar.
class_name ModManifest
extends RefCounted

@export var mod_id: String = ""
@export var name: String = ""
@export var author: String = ""
@export var version: String = "1.0.0"
@export var min_players: int = 2
@export var max_players: int = 4
@export var tags: Array[String] = []
@export var dependencies: Array[String] = []  # mod_ids que este mod requiere para funcionar
@export var checksum: String = ""
@export var created_at: String = ""
@export var updated_at: String = ""
@export var scene_path: String = "res://scene.tscn"

## Máximo tamaño permitido de un paquete .gmod (en MB).
const MAX_MOD_SIZE_MB := 100
## Número máximo de dependencias permitidas por mod.
const MAX_DEPENDENCIES := 10

func _init(p_mod_id: String = "", p_name: String = ""):
	mod_id = p_mod_id if p_mod_id != "" else str(Time.get_ticks_msec())
	name = p_name if p_name != "" else "Mi Mod"
	var now: String = Time.get_datetime_string_from_system()
	created_at = now
	updated_at = now

## Valida que el manifiesto tenga los campos obligatorios bien rellenados.
## Devuelve "" si es válido, o un mensaje de error si no lo es.
func validate() -> String:
	if mod_id == "":
		return "El mod no tiene identificador (mod_id)."
	if mod_id.length() > 64:
		return "El identificador del mod es demasiado largo (máximo 64 caracteres)."
	if name == "":
		return "El mod no tiene nombre."
	if name.length() > 64:
		return "El nombre del mod es demasiado largo (máximo 64 caracteres)."
	if version == "":
		return "El mod no tiene versión."
	if not _is_valid_version(version):
		return "La versión no tiene el formato X.Y.Z (ej. 1.0.0)."
	if dependencies.size() > MAX_DEPENDENCIES:
		return "Demasiadas dependencias (máximo %d)." % MAX_DEPENDENCIES
	for dep in dependencies:
		if dep == mod_id:
			return "El mod no puede depender de sí mismo."
		if dep == "":
			return "Una dependencia está vacía."
	return ""

## Comprueba que `version` tenga el formato semántico X.Y.Z.
func _is_valid_version(v: String) -> bool:
	var parts := v.split(".")
	if parts.size() != 3:
		return false
	for p in parts:
		if not p.is_valid_int():
			return false
	return true

## Resume las dependencias como texto legible.
func dependencies_text() -> String:
	if dependencies.is_empty():
		return tr("Sin dependencias")
	var texto := ""
	for i in dependencies.size():
		if i > 0:
			texto += ", "
		texto += dependencies[i]
	return texto
