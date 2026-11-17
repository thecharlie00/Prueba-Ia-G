# ModDependencyValidator.gd
# Valida que un paquete .gmod tenga todas sus dependencias resueltas antes de
# instalarse. Comprueba el manifiesto, las dependencias declaradas y que no haya
# dependencias circulares entre los mods ya instalados.
class_name ModDependencyValidator
extends RefCounted

## Resultado de validación: { "ok": bool, "error": String, "missing": Array[String] }.
## `missing` lista los mod_ids de dependencias que no están instaladas.

## Valida un manifiesto contra la lista de mod_ids ya instalados.
## Devuelve { "ok": true } si todo está bien, o { "ok": false, "error": ..., "missing": [...] } si falla.
static func validate(manifest: ModManifest, installed_mod_ids: Array[String]) -> Dictionary:
	# 1. El manifiesto debe ser válido por sí mismo.
	var manifest_error := manifest.validate()
	if manifest_error != "":
		return {
			"ok": false,
			"error": manifest_error,
			"missing": [],
		}

	# 2. Cada dependencia declarada debe estar instalada.
	var missing: Array[String] = []
	for dep in manifest.dependencies:
		if dep not in installed_mod_ids:
			missing.append(dep)

	if missing.size() > 0:
		var lista := ""
		for i in missing.size():
			if i > 0:
				lista += ", "
			lista += missing[i]
		return {
			"ok": false,
			"error": "Faltan dependencias: %s" % lista,
			"missing": missing,
		}

	# 3. No debe haber dependencia circular (el mod no puede requerirse a sí mismo,
	#    ya validado en ModManifest.validate, pero lo comprobamos aquí también por seguridad).
	if manifest.mod_id in manifest.dependencies:
		return {
			"ok": false,
			"error": "El mod «%s» depende de sí mismo." % manifest.mod_id,
			"missing": [],
		}

	return {
		"ok": true,
		"error": "",
		"missing": [],
	}

## Valida una lista de manifiestos en orden de instalación: cada mod puede depender
## de los que ya se instalaron antes. Devuelve el primer error encontrado, o { "ok": true }.
static func validate_batch(manifests: Array[ModManifest]) -> Dictionary:
	var installed: Array[String] = []
	for manifest in manifests:
		var result := validate(manifest, installed)
		if not result.get("ok", false):
			return result
		installed.append(manifest.mod_id)
	return { "ok": true, "error": "", "missing": [] }
