extends SceneTree
## Mide cuánto cuesta (CPU y fotograma) la celebración del dado y la captura del rebobinado.


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> Array:
	var times := []
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	return times


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 90:
		await process_frame
	var dice: Dice3D = current_scene.get_node("Objects/Dice")
	var base: Array = await _frames(30)
	base.sort()
	print("mediana base %.1f ms" % base[15])
	for round in 4:
		var t0 := Time.get_ticks_usec()
		dice._celebrate(1 + round)
		var cpu := (Time.get_ticks_usec() - t0) / 1000.0
		var after: Array = await _frames(20)
		print("celebración %d: cpu %.1f ms · fotogramas siguientes max %.1f ms" % [round, cpu, after.max()])
		await _frames(60)
	var timeline: TableTimeline = current_scene.find_child("*Timeline*", true, false)
	if timeline != null:
		for round in 3:
			var t1 := Time.get_ticks_usec()
			timeline.capture()
			print("captura rebobinado: %.1f ms" % ((Time.get_ticks_usec() - t1) / 1000.0))
	quit(0)
