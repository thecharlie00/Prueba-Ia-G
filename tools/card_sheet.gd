extends SceneTree
## Hoja con muestras del arte de cartas (CardArt), para revisarlo.
## Uso: godot --path . --resolution 1280x720 --script res://tools/card_sheet.gd -- salida.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var samples := [
		["playing", "A ♠"], ["playing", "7 ♥"], ["playing", "Q ♦"], ["playing", "3 ♣"],
		["playing", "1 O"], ["playing", "5 C"], ["playing", "11 E"], ["playing", "7 B"],
		["back", ""], ["resource", 4], ["development", 0], ["development", 4],
	]
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(20, 20)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	for sample in samples:
		var rect := TextureRect.new()
		rect.texture = CardArt.texture(sample[0], sample[1])
		rect.custom_minimum_size = Vector2(190, 268)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		grid.add_child(rect)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
