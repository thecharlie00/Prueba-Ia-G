extends Node
## Conexión con el chat de Twitch (autoload «Twitch»).
##
## - Autorización con el flujo de dispositivo: el juego pide un código, el streamer lo escribe en
##   twitch.tv/activate y el juego recibe un token. Sin contraseñas ni servidor propio.
## - Lectura del chat por EventSub en WebSocket (channel.chat.message), más los borrados y
##   limpiezas de mensajes para respetar la moderación del canal.
## - Chat simulado: espectadores de mentira que escriben y votan, para probar sin estar en
##   directo y para los tests.
##
## Todo lo demás (votaciones, asiento del chat, panel) escucha la señal `chat_message`.

signal state_changed(state: String)
signal chat_message(message: Dictionary)
## Twitch borró un mensaje (`message_id`) o todos los de un usuario (`user_id`). Con los dos
## vacíos, se limpió el chat entero.
signal moderation(message_id: String, user_id: String)
## Código para escribir en twitch.tv/activate mientras se espera la autorización.
signal device_code(user_code: String, uri: String)
## Evento del canal para los bloques de los juegos de la comunidad: «bits», «sub», «follow»,
## «raid», «canje», «hype» o «anuncio», con sus datos ya normalizados.
signal channel_event(kind: String, data: Dictionary)

enum { OFFLINE, WAITING_CODE, CONNECTING, CONNECTED, ERROR }
const STATE_NAMES := ["offline", "waiting_code", "connecting", "connected", "error"]

const CONFIG_PATH := "user://twitch.cfg"
const CLIENT_ID_SETTING := "tablerama/twitch/client_id"
const SCOPES := "user:read:chat"
const DEVICE_URL := "https://id.twitch.tv/oauth2/device"
const TOKEN_URL := "https://id.twitch.tv/oauth2/token"
const VALIDATE_URL := "https://id.twitch.tv/oauth2/validate"
const HELIX := "https://api.twitch.tv/helix"
const EVENTSUB_URL := "wss://eventsub.wss.twitch.tv/ws"
const SUBSCRIPTIONS := ["channel.chat.message", "channel.chat.message_delete", "channel.chat.clear_user_messages", "channel.chat.clear"]
## Eventos del canal: [tipo, versión, permiso necesario ("" si ninguno), campo de la condición].
const CHANNEL_SUBSCRIPTIONS := [
	["channel.cheer", "1", "bits:read", "broadcaster_user_id"],
	["channel.subscribe", "1", "channel:read:subscriptions", "broadcaster_user_id"],
	["channel.subscription.message", "1", "channel:read:subscriptions", "broadcaster_user_id"],
	["channel.subscription.gift", "1", "channel:read:subscriptions", "broadcaster_user_id"],
	["channel.follow", "2", "moderator:read:followers", "broadcaster_user_id"],
	["channel.raid", "1", "", "to_broadcaster_user_id"],
	["channel.channel_points_custom_reward_redemption.add", "1", "channel:manage:redemptions", "broadcaster_user_id"],
	["channel.hype_train.begin", "1", "channel:read:hype_train", "broadcaster_user_id"],
	["channel.hype_train.progress", "1", "channel:read:hype_train", "broadcaster_user_id"],
	["channel.hype_train.end", "1", "channel:read:hype_train", "broadcaster_user_id"],
	["channel.ad_break.begin", "1", "channel:read:ads", "broadcaster_user_id"],
]
## Permiso que pide cada evento o acción de los bloques.
const SCOPE_FOR := {
	"bits": "bits:read", "sub": "channel:read:subscriptions", "follow": "moderator:read:followers",
	"canje": "channel:manage:redemptions", "recompensa": "channel:manage:redemptions",
	"hype": "channel:read:hype_train", "anuncio": "channel:read:ads", "escribir": "user:write:chat",
}
## Un mensaje del juego en el chat cada 3 segundos como mucho.
const SEND_INTERVAL := 3.0
## Mensajes recordados para no procesar dos veces el mismo id.
const SEEN_LIMIT := 400

var state := OFFLINE
var login := ""
var user_id := ""
var last_error := ""
## Chat de mentira activo (se puede combinar con el real).
var simulated := false
## Opciones de la votación abierta, para que el chat simulado vote dentro de rango (0 = ninguna).
var simulated_vote_options := 0
## Segundos de cada votación del chat (ajuste del streamer).
var vote_seconds := 20
## Permisos extra que han pedido los juegos (se piden al volver a conectar).
var wanted_scopes: Array[String] = []
## Permisos que Twitch ha concedido de verdad.
var granted_scopes: Array[String] = []
## Palabras que el chat nunca enseña en pantalla (ajuste del streamer).
var blocked_words: Array[String] = []
## Los juegos de la comunidad pueden escribir en el chat (ajuste del streamer).
var allow_game_messages := false
## Cómo decide el chat en su turno: «democracia» (gana la más votada al acabar el tiempo) o
## «anarquía» (el primer voto válido juega al momento). Ajuste del streamer.
var decision_mode := "democracia"
## El chat de prueba del creador está abierto (cuenta como chat disponible).
var test_chat := false
## Quién puede votar en las votaciones del chat: todos, suscriptores, VIP o moderadores (ajuste del streamer).
var vote_who := "todos"
## Enseñar los nombres del chat en pantalla; si no, sale «Espectador» (ajuste del streamer).
var show_names := true
## Los juegos de la comunidad reciben bits, subs, raids, canjes… (ajuste del streamer).
var allow_community_events := true
## Los canjes se completan solos; un juego que decide completar o devolver lo apaga.
var auto_fulfill := true
## Recompensas de puntos de canal creadas en esta partida: título → id.
var rewards := {}
var _last_send := -1000.0

var _access_token := ""
var _refresh_token := ""
var _socket: WebSocketPeer
var _socket_url := EVENTSUB_URL
var _keepalive := 30.0
var _since_message := 0.0
var _session_id := ""
var _cancel_device := false
var _seen: Array[String] = []
var _sim_timer := 0.0
var _sim_rng := RandomNumberGenerator.new()
var _sim_count := 0

const SIM_NAMES := ["pixel_ana", "dado_loco", "la_ficha_roja", "turno_eterno", "mesa_redonda", "seis_doble", "torre_alta", "carta_brava", "ficha_veloz", "gato_tablero", "rey_del_cubilete", "nube_morada"]
const SIM_COLORS := ["#4d7cfe", "#e0484a", "#1f9e6e", "#c2410c", "#7c3aed", "#0e7490", "#db2777", "#ca8a04"]
const SIM_LINES := ["vamos chat!", "esa ficha está en peligro", "jajaja", "a por todas", "buena jugada", "nooo", "confiad en el chat", "GG", "el bot no tiene nada que hacer", "qué nervios"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sim_rng.randomize()
	_load()
	if not _access_token.is_empty() and has_client_id() and not _headless():
		connect_saved.call_deferred()


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func client_id() -> String:
	return str(ProjectSettings.get_setting(CLIENT_ID_SETTING, "")).strip_edges()


func has_client_id() -> bool:
	return not client_id().is_empty()


func is_connected_to_chat() -> bool:
	return state == CONNECTED


## Hay algún chat del que pueden llegar votos (real, simulado o el chat de prueba del creador).
func is_available() -> bool:
	return state == CONNECTED or simulated or test_chat


func state_name() -> String:
	return STATE_NAMES[state]


func _set_state(value: int, error := "") -> void:
	state = value
	last_error = error
	state_changed.emit(STATE_NAMES[value])


# --- Ajustes guardados ------------------------------------------------------------

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	_access_token = str(config.get_value("auth", "access_token", ""))
	_refresh_token = str(config.get_value("auth", "refresh_token", ""))
	login = str(config.get_value("auth", "login", ""))
	user_id = str(config.get_value("auth", "user_id", ""))
	simulated = bool(config.get_value("chat", "simulated", false))
	vote_seconds = clampi(int(config.get_value("chat", "vote_seconds", 20)), 10, 60)
	wanted_scopes.assign(config.get_value("auth", "extra_scopes", []))
	blocked_words.assign(config.get_value("chat", "blocked_words", []))
	allow_game_messages = bool(config.get_value("chat", "allow_game_messages", false))
	vote_who = str(config.get_value("chat", "vote_who", "todos"))
	decision_mode = str(config.get_value("chat", "decision_mode", "democracia"))
	show_names = bool(config.get_value("chat", "show_names", true))
	allow_community_events = bool(config.get_value("chat", "allow_community_events", true))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("auth", "access_token", _access_token)
	config.set_value("auth", "refresh_token", _refresh_token)
	config.set_value("auth", "login", login)
	config.set_value("auth", "user_id", user_id)
	config.set_value("chat", "simulated", simulated)
	config.set_value("chat", "vote_seconds", vote_seconds)
	config.set_value("auth", "extra_scopes", wanted_scopes)
	config.set_value("chat", "blocked_words", blocked_words)
	config.set_value("chat", "allow_game_messages", allow_game_messages)
	config.set_value("chat", "vote_who", vote_who)
	config.set_value("chat", "decision_mode", decision_mode)
	config.set_value("chat", "show_names", show_names)
	config.set_value("chat", "allow_community_events", allow_community_events)
	config.save(CONFIG_PATH)


func set_simulated(enabled: bool, persist := true) -> void:
	simulated = enabled
	_sim_timer = 0.0
	if persist:
		save()
	state_changed.emit(STATE_NAMES[state])


func set_vote_seconds(seconds: int) -> void:
	vote_seconds = clampi(seconds, 10, 60)
	save()


# --- Autorización -----------------------------------------------------------------

## Empieza la conexión: pide un código de dispositivo y espera a que el streamer lo acepte.
func connect_account() -> void:
	if not has_client_id():
		_set_state(ERROR, "Falta el Client ID de Twitch en los ajustes del proyecto.")
		return
	if state == WAITING_CODE or state == CONNECTING:
		return
	_cancel_device = false
	_set_state(WAITING_CODE)
	var response := await _post_form(DEVICE_URL, {"client_id": client_id(), "scopes": _scope_string()})
	if response["code"] != 200:
		_set_state(ERROR, "Twitch no ha dado un código. Inténtalo de nuevo.")
		return
	var body: Dictionary = response["json"]
	var device_code_value := str(body.get("device_code", ""))
	var user_code := str(body.get("user_code", ""))
	var uri := str(body.get("verification_uri", "https://www.twitch.tv/activate"))
	var interval := maxf(float(body.get("interval", 5)), 1.0)
	var expires := float(body.get("expires_in", 1800))
	device_code.emit(user_code, uri)
	OS.shell_open(uri)
	var waited := 0.0
	while waited < expires and not _cancel_device:
		await get_tree().create_timer(interval).timeout
		waited += interval
		if _cancel_device:
			break
		var token := await _post_form(TOKEN_URL, {
			"client_id": client_id(), "scopes": _scope_string(), "device_code": device_code_value,
			"grant_type": "urn:ietf:params:oauth:grant-type:device_code",
		})
		if token["code"] == 200:
			_store_tokens(token["json"])
			await _validate_and_listen()
			return
		var message := str((token["json"] as Dictionary).get("message", ""))
		if message == "slow_down":
			interval += 2.0
		elif message != "authorization_pending":
			_set_state(ERROR, "Twitch no ha aceptado la conexión.")
			return
	if _cancel_device:
		_set_state(OFFLINE)
	else:
		_set_state(ERROR, "El código ha caducado. Vuelve a conectar.")


func cancel_connect() -> void:
	_cancel_device = true


## Reconecta con el token guardado (al arrancar el juego).
func connect_saved() -> void:
	if _access_token.is_empty() or state == CONNECTING or state == CONNECTED:
		return
	_set_state(CONNECTING)
	await _validate_and_listen()


func disconnect_account() -> void:
	if not _access_token.is_empty() and has_client_id():
		_post_form("https://id.twitch.tv/oauth2/revoke", {"client_id": client_id(), "token": _access_token})
	_close_socket()
	_access_token = ""
	_refresh_token = ""
	login = ""
	user_id = ""
	save()
	_set_state(OFFLINE)


func _store_tokens(body: Dictionary) -> void:
	_access_token = str(body.get("access_token", ""))
	var refresh := str(body.get("refresh_token", ""))
	if not refresh.is_empty():
		_refresh_token = refresh
	save()


func _refresh() -> bool:
	if _refresh_token.is_empty():
		return false
	var response := await _post_form(TOKEN_URL, {
		"client_id": client_id(), "grant_type": "refresh_token", "refresh_token": _refresh_token,
	})
	if response["code"] != 200:
		return false
	_store_tokens(response["json"])
	return true


func _validate_and_listen() -> void:
	_set_state(CONNECTING)
	var check := await _request(VALIDATE_URL, PackedStringArray(["Authorization: OAuth " + _access_token]))
	if check["code"] == 401 and await _refresh():
		check = await _request(VALIDATE_URL, PackedStringArray(["Authorization: OAuth " + _access_token]))
	if check["code"] != 200:
		_access_token = ""
		save()
		_set_state(ERROR, "La conexión con Twitch ha caducado. Vuelve a conectar.")
		return
	var body: Dictionary = check["json"]
	granted_scopes.assign(body.get("scopes", []))
	login = str(body.get("login", login))
	user_id = str(body.get("user_id", user_id))
	save()
	_open_socket(EVENTSUB_URL)


# --- EventSub ---------------------------------------------------------------------

func _open_socket(url: String) -> void:
	_close_socket()
	_socket = WebSocketPeer.new()
	_socket_url = url
	_since_message = 0.0
	if _socket.connect_to_url(url) != OK:
		_set_state(ERROR, "No se puede abrir la conexión con Twitch.")
		_socket = null


func _close_socket() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_session_id = ""


func _process(delta: float) -> void:
	_poll_socket(delta)
	_tick_simulation(delta)


func _poll_socket(delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var socket_state := _socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_OPEN:
		_since_message += delta
		while _socket.get_available_packet_count() > 0:
			_since_message = 0.0
			handle_eventsub(_socket.get_packet().get_string_from_utf8())
		if _since_message > _keepalive + 10.0:
			_reconnect_later()
	elif socket_state == WebSocketPeer.STATE_CLOSED:
		_socket = null
		if state == CONNECTED or state == CONNECTING:
			_reconnect_later()


func _reconnect_later() -> void:
	_close_socket()
	_set_state(CONNECTING)
	await get_tree().create_timer(3.0).timeout
	if state == CONNECTING and _socket == null and not _access_token.is_empty():
		_validate_and_listen()


## Procesa un mensaje de EventSub (público para los tests).
func handle_eventsub(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var metadata: Dictionary = data.get("metadata", {})
	var payload: Dictionary = data.get("payload", {})
	match str(metadata.get("message_type", "")):
		"session_welcome":
			var session: Dictionary = payload.get("session", {})
			_session_id = str(session.get("id", ""))
			_keepalive = float(session.get("keepalive_timeout_seconds", 30))
			if _socket_url == EVENTSUB_URL:
				_subscribe_all()
			else:
				_set_state(CONNECTED)
		"session_reconnect":
			var next: Dictionary = payload.get("session", {})
			var url := str(next.get("reconnect_url", ""))
			if not url.is_empty():
				_open_socket(url)
		"notification":
			var subscription: Dictionary = payload.get("subscription", {})
			_handle_event(str(subscription.get("type", "")), payload.get("event", {}))
		"revocation":
			_set_state(ERROR, "Twitch ha retirado el permiso de leer el chat. Vuelve a conectar.")


func _subscribe_all() -> void:
	var ok := true
	for type in SUBSCRIPTIONS:
		var body := {
			"type": type, "version": "1",
			"condition": {"broadcaster_user_id": user_id, "user_id": user_id},
			"transport": {"method": "websocket", "session_id": _session_id},
		}
		var response := await _request(HELIX + "/eventsub/subscriptions", _helix_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
		if response["code"] != 202 and type == "channel.chat.message":
			ok = false
	for entry: Array in CHANNEL_SUBSCRIPTIONS:
		var scope := str(entry[2])
		if not scope.is_empty() and scope not in granted_scopes:
			continue
		var condition := {str(entry[3]): user_id}
		if str(entry[0]) == "channel.follow":
			condition["moderator_user_id"] = user_id
		var body := {"type": entry[0], "version": entry[1], "condition": condition, "transport": {"method": "websocket", "session_id": _session_id}}
		await _request(HELIX + "/eventsub/subscriptions", _helix_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if ok:
		_set_state(CONNECTED)
	else:
		_set_state(ERROR, "Twitch no ha dejado leer el chat.")


func _helix_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + _access_token, "Client-Id: " + client_id(), "Content-Type: application/json"])


func _handle_event(type: String, event: Dictionary) -> void:
	match type:
		"channel.chat.message":
			var message := normalize_message(event)
			if not message.is_empty():
				_deliver(message)
		"channel.chat.message_delete":
			moderation.emit(str(event.get("message_id", "")), "")
		"channel.chat.clear_user_messages":
			moderation.emit("", str(event.get("target_user_id", "")))
		"channel.chat.clear":
			moderation.emit("", "")
		_:
			var normalized := normalize_channel_event(type, event)
			if not normalized.is_empty():
				channel_event.emit(str(normalized["kind"]), normalized)
				if str(normalized["kind"]) == "canje" and auto_fulfill:
					_fulfill(str(event.get("id", "")), str((event.get("reward", {}) as Dictionary).get("id", "")))


## Convierte el evento de Twitch en un mensaje del juego.
static func normalize_message(event: Dictionary) -> Dictionary:
	var body: Dictionary = event.get("message", {})
	var text := str(body.get("text", "")).strip_edges()
	var id := str(event.get("message_id", ""))
	if text.is_empty() or id.is_empty():
		return {}
	var badges: Array[String] = []
	for badge: Variant in event.get("badges", []):
		if badge is Dictionary:
			badges.append(str((badge as Dictionary).get("set_id", "")))
	var emotes: Array[Dictionary] = []
	for fragment: Variant in body.get("fragments", []):
		if fragment is Dictionary and str((fragment as Dictionary).get("type", "")) == "emote":
			var emote: Dictionary = (fragment as Dictionary).get("emote", {})
			emotes.append({"id": str(emote.get("id", "")), "code": str((fragment as Dictionary).get("text", ""))})
	var color := str(event.get("color", ""))
	return {
		"id": id,
		"user_id": str(event.get("chatter_user_id", "")),
		"login": str(event.get("chatter_user_login", "")),
		"name": str(event.get("chatter_user_name", "")),
		"color": color if not color.is_empty() else "#a78bff",
		"badges": badges,
		"text": text,
		"emotes": emotes,
		"simulated": false,
	}


## Convierte un evento del canal en datos para los bloques ({} si no es de los que se usan).
static func normalize_channel_event(type: String, event: Dictionary) -> Dictionary:
	var user := str(event.get("user_name", "")) if event.get("user_name") != null else ""
	match type:
		"channel.cheer":
			return {"kind": "bits", "usuario": user if not user.is_empty() else "Anónimo", "cantidad": int(event.get("bits", 0))}
		"channel.subscribe":
			if bool(event.get("is_gift", false)):
				return {}
			return {"kind": "sub", "usuario": user, "meses": 1, "regalo": false}
		"channel.subscription.message":
			return {"kind": "sub", "usuario": user, "meses": int(event.get("cumulative_months", 1)), "regalo": false}
		"channel.subscription.gift":
			return {"kind": "sub", "usuario": user if not user.is_empty() else "Anónimo", "meses": int(event.get("total", 1)), "regalo": true}
		"channel.follow":
			return {"kind": "follow", "usuario": user}
		"channel.raid":
			return {"kind": "raid", "canal": str(event.get("from_broadcaster_user_name", "")), "espectadores": int(event.get("viewers", 0))}
		"channel.channel_points_custom_reward_redemption.add":
			var reward: Dictionary = event.get("reward", {})
			return {"kind": "canje", "usuario": user, "recompensa": str(reward.get("title", "")), "id": str(event.get("id", "")), "reward_id": str(reward.get("id", ""))}
		"channel.hype_train.begin":
			return {"kind": "hype", "fase": "empieza", "nivel": int(event.get("level", 1))}
		"channel.hype_train.progress":
			return {"kind": "hype", "fase": "sube de nivel", "nivel": int(event.get("level", 1))}
		"channel.hype_train.end":
			return {"kind": "hype", "fase": "termina", "nivel": int(event.get("level", 1))}
		"channel.ad_break.begin":
			return {"kind": "anuncio", "segundos": int(event.get("duration_seconds", 0))}
	return {}


## Permisos que faltan para estos usos («bits», «canje»…). Los apunta para la próxima conexión.
func request_scopes(uses: Array) -> Array[String]:
	var missing: Array[String] = []
	for use: Variant in uses:
		var scope := str(SCOPE_FOR.get(str(use), ""))
		if scope.is_empty():
			continue
		if scope not in wanted_scopes:
			wanted_scopes.append(scope)
		if state == CONNECTED and scope not in granted_scopes and scope not in missing:
			missing.append(scope)
	save()
	return missing


func _scope_string() -> String:
	var scopes: Array[String] = [SCOPES]
	for scope in wanted_scopes:
		if scope not in scopes:
			scopes.append(scope)
	return " ".join(scopes)


## ¿Lo enseñaría el chat en pantalla? (filtro de palabras del streamer)
func is_blocked(text: String) -> bool:
	var lower := text.to_lower()
	for word in blocked_words:
		if not word.is_empty() and lower.contains(word.to_lower()):
			return true
	return false


## Evento del canal de mentira (chat de prueba y tests).
func inject_event(kind: String, data: Dictionary) -> void:
	var event := data.duplicate()
	event["kind"] = kind
	event["simulated"] = true
	channel_event.emit(kind, event)


## Crea una recompensa de puntos de canal para esta partida (solo canales Afiliados o Partners).
func create_reward(title: String, cost: int) -> bool:
	if rewards.has(title):
		return true
	if state != CONNECTED or "channel:manage:redemptions" not in granted_scopes:
		rewards[title] = ""
		return false
	var body := {"title": title.left(45), "cost": maxi(cost, 1), "is_enabled": true}
	var response := await _request(HELIX + "/channel_points/custom_rewards?broadcaster_id=" + user_id, _helix_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	if response["code"] != 200:
		return false
	var data: Array = (response["json"] as Dictionary).get("data", [])
	rewards[title] = str((data[0] as Dictionary).get("id", "")) if not data.is_empty() else ""
	return true


## Pausa o reanuda una recompensa creada por la partida.
func pause_reward(title: String, paused: bool) -> void:
	var id := str(rewards.get(title, ""))
	if id.is_empty() or state != CONNECTED:
		return
	_request(HELIX + "/channel_points/custom_rewards?broadcaster_id=%s&id=%s" % [user_id, id], _helix_headers(), HTTPClient.METHOD_PATCH, JSON.stringify({"is_paused": paused}))


## Borra las recompensas creadas por la partida (al terminar de jugar).
func clear_rewards() -> void:
	for title: Variant in rewards.keys():
		var id := str(rewards[title])
		if not id.is_empty() and state == CONNECTED:
			_request(HELIX + "/channel_points/custom_rewards?broadcaster_id=%s&id=%s" % [user_id, id], _helix_headers(), HTTPClient.METHOD_DELETE)
	rewards.clear()


func _fulfill(redemption_id: String, reward_id: String, refund := false) -> void:
	if redemption_id.is_empty() or reward_id.is_empty() or reward_id not in rewards.values() or state != CONNECTED:
		return
	var url := HELIX + "/channel_points/custom_rewards/redemptions?broadcaster_id=%s&reward_id=%s&id=%s" % [user_id, reward_id, redemption_id]
	_request(url, _helix_headers(), HTTPClient.METHOD_PATCH, JSON.stringify({"status": "CANCELED" if refund else "FULFILLED"}))


## Completa o devuelve un canje. `token` es «id|reward_id», como lo da el bloque «Al canjear».
func resolve_redemption(token: String, refund: bool) -> void:
	var parts := token.split("|")
	if parts.size() == 2:
		_fulfill(parts[0], parts[1], refund)


## Quién puede votar según los ajustes del streamer.
func can_vote(badges: Array) -> bool:
	match vote_who:
		"suscriptores":
			return "subscriber" in badges or "founder" in badges or "broadcaster" in badges
		"VIP":
			return "vip" in badges or "subscriber" in badges or "founder" in badges or "moderator" in badges or "broadcaster" in badges
		"moderadores":
			return "moderator" in badges or "broadcaster" in badges
	return true


## Nombre que se enseña en pantalla (o «Espectador» si el streamer lo oculta).
func display_name(name: String) -> String:
	return name if show_names else tr("Espectador")


## Escribe en el chat del canal (si el streamer lo permite). Un mensaje cada 3 s como mucho.
func send_chat(text: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if not allow_game_messages or text.strip_edges().is_empty() or now - _last_send < SEND_INTERVAL:
		return false
	_last_send = now
	if simulated and state != CONNECTED:
		inject("Tablerama", text.left(300), ["broadcaster"])
		return true
	if state != CONNECTED or "user:write:chat" not in granted_scopes:
		return false
	var body := {"broadcaster_id": user_id, "sender_id": user_id, "message": text.left(500)}
	_request(HELIX + "/chat/messages", _helix_headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
	return true


func _deliver(message: Dictionary) -> void:
	var id := str(message.get("id", ""))
	if id in _seen:
		return
	_seen.append(id)
	if _seen.size() > SEEN_LIMIT:
		_seen = _seen.slice(_seen.size() - SEEN_LIMIT)
	chat_message.emit(message)


# --- Chat simulado ----------------------------------------------------------------

## Mete un mensaje como si viniera del chat (chat simulado y tests).
## Emotes globales de Twitch que el chat de prueba reconoce en el texto (código → id).
const SIM_EMOTES := {"Kappa": "25", "<3": "9", "LUL": "425618", "PogChamp": "305954156", "HeyGuys": "30259", "BibleThump": "86"}


static func sim_emotes(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for word in text.split(" ", false):
		if SIM_EMOTES.has(word):
			result.append({"id": str(SIM_EMOTES[word]), "code": word})
	return result


func inject(name: String, text: String, badges: Array[String] = []) -> Dictionary:
	_sim_count += 1
	var message := {
		"id": "sim-%d" % _sim_count,
		"user_id": "sim-" + name,
		"login": name.to_lower(),
		"name": name,
		"color": SIM_COLORS[absi(name.hash()) % SIM_COLORS.size()],
		"badges": badges,
		"text": text,
		"emotes": sim_emotes(text),
		"simulated": true,
	}
	_deliver(message)
	return message


func _tick_simulation(delta: float) -> void:
	if not simulated:
		return
	_sim_timer -= delta
	if _sim_timer > 0.0:
		return
	var voting := simulated_vote_options > 0
	_sim_timer = _sim_rng.randf_range(0.35, 1.1) if voting else _sim_rng.randf_range(1.5, 4.0)
	var name: String = SIM_NAMES[_sim_rng.randi() % SIM_NAMES.size()]
	var badges: Array[String] = []
	if _sim_rng.randf() < 0.3:
		badges.append("subscriber")
	if voting and _sim_rng.randf() < 0.8:
		# Votos con algo de preferencia, para que la votación tenga emoción.
		var pick := 1 + mini(int(_sim_rng.randfn(0.0, 1.2) ** 2), simulated_vote_options - 1)
		inject(name, "!%d" % pick, badges)
	else:
		inject(name, SIM_LINES[_sim_rng.randi() % SIM_LINES.size()], badges)


# --- HTTP -------------------------------------------------------------------------

func _post_form(url: String, fields: Dictionary) -> Dictionary:
	var parts: PackedStringArray = []
	for key: Variant in fields:
		parts.append("%s=%s" % [str(key).uri_encode(), str(fields[key]).uri_encode()])
	return await _request(url, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), HTTPClient.METHOD_POST, "&".join(parts))


func _request(url: String, headers: PackedStringArray, method := HTTPClient.METHOD_GET, body := "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return {"code": 0, "json": {}}
	var result: Array = await http.request_completed
	http.queue_free()
	var code := int(result[1])
	var raw: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return {"code": code, "json": parsed if parsed is Dictionary else {}}


# --- Fila de ajustes --------------------------------------------------------------

## Fila «Twitch» de los ajustes: estado, botón Conectar/Desconectar y chat simulado.
func make_settings_row(label_color: Color) -> Control:
	var box := VBoxContainer.new()
	box.name = "TwitchRow"
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var title := Label.new()
	title.text = "Twitch"
	title.add_theme_color_override("font_color", label_color)
	row.add_child(title)
	var status := Label.new()
	status.name = "TwitchStatus"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", label_color)
	row.add_child(status)
	var button := Button.new()
	button.name = "TwitchConnect"
	row.add_child(button)
	var sim := CheckBox.new()
	sim.name = "TwitchSimulated"
	sim.text = "Chat simulado para probar"
	sim.tooltip_text = "Espectadores de mentira escriben y votan, sin estar en directo"
	sim.button_pressed = simulated
	sim.add_theme_color_override("font_color", label_color)
	sim.toggled.connect(func(on: bool) -> void: set_simulated(on))
	box.add_child(sim)
	var options := Button.new()
	options.name = "TwitchLiveOptions"
	options.text = "Opciones del directo…"
	options.pressed.connect(func() -> void: open_live_options(box))
	box.add_child(options)
	var code := {"text": ""}
	var refresh := func() -> void:
		match state:
			CONNECTED:
				status.text = tr("Conectado como %s") % login
				button.text = tr("Desconectar")
			WAITING_CODE:
				status.text = tr("Escribe %s en twitch.tv/activate") % code["text"] if not str(code["text"]).is_empty() else tr("Pidiendo código a Twitch…")
				button.text = tr("Cancelar")
			CONNECTING:
				status.text = tr("Conectando…")
				button.text = tr("Desconectar")
			ERROR:
				status.text = tr(last_error)
				button.text = tr("Conectar")
			_:
				status.text = tr("Sin conectar") if has_client_id() else tr("Falta el Client ID de Twitch")
				button.text = tr("Conectar")
		button.disabled = not has_client_id()
	button.pressed.connect(func() -> void:
		match state:
			CONNECTED, CONNECTING:
				disconnect_account()
			WAITING_CODE:
				cancel_connect()
			_:
				connect_account()
	)
	var on_code := func(user_code: String, _uri: String) -> void:
		code["text"] = user_code
		refresh.call()
	var on_state := refresh.unbind(1)
	state_changed.connect(on_state)
	device_code.connect(on_code)
	box.tree_exiting.connect(func() -> void:
		if state_changed.is_connected(on_state):
			state_changed.disconnect(on_state)
		if device_code.is_connected(on_code):
			device_code.disconnect(on_code)
	)
	refresh.call()
	return box


# --- Opciones del directo ----------------------------------------------------------

const VOTE_TIMES := [10, 15, 20, 30, 45, 60]
const VOTE_WHO := ["todos", "suscriptores", "VIP", "moderadores"]
const DECISION_MODES := ["democracia", "anarquía"]


## Ventana con los ajustes del directo: votaciones, nombres, filtro de palabras y qué
## pueden hacer los juegos de la comunidad con el canal.
func open_live_options(from: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "TwitchLiveOptionsLayer"
	layer.layer = 90
	from.get_tree().root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "LiveOptions"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.set_corner_radius_all(18)
	style.set_border_width_all(4)
	style.border_color = Palette.INK
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Opciones del directo"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Palette.LAVENDER)
	column.add_child(title)
	var add_row := func(text: String, control: Control) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Palette.PAPER)
		row.add_child(label)
		control.custom_minimum_size.x = 200
		row.add_child(control)
		column.add_child(row)
	var seconds := OptionButton.new()
	seconds.name = "VoteSeconds"
	for value: int in VOTE_TIMES:
		seconds.add_item("%d s" % value)
		if value == vote_seconds:
			seconds.select(seconds.item_count - 1)
	seconds.item_selected.connect(func(i: int) -> void: set_vote_seconds(VOTE_TIMES[i]))
	add_row.call("Tiempo de votación", seconds)
	var who := OptionButton.new()
	who.name = "VoteWho"
	for value: String in VOTE_WHO:
		who.add_item(value)
		if value == vote_who:
			who.select(who.item_count - 1)
	who.item_selected.connect(func(i: int) -> void:
		vote_who = VOTE_WHO[i]
		save()
	)
	add_row.call("Quién puede votar", who)
	var mode := OptionButton.new()
	mode.name = "DecisionMode"
	for value: String in DECISION_MODES:
		mode.add_item(value)
		if value == decision_mode:
			mode.select(mode.item_count - 1)
	mode.tooltip_text = "Democracia: gana la jugada más votada. Anarquía: el primer voto juega al momento."
	mode.item_selected.connect(func(i: int) -> void:
		decision_mode = DECISION_MODES[i]
		save()
	)
	add_row.call("Cómo decide el chat", mode)
	var words := LineEdit.new()
	words.name = "BlockedWords"
	words.text = ", ".join(blocked_words)
	words.placeholder_text = "palabra, otra palabra"
	words.text_changed.connect(func(text: String) -> void:
		var list: Array[String] = []
		for word in text.split(",", false):
			if not word.strip_edges().is_empty():
				list.append(word.strip_edges())
		blocked_words = list
		save()
	)
	add_row.call("Palabras que nunca salen en pantalla", words)
	var checks := [
		["ShowNames", "Enseñar los nombres del chat en pantalla", show_names, func(on: bool) -> void: show_names = on],
		["AllowEvents", "Los juegos de la comunidad reciben bits, subs, raids y canjes", allow_community_events, func(on: bool) -> void: allow_community_events = on],
		["AllowMessages", "Los juegos de la comunidad pueden escribir en mi chat", allow_game_messages, func(on: bool) -> void: allow_game_messages = on],
	]
	for entry: Array in checks:
		var check := CheckBox.new()
		check.name = str(entry[0])
		check.text = str(entry[1])
		check.button_pressed = bool(entry[2])
		check.add_theme_color_override("font_color", Palette.PAPER)
		var setter: Callable = entry[3]
		check.toggled.connect(func(on: bool) -> void:
			setter.call(on)
			save()
		)
		column.add_child(check)
	var close := Button.new()
	close.name = "Close"
	close.text = "Listo"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(layer.queue_free)
	column.add_child(close)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			layer.queue_free()
	)
	close.grab_focus.call_deferred()
	return layer
