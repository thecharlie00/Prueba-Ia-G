extends SceneTree
## Capturas de la brisca, el parchís y la mesa de cartas (revisión visual del contenido offline).
## Uso: xvfb-run godot --path . --script res://tools/offline_shots.gd -- carpeta_de_salida


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1600, 900)
	# Brisca a mitad de baza.
	var brisca: BriscaView = (load("res://scenes/Brisca.tscn") as PackedScene).instantiate()
	root.add_child(brisca)
	await _frames(20)
	brisca.rules = BriscaRules.new(5)
	brisca.play(brisca.rules.hands[0][1])
	brisca.set_process(false)
	brisca.refresh()
	await _frames(60)
	await _shot(out.path_join("brisca.png"))
	brisca.hand.sort_cards("suit")
	await _frames(30)
	brisca.queue_free()
	await _frames(3)
	# Parchís a 4 con una barrera y fichas en juego.
	var parchis: LudoView = (load("res://scenes/Parchis.tscn") as PackedScene).instantiate()
	root.add_child(parchis)
	await _frames(20)
	parchis.rules.positions[0] = [6, 6, 20, LudoRules.YARD]
	parchis.rules.positions[1] = [3, LudoRules.YARD, LudoRules.YARD, LudoRules.YARD]
	parchis.rules.positions[2] = [10, 30, LudoRules.YARD, LudoRules.YARD]
	parchis._refresh()
	await _frames(240)
	await _shot(out.path_join("parchis.png"))
	parchis.queue_free()
	await _frames(3)
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
