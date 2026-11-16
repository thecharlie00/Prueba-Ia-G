extends SceneTree
## Capturas de la habitación con el peón en distintos sitios (revisión de arte).
## Uso: xvfb-run godot --path . --script res://tools/home_shots.gd -- carpeta [--demo] [--en]

const SPOTS := {
	"inicio": Vector3(0, 0, 3.75),
	"puerta": Vector3(-7.6, 0, -1.6),
	"estanteria": Vector3(-5.2, 0, -5.8),
	"taller": Vector3(6.3, 0, 2.3),
	"gato": Vector3(-4.2, 0, 4.5),
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://home_shots"
	DirAccess.make_dir_recursive_absolute(out)
	if "--en" in args:
		root.get_node("Locale").set_language("en", false)
	change_scene_to_file("res://scenes/Home.tscn")
	for i in 10:
		await process_frame
	var home := current_scene as Home
	for key in SPOTS:
		home.pawn.position = SPOTS[key]
		home.pawn.rotation.y = PI
		for i in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))
	home.open_settings()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out.path_join("ajustes.png"))
	quit(0)
