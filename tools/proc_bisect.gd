extends SceneTree
## Localiza qué nodos se llevan el tiempo de «process» desactivándolos uno a uno.


func _initialize() -> void:
	_run.call_deferred()


func _avg() -> float:
	var total := 0.0
	for i in 10:
		await process_frame
		total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return total / 10.0


func _run() -> void:
	change_scene_to_file(OS.get_cmdline_user_args()[0])
	for i in 40:
		await process_frame
	var base: float = await _avg()
	print("base %.1f ms" % base)
	var nodes: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		if node.is_processing() or node.is_physics_processing():
			nodes.append(node)
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var was_p := node.is_processing()
		node.set_process(false)
		var t: float = await _avg()
		if base - t > 5.0:
			print("  %s (%s): -%.1f ms" % [node.get_path(), node.get_script().resource_path.get_file() if node.get_script() else node.get_class(), base - t])
		node.set_process(was_p)
	quit(0)
