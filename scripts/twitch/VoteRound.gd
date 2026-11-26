class_name VoteRound
extends RefCounted
## Una votación del chat: opciones numeradas, un voto por persona (cuenta el último),
## tiempo límite y recuento en directo. Respeta la moderación: un mensaje borrado o un usuario
## limpiado por Twitch pierde su voto.

signal tally_changed()
signal closed(winner: int)

var options: Array[String] = []
var seconds := 20.0
var remaining := 20.0
var is_open := false
var winner := -1
## user_id → {option, order, message_id, name}
var votes := {}
## Últimos votantes, para enseñarlos bajo el panel («pixel_ana votó 2»).
var recent: Array[String] = []
## Peso de cada voto (opcional): recibe el voto {option, name…} y devuelve cuántos cuenta.
var weight_of := Callable()
var _order := 0
var _vote_re := RegEx.create_from_string("^!\\s*([1-9])\\b")


func _init(option_labels: Array[String], duration: float = 20.0) -> void:
	options = option_labels
	seconds = duration
	remaining = duration


func open() -> void:
	is_open = true


## Lee un mensaje del chat; devuelve true si contaba como voto.
func feed(message: Dictionary) -> bool:
	if not is_open:
		return false
	var match := _vote_re.search(str(message.get("text", "")).strip_edges().to_lower())
	if match == null:
		return false
	var option := int(match.get_string(1)) - 1
	if option < 0 or option >= options.size():
		return false
	var user := str(message.get("user_id", ""))
	if user.is_empty():
		return false
	_order += 1
	var first_order: int = (votes[user] as Dictionary)["order"] if votes.has(user) else _order
	votes[user] = {"option": option, "order": first_order, "last": _order, "message_id": str(message.get("id", "")), "name": str(message.get("name", ""))}
	recent.append(tr_voted(str(message.get("name", "")), option))
	if recent.size() > 6:
		recent.remove_at(0)
	tally_changed.emit()
	return true


static func tr_voted(name: String, option: int) -> String:
	return TranslationServer.translate("%s votó %d") % [name, option + 1]


## Moderación: quita el voto ligado a un mensaje borrado o a un usuario limpiado.
func moderate(message_id: String, user_id: String) -> void:
	var changed := false
	if message_id.is_empty() and user_id.is_empty():
		changed = not votes.is_empty()
		votes.clear()
	for user: Variant in votes.keys():
		var vote: Dictionary = votes[user]
		if (not user_id.is_empty() and str(user) == user_id) or (not message_id.is_empty() and str(vote["message_id"]) == message_id):
			votes.erase(user)
			changed = true
	if changed:
		tally_changed.emit()


func counts() -> Array[int]:
	var result: Array[int] = []
	result.resize(options.size())
	result.fill(0)
	for user: Variant in votes:
		var vote: Dictionary = votes[user]
		result[int(vote["option"])] += maxi(int(weight_of.call(vote)), 1) if weight_of.is_valid() else 1
	return result


## Votos contados (con su peso, si lo hay).
func total() -> int:
	var sum := 0
	for count in counts():
		sum += count
	return sum


## Opción que va ganando: más votos; en empate, la que recibió antes su primer voto.
func leader() -> int:
	var tally := counts()
	var best := -1
	var best_count := 0
	var best_first := 1 << 30
	var first_vote := {}
	for user: Variant in votes:
		var vote: Dictionary = votes[user]
		var option := int(vote["option"])
		first_vote[option] = mini(int(first_vote.get(option, 1 << 30)), int(vote["last"]))
	for i in tally.size():
		var first := int(first_vote.get(i, 1 << 30))
		if tally[i] > best_count or (tally[i] == best_count and tally[i] > 0 and first < best_first):
			best = i
			best_count = tally[i]
			best_first = first
	return best


## Avanza el reloj; cierra la votación al acabar el tiempo.
func tick(delta: float) -> void:
	if not is_open:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		close()


func close() -> void:
	if not is_open:
		return
	is_open = false
	winner = leader()
	closed.emit(winner)
