extends SceneTree
## Portada con versión, créditos con las licencias de terceros e informe de fallo.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_check(not version.is_empty(), "el proyecto tiene versión")
	change_scene_to_file("res://scenes/BotMenu.tscn")
	await _frames(5)
	var label := current_scene.find_child("Version", true, false) as Label
	_check(label != null and label.text.contains(version), "la portada enseña la versión")
	var credits_btn := current_scene.find_child("Credits", true, false) as Button
	_check(credits_btn != null, "la portada tiene botón de créditos")
	var report := AppInfo.report_text()
	_check(report.contains(version), "el informe lleva la versión")
	_check(report.contains("Registro:"), "y dice dónde está el registro")
	_check(report.contains(OS.get_name()), "y el sistema")
	credits_btn.pressed.emit()
	await _frames(6)
	_check(current_scene.scene_file_path == "res://scenes/Credits.tscn", "créditos se abre desde la portada")
	for card in ["GodotEngineCredit", "JoltPhysicsCredit", "LilitaOneCredit", "NunitoCredit"]:
		_check(current_scene.find_child(card, true, false) != null, "créditos menciona %s" % card)
	var legal: String = current_scene.legal_text()
	_check(legal.contains("MIT") or legal.contains("Permission is hereby granted"), "incluye el texto de la licencia de Godot")
	_check(root.get_node("Edition").allows("res://scenes/Credits.tscn"), "créditos está en la demo")
	if _failed:
		quit(1)
	else:
		print("credits_report: ok")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
