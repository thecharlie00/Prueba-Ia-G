extends SceneTree
## Capturas de inspección 3D, marcador, mazo formado al apilar y ludo con bots.
## Uso: -- <carpeta>


func _initialize() -> void:
	_run.call_deferred()


func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 30:
		await process_frame
	var main := current_scene
	var objects := main.get_node("Objects")
	var board: Scoreboard3D = main.spawn_utility("scoreboard")
	board.global_position = Vector3(-1.2, 1.0, -0.5)
	for i in 40:
		await physics_frame
	board.scores = [12, 7, 3, 9]
	board.select_row(0)
	var deck := objects.get_node("Deck") as Deck3D
	deck.draw_card()
	deck.draw_card()
	var cards := objects.find_children("*", "Card3D", false, false)
	TableStacking.on_release(objects, cards[1], cards[0].global_position)
	for i in 40:
		await physics_frame
	var grabber: PhysicsGrabber3D = main.grabber
	var dice := objects.get_node("Dice") as Dice3D
	var at: Vector2 = grabber.camera.unproject_position(dice.global_position)
	root.warp_mouse(at)
	for i in 4:
		await physics_frame
	grabber._update_hover(at)
	grabber._inspecting = true
	grabber._refresh_inspection()
	await _shot(out + "/inspect_dice.png")
	var loose: Node3D = objects.find_children("*", "Card3D", false, false)[0]
	var card_at: Vector2 = grabber.camera.unproject_position(loose.global_position)
	root.warp_mouse(card_at)
	for i in 4:
		await physics_frame
	grabber._update_hover(card_at)
	grabber._refresh_inspection()
	await _shot(out + "/inspect_card.png")
	grabber._hide_inspection()
	main.get_node("TabletopCamera3D").set_view("top", true)
	await _shot(out + "/scoreboard_top.png")
	change_scene_to_file("res://scenes/Ludo4.tscn")
	for i in 30:
		await process_frame
	var ludo := current_scene
	for player in 4:
		ludo.set_bot(player != 0, player)
	ludo.rules.apply_roll(6)
	ludo._choose_token(0)
	for i in 60:
		await physics_frame
	await _shot(out + "/ludo_bots.png")
	quit(0)
