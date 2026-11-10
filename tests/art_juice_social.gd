extends SceneTree
## Verifica la capa de dirección de arte 3D, avatares expresivos, abanicos de cartas rivales,
## juice táctil / shaders, iluminación de habitación optimizada y feedback social online.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_room_vfx_and_juice()
	await _test_brisca_avatars_and_rival_fan()
	await _test_island_rival_cards_and_social()
	if _failures > 0:
		push_error("art_juice_social: %d fallos" % _failures)
		quit(1)
	else:
		print("art_juice_social: OK")
		quit(0)


func _test_room_vfx_and_juice() -> void:
	var main: Node3D = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(main)
	for i in 5:
		await process_frame

	# 1. Habitación optimizada con MultiMesh y foco cálido cenital + pool de VFX.
	var decor := main.get_node_or_null("RoomDecor") as RoomDecor
	_check(decor != null, "Main incluye RoomDecor")
	if decor != null:
		var lines := decor.get_node_or_null("FloorboardLines") as MultiMeshInstance3D
		var cuts := decor.get_node_or_null("FloorboardCuts") as MultiMeshInstance3D
		_check(
			lines != null and lines.multimesh != null and lines.multimesh.instance_count == 33,
			"juntas longitudinales agrupadas en MultiMeshInstance3D"
		)
		_check(
			cuts != null and cuts.multimesh != null and cuts.multimesh.instance_count == 429,
			"juntas transversales agrupadas en MultiMeshInstance3D"
		)
		var spot := decor.find_child("TableWarmSpot", true, false) as SpotLight3D
		_check(
			spot != null and not spot.shadow_enabled and spot.light_energy > 0.2,
			"lámpara colgante proyecta foco cálido sin sobrecoste de sombras"
		)

	var vfx := TableVfx.ensure_for(main)
	_check(vfx != null and vfx.get_node_or_null("DropRing0") != null, "pool TableVfx inicializado")

	# 2. Estados de interacción, sombra de contacto y destello coral de acción inválida.
	var dice := main.get_node("Objects/Dice") as InteractiveTableObject
	var visual := dice.get_node("Visual") as MeshInstance3D
	dice.set_hovered(true)
	await process_frame
	var rim := visual.get_node_or_null("RimGlow") as MeshInstance3D
	var shadow := dice.get_node_or_null("ContactShadow") as MeshInstance3D
	_check(
		rim != null and rim.visible and rim.material_override is ShaderMaterial,
		"RimGlow Fresnel activo al señalar pieza"
	)
	_check(shadow != null, "ContactShadow creado en objetos interactivos")
	dice.flash_invalid()
	await process_frame
	_check(dice._invalid_timer > 0.0, "flash_invalid activa temporizador de rechazo coral")
	dice.set_hovered(false)

	# 3. Shader de flexión aerodinámica en Card3D.
	var card: Card3D = (load("res://scenes/Card3D.tscn") as PackedScene).instantiate() as Card3D
	main.get_node("Objects").add_child(card)
	card.set_card_label("A ♠")
	await process_frame
	var front := card.get_node_or_null("Visual/Front") as MeshInstance3D
	_check(
		front != null and front.material_override is ShaderMaterial,
		"Card3D usa ShaderMaterial de flexión aerodinámica"
	)
	if front != null and front.mesh is QuadMesh:
		var qm := front.mesh as QuadMesh
		_check(
			qm.subdivide_width == 8 and qm.subdivide_depth == 12,
			"Card3D comparte QuadMesh subdividido 8x12"
		)

	main.queue_free()
	await process_frame
	await process_frame


func _test_brisca_avatars_and_rival_fan() -> void:
	var brisca: BriscaView = (load("res://scenes/Brisca.tscn") as PackedScene).instantiate() as BriscaView
	root.add_child(brisca)
	for i in 5:
		await process_frame

	var hud := brisca.get_node_or_null("TableHud") as TableHud
	_check(hud != null and hud.seats != null, "Brisca monta TableHud y TableSeats")
	if hud != null and hud.seats != null:
		var seats := hud.seats
		# El asiento 0 (jugador local) no duplica su mano en el abanico 3D; el asiento 1 (rival) muestra 3 dorsos.
		_check(seats.card_count(0) == 0, "el jugador local no duplica su mano en RivalHandFan")
		_check(seats.card_count(1) == 3, "el rival en Brisca muestra exactamente 3 cartas en su abanico 3D")

		var rival_avatar := seats.avatar(1)
		_check(rival_avatar != null, "existe nodo Seat1 del rival")
		if rival_avatar != null:
			_check(
				rival_avatar.find_child("HeadPivot", true, false) != null
				and rival_avatar.find_child("HandL", true, false) != null
				and rival_avatar.find_child("BrowL", true, false) != null,
				"avatar rival tiene cabeza articulada, cejas y manos flotantes"
			)
			var fan := rival_avatar.get_node_or_null("RivalHandFan") as RivalHandFan3D
			_check(fan != null and fan.visible, "RivalHandFan visible con cartas")

		seats.set_focus_target(Vector3(0.5, 0.85, -0.2), 1.5)
		seats.trigger_emote(1, "victory", 1.2)
		await process_frame
		var bubble := rival_avatar.get_node_or_null("EmoteBubble") as EmoteBubble3D
		_check(
			bubble != null and bubble.visible and bubble.current_emote == "victory",
			"trigger_emote despliega bocadillo cómic sobre el avatar"
		)

	brisca.queue_free()
	await process_frame
	await process_frame


func _test_island_rival_cards_and_social() -> void:
	var island: IslandView = (load("res://scenes/Island.tscn") as PackedScene).instantiate() as IslandView
	root.add_child(island)
	for i in 5:
		await process_frame

	island.rules.resources[0] = [2, 1, 0, 0, 0]
	island.rules.resources[1] = [1, 2, 1, 0, 1]
	island.rules.dev_new[1][IslandRules.KNIGHT] = 1
	island._refresh()
	await process_frame

	_check(island.seats != null, "Isla crea TableSeats")
	if island.seats != null:
		_check(island.seats.card_count(0) == 0, "visor local en Isla oculta su propio RivalHandFan")
		_check(
			island.seats.card_count(1) == 6,
			"rival J2 en Isla refleja sus 5 recursos + 1 desarrollo como 6 dorsos"
		)

	var social := island.get_node_or_null("SocialOverlay3D") as SocialOverlay3D
	_check(social != null, "SocialOverlay3D adjunto automáticamente a Isla")
	if social != null and island.net_table != null:
		# Simular recepción de cursor, ping y emote de un jugador remoto (peer -99, butaca 1).
		island.net_table.net_cursor(-99, 1, 120, 82, -65, 1)
		await process_frame
		var ptr := social.get_node_or_null("RemotePointer1") as Node3D
		_check(
			ptr != null and ptr.visible,
			"net_cursor activa e interpola el puntero 3D del jugador remoto"
		)

		island.net_table.net_emote(-99, 1, "laugh")
		await process_frame
		var seat1: Node3D = island.seats.avatar(1)
		var bubble: EmoteBubble3D = (
			seat1.get_node_or_null("EmoteBubble") as EmoteBubble3D if seat1 != null else null
		)
		_check(
			bubble != null and bubble.visible and bubble.current_emote == "laugh",
			"net_emote muestra reacción cómic del jugador remoto"
		)

		island.net_table.net_ping(-99, 2, -80, 82, 40)
		await process_frame
		_check(
			island.seats._focus_hold > 1.0,
			"net_ping dirige la atención (Look-At) de los avatares al punto señalado"
		)

		# Verificar barra rápida de emotes (botón ☺ y tecla G).
		var toggle := social.find_child("EmoteToggle", true, false) as Button
		var bar := social.find_child("EmoteBar", true, false) as Control
		_check(toggle != null and bar != null and not bar.visible, "barra de emotes inicialmente cerrada")
		if toggle != null and bar != null:
			toggle.pressed.emit()
			await process_frame
			_check(bar.visible, "pulsar ☺ despliega la barra de emotes")

	island.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FALLO: " + message)
