extends SceneTree
## Partidas de dominó bot contra bot con varias semillas; informa de fichas que no llegan.
## Uso: -- <semilla_inicial> <partidas>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var games := int(args[1]) if args.size() > 1 else 5
	for seed_value in range(first, first + games):
		var view: Node = (load("res://scenes/GuidedDomino.tscn") as PackedScene).instantiate()
		root.add_child(view)
		for i in 5:
			await physics_frame
		view.rules.reset(seed_value)
		view._sync_homes(true)
		for i in 20:
			await physics_frame
		var steps := 0
		while view.rules.result == DominoRules.PLAYING and steps < 120:
			view.bot_step()
			steps += 1
			for i in 6:
				await physics_frame
		for i in 300:
			await physics_frame
		var worst := 0.0
		var info := ""
		for key in view.homes:
			var b := key as RigidBody3D
			var h: Vector3 = view.homes[key]
			var d := Vector2(b.global_position.x - h.x, b.global_position.z - h.z).length()
			if d > worst:
				worst = d
				b.contact_monitor = true
				b.max_contacts_reported = 8
				info = "%s pos %s casa %s viaja %s cadena %d" % [b.name, b.global_position, h, HomeSteering.is_traveling(b), view._chain_index(view.tile_ids[b])]
		if worst > 0.2:
			for i in 3:
				await physics_frame
			for key in view.homes:
				var b := key as RigidBody3D
				if b.contact_monitor:
					var names := []
					for other in b.get_colliding_bodies():
						names.append("%s@%s" % [other.name, other.global_position.snapped(Vector3.ONE * 0.01)])
					info += " choca con %s" % [names]
		print("semilla %d: %d acciones, cadena %d, peor %.3f %s" % [seed_value, steps, view.rules.chain.size(), worst, info if worst > 0.2 else ""])
		view.queue_free()
		await process_frame
	quit(0)
