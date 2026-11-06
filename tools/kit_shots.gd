extends SceneTree
## Capturas de las herramientas de mesa (contador, bolsa, nota, reloj, zonas privadas, pincel,
## vistas y tutorial). Uso con xvfb:
##   godot --path . --resolution 1280x720 --script res://tools/kit_shots.gd -- <carpeta> [es|en|ca]


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var language: String = args[1] if args.size() > 1 else "es"
	root.get_node("Locale").set_language(language, false)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 20:
		await physics_frame
	var counter: Counter3D = main.spawn_utility("counter")
	counter.global_position = Vector3(-1.4, 1.1, 0.3)
	var bag: Bag3D = main.spawn_utility("bag")
	bag.global_position = Vector3(-0.3, 1.1, 0.4)
	var note: Note3D = main.spawn_utility("note")
	note.global_position = Vector3(0.8, 1.0, -0.9)
	var timer: Timer3D = main.spawn_utility("timer")
	timer.global_position = Vector3(-2.4, 1.1, -0.6)
	for i in 30:
		await physics_frame
	counter.set_value(12)
	note.close_editor("¡Turno de Ana!" if language == "es" else "Ana's turn!")
	timer.adjust(90.0)
	timer.toggle()
	bag.put(main.get_node("Objects/TokenBlue"))
	bag.put(main.get_node("Objects/TokenRed"))
	main.get_node("Objects/Dice2").global_position = Vector3(-1.6, 1.0, -1.9)
	var card := main.get_node("Objects/Card") as Node3D
	card.global_position = Vector3(1.6, 0.9, 1.9)
	var rig: TabletopCamera3D = main.get_node("TabletopCamera3D")
	rig.set_view("seat1", true)
	for i in 60:
		await physics_frame
	var brush: TableBrush = main.get_node("TableBrush")
	brush.set_active(true)
	var start := rig.camera.unproject_position(Vector3(0.3, 0.82, -0.3))
	brush.begin_stroke(start)
	for k in 24:
		brush.extend_stroke(start + Vector2(k * 9.0, sin(k * 0.5) * 30.0))
	brush.end_stroke()
	main.grabber._update_hover(rig.camera.unproject_position(counter.global_position))
	await _shot(out + "/kit_seat1_%s.png" % language)
	brush.set_active(false)
	rig.set_view("top", true)
	await _shot(out + "/kit_top_%s.png" % language)
	rig.set_view("seat2", true)
	await _shot(out + "/kit_seat2_%s.png" % language)
	rig.set_view("", true)
	Tutorial.start(main)
	main.get_node("TableHud").set_drawer_open(true)
	await _shot(out + "/kit_tutorial_%s.png" % language)
	quit(0)
