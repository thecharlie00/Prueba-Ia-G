extends SceneTree
## FASE 6 — Paquetes con manifiesto y validación de dependencias (.gmod).
## Prueba: crear un manifiesto, exportar un paquete .gmod, validar que
## las dependencias faltantes rechazan la importación, instalar la dependencia
## y volver a importar con éxito. También rechaza manifiestos inválidos.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# No necesitamos cargar el editor para probar ModManifest y ModDependencyValidator.
	# Probamos los modelos de datos de la FASE 6 directamente.

	# 1. Crear un manifiesto válido sin dependencias.
	var manifest := ModManifest.new("mod_principal", "Mi Mod Principal")
	manifest.version = "1.0.0"
	manifest.author = "Autor Test"
	manifest.tags = ["cartas", "ejemplo"]
	_check(manifest.validate() == "", "manifiesto válido sin dependencias (%s)" % manifest.validate())

	# 2. Crear una dependencia que no esté instalada.
	var manifest_con_dep := ModManifest.new("mod_con_dep", "Mod con Dependencia")
	manifest_con_dep.version = "1.0.0"
	manifest_con_dep.dependencies = ["mod_inesistente"]
	var validacion := ModDependencyValidator.validate(manifest_con_dep, [])
	_check(not validacion.get("ok", true), "se rechaza mod con dependencia faltante")
	_check("mod_inesistente" in validacion.get("missing", []), "la dependencia falta aparece en missing")

	# 3. Instalar primero la dependencia y volver a validar.
	var instalar_primero := ModManifest.new("mod_inesistente", "Mod Inexistente")
	instalar_primero.version = "1.0.0"
	var validacion2 := ModDependencyValidator.validate(manifest_con_dep, ["mod_inesistente"])
	_check(validacion2.get("ok", false), "se acepta mod cuando su dependencia está instalada")

	# 4. Un mod no puede depender de sí mismo.
	var manifest_auto := ModManifest.new("mod_auto", "Mod Auto")
	manifest_auto.dependencies = ["mod_auto"]
	var validacion3 := ModDependencyValidator.validate(manifest_auto, [])
	_check(not validacion3.get("ok", true), "se rechaza mod que depende de sí mismo")

	# 5. Validación en lote (batch): varios mods en orden de instalación.
	var lote := [
		ModManifest.new("mod_a", "Mod A"),
		ModManifest.new("mod_b", "Mod B"),
	]
	lote[0].dependencies = []
	lote[1].dependencies = ["mod_a"]
	var validacion_lote := ModDependencyValidator.validate_batch(lote)
	_check(validacion_lote.get("ok", false), "lote válido cuando las dependencias se respetan en orden")

	# 6. Lote inválido: mod_b depende de mod_c que no está antes en el lote.
	var lote_mal := [
		ModManifest.new("mod_b", "Mod B"),
		ModManifest.new("mod_c", "Mod C"),
	]
	lote_mal[0].dependencies = ["mod_c"]
	var validacion_lote_mal := ModDependencyValidator.validate_batch(lote_mal)
	_check(not validacion_lote_mal.get("ok", true), "se rechaza lote con dependencia fuera de orden")

	# 7. Manifiesto sin mod_id.
	var manifest_sin_id := ModManifest.new("", "Sin ID")
	_check(manifest_sin_id.validate() != "", "se rechaza manifiesto sin mod_id")

	# 8. Manifiesto sin nombre.
	var manifest_sin_nombre := ModManifest.new("id1", "")
	_check(manifest_sin_nombre.validate() != "", "se rechaza manifiesto sin nombre")

	# 9. Versión con formato inválido.
	var manifest_version_mal := ModManifest.new("id2", "Version Mal")
	manifest_version_mal.version = "no-es-una-version"
	_check(manifest_version_mal.validate() != "", "se rechaza versión con formato inválido")

	# 10. Demasiadas dependencias.
	var manifest_many_deps := ModManifest.new("id3", "Muchas Deps")
	for i in range(11):
		manifest_many_deps.dependencies.append("dep_%d" % i)
	_check(manifest_many_deps.validate() != "", "se rechazan más de %d dependencias" % ModManifest.MAX_DEPENDENCIES)

	# 11. dependencies_text() devuelve texto legible.
	var manifest_con_tags := ModManifest.new("id4", "Con Deps")
	manifest_con_tags.dependencies = ["dep1", "dep2"]
	var texto := manifest_con_tags.dependencies_text()
	_check(texto == "dep1, dep2", "dependencies_text() lista las dependencias: «%s»" % texto)

	var manifest_sin_deps := ModManifest.new("id5", "Sin Deps")
	var texto2 := manifest_sin_deps.dependencies_text()
	_check(texto2 == tr("Sin dependencias"), "dependencies_text() dice «Sin dependencias» si no hay (%s)" % texto2)

	# 12. ModBundleExporter: rechaza manifiesto inválido.
	var exporter := ModBundleExporter.new()
	var manifest_mal := ModManifest.new("", "")
	var resultado := exporter.export_mod(manifest_mal, "res://scene.tscn", "user://", "user://test_bad.gmod")
	_check(not resultado.get("success", true), "export_mod rechaza manifiesto inválido")

	# Limpieza de archivos temporales.
	for fpath in ["user://test_bad.gmod"]:
		if FileAccess.file_exists(fpath):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fpath))

	if _failed:
		quit(1)
	else:
		print("editor_mods: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
