extends SceneTree
## Banco de rendimiento: abre cada pantalla, espera a que se asiente y mide durante unos
## segundos el tiempo por fotograma, llamadas de dibujo, objetos, triángulos y memoria.
## Uso (con pantalla, real o xvfb):
##   godot --path . --rendering-driver opengl3 --script res://tools/bench.gd -- [salida.json] [escena ...]
## Sin escenas, mide la lista por defecto. Con «--calidad=bajo|medio|alto», la fija antes.

const SCENES := {
	"habitacion": "res://scenes/Home.tscn",
	"menu": "res://scenes/BotMenu.tscn",
	"parchis": "res://scenes/Parchis.tscn",
	"ajedrez": "res://scenes/PhysicalChess.tscn",
	"damas": "res://scenes/PhysicalCheckers.tscn",
	"domino": "res://scenes/PhysicalDomino.tscn",
	"cartas": "res://scenes/Brisca.tscn",
	"isla": "res://scenes/Island.tscn",
	"editor": "res://scenes/game_creator/GameCreatorEditor.tscn",
}
const WARMUP := 2.0
const MEASURE := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://bench.json"
	var wanted: Array = []
	for arg in args:
		if arg.ends_with(".json"):
			out = arg
		elif arg.begins_with("--calidad="):
			var graphics := root.get_node_or_null("Graphics")
			if graphics != null:
				graphics.set_quality(arg.get_slice("=", 1), false)
		elif SCENES.has(arg):
			wanted.append(arg)
	if wanted.is_empty():
		wanted = SCENES.keys()
	var results := {}
	for key in wanted:
		change_scene_to_file(SCENES[key])
		await process_frame
		await process_frame
		if key == "editor" and current_scene.has_method("load_template"):
			current_scene.load_template("damas")
		await _wait(WARMUP)
		results[key] = await _measure(MEASURE)
		print("%-11s %6.1f fps  med %5.1f ms  p95 %5.1f ms  peor %6.1f ms  draw %4d  obj %4d  tri %7d  cpu %4.1f ms  física %4.1f ms" % [
			key, results[key]["fps"], results[key]["frame_ms"], results[key]["p95_ms"], results[key]["worst_ms"],
			results[key]["draw_calls"], results[key]["objects"], results[key]["primitives"], results[key]["process_ms"], results[key]["physics_ms"]])
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	quit()


func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _measure(seconds: float) -> Dictionary:
	var frames: Array[float] = []
	var draws := 0.0
	var objects := 0.0
	var primitives := 0.0
	var process := 0.0
	var physics := 0.0
	var last := Time.get_ticks_usec()
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var n := maxi(frames.size(), 1)
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in frames:
		total += f
	return {
		"fps": 1000.0 / (total / n),
		"frame_ms": total / n,
		"p95_ms": sorted[int(n * 0.95)] if n > 1 else total,
		"worst_ms": sorted.back() if not sorted.is_empty() else 0.0,
		"draw_calls": int(draws / n),
		"objects": int(objects / n),
		"primitives": int(primitives / n),
		"process_ms": process / n,
		"physics_ms": physics / n,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
