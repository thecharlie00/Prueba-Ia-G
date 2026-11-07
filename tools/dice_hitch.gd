extends SceneTree
## Mide los tirones de fotogramas al tirar un dado y salir el número (con renderizado real).

var _worst := 0.0
var _worst_at := 0
var _last := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 60:
		await process_frame
	var main: Node = current_scene
	for round in 3:
		var dice: Dice3D = main.get_node("Objects/Dice")
		dice.roll()
		_worst = 0.0
		_last = Time.get_ticks_usec()
		var start := Time.get_ticks_msec()
		var result_at := [-1]
		dice.result_ready.connect(func(_v: int) -> void: result_at[0] = Time.get_ticks_msec() - start, CONNECT_ONE_SHOT)
		while Time.get_ticks_msec() - start < 15000:
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - _last) / 1000.0
			_last = now
			if dt > 250.0:
				print("  tirón %.0f ms a los %d ms" % [dt, Time.get_ticks_msec() - start])
			if dt > _worst:
				_worst = dt
				_worst_at = Time.get_ticks_msec() - start
		print("ronda %d: resultado a los %d ms · peor fotograma %.1f ms a los %d ms · fps %d" % [round, result_at[0], _worst, _worst_at, Engine.get_frames_per_second()])
	quit(0)
