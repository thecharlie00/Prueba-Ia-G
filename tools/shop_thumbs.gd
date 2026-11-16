extends SceneTree
## Genera las miniaturas de Dadazon (assets/shop/<id>.png, 256×256, fondo transparente).
## Uso: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/shop_thumbs.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.95)
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.current = true
	var out := ProjectSettings.globalize_path("res://assets/shop")
	DirAccess.make_dir_recursive_absolute(out)
	for id in ShopCatalog.ITEMS:
		var holder := Node3D.new()
		viewport.add_child(holder)
		var kind := ShopCatalog.kind(id)
		var center := Vector3.ZERO
		var radius := 1.0
		if kind == ShopCatalog.DECOR:
			DecorItems.make(holder, id)
			var box := _bounds(holder)
			center = box.get_center()
			radius = maxf(box.size.length() * 0.5, 0.3)
			if id == "bola_disco":
				center = Vector3.ZERO
				radius = 0.5
		else:
			var meeple := HomeDecor.make_meeple(HomePrefs.COLORS[0])
			holder.add_child(meeple)
			PawnWear.apply(meeple, id if kind == ShopCatalog.HAT else "sin_sombrero", id if kind == ShopCatalog.ACCESSORY else "sin_complemento")
			center = Vector3(0, 2.15 if kind == ShopCatalog.HAT else 1.75, 0)
			radius = 0.85 if kind == ShopCatalog.HAT else 0.75
		holder.rotation.y = -0.45
		var distance := radius / sin(deg_to_rad(camera.fov * 0.5)) * 1.05
		camera.position = center + Vector3(0, radius * 0.45, distance)
		camera.look_at(center, Vector3.UP)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(out.path_join(id + ".png"))
		holder.queue_free()
		await process_frame
	print("shop_thumbs: %d" % ShopCatalog.ITEMS.size())
	quit(0)


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		stack.append_array(current.get_children())
		if current is VisualInstance3D and not (current is Light3D):
			var visual := current as VisualInstance3D
			var world := visual.global_transform * visual.get_aabb()
			box = world if first else box.merge(world)
			first = false
	return box
