extends SceneTree
## El medidor F3 apunta los tirones con el suceso del juego que los precede.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var meter := root.get_node_or_null("PerfMeter")
	if meter == null:
		push_error("El medidor debe estar activo como autoload.")
		quit(1)
		return
	meter.record_frame(16.0)
	if not meter.spikes.is_empty():
		push_error("Un fotograma normal no es un tirón.")
		quit(1)
		return
	meter.note("dado: resultado")
	meter.record_frame(180.0)
	if meter.spikes.size() != 1 or meter.spikes[0]["event"] != "dado: resultado":
		push_error("Un tirón tras el dado debe quedar apuntado con su suceso.")
		quit(1)
		return
	for i in 10:
		meter.record_frame(90.0)
	if meter.spikes.size() != meter.KEEP:
		push_error("Solo se guardan los últimos tirones.")
		quit(1)
		return
	meter._refresh()
	print("perf_meter: ok")
	quit(0)
