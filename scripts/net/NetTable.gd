extends Node
class_name NetTable
## Protocolo de mesa online: el anfitrión (master client) valida y difunde; los
## clientes reciben los cambios aplicados.
##
## Flujo:
## - submit(action): el jugador local pide aplicar una acción. En el anfitrión se
##   valida (fase, turno, identidad), se aplica localmente y se difunde el cambio;
##   en un cliente se pide al anfitrión por RPC.
## - rule_event(change): difusión del cambio ya aplicado. Todos los clientes lo
##   aplican por el mismo código que el replay del guardado.
## - sync_request/sync_state: reconexión y entrada tardía. El anfitrión responde con
##   el registro completo de eventos (export_record) y el cliente lo reemite.
## - Las acciones y los eventos comparten el mismo diccionario:
##   {"type": "settlement", "id": v} etc.

signal chat_received(sender_id: int, text: String)
signal sync_received()

## Intentos de resync antes de darse por vencido.
const SYNC_TRIES := 10
const SYNC_INTERVAL := 2.0

var _sync_tries := 0
var _sync_timer: Timer


func _enter_tree() -> void:
	if Engine.has_singleton("Fusion"):
		Fusion.register_broadcast_receiver(self)
	if not is_host():
		_sync_timer = Timer.new()
		_sync_timer.wait_time = SYNC_INTERVAL
		_sync_timer.one_shot = false
		_sync_timer.timeout.connect(_request_sync)
		add_child(_sync_timer)
		_request_sync()


func _exit_tree() -> void:
	if Engine.has_singleton("Fusion"):
		Fusion.unregister_broadcast_receiver(self)
	if _sync_timer != null:
		_sync_timer.stop()


func is_host() -> bool:
	return Engine.has_singleton("Fusion") and Fusion.is_master_client()


func _net() -> Node:
	return get_node_or_null("/root/Net")


func local_seat() -> int:
	var net := _net()
	return int(net.local_seat()) if net != null else -1


## El jugador local pide aplicar una acción. Devuelve true si se aceptó (en el
## anfitrión) o se envió (en un cliente). `acting_seat` es la butaca que actúa;
## por defecto la del jugador local.
func submit(action: Dictionary, acting_seat: int = -1) -> bool:
	if acting_seat < 0:
		acting_seat = local_seat()
	if is_host():
		if _allows(action, acting_seat):
			_host_apply(action, acting_seat)
			return true
		return false
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc_to(Fusion.TARGET_MASTER, req_action, action, acting_seat)
	return true


## El anfitrión aplica, difunde y avisa.
func _host_apply(action: Dictionary, _seat: int) -> void:
	if _apply(action) and _event_for(action) != null:
		if Engine.has_singleton("Fusion") and Fusion.is_in_room():
			Fusion.rpc(rule_event, _event_for(action))
		_on_applied(_event_for(action))


## Pide el registro completo al anfitrión (entrada tardía o reconexión).
func request_sync() -> void:
	_request_sync()


## Petición de sync de un cliente que se une o reconecta.
func _request_sync() -> void:
	if is_host():
		return
	if Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc_to(Fusion.TARGET_MASTER, sync_request)
	_sync_tries += 1
	if _sync_tries >= SYNC_TRIES and _sync_timer != null:
		_sync_timer.stop()


#region RPCs

@rpc("any_peer", "call_remote")
func req_action(action: Dictionary, acting_seat: int) -> void:
	if not is_host():
		return
	if _allows(action, acting_seat):
		_host_apply(action, acting_seat)


@rpc("any_peer", "call_remote")
func rule_event(change: Dictionary) -> void:
	# El host ya aplicó el cambio localmente en _host_apply; Fusion.rpc()
	# reenvía el broadcast al host también, así que se salta la aplicación.
	if is_host():
		return
	_apply_event(change)


@rpc("any_peer", "call_remote")
func sync_request() -> void:
	if is_host():
		Fusion.rpc_to_player(Fusion.get_rpc_sender(), sync_state, snapshot())


@rpc("any_peer", "call_remote")
func sync_state(record: Dictionary) -> void:
	_on_sync(record)


@rpc("any_peer", "call_remote")
func net_chat(sender_id: int, text: String) -> void:
	chat_received.emit(sender_id, text)


func send_chat(text: String) -> void:
	var net := _net()
	if net != null and Engine.has_singleton("Fusion") and Fusion.is_in_room():
		Fusion.rpc(net_chat, int(net.local_id()), text)


#endregion

## Hooks de la mesa concreta:
## - _allows(action, seat): valida fase, turno e identidad.
## - _apply(action): aplica reglas y escena (vista local).
## - _event_for(action): evento difundido (mismo diccionario normalizado).
## - _apply_event(change): aplica un evento recibido (replay).
## - _on_applied(change): hook del anfitrión tras aplicar.
## - _on_sync(record): resync completo (replay del registro).
## - snapshot(): registro completo del estado (export_record de la mesa).

func _allows(_action: Dictionary, _seat: int) -> bool:
	return false


func _apply(_action: Dictionary) -> bool:
	return false


func _event_for(action: Dictionary) -> Dictionary:
	return action


func _apply_event(_change: Dictionary) -> void:
	pass


func _on_applied(_change: Dictionary) -> void:
	pass


func _on_sync(_record: Dictionary) -> void:
	pass


func snapshot() -> Dictionary:
	return {}


## Aplica un cambio recibido como evento de forma idéntica al apply local.
func apply_change(change: Dictionary) -> bool:
	return _apply(change)
