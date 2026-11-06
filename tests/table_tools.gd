extends SceneTree
## Herramientas de mesa (fase 2): menú radial, señalar y rebobinar la mesa libre.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var grabber: PhysicsGrabber3D = main.grabber
	var menu: RadialMenu = grabber.radial_menu
	if menu == null:
		_fail("El agarre debe crear el menú radial.")
		return

	# Menú de un dado: tirar, girar, recuperar, señalar... cada acción con su tecla.
	var dice := main.get_node("Objects/Dice") as Dice3D
	var dice_actions := menu.actions_for(dice).map(func(a: Dictionary) -> String: return a["key"])
	if not "R" in dice_actions or not "P" in dice_actions or not "H" in dice_actions:
		_fail("El menú del dado debe ofrecer tirar, recuperar y señalar: %s" % [dice_actions])
		return
	var deck: Deck3D = null
	for child in main.get_node("Objects").get_children():
		if child is Deck3D:
			deck = child
	var deck_labels := menu.actions_for(deck).map(func(a: Dictionary) -> String: return a["label"])
	if not "Robar" in deck_labels or not "Mezclar" in deck_labels:
		_fail("El menú del mazo debe ofrecer robar y mezclar.")
		return

	# Elegir "Girar ↻" envía la tecla E y gira la pieza.
	menu.open(dice, Vector2(600, 360))
	if not menu.is_open() or menu._root.get_child_count() != menu.actions.size() + 1:
		_fail("El menú debe mostrar un botón por acción más el nombre de la pieza.")
		return
	var before := dice.global_basis
	var turn := -1
	for i in menu.actions.size():
		if menu.actions[i]["keycode"] == KEY_E:
			turn = i
	menu.choose(turn)
	for i in 30:
		await physics_frame
	if menu.is_open():
		_fail("El menú debe cerrarse al elegir una acción.")
		return
	if dice.global_basis.is_equal_approx(before):
		_fail("Elegir Girar en el menú debe girar el dado.")
		return

	# Señalar deja una marca que desaparece sola.
	var marker := grabber.ping(Vector3(0, 0.9, 0))
	if not is_instance_valid(marker) or marker.get_parent() != main:
		_fail("Señalar debe crear una marca en la mesa.")
		return
	await create_timer(1.6).timeout
	if is_instance_valid(marker):
		_fail("La marca de señalar debe desaparecer.")
		return

	# Rebobinar: mover una pieza, capturar y volver al momento anterior.
	var timeline: TableTimeline = main.timeline
	for i in 120:
		await physics_frame
	timeline.capture()
	var count := timeline.moments.size()
	if count < 1:
		_fail("La línea de tiempo debe guardar la mesa quieta.")
		return
	var start: Vector3 = dice.global_position
	dice.global_position = start + Vector3(1.5, 0.05, 0)
	dice.linear_velocity = Vector3.ZERO
	for i in 120:
		await physics_frame
	timeline.capture()  # Puede que ya lo haya guardado la captura automática.
	if timeline.moments.size() < count + 1:
		_fail("Un cambio en la mesa debe crear un momento nuevo.")
		return
	if timeline.capture():
		_fail("Sin cambios no debe crearse otro momento.")
		return
	timeline.toggle()
	if not timeline.is_open() or timeline._strip.get_child_count() != timeline.moments.size():
		_fail("La tira de rebobinado debe mostrar un botón por momento.")
		return
	var before_move := -1
	for i in timeline.moments.size():
		var piece: Dictionary = timeline.moments[i]["record"]["objects"].filter(func(p: Dictionary) -> bool: return p["name"] == "Dice")[0]
		if Vector3(piece["position"][0], piece["position"][1], piece["position"][2]).distance_to(start) < 0.05:
			before_move = i
	if not timeline.rewind_to(before_move):
		_fail("Volver a un momento anterior debe funcionar.")
		return
	await physics_frame
	var restored := main.get_node("Objects/Dice") as Dice3D
	if restored == null or restored.global_position.distance_to(start) > 0.05:
		_fail("Rebobinar debe devolver el dado a su sitio: %s" % [restored.global_position if restored else null])
		return

	print("Table tools tests OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
