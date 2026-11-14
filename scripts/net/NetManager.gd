extends Node
## Gestión de la sesión online: conexión a Photon Fusion, buscador de salas públicas,
## filtros, contraseñas con hash SHA-256 + salt, estado «Listo» y bots en sala.
##
## El autoload «Net» expone conexión, salas y señales; las pantallas (Lobby) y
## las mesas online (NetTable) se subscriben. Sin App ID en los ajustes del
## proyecto (net/app_id), arranca en modo sala offline (create_singleplayer_room)
## para probar el protocolo sin cuenta de Photon.

signal connected()
signal disconnected()
signal connection_failed(error: String)
signal room_joined()
signal room_left()
signal room_list_changed(rooms: Array)
signal player_joined(player_id: int, user_id: String)
signal player_left(player_id: int)
signal host_changed(new_id: int)
signal start_announced(scene: String, seats: int)
signal room_info_received()
signal auth_rejected(reason: String)
signal kicked(reason: String)

## Butacas máximas de una sala.
const SEATS_MAX := 4

## Propiedades expuestas al buscador público del Lobby de Photon.
const LOBBY_PROP_KEYS := [
	"title",
	"host",
	"game",
	"seats",
	"started",
	"locked",
	"salt",
	"pw_hash",
]

## Mesas disponibles para jugar online: identificador y escena.
const ONLINE_GAMES := [
	{"id": "IslandTwo", "title": "Isla de recursos · 2 jugadores", "scene": "res://scenes/IslandTwo.tscn", "seats": 2},
	{"id": "Island", "title": "Isla de recursos · 3 jugadores", "scene": "res://scenes/Island.tscn", "seats": 3},
	{"id": "IslandFour", "title": "Isla de recursos · 4 jugadores", "scene": "res://scenes/IslandFour.tscn", "seats": 4},
	{"id": "Parchis2", "title": "Parchís · 2 jugadores", "scene": "res://scenes/Parchis2.tscn", "seats": 2},
	{"id": "Parchis", "title": "Parchís · 4 jugadores", "scene": "res://scenes/Parchis.tscn", "seats": 4},
	{"id": "Ludo", "title": "Ludo · 2 jugadores", "scene": "res://scenes/Ludo.tscn", "seats": 2},
	{"id": "Ludo3", "title": "Ludo · 3 jugadores", "scene": "res://scenes/Ludo3.tscn", "seats": 3},
	{"id": "Ludo4", "title": "Ludo · 4 jugadores", "scene": "res://scenes/Ludo4.tscn", "seats": 4},
	{"id": "ChessOnline", "title": "Ajedrez · 2 jugadores", "scene": "res://scenes/GuidedPhysicalChess.tscn", "seats": 2},
	{"id": "CheckersOnline", "title": "Damas · 2 jugadores", "scene": "res://scenes/GuidedPhysicalCheckers.tscn", "seats": 2},
	{"id": "DominoOnline", "title": "Dominó · 2 jugadores", "scene": "res://scenes/GuidedDomino.tscn", "seats": 2},
	{"id": "BriscaOnline", "title": "Brisca · 2 jugadores", "scene": "res://scenes/Brisca.tscn", "seats": 2},
]

var players: Dictionary = {}  # player_id (Photon) -> display name
var local_name: String = ""
## Identificador único de sesión para Photon Cloud (evita colisiones cuando dos jugadores se llaman «Jugador»).
var session_user_id: String = ""

## Escena que la sala indica cuando se empieza la partida.
var start_scene: String = ""
var start_seats: int = 3

## Configuración y estado de la sala actual.
var room_title: String = ""
var room_game: String = ""
var room_seats: int = 3
var room_public: bool = true
var room_locked: bool = false
var room_salt: String = ""
var room_pw_hash: String = ""
var pending_join_password: String = ""
var _auth_sent_for_room: String = ""
var authenticated_peers: Dictionary = {}  # player_id -> bool (usado por el host si room_locked)

var room_bots: Array[bool] = [false, false, false, false]
var room_ready: Array[bool] = [false, false, false, false]
var room_started: bool = false
var room_code := ""
var room_listings: Array[Dictionary] = []
var singleplayer_room := false  # sala offline creada sin App ID (testing)


func _ready() -> void:
	if not is_available():
		return
	FusionBridge.sdk().register_broadcast_receiver(self)
	FusionBridge.sdk().room_joined.connect(_on_room_joined)
	FusionBridge.sdk().room_left.connect(_on_room_left)
	FusionBridge.sdk().room_list_updated.connect(_on_room_list_updated)
	FusionBridge.sdk().player_joined.connect(_on_player_joined)
	FusionBridge.sdk().player_left.connect(_on_player_left)
	FusionBridge.sdk().master_client_changed.connect(_on_master_changed)
	FusionBridge.sdk().connection_failed.connect(_on_connection_failed)
	FusionBridge.sdk().connected_to_photon.connect(_on_connected)
	FusionBridge.sdk().disconnected_from_photon.connect(_on_disconnected)


func _exit_tree() -> void:
	if is_available():
		FusionBridge.sdk().unregister_broadcast_receiver(self)


func is_available() -> bool:
	return FusionBridge.available()


func is_singleplayer() -> bool:
	return singleplayer_room


## Genera una vez por instancia un UserId único para Photon Cloud, separado del nombre visible.
func ensure_session_user_id() -> String:
	if session_user_id.is_empty():
		session_user_id = "u_%x_%s" % [OS.get_process_id(), generate_salt()]
	return session_user_id


func display_name() -> String:
	var clean := local_name.strip_edges()
	if not clean.is_empty():
		return clean
	return str(ProjectSettings.get_setting("net/user", "Jugador"))


func clean_peer_name(raw_name: String, player_id: int) -> String:
	var clean := raw_name.strip_edges()
	if clean.is_empty() or clean.begins_with("u_"):
		return "Jugador %d" % player_id
	return clean


## Arranca la sesión: con App ID se conecta a Photon Cloud; sin ella, sala offline.
func start_session(user_name: String) -> void:
	local_name = user_name.strip_edges()
	if not is_available():
		connection_failed.emit("El SDK Photon Fusion no está instalado. Instala el addon Fusion para Godot.")
		return
	var app_id := str(ProjectSettings.get_setting("net/app_id", ""))
	if app_id.is_empty():
		singleplayer_room = true
		FusionBridge.sdk().create_singleplayer_room()
		return
	if FusionBridge.sdk().is_connected_to_photon():
		connected.emit()
		return
	FusionBridge.sdk().set_app_id(app_id)
	FusionBridge.sdk().connect_to_photon.call_deferred(
		ensure_session_user_id(),
		str(ProjectSettings.get_setting("net/region", "eu"))
	)


func connect_or_retry() -> void:
	if not is_available():
		return
	if FusionBridge.sdk().is_connected_to_photon():
		refresh_room_list()
		return
	if local_name.is_empty():
		local_name = str(ProjectSettings.get_setting("net/user", "Jugador"))
	var app_id := str(ProjectSettings.get_setting("net/app_id", ""))
	if not app_id.is_empty():
		FusionBridge.sdk().set_app_id(app_id)
		FusionBridge.sdk().connect_to_photon.call_deferred(
			ensure_session_user_id(),
			str(ProjectSettings.get_setting("net/region", "eu"))
		)


## Refresca la caché local de salas públicas desde el cliente nativo de Fusion.
func refresh_room_list() -> void:
	if not is_available() or not FusionBridge.sdk().is_connected_to_photon():
		return
	var raw: Array = FusionBridge.sdk().get_room_list()
	_update_listings_from_raw(raw)


#region Seguridad de contraseña y filtrado de salas

func generate_salt() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hex := "0123456789abcdef"
	var out := ""
	for i in 16:
		out += hex[rng.randi_range(0, 15)]
	return out


func hash_password(password: String, salt: String) -> String:
	if password.is_empty():
		return ""
	return (salt + ":" + password).sha256_text()


func verify_password(password: String, salt: String, expected_hash: String) -> bool:
	if expected_hash.is_empty():
		return true
	if password.is_empty():
		return false
	return hash_password(password, salt) == expected_hash


func game_title_for(game_id: String) -> String:
	for entry in ONLINE_GAMES:
		if entry["id"] == game_id:
			return str(entry["title"])
	return game_id


## Convierte un FusionRoomListing nativo (o un Dictionary de test) a un diccionario uniforme.
func parse_room_listing(item: Variant) -> Dictionary:
	if item is Dictionary:
		var d: Dictionary = item
		var props_d: Dictionary = d.get("custom_properties", {})
		var code_d := str(d.get("code", d.get("name", "")))
		var seats_d := int(props_d.get("seats", d.get("max_players", 3)))
		var pw_hash_d := str(props_d.get("pw_hash", d.get("pw_hash", "")))
		return {
			"code": code_d,
			"title": str(props_d.get("title", d.get("title", "Sala " + code_d))),
			"host": str(props_d.get("host", d.get("host", ""))),
			"game": str(props_d.get("game", d.get("game", "Island"))),
			"seats": seats_d,
			"players": int(d.get("players", d.get("player_count", 1))),
			"max_players": int(d.get("max_players", seats_d)),
			"is_open": bool(d.get("is_open", true)),
			"started": bool(props_d.get("started", d.get("started", false))),
			"locked": bool(props_d.get("locked", not pw_hash_d.is_empty())),
			"salt": str(props_d.get("salt", d.get("salt", ""))),
			"pw_hash": pw_hash_d,
		}
	if item != null and item is Object and (item.has_method("get_name") or item.has_method("get_room_name")):
		var code := (
			str(item.call("get_name"))
			if item.has_method("get_name")
			else str(item.call("get_room_name"))
		)
		var props: Dictionary = (
			item.call("get_custom_properties")
			if item.has_method("get_custom_properties")
			else {}
		)
		var max_p := int(item.call("get_max_players")) if item.has_method("get_max_players") else 3
		var seats := int(props.get("seats", max_p if max_p > 0 else 3))
		var pw_hash := str(props.get("pw_hash", ""))
		var title := str(props.get("title", "")).strip_edges()
		if title.is_empty():
			title = "Sala %s" % code
		return {
			"code": code,
			"title": title,
			"host": str(props.get("host", "")),
			"game": str(props.get("game", "Island")),
			"seats": seats,
			"players": int(item.call("get_player_count")) if item.has_method("get_player_count") else 1,
			"max_players": max_p if max_p > 0 else seats,
			"is_open": bool(item.call("get_is_open")) if item.has_method("get_is_open") else true,
			"started": bool(props.get("started", false)),
			"locked": bool(props.get("locked", not pw_hash.is_empty())),
			"salt": str(props.get("salt", "")),
			"pw_hash": pw_hash,
		}
	return {}


## Filtra una lista de salas normalizadas según búsqueda, modo, huecos libres y contraseña.
func filter_rooms(
	rooms: Array,
	search: String = "",
	game_filter: String = "",
	only_open: bool = true,
	hide_locked: bool = false
) -> Array[Dictionary]:
	var needle := search.strip_edges().to_lower()
	var result: Array[Dictionary] = []
	for raw in rooms:
		var info: Dictionary = raw if (raw is Dictionary and raw.has("code")) else parse_room_listing(raw)
		if info.is_empty():
			continue
		var is_started := bool(info.get("started", false))
		var is_open := bool(info.get("is_open", true))
		var cur_players := int(info.get("players", 0))
		var max_players := int(info.get("max_players", 4))
		if only_open and (not is_open or is_started or cur_players >= max_players):
			continue
		if not game_filter.is_empty() and str(info.get("game", "")) != game_filter:
			continue
		if hide_locked and bool(info.get("locked", false)):
			continue
		if not needle.is_empty():
			var hay := "%s %s %s" % [
				str(info.get("title", "")).to_lower(),
				str(info.get("host", "")).to_lower(),
				str(info.get("code", "")).to_lower(),
			]
			if not hay.contains(needle):
				continue
		result.append(info)
	return result


func find_listed_room(code: String) -> Dictionary:
	var target := code.strip_edges().to_upper()
	for info in room_listings:
		if str(info.get("code", "")).to_upper() == target:
			return info
	return {}

#endregion

#region Creación, unión, «Listo», bots y expulsión

func _configure_lobby_properties(options: RefCounted) -> void:
	if options == null or not options.has_method("get_lobby_properties"):
		return
	var current: Variant = options.call("get_lobby_properties")
	if current is PackedStringArray:
		options.call("set_lobby_properties", PackedStringArray(LOBBY_PROP_KEYS))
	else:
		var typed: Array[String] = []
		for key in LOBBY_PROP_KEYS:
			typed.append(key)
		options.call("set_lobby_properties", typed)


## El anfitrión crea la sala (pública en el buscador o privada por código, y con contraseña opcional).
func create_room(
	game_id: String,
	seats: int,
	is_public: bool = true,
	custom_title: String = "",
	password: String = ""
) -> void:
	if not is_available():
		return
	if FusionBridge.sdk().is_in_room() or FusionBridge.sdk().get_connection_status() == FusionBridge.STATUS_JOINING_ROOM:
		return
	if not FusionBridge.sdk().is_connected_to_photon():
		return
	singleplayer_room = false
	room_game = game_id
	room_seats = clampi(seats, 2, SEATS_MAX)
	room_public = is_public
	var clean_title := custom_title.strip_edges()
	var host_label := display_name()
	room_title = clean_title if not clean_title.is_empty() else ("Mesa de %s" % host_label)
	var clean_pw := password.strip_edges()
	room_locked = not clean_pw.is_empty()
	room_salt = generate_salt() if room_locked else ""
	room_pw_hash = hash_password(clean_pw, room_salt) if room_locked else ""
	pending_join_password = ""
	_auth_sent_for_room = ""
	authenticated_peers.clear()
	reset_room_bots()
	reset_room_ready()
	room_started = false
	room_code = _room_code()

	var edition := get_node_or_null("/root/Edition")
	var is_demo := bool(edition.get("demo")) if edition != null else false
	var options: RefCounted = FusionBridge.room_options()
	options.max_players = room_seats
	options.is_visible = is_public
	options.is_open = true
	if options.has_method("set_player_ttl_ms"):
		options.call("set_player_ttl_ms", 60_000)
	options.custom_properties = {
		"title": room_title,
		"host": host_label,
		"game": game_id,
		"seats": room_seats,
		"started": false,
		"locked": room_locked,
		"salt": room_salt,
		"pw_hash": room_pw_hash,
		"host_edition": "demo" if is_demo else "full",
	}
	_configure_lobby_properties(options)
	FusionBridge.sdk().join_or_create_room(room_code, options)


## Un invitado entra con el código de la sala (o desde el buscador público).
func join_room(code: String, password: String = "") -> void:
	if not is_available() or not FusionBridge.sdk().is_connected_to_photon():
		return
	if FusionBridge.sdk().is_in_room() or FusionBridge.sdk().get_connection_status() == FusionBridge.STATUS_JOINING_ROOM:
		return
	singleplayer_room = false
	reset_room_bots()
	reset_room_ready()
	authenticated_peers.clear()
	room_started = false
	room_code = code.strip_edges().to_upper()
	pending_join_password = password.strip_edges()
	_auth_sent_for_room = ""
	var options: RefCounted = FusionBridge.room_options()
	FusionBridge.sdk().join_room(room_code, options)


func reset_room_bots() -> void:
	room_bots = [false, false, false, false]


func reset_room_ready() -> void:
	room_ready = [false, false, false, false]


func set_room_bot(seat: int, enabled: bool) -> void:
	if seat < 0 or seat >= room_bots.size():
		return
	if is_available() and FusionBridge.sdk().is_in_room() and not (is_host() or singleplayer_room):
		return
	room_bots[seat] = enabled
	if enabled and seat < room_ready.size():
		room_ready[seat] = true
	_broadcast_lobby_masks()
	room_info_received.emit()


func is_seat_ready(seat: int) -> bool:
	if seat < 0 or seat >= SEATS_MAX:
		return false
	if seat < room_bots.size() and room_bots[seat]:
		return true
	return seat < room_ready.size() and room_ready[seat]


func set_local_ready(ready_flag: bool) -> void:
	var seat := local_seat()
	if seat < 0 or seat >= room_ready.size():
		return
	if singleplayer_room or (is_available() and is_host()):
		room_ready[seat] = ready_flag
		_broadcast_lobby_masks()
		room_info_received.emit()
		return
	if is_available() and FusionBridge.sdk().is_in_room():
		room_ready[seat] = ready_flag
		FusionBridge.sdk().rpc_to(FusionBridge.TARGET_MASTER, _rpc_set_ready, ready_flag)
		room_info_received.emit()


## Todos los invitados humanos conectados deben haber marcado «Listo» (y estar autenticados si hay clave).
func are_all_guests_ready() -> bool:
	if singleplayer_room or not is_available() or not FusionBridge.sdk().is_in_room():
		return true
	var my_id := local_id()
	for pid_var in players:
		var pid := int(pid_var)
		if pid == my_id:
			continue
		var seat := pid - 1
		if seat < 0 or seat >= room_seats:
			continue
		if room_locked and not bool(authenticated_peers.get(pid, false)):
			return false
		if not is_seat_ready(seat):
			return false
	return true


func kick_player(player_id: int) -> void:
	if not is_available() or not FusionBridge.sdk().is_in_room() or not is_host():
		return
	if player_id == local_id():
		return
	FusionBridge.sdk().rpc_to_player(
		player_id,
		_rpc_kicked,
		"El anfitrión te ha retirado de la sala."
	)


func _bots_mask() -> int:
	var mask := 0
	for i in range(room_bots.size()):
		if room_bots[i]:
			mask |= (1 << i)
	return mask


func _apply_bots_mask(mask: int) -> void:
	for i in range(room_bots.size()):
		room_bots[i] = (mask & (1 << i)) != 0


func _ready_mask() -> int:
	var mask := 0
	for i in range(room_ready.size()):
		if room_ready[i]:
			mask |= (1 << i)
	return mask


func _apply_ready_mask(mask: int) -> void:
	for i in range(room_ready.size()):
		room_ready[i] = (mask & (1 << i)) != 0


func _broadcast_lobby_masks() -> void:
	if is_available() and FusionBridge.sdk().is_in_room() and not singleplayer_room and is_host():
		FusionBridge.sdk().rpc(_rpc_room_masks, _bots_mask(), _ready_mask())

#endregion

func is_host() -> bool:
	return is_available() and FusionBridge.sdk().is_master_client()


func local_id() -> int:
	return FusionBridge.sdk().get_local_player_id() if is_available() else 1


func local_seat() -> int:
	return local_id() - 1


func leave_room() -> void:
	if is_available() and FusionBridge.sdk().is_in_room():
		FusionBridge.sdk().leave_room()


## Cierra la conexión a Photon Cloud (evita chocar con Object.disconnect).
func disconnect_session() -> void:
	if is_available() and FusionBridge.sdk().is_connected_to_photon():
		FusionBridge.sdk().disconnect_from_photon()


## El anfitrión anuncia el inicio de la partida: cierra la sala pública y difunde el anuncio.
func start_game(scene: String, seats: int) -> void:
	start_scene = scene
	start_seats = seats
	room_started = true
	if is_available() and FusionBridge.sdk().is_in_room() and not singleplayer_room and is_host():
		var room: Variant = FusionBridge.sdk().get_room()
		if room != null and room is Object:
			if room.has_method("set_open"):
				room.call("set_open", false)
			if room.has_method("set_properties"):
				room.call("set_properties", {"started": true})
			elif room.has_method("set_property"):
				room.call("set_property", "started", true)
	start_announced.emit(scene, seats)


## Recibe el anuncio de inicio y prepara cargar la escena local.
func consume_start() -> bool:
	if start_scene.is_empty():
		return false
	start_seats = room_seats if room_seats > 0 else start_seats
	return true


## El invitado pregunta al anfitrión por el estado de la sala.
func request_room_info() -> void:
	if is_available() and FusionBridge.sdk().is_in_room():
		FusionBridge.sdk().rpc_to(FusionBridge.TARGET_MASTER, _rpc_room_info_request)


## El anfitrión envía la mesa, contraseña (salt) y máscaras a un invitado concreto.
func send_room_info_to(player_id: int) -> void:
	if is_host() and is_available() and FusionBridge.sdk().is_in_room():
		FusionBridge.sdk().rpc_to_player(
			player_id,
			_rpc_room_info,
			room_title,
			room_game,
			room_seats,
			room_started,
			start_scene,
			_bots_mask(),
			_ready_mask(),
			room_locked,
			room_salt
		)


func _sync_room_snapshot() -> void:
	if not is_available() or not FusionBridge.sdk().is_in_room():
		return
	var room: Variant = FusionBridge.sdk().get_room()
	if room == null or not (room is Object):
		return
	if room.has_method("get_room_name"):
		var rname := str(room.call("get_room_name"))
		if not rname.is_empty():
			room_code = rname
	if room.has_method("get_custom_properties"):
		var props: Dictionary = room.call("get_custom_properties")
		if props.has("title"):
			room_title = str(props["title"])
		if props.has("game"):
			room_game = str(props["game"])
		if props.has("seats"):
			room_seats = int(props["seats"])
		if props.has("locked"):
			room_locked = bool(props["locked"])
		if props.has("salt"):
			room_salt = str(props["salt"])
		if props.has("pw_hash"):
			room_pw_hash = str(props["pw_hash"])
		if props.has("host") and room.has_method("get_master_client_id"):
			var master_id := int(room.call("get_master_client_id"))
			var host_name := str(props["host"]).strip_edges()
			if master_id > 0 and not host_name.is_empty() and not players.has(master_id):
				players[master_id] = host_name
	if room.has_method("get_players"):
		var plist: Array = room.call("get_players")
		var my_id := local_id()
		for p in plist:
			if p != null and p is Object and p.has_method("get_number"):
				var pnum := int(p.call("get_number"))
				if pnum == my_id:
					players[pnum] = display_name()
					continue
				if players.has(pnum) and not str(players[pnum]).is_empty():
					continue
				var pname := str(p.call("get_name")) if p.has_method("get_name") else ""
				if pname.is_empty() and p.has_method("get_user_id"):
					pname = str(p.call("get_user_id"))
				players[pnum] = clean_peer_name(pname, pnum)


func _maybe_send_password_to_host() -> void:
	if singleplayer_room or not is_available() or not FusionBridge.sdk().is_in_room() or is_host():
		return
	if not room_locked or room_salt.is_empty():
		return
	if _auth_sent_for_room == room_code and not room_code.is_empty():
		return
	_auth_sent_for_room = room_code
	var candidate := hash_password(pending_join_password, room_salt)
	FusionBridge.sdk().rpc_to(FusionBridge.TARGET_MASTER, _rpc_submit_password, candidate)


#region RPCs

@rpc("any_peer", "call_remote")
func _rpc_hello(peer_name: String, reply: bool) -> void:
	var sender: int = FusionBridge.sdk().get_rpc_sender()
	if sender <= 0:
		return
	var cleaned := peer_name.strip_edges()
	if not cleaned.is_empty():
		players[sender] = cleaned
	if reply and sender != local_id() and is_available() and FusionBridge.sdk().is_in_room() and not singleplayer_room:
		FusionBridge.sdk().rpc_to_player(sender, _rpc_hello, display_name(), false)
	room_info_received.emit()


@rpc("any_peer", "call_remote")
func _rpc_room_info_request() -> void:
	if is_host():
		send_room_info_to(FusionBridge.sdk().get_rpc_sender())


@rpc("any_peer", "call_remote")
func _rpc_room_info(
	title: String,
	game: String,
	seats: int,
	started: bool,
	scene: String,
	bots_mask: int,
	ready_mask: int,
	locked: bool,
	salt: String
) -> void:
	room_title = title
	room_game = game
	room_seats = seats
	room_started = started
	start_scene = scene
	room_locked = locked
	room_salt = salt
	_apply_bots_mask(bots_mask)
	_apply_ready_mask(ready_mask)
	_maybe_send_password_to_host()
	room_info_received.emit()


@rpc("any_peer", "call_remote")
func _rpc_room_masks(bots_mask: int, ready_mask: int) -> void:
	if is_host():
		return
	_apply_bots_mask(bots_mask)
	_apply_ready_mask(ready_mask)
	room_info_received.emit()


@rpc("any_peer", "call_remote")
func _rpc_set_ready(ready_flag: bool) -> void:
	if not is_host():
		return
	var sender: int = FusionBridge.sdk().get_rpc_sender()
	if room_locked and not bool(authenticated_peers.get(sender, false)):
		return
	var seat := sender - 1
	if seat >= 0 and seat < room_ready.size():
		room_ready[seat] = ready_flag
		_broadcast_lobby_masks()
		room_info_received.emit()


@rpc("any_peer", "call_remote")
func _rpc_submit_password(candidate_hash: String) -> void:
	if not is_host():
		return
	var sender: int = FusionBridge.sdk().get_rpc_sender()
	if not room_locked or (not candidate_hash.is_empty() and candidate_hash == room_pw_hash):
		authenticated_peers[sender] = true
		room_info_received.emit()
		return
	authenticated_peers.erase(sender)
	FusionBridge.sdk().rpc_to_player(sender, _rpc_auth_failed, "Contraseña incorrecta para esta sala.")


@rpc("any_peer", "call_remote")
func _rpc_auth_failed(reason: String) -> void:
	pending_join_password = ""
	leave_room()
	auth_rejected.emit(reason)


@rpc("any_peer", "call_remote")
func _rpc_kicked(reason: String) -> void:
	leave_room()
	kicked.emit(reason)

#endregion

func _room_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 6:
		code += alphabet[randi() % alphabet.length()]
	return code


func _update_listings_from_raw(raw: Array) -> void:
	room_listings.clear()
	for entry in raw:
		var parsed := parse_room_listing(entry)
		if not parsed.is_empty():
			room_listings.append(parsed)
	room_list_changed.emit(room_listings)


func _on_room_list_updated(rooms: Array) -> void:
	_update_listings_from_raw(rooms)


func _on_room_joined() -> void:
	players[local_id()] = display_name()
	_sync_room_snapshot()
	if is_host() or singleplayer_room:
		var my_seat := local_seat()
		if my_seat >= 0 and my_seat < room_ready.size():
			room_ready[my_seat] = true
		authenticated_peers[local_id()] = true
	else:
		_maybe_send_password_to_host()
	if is_available() and FusionBridge.sdk().is_in_room() and not singleplayer_room:
		FusionBridge.sdk().rpc(_rpc_hello, display_name(), true)
	room_joined.emit()


func _on_room_left() -> void:
	singleplayer_room = false
	room_code = ""
	room_title = ""
	room_locked = false
	room_salt = ""
	room_pw_hash = ""
	_auth_sent_for_room = ""
	authenticated_peers.clear()
	players.clear()
	reset_room_bots()
	reset_room_ready()
	room_left.emit()


func _on_player_joined(player_id: int, user_id: String) -> void:
	_sync_room_snapshot()
	if not players.has(player_id) or str(players[player_id]).is_empty():
		players[player_id] = clean_peer_name(user_id, player_id)
	var seat := player_id - 1
	if seat >= 0 and seat < room_bots.size():
		room_bots[seat] = false
	if seat >= 0 and seat < room_ready.size() and player_id != local_id():
		room_ready[seat] = false
	if not room_locked:
		authenticated_peers[player_id] = true
	player_joined.emit(player_id, str(players.get(player_id, clean_peer_name(user_id, player_id))))


func _on_player_left(player_id: int, _is_inactive: bool) -> void:
	players.erase(player_id)
	authenticated_peers.erase(player_id)
	var seat := player_id - 1
	if seat >= 0 and seat < room_ready.size():
		room_ready[seat] = false
	player_left.emit(player_id)


func _on_master_changed(new_id: int, _old_id: int) -> void:
	var seat := new_id - 1
	if seat >= 0 and seat < room_ready.size():
		room_ready[seat] = true
	host_changed.emit(new_id)
	room_info_received.emit()


func _on_connection_failed(error: String) -> void:
	connection_failed.emit(error)


func _on_connected() -> void:
	refresh_room_list()
	connected.emit()


func _on_disconnected() -> void:
	room_listings.clear()
	room_list_changed.emit(room_listings)
	disconnected.emit()
