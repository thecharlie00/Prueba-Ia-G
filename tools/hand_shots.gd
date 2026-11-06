extends SceneTree
## Capturas de las manos 3D con cartas de ejemplo (isla y mesa de cartas), para revisar el arte.
## Uso: godot --path . --resolution 1280x720 --script res://tools/hand_shots.gd -- carpeta


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var island: IslandView = (load("res://scenes/Island.tscn") as PackedScene).instantiate()
	root.add_child(island)
	await _frames(20)
	island.rules.resources[0] = [3, 1, 0, 2, 1]
	island.rules.dev_ready[0][0] = 1
	island.rules.dev_new[0][4] = 1
	island._refresh()
	await _shot(out + "/hand_island.png")
	island.queue_free()
	await _frames(5)
	var table: CardTable = (load("res://scenes/CardTable.tscn") as PackedScene).instantiate()
	root.add_child(table)
	await _frames(20)
	for i in 4:
		table.draw_to_hand(i % 2 == 0)
	table.draw_to_hand(true)
	for i in 3:
		table.english.draw_card()
		table.spanish.draw_card()
	await _shot(out + "/hand_cards.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(path: String) -> void:
	await _frames(60)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
