extends SceneTree
## Sonido generado, celebración del dado y habitación alrededor de la mesa.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sfx := root.get_node_or_null("Sfx")
	if sfx == null:
		_fail("El autoload Sfx debe estar registrado.")
		return
	for sound in sfx.SOUNDS:
		var stream: AudioStreamWAV = sfx.streams.get(sound)
		if stream == null or stream.data.size() < 200:
			_fail("Falta el sonido generado '%s'." % sound)
			return
	sfx.play("grab")
	sfx.play("grab")  # La repetición inmediata se ignora sin errores.
	var was_enabled: bool = sfx.enabled
	sfx.settings_path = "user://test_sound_settings.cfg"
	sfx.set_enabled(false)
	var config := ConfigFile.new()
	config.load(sfx.settings_path)
	if config.get_value("audio", "effects", true) != false:
		_fail("Desactivar los efectos debe guardarse.")
		return
	sfx.set_enabled(was_enabled)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sfx.settings_path))

	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	if not main.has_node("RoomDecor"):
		_fail("La mesa debe tener la habitación alrededor.")
		return
	var dice := main.get_node("Objects/Dice") as Dice3D
	dice._celebrate(4)
	await process_frame
	var pop := main.find_child("ResultPop", true, false) as Label3D
	if pop == null or pop.text != "4":
		_fail("Al salir un resultado, el número debe saltar encima del dado.")
		return
	await create_timer(1.6).timeout
	if is_instance_valid(pop):
		_fail("El número del dado debe desaparecer tras mostrarse.")
		return

	print("Sound and room tests OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
