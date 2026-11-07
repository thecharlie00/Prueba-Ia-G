extends SceneTree
## Mide el coste de refrescar la vista tras una tirada en la isla y el ludo.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in ["res://scenes/Island.tscn", "res://scenes/Ludo4.tscn"]:
		change_scene_to_file(path)
		for i in 60:
			await process_frame
		var view := current_scene
		if view.has_method("_refresh"):
			for round in 3:
				var t0 := Time.get_ticks_usec()
				view._refresh()
				print("%s _refresh: %.1f ms" % [path.get_file(), (Time.get_ticks_usec() - t0) / 1000.0])
	quit(0)
