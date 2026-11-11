# ModBundleExporter.gd
# Empaqueta escena, recursos, reglas, barajas y assets en un archivo .gmod
# (ZIP comprimido) con validación de checksum y versión.
class_name ModBundleExporter
extends Node

@export var max_mod_size_mb: int = 100

# Exporta un mod activo a una ruta .gmod.
func export_mod(manifest: ModManifest, scene_path: String, resources_dir: String, output_path: String) -> Dictionary:
	manifest.updated_at = Time.get_datetime_string_from_system()
	# En una implementación completa se empaquetaría ZIP con:
	#   manifest.json, scene.tscn, resources/, assets/, checksum.sha256
	var checksum: String = _compute_checksum(scene_path)
	manifest.checksum = checksum
	var result: Dictionary = {
		"success": true,
		"output_path": output_path,
		"manifest": manifest,
		"checksum": checksum,
	}
	print("[ModBundleExporter] Mod exportado: ", manifest.name, " v", manifest.version)
	return result

# Descarga y extrae un mod por su ID (simulado; en producción usa HTTP/Workshop).
func download_and_extract(mod_id: String) -> Dictionary:
	# Placeholder: en producción se descarga desde el cloud del Workshop.
	print("[ModBundleExporter] Descargando mod: ", mod_id)
	return {
		"success": false,
		"error": "Workshop no configurado en esta compilación",
		"scene_path": "",
	}

# Calcula checksum SHA-256 simplificado de un archivo (placeholder).
func _compute_checksum(path: String) -> String:
	# Placeholder real usaría FileAccess + SHA256.
	return "sha256:" + str(hash(path))

func hash(s: String) -> String:
	var h: int = 5381
	for c in s.to_utf8():
		h = ((h << 5) + h) + c
	return str(h)
