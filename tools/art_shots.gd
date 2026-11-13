extends SceneTree
## Capturas de revisión de arte de las pantallas principales.
## Uso: xvfb-run godot --path . --script res://tools/art_shots.gd -- carpeta_de_salida [filtro]

const SHOTS := {
	"menu": "res://scenes/BotMenu.tscn",
	"modos": "res://scenes/ModeSelect.tscn",
	"mesa_libre": "res://scenes/Main.tscn",
	"ajedrez": "res://scenes/GuidedPhysicalChess.tscn",
	"parchis": "res://scenes/Parchis.tscn",
	"isla": "res://scenes/Island.tscn",
	"brisca": "res://scenes/Brisca.tscn",
	"domino": "res://scenes/GuidedDomino.tscn",
	"editor": "res://scenes/game_creator/GameCreatorEditor.tscn",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var filter: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	for key in SHOTS:
		if not filter.is_empty() and not filter in key:
			continue
		change_scene_to_file(SHOTS[key])
		for i in 150:
			await process_frame
		if key == "editor" and current_scene.has_method("_spawn_example_entity"):
			for i in 3:
				current_scene._spawn_example_entity()
			for i in 20:
				await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))
	quit()
