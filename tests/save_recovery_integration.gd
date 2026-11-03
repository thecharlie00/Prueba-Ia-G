extends SceneTree

const PATH := "user://test_save_recovery_integration.json"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_rules_scene("res://scenes/Chess.tscn", "chess")
	await _test_rules_scene("res://scenes/GuidedPhysicalChess.tscn", "chess")
	await _test_rules_scene("res://scenes/Checkers.tscn", "checkers")
	await _test_rules_scene("res://scenes/GuidedPhysicalCheckers.tscn", "checkers")
	await _test_rules_scene("res://scenes/GuidedDomino.tscn", "domino")
	await _test_rules_scene("res://scenes/Island.tscn", "island")
	await _test_rules_scene("res://scenes/Ludo.tscn", "ludo")
	await _test_sandbox()
	_clean()
	if failures:
		printerr("Save recovery integration: %d errores" % failures)
		quit(1)
	else:
		print("Save recovery integration tests OK")
		quit(0)


func _test_rules_scene(scene_path: String, kind: String) -> void:
	_clean()
	var view: Node = load(scene_path).instantiate()
	root.add_child(view)
	await process_frame
	view.set("save_path", PATH)
	var rules: Variant = view.get("rules")
	var initial: Dictionary = rules.export_record()
	view.call("_save_game")
	_check(FileAccess.file_exists(PATH), kind + " crea guardado")
	var changed := false
	match kind:
		"chess":
			changed = rules.play(52, 36)
		"checkers":
			changed = rules.play(40, 33)
		"domino":
			changed = rules.play(int(rules.hands[0][0]), "left")
		"island":
			changed = rules.place_settlement(0)
		"ludo":
			changed = rules.apply_roll(6)
	_check(changed, kind + " prepara segundo estado")
	view.call("_save_game")
	_check(FileAccess.file_exists(PATH + ".previous"), kind + " conserva copia")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{corrupto")
	file.close()
	view.call("_load_game")
	var restored: Variant = view.get("rules")
	_check(restored.export_record() == initial, kind + " recupera estado anterior")
	var label: Label
	if kind in ["chess", "checkers"] and not scene_path.contains("Guided"):
		label = view.get("help_label") as Label
	elif kind == "island" or kind == "ludo":
		label = view.get("help") as Label
	else:
		label = view.get_node("UI/Panel/Margin/Content/Help") as Label
	_check(label != null and "copia anterior" in label.text, kind + " informa recuperación")
	view.queue_free()
	await process_frame


func _test_sandbox() -> void:
	_clean()
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set("sandbox_save_path", PATH)
	var grid := main.get_node("SnapGrid3D") as SnapGrid3D
	grid.enabled = false
	main.call("_on_save_pressed")
	grid.enabled = true
	main.call("_on_save_pressed")
	_check(FileAccess.file_exists(PATH + ".previous"), "sandbox conserva copia")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{corrupto")
	file.close()
	main.call("_on_load_pressed")
	_check(not grid.enabled, "sandbox recupera estado físico anterior")
	var label := main.get_node("UI/Margin/Panel/Content/Result") as Label
	_check("copia anterior" in label.text, "sandbox informa recuperación")
	main.queue_free()
	await process_frame


func _clean() -> void:
	for suffix in ["", ".previous", ".pending", ".previous.pending"]:
		var file: String = PATH + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
