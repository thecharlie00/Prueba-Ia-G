extends SceneTree
## Coste real de una captura del rebobinado tras tirar el dado.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 60:
		await process_frame
	var main := current_scene
	var timeline: TableTimeline = main.timeline
	for round in 3:
		var dice: Dice3D = main.get_node("Objects/Dice")
		dice.roll()
		while dice._awaiting_result:
			await physics_frame
		timeline._dirty = true
		await physics_frame
		var t0 := Time.get_ticks_usec()
		var settled: bool = timeline._settled()
		var t1 := Time.get_ticks_usec()
		var record := SandboxPersistence.snapshot(main.get_node("Objects"), false)
		var t2 := Time.get_ticks_usec()
		var sig := timeline._signature(record)
		var t3 := Time.get_ticks_usec()
		var ok := timeline.capture()
		var t4 := Time.get_ticks_usec()
		print("ronda %d: settled %s %.1f ms · snapshot %.1f ms (%s) · firma %.1f ms · capture %s %.1f ms" % [round, settled, (t1-t0)/1000.0, (t2-t1)/1000.0, "vacío" if record.is_empty() else "ok", (t3-t2)/1000.0, ok, (t4-t3)/1000.0])
	quit(0)
