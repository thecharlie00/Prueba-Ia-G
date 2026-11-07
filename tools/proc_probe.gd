extends SceneTree
## Tiempo de «process» por escena con renderizado real (para comparar).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in OS.get_cmdline_user_args():
		if path == "vacía":
			if current_scene != null:
				current_scene.queue_free()
			var node := Node3D.new()
			root.add_child(node)
			var cam := Camera3D.new()
			cam.position = Vector3(0, 1, 3)
			node.add_child(cam)
			var box := MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			node.add_child(box)
			node.add_child(DirectionalLight3D.new())
		else:
			change_scene_to_file(path)
		for i in 40:
			await process_frame
		var total := 0.0
		for i in 20:
			await process_frame
			total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		print("%s: process %.1f ms · fps %d" % [path, total / 20.0, Engine.get_frames_per_second()])
	quit(0)
