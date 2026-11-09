extends Node
## Gestión de la sesión online: conexión a Photon Fusion y ciclo de vida de salas.
##
## El autoload «Net» expone conexión, salas y señales; las pantallas (Lobby) y
## las mesas online (NetTable) se subscriben. Sin App ID en los ajustes del
## proyecto (net/app_id), arranca en modo sala offline (create_singleplayer_room)
## para probar el protocolo sin cuenta de Photon.

signal connected()
signal connection_failed(error: String)
signal room_joined()
signal room_left()
signal player_joined(player_id: int, user_id: String)
signal player_left(player_id: int)
signal host_changed(new_id: int)
signal start_announced(scene: String, seats: int)
signal room_info_received()

## Butacas máximas de una sala.
const SEATS_MAX := 4

## Mesas disponibles para jugar online: identificador y escena.
const ONLINE_GAMES := [
	{"id": "Island", "title": "Isla de recursos · 3 jugadores", "scene": "res://scenes/Island.tscn", "seats": 3},
	{"id": "IslandFour", "title": "Isla de recursos · 4 jugadores", "scene": "res://scenes/IslandFour.tscn", "seats": 4},
]

var players: Dictionary = {}  # player_id (Photon) -> user_id
var local_name: String = ""

## Escena que la sala indica cuando se empieza la partida.
var start_scene: String = ""
var start_seats: int = 3

## Juego de la sala actual y butacas.
var room_game: String = ""
var room_seats: int = 3
var room_started: bool = false
var room_code := ""
var singleplayer_room := false  # sala offline creada sin App ID (testing)


func _ready() -> void:
	if not is_available():
		return
	Fusion.register_broadcast_receiver(self)
	Fusion.room_joined.connect(_on_room_joined)
	Fusion.room_left.connect(_on_room_left)
	Fusion.player_joined.connect(_on_player_joined)
	Fusion.player_left.connect(_on_player_left)
	Fusion.master_client_changed.connect(_on_master_changed)
	Fusion.connection_failed.connect(_on_connection_failed)
	Fusion.connected_to_photon.connect(_on_connected)


func is_available() -> bool:
	return Engine.has_singleton("Fusion")


func is_singleplayer() -> bool:
	return singleplayer_room


## Arranca la sesión: con App ID se conecta a Photon Cloud; sin ella, sala offline.
func start_session(user_name: String) -> void:
	local_name = user_name
	if not is_available():
		connection_failed.emit("El SDK Photon Fusion no está instalado. Instala el addon Fusion para Godot.")
		return
	var app_id := str(get_setting("net/app_id", ""))
	if app_id.is_empty():
		singleplayer_room = true
		Fusion.create_singleplayer_room()
		return
	Fusion.set_app_id(app_id)
	Fusion.connect_to_photon.call_deferred(user_name, str(get_setting("net/region", "eu")))


func connect_or_retry() -> void:
	if Fusion.is_connected_to_photon():
		return
	local_name = str(get_setting("net/user", "Jugador"))
	var app_id := str(get_setting("net/app_id", ""))
	if not app_id.is_empty():
		Fusion.connect_to_photon.call_deferred(local_name, str(get_setting("net/region", "eu")))


## El anfitrión crea la sala con un código. La demo solo puede entrar.
func create_room(game_id: String, seats: int) -> void:
	if not Fusion.is_in_room() and not Fusion.is_connected_to_photon():
		return
	singleplayer_room = false
	room_game = game_id
	room_seats = seats
	room_started = false
	room_code = _room_code()
	var options := FusionRoomOptions.new()
	options.max_players = SEATS_MAX
	options.is_visible = false  # se entra por código, no se lista en un lobby global
	options.is_open = true
	options.player_ttl_ms = 60_000
	options.custom_properties = {
		"game": game_id,
		"seats": seats,
		"host_edition": "demo" if Edition.demo else "full",
	}
	Fusion.create_room(room_code, options)


## Un invitado entra con el código de la sala.
func join_room(code: String) -> void:
	if not Fusion.is_connected_to_photon():
		return
	singleplayer_room = false
	room_started = false
	room_code = ""
	var options := FusionRoomOptions.new()
	options.max_players = SEATS_MAX
	Fusion.join_room(code, options)


func is_host() -> bool:
	return Fusion.is_master_client()


func local_id() -> int:
	return Fusion.get_local_player_id()


func local_seat() -> int:
	return Fusion.get_local_player_id() - 1


func leave_room() -> void:
	Fusion.leave_room()


func disconnect() -> void:
	if Fusion.is_connected_to_photon():
		Fusion.disconnect_from_photon()


## El anfitrión anuncia el inicio de la partida: el Lobby carga la escena
## localmente y difunde el anuncio a la sala (los clientes cambian de escena
## al recibirlo).
func start_game(scene: String, seats: int) -> void:
	start_scene = scene
	start_seats = seats
	room_started = true
	start_announced.emit(scene, seats)


## Recibe el anuncio de inicio y prepara cargar la escena local.
func consume_start() -> bool:
	if start_scene.is_empty():
		return false
	start_seats = room_seats if room_seats > 0 else start_seats
	return true


## El invitado pregunta al anfitrión por el estado de la sala (crea un aparato
## para que el Lobby se actualice aunque el anfitrión ya esté en partida).
func request_room_info() -> void:
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc_to(Fusion.TARGET_MASTER, _rpc_room_info_request)


## El anfitrión envía la mesa y el estado a un invitado concreto.
func send_room_info_to(player_id: int) -> void:
	if is_host() and Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc_to_player(
			player_id,
			_rpc_room_info,
			room_game,
			room_seats,
			room_started,
			start_scene
		)


@rpc("any_peer", "call_remote")
func _rpc_room_info_request() -> void:
	if is_host():
		Fusion.rpc_to_player(
			Fusion.get_rpc_sender(),
			_rpc_room_info,
			room_game,
			room_seats,
			room_started,
			start_scene
		)


@rpc("any_peer", "call_remote")
func _rpc_room_info(game: String, seats: int, started: bool, scene: String) -> void:
	room_game = game
	room_seats = seats
	room_started = started
	start_scene = scene
	room_info_received.emit()


func _room_code() -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 6:
		code += alphabet[randi() % alphabet.length()]
	return code


func _on_room_joined() -> void:
	room_joined.emit()


func _on_room_left() -> void:
	singleplayer_room = false
	room_code = ""
	room_left.emit()


func _on_player_joined(player_id: int, user_id: String) -> void:
	players[player_id] = user_id
	player_joined.emit(player_id, user_id)


func _on_player_left(player_id: int, _is_inactive: bool) -> void:
	players.erase(player_id)
	player_left.emit(player_id)


func _on_master_changed(new_id: int, _old_id: int) -> void:
	host_changed.emit(new_id)


func _on_connection_failed(error: String) -> void:
	connection_failed.emit(error)


func _on_connected() -> void:
	connected.emit()
