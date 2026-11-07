extends SceneTree
## Edición demo: el menú muestra todas las mesas pero solo abre las de la demo, y una mesa
## bloqueada abierta desde otra vuelve al menú con un aviso.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var edition := root.get_node("Edition")
	_check(not edition.demo, "sin la característica «demo» es el juego completo")
	_check(edition.allows("res://scenes/Chess.tscn"), "el juego completo abre todas las mesas")
	edition.demo = true
	change_scene_to_file("res://scenes/Menu.tscn")
	await _frames(5)
	var menu := current_scene
	_check(menu.find_child("DemoBanner", true, false) != null, "la demo enseña su cartel")
	for id in ["Chess", "GuidedChess", "Ludo", "Island", "GuidedDomino", "Cards"]:
		var button := menu.find_child(id, true, false) as Button
		_check(button != null and button.disabled, "en la demo «%s» está bloqueada" % id)
	for id in ["Tutorial", "Sandbox", "Brisca", "Parchis", "Parchis2", "DemoBrisca", "DemoParchis", "DemoSandbox"]:
		var button := menu.find_child(id, true, false) as Button
		_check(button != null and not button.disabled, "en la demo «%s» se puede abrir" % id)
	# Una mesa bloqueada (por ejemplo, desde un botón de otra mesa) vuelve al menú.
	change_scene_to_file("res://scenes/Brisca.tscn")
	await _frames(8)
	_check(current_scene.scene_file_path == "res://scenes/Brisca.tscn", "la brisca se abre en la demo")
	change_scene_to_file("res://scenes/CardTable.tscn")
	await _frames(12)
	_check(current_scene.scene_file_path == "res://scenes/Menu.tscn", "una mesa bloqueada vuelve al menú")
	_check(current_scene.find_child("DemoNotice", true, false) != null, "y se explica por qué")
	edition.demo = false
	change_scene_to_file("res://scenes/Menu.tscn")
	await _frames(5)
	_check(current_scene.find_child("DemoBanner", true, false) == null, "el juego completo no lleva cartel de demo")
	_check(current_scene.find_child("DemoBrisca", true, false) == null, "ni la sección de la demo")
	if _failed:
		quit(1)
	else:
		print("demo_edition: ok")
		quit(0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
