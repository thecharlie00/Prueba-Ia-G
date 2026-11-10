extends SceneTree
## Pruebas del sistema de Lobby online: hash de contraseñas con salt, buscador y filtros
## de salas públicas, máscaras de bots/«Listo» y reactividad de la escena Lobby.tscn.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var net := root.get_node_or_null("Net")
	_check(net != null, "autoload Net registrado")
	if net == null:
		quit(1)
		return

	# 1. Hash SHA-256 + salt y verificación de contraseñas
	var salt1: String = net.generate_salt()
	var salt2: String = net.generate_salt()
	_check(salt1.length() == 16 and salt1 != salt2, "salts aleatorios de 16 hex")
	var h1: String = net.hash_password("secreto123", salt1)
	var h2: String = net.hash_password("secreto123", salt2)
	_check(h1.length() == 64 and h1 != h2, "el mismo secreto con distinto salt da distinto hash")
	_check(net.verify_password("secreto123", salt1, h1), "contraseña correcta verificada")
	_check(not net.verify_password("otra", salt1, h1), "contraseña errónea rechazada")
	_check(not net.verify_password("", salt1, h1), "contraseña vacía rechazada en sala con clave")
	_check(net.verify_password("", "", ""), "sala sin clave acepta entrada libre")

	# 2. Parseo y filtrado multicriterio de salas públicas
	var sample_rooms := [
		{
			"name": "AAA111",
			"player_count": 1,
			"max_players": 2,
			"is_open": true,
			"custom_properties": {
				"title": "Duelo rápido",
				"host": "Marta",
				"game": "IslandTwo",
				"seats": 2,
				"started": false,
				"locked": false,
			},
		},
		{
			"name": "BBB222",
			"player_count": 2,
			"max_players": 3,
			"is_open": true,
			"custom_properties": {
				"title": "Isla privada amigos",
				"host": "Carlos",
				"game": "Island",
				"seats": 3,
				"started": false,
				"locked": true,
				"salt": salt1,
				"pw_hash": h1,
			},
		},
		{
			"name": "CCC333",
			"player_count": 4,
			"max_players": 4,
			"is_open": true,
			"custom_properties": {
				"title": "Mesa llena",
				"host": "Elena",
				"game": "IslandFour",
				"seats": 4,
				"started": false,
				"locked": false,
			},
		},
		{
			"name": "DDD444",
			"player_count": 2,
			"max_players": 4,
			"is_open": false,
			"custom_properties": {
				"title": "Ya empezada",
				"host": "Pablo",
				"game": "IslandFour",
				"seats": 4,
				"started": true,
				"locked": false,
			},
		},
	]

	var open_rooms: Array = net.filter_rooms(sample_rooms, "", "", true, false)
	_check(open_rooms.size() == 2, "solo con hueco excluye salas llenas o ya iniciadas")
	var all_rooms: Array = net.filter_rooms(sample_rooms, "", "", false, false)
	_check(all_rooms.size() == 4, "desactivar filtro de hueco muestra las 4 salas")
	var unlocked_open: Array = net.filter_rooms(sample_rooms, "", "", true, true)
	_check(
		unlocked_open.size() == 1 and str(unlocked_open[0]["code"]) == "AAA111",
		"filtro sin contraseña oculta salas con clave"
	)
	var by_mode: Array = net.filter_rooms(sample_rooms, "", "Island", true, false)
	_check(
		by_mode.size() == 1 and str(by_mode[0]["code"]) == "BBB222",
		"filtro por modo de juego funciona"
	)
	var by_host: Array = net.filter_rooms(sample_rooms, "marta", "", true, false)
	_check(
		by_host.size() == 1 and str(by_host[0]["code"]) == "AAA111",
		"búsqueda por anfitrión sin distinción de mayúsculas"
	)

	# 3. Máscaras de bots y estado «Listo»
	net.reset_room_bots()
	net.reset_room_ready()
	net.room_bots = [false, true, false, true]
	net.room_ready = [true, false, true, false]
	var bmask: int = net._bots_mask()
	var rmask: int = net._ready_mask()
	net.reset_room_bots()
	net.reset_room_ready()
	net._apply_bots_mask(bmask)
	net._apply_ready_mask(rmask)
	_check(
		net.room_bots == [false, true, false, true] and net.room_ready == [true, false, true, false],
		"máscaras enteras de bots y listo se serializan sin pérdida"
	)
	_check(
		net.is_seat_ready(0) and net.is_seat_ready(1) and net.is_seat_ready(2) and net.is_seat_ready(3),
		"butacas con bot cuentan automáticamente como listas"
	)
	net.reset_room_bots()
	net.reset_room_ready()

	# 4. Escena Lobby.tscn: buscador reactivo, filtros en vivo y validación de clave
	_check(change_scene_to_file("res://scenes/Lobby.tscn") == OK, "abrir escena Lobby.tscn")
	await process_frame
	await process_frame
	var lobby := current_scene
	_check(lobby != null, "escena Lobby cargada")
	if lobby != null:
		var browser := lobby.find_child("BrowserSection", true, false) as Control
		var room_list := lobby.find_child("RoomList", true, false) as VBoxContainer
		var search_edit := lobby.find_child("FilterSearch", true, false) as LineEdit
		var no_pass_check := lobby.find_child("FilterNoPass", true, false) as CheckBox
		_check(
			browser != null and browser.visible and room_list != null,
			"el buscador de salas públicas es visible al abrir el Lobby"
		)
		net._update_listings_from_raw(sample_rooms)
		await process_frame
		_check(
			room_list.get_child_count() == 2
			and room_list.get_node_or_null("RoomCard_AAA111") != null
			and room_list.get_node_or_null("RoomCard_BBB222") != null,
			"la lista renderiza las tarjetas de salas abiertas"
		)
		search_edit.text = "carlos"
		search_edit.text_changed.emit("carlos")
		await process_frame
		_check(
			room_list.get_child_count() == 1
			and room_list.get_node_or_null("RoomCard_BBB222") != null,
			"escribir en el buscador filtra las tarjetas en vivo"
		)
		search_edit.text = ""
		search_edit.text_changed.emit("")
		no_pass_check.button_pressed = true
		await process_frame
		_check(
			room_list.get_child_count() == 1
			and room_list.get_node_or_null("RoomCard_AAA111") != null,
			"marcar «Sin contraseña» oculta las salas protegidas"
		)
		# Verificar rechazo inmediato de contraseña errónea en diálogo de sala protegida
		var locked_info: Dictionary = net.find_listed_room("BBB222")
		lobby.set("_pw_dialog_room", locked_info)
		var dialog_input := lobby.find_child("DialogPasswordInput", true, false) as LineEdit
		var status_lbl := lobby.find_child("Status", true, false) as Label
		dialog_input.text = "clave_mala"
		lobby.call("_confirm_password_dialog")
		_check(
			status_lbl.text.contains("Contraseña incorrecta"),
			"el diálogo rechaza una contraseña incorrecta antes de conectar a la sala"
		)
		net.room_listings.clear()

	if failures > 0:
		printerr("Lobby system tests: %d errores" % failures)
		quit(1)
	else:
		print("Lobby system tests OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FALLO: " + message)
