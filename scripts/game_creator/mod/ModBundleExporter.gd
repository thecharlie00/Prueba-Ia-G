# ModBundleExporter.gd
# Empaqueta escena, recursos, reglas, barajas y assets en un archivo .gmod
# (ZIP comprimido) con validación de checksum y versión.
class_name ModBundleExporter
extends Node

@export var max_mod_size_mb: int = 100

## Exporta un mod activo a una ruta .gmod.
## Crea un ZIP con: manifest.json, scene.tscn, resources/, assets/, checksum.sha256.
func export_mod(manifest: ModManifest, scene_path: String, resources_dir: String, output_path: String) -> Dictionary:
	# Validar el manifiesto antes de empaquetar.
	var manifest_error := manifest.validate()
	if manifest_error != "":
		return {
			"success": false,
			"error": manifest_error,
			"output_path": "",
		}

	manifest.updated_at = Time.get_datetime_string_from_system()

	var zip := ZIPPacker.new()
	var zip_error := zip.open(output_path, 1)  # flag 1 = CREATE mode
	if zip_error != OK:
		return {
			"success": false,
			"error": "No se pudo crear el archivo .gmod: %s" % zip_error,
			"output_path": "",
		}

	# 1. Añadir el manifiesto como manifest.json dentro del ZIP.
	var manifest_json := _manifest_to_json(manifest)
	zip.add_file("manifest.json", manifest_json.to_utf8_buffer())

	# 2. Añadir la escena principal.
	if scene_path != "" and FileAccess.file_exists(scene_path):
		var scene_bytes := FileAccess.get_file_as_bytes(scene_path)
		zip.add_file("scene.tscn", scene_bytes)

	# 3. Añadir recursos (carpetas de imágenes, modelos, etc.).
	if resources_dir != "" and DirAccess.dir_exists_absolute(resources_dir):
		_dir_to_zip(zip, resources_dir, "resources/")

	zip.close()

	# 4. Calcular checksum del archivo ZIP creado.
	var checksum := _compute_checksum(output_path)
	manifest.checksum = checksum

	# 5. Reabrir el ZIP para añadir checksum.sha256 al final.
	zip.open(output_path, 3)  # flag 3 = CREATE | APPEND
	zip.add_file("checksum.sha256", checksum.to_utf8_buffer())
	zip.close()

	# Verificar tamaño del archivo resultante.
	var f := FileAccess.open(output_path, FileAccess.READ)
	var size_mb := 0.0
	if f != null:
		size_mb = float(f.get_length()) / (1024.0 * 1024.0)
		f.close()
	if size_mb > max_mod_size_mb:
		return {
			"success": false,
			"error": "El mod excede el tamaño máximo de %d MB (%.1f MB)." % [max_mod_size_mb, size_mb],
			"output_path": output_path,
		}

	print("[ModBundleExporter] Mod exportado: ", manifest.name, " v", manifest.version, " (checksum: ", checksum, ")")
	return {
		"success": true,
		"output_path": output_path,
		"manifest": manifest,
		"checksum": checksum,
	}

## Descarga y extrae un mod por su ID (simulado; en producción usa HTTP/Workshop).
func download_and_extract(mod_id: String) -> Dictionary:
	# Placeholder: en producción se descarga desde el cloud del Workshop.
	print("[ModBundleExporter] Descargando mod: ", mod_id)
	return {
		"success": false,
		"error": "Workshop no configurado en esta compilación",
		"scene_path": "",
	}

## Checksum SHA-256 del archivo ("" si no se puede leer).
func _compute_checksum(path: String) -> String:
	var sha := FileAccess.get_sha256(path)
	return "sha256:" + sha if not sha.is_empty() else ""

## Convierte el ModManifest a un JSON string.
func _manifest_to_json(manifest: ModManifest) -> String:
	var d := {
		"mod_id": manifest.mod_id,
		"name": manifest.name,
		"author": manifest.author,
		"version": manifest.version,
		"min_players": manifest.min_players,
		"max_players": manifest.max_players,
		"tags": manifest.tags,
		"dependencies": manifest.dependencies,
		"checksum": manifest.checksum,
		"created_at": manifest.created_at,
		"updated_at": manifest.updated_at,
		"scene_path": manifest.scene_path,
	}
	return JSON.stringify(d)

## Añade recursivamente el contenido de un directorio al ZIP, bajo un prefijo interno.
func _dir_to_zip(zip: ZIPPacker, dir_path: String, zip_prefix: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		var full_path := dir_path.path_join(name)
		if dir.current_is_dir():
			_dir_to_zip(zip, full_path, zip_prefix + name + "/")
		else:
			var data := FileAccess.get_file_as_bytes(full_path)
			zip.add_file(zip_prefix + name, data)
	dir.list_dir_end()
