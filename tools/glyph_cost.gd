extends SceneTree
## Coste de dibujar por primera vez cada número del dado con contorno (glifos nuevos).


func _initialize() -> void:
	_run.call_deferred()


func _measure(size: int, outline: int, digit: String) -> float:
	var label := Label3D.new()
	label.text = digit
	label.font_size = size
	label.outline_size = outline
	label.font = root.get_node("ToonStyle").DISPLAY_FONT
	await process_frame
	var t0 := Time.get_ticks_usec()
	current_scene.add_child(label)
	await process_frame
	var cost := (Time.get_ticks_usec() - t0) / 1000.0
	label.queue_free()
	return cost


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 30:
		await process_frame
	for spec in [[150, 36], [96, 22]]:
		var costs := []
		for digit in ["1", "2", "3", "4", "5", "6", "1"]:
			costs.append("%.1f" % (await _measure(spec[0], spec[1], digit)))
		print("tamaño %d contorno %d: %s ms" % [spec[0], spec[1], ", ".join(costs)])
	quit(0)
