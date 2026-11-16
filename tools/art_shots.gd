extends SceneTree
## Capturas de revisión de arte de las pantallas principales.
## Uso: xvfb-run godot --path . --script res://tools/art_shots.gd -- carpeta_de_salida [filtro]

const SHOTS := {
	"menu": "res://scenes/BotMenu.tscn",
	"habitacion": "res://scenes/Home.tscn",
	"modos": "res://scenes/ModeSelect.tscn",
	"bots": "res://scenes/BotSelect.tscn",
	"lobby": "res://scenes/Lobby.tscn",
	"lista": "res://scenes/Menu.tscn",
	"mesa_libre": "res://scenes/Main.tscn",
	"ajedrez": "res://scenes/GuidedPhysicalChess.tscn",
	"parchis": "res://scenes/Parchis.tscn",
	"isla": "res://scenes/Island.tscn",
	"brisca": "res://scenes/Brisca.tscn",
	"domino": "res://scenes/GuidedDomino.tscn",
	"editor": "res://scenes/game_creator/GameCreatorEditor.tscn",
	"editor_piezas": "res://scenes/game_creator/GameCreatorEditor.tscn",
	"creditos": "res://scenes/Credits.tscn",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var filter: String = args[1] if args.size() > 1 and not args[1].begins_with("--") else ""
	# --en: capturas en inglés. --demo: la edición demo (la lee el autoload Edition).
	if "--en" in args:
		root.get_node("Locale").set_language("en", false)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	for key in SHOTS:
		if not filter.is_empty() and not filter.trim_suffix("+cajon").trim_suffix("+prueba") in key:
			continue
		change_scene_to_file(SHOTS[key])
		for i in 150:
			await process_frame
		# Con «cajon» en el filtro, se abre el cajón «Partida» de la mesa.
		if "cajon" in filter:
			var hud := current_scene.find_child("TableHud", true, false)
			if hud != null:
				hud.set_drawer_open(true)
				for i in 10:
					await process_frame
		if key == "editor_piezas" and current_scene.has_method("add_piece"):
			# Una mesa de ejemplo con las formas nuevas y dos piezas seleccionadas.
			var editor := current_scene
			editor.add_piece("tablero")
			var colors := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_GREEN, Palette.PLAYER_YELLOW]
			var pawns: Array = []
			for i in 4:
				var pawn: PropEntity = editor.add_piece("peon")
				pawn.position = Vector3(-0.6 + i * 0.4, pawn.position.y, 0.6)
				editor.select_pieces([pawn])
				editor._edit_selection("color", colors[i])
				pawns.append(pawn)
			var deck: Array = []
			for i in 5:
				deck.append(editor.add_piece("carta"))
			editor.select_pieces(deck)
			editor._edit_selection("color", Palette.PIECE_DARK)
			editor.stack_selection()
			for card in deck:
				card.position += Vector3(1.6, 0, -0.3)
			var die: PropEntity = editor.add_piece("dado")
			die.position = Vector3(-1.5, 0, -0.5)
			editor._settle([die])
			editor.rotate_selection(30)
			for i in 3:
				var coin: PropEntity = editor.add_piece("moneda")
				coin.position = Vector3(1.5, 0.035 * i, 0.9)
			editor.select_pieces([pawns[1], pawns[2]])
			for i in 30:
				await process_frame
		if key == "editor" and current_scene.has_method("_spawn_example_entity"):
			for i in 3:
				current_scene._spawn_example_entity()
			# Una interfaz de ejemplo: marcador, botones y un título.
			var editor := current_scene
			var title_id: int = editor.add_ui_element("text")
			editor.set_ui_property("text", "Mi juego")
			editor.ui_layout.find(title_id)["pos"] = Vector2(510, 24)
			var score_id: int = editor.add_ui_element("counter")
			editor.ui_layout.find(score_id)["pos"] = Vector2(520, 630)
			var plus_id: int = editor.add_ui_element("button")
			editor.set_ui_property("text", "Tirar dado")
			editor.set_ui_property("action", "roll")
			editor.ui_layout.find(plus_id)["pos"] = Vector2(760, 634)
			for element in editor.ui_layout.elements:
				editor.ui_layout.reanchor(element)
			editor.ui_view.rebuild()
			editor.ui_view.select(plus_id)
			for i in 5:
				await process_frame
			if "prueba" in filter:
				editor._toggle_mode()
			for i in 20:
				await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))
	quit()
