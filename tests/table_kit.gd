extends SceneTree
## Quejas de TTS resueltas en local: contadores, bolsas, notas, reloj, zonas privadas,
## vistas por asiento, pincel y volcar la mesa.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var grabber: PhysicsGrabber3D = main.grabber
	var objects: Node = main.get_node("Objects")

	# Contador: + / − y a cero, también desde el menú radial.
	var counter := main.spawn_utility("counter") as Counter3D
	_check(counter != null, "se puede añadir un contador")
	await physics_frame
	grabber.apply_shortcut(KEY_PLUS, counter)
	grabber.apply_shortcut(KEY_PLUS, counter)
	grabber.apply_shortcut(KEY_MINUS, counter)
	_check(counter.value == 1, "el contador suma y resta (%d)" % counter.value)
	var labels := grabber.radial_menu.actions_for(counter).map(func(a: Dictionary) -> String: return a["label"])
	_check("+1" in labels and "A cero" in labels, "el menú radial del contador ofrece +1 y a cero")

	# Reloj: cuenta atrás de 30 s que se puede arrancar y pausar.
	var timer := main.spawn_utility("timer") as Timer3D
	await physics_frame
	grabber.apply_shortcut(KEY_PLUS, timer)
	_check(is_equal_approx(timer.seconds, 30.0), "+ pone 30 s de cuenta atrás")
	grabber.apply_shortcut(KEY_R, timer)
	await create_timer(0.3).timeout
	_check(timer.running and timer.seconds < 30.0, "el reloj descuenta al arrancar")
	grabber.apply_shortcut(KEY_R, timer)
	_check(not timer.running, "R pausa el reloj")

	# Nota con texto.
	var note := main.spawn_utility("note") as Note3D
	await physics_frame
	var input := note.open_editor()
	_check(input != null, "Intro abre el editor de la nota")
	note.close_editor("Turno de Ana")
	_check(note.text == "Turno de Ana", "la nota guarda el texto")

	# Bolsa: guardar una ficha y sacarla al azar.
	var bag := main.spawn_utility("bag") as Bag3D
	await physics_frame
	var token := objects.get_node("TokenRed") as Token3D
	_check(bag.put(token), "la bolsa acepta una ficha")
	await process_frame
	_check(bag.contents.size() == 1 and not is_instance_valid(token), "la ficha queda dentro de la bolsa")
	_check(not bag.can_hold(bag), "una bolsa no se mete en sí misma")

	# Todo se guarda y se restaura con la mesa.
	for i in 90:
		await physics_frame
	var record := SandboxPersistence.snapshot(objects, false)
	_check(not record.is_empty(), "la mesa con contador, reloj, nota y bolsa se puede guardar")
	if not record.is_empty():
		var json: Variant = JSON.parse_string(JSON.stringify(record))
		_check(SandboxPersistence.validate(json), "el guardado sobrevive a JSON")
		_check(main.apply_record(json), "el guardado se restaura")
		await process_frame
		var restored_bag: Bag3D = null
		var restored_note: Note3D = null
		var restored_counter: Counter3D = null
		for child in objects.get_children():
			if child is Bag3D:
				restored_bag = child
			elif child is Note3D:
				restored_note = child
			elif child is Counter3D:
				restored_counter = child
		_check(restored_bag != null and restored_bag.contents.size() == 1, "la bolsa conserva lo que lleva")
		_check(restored_note != null and restored_note.text == "Turno de Ana", "la nota conserva el texto")
		_check(restored_counter != null and restored_counter.value == 1, "el contador conserva el valor")
		if restored_bag != null:
			var drawn := restored_bag.draw_random()
			_check(drawn is Token3D and restored_bag.contents.is_empty(), "N saca la ficha de la bolsa")

	# Una bolsa dentro de otra no es un guardado válido.
	var nested := {
		"format": "diceon_sandbox", "version": 1, "snap": false,
		"objects": [{
			"type": "bag", "name": "B", "display_name": "Bolsa", "position": [0, 1, 0],
			"rotation": [0, 0, 0, 1], "velocity": [0, 0, 0], "angular_velocity": [0, 0, 0],
			"locked": false, "color": [1, 1, 1, 1],
			"contents": [{
				"type": "bag", "name": "C", "display_name": "Bolsa", "position": [0, 1, 0],
				"rotation": [0, 0, 0, 1], "velocity": [0, 0, 0], "angular_velocity": [0, 0, 0],
				"locked": false, "color": [1, 1, 1, 1], "contents": []
			}]
		}]
	}
	_check(not SandboxPersistence.validate(nested), "no se aceptan bolsas dentro de bolsas")

	# Vistas: V recorre cenital y asientos; el asiento decide qué zona privada se ve.
	var rig: TabletopCamera3D = main.get_node("TabletopCamera3D")
	_check(rig.cycle_view() == "top", "V empieza por la vista cenital")
	rig.set_view("top", true)
	_check(rig.camera.global_basis.z.y > 0.98, "la vista cenital mira hacia abajo")
	var zone1: HiddenZone3D = main.get_node("HiddenZone1")
	var zone2: HiddenZone3D = main.get_node("HiddenZone2")
	var dice := objects.get_node("Dice2") as Dice3D
	dice.global_position = zone2.global_position + Vector3.UP * 0.2
	for i in 4:
		await physics_frame
	rig.set_view("seat1", true)
	await physics_frame
	_check(zone2.inside.has(dice), "la zona detecta la pieza que tiene dentro")
	_check(bool(dice.get_meta(&"private_hidden", false)), "desde el asiento 1 la mano de J2 está oculta")
	_check(not dice.visible and zone2.hidden_count() == 1, "la pieza ajena se ve como una nubecilla")
	_check(zone1.hidden_count() == 0, "la mano propia no se oculta")
	rig.set_view("seat2", true)
	await physics_frame
	_check(not bool(dice.get_meta(&"private_hidden", false)), "J2 ve su propia mano")
	_check(dice.visible and zone2.hidden_count() == 0, "al cambiar de asiento la pieza vuelve a verse")
	rig.set_view("seat1", true)
	await physics_frame
	grabber._update_hover(rig.camera.unproject_position(dice.global_position))
	_check(grabber.hovered != dice, "no se puede agarrar una pieza de la mano ajena")

	# Pincel: D lo activa y arrastrar deja un trazo.
	var brush: TableBrush = main.get_node("TableBrush")
	brush.set_active(true)
	rig.set_view("top", true)
	await physics_frame
	var center := rig.camera.unproject_position(Vector3(0.5, 0.82, 0.5))
	_check(brush.begin_stroke(center), "el pincel encuentra la mesa bajo el ratón")
	brush.extend_stroke(center + Vector2(80, 0))
	brush.extend_stroke(center + Vector2(80, 60))
	brush.end_stroke()
	_check(brush.strokes.size() == 1 and brush.strokes[0].mesh != null, "arrastrar crea un trazo")
	brush.undo_stroke()
	await process_frame
	_check(brush.strokes.is_empty(), "Retroceso borra el último trazo")
	brush.set_active(false)

	# Volcar la mesa lanza las piezas sueltas.
	var token_gold := objects.get_node("TokenGold") as Token3D
	_check(main.flip_table(), "se puede volcar la mesa")
	for i in 3:
		await physics_frame
	_check(token_gold.linear_velocity.y > 1.0, "las piezas salen por los aires")

	if _failed:
		quit(1)
	else:
		print("table_kit: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
