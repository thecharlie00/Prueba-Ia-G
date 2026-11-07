extends SceneTree
## Revisión visual de todas las mesas como escena actual (con HUD y botones de sesión).
## Uso: -- <carpeta> <sufijo> [escena...]

const SCENES := [
	"Menu", "Main", "Chess", "GuidedPhysicalChess", "PhysicalChess", "Checkers",
	"GuidedPhysicalCheckers", "PhysicalCheckers", "GuidedDomino", "PhysicalDomino",
	"Ludo", "Ludo3", "Ludo4", "Island", "IslandFour", "CardTable",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var suffix: String = args[1]
	var list: Array = args.slice(2) if args.size() > 2 else SCENES
	root.get_node("Locale").set_language("es", false)
	for scene in list:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		for i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, scene, suffix])
		print("captura %s" % scene)
	quit(0)
