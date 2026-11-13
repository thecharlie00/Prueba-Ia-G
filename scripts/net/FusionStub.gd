class_name FusionStub
extends RefCounted
## Sustituto inerte del singleton Photon Fusion cuando el SDK no está instalado.
## Expone las mismas señales y métodos que usa el juego; nada se conecta nunca.

signal connected_to_photon
signal disconnected_from_photon
signal connection_failed(message: String)
signal room_joined
signal room_left
signal room_list_updated
signal player_joined(player_id: int)
signal player_left(player_id: int)
signal master_client_changed(player_id: int)


func is_in_room() -> bool:
	return false


func is_connected_to_photon() -> bool:
	return false


func is_master_client() -> bool:
	return false


func get_connection_status() -> int:
	return FusionBridge.STATUS_DISCONNECTED


func get_local_player_id() -> int:
	return 1


func get_rpc_sender() -> int:
	return 0


func get_room() -> Variant:
	return null


func get_room_list() -> Array:
	return []


func set_app_id(_app_id: String) -> void:
	pass


func connect_to_photon(..._args: Array) -> void:
	connection_failed.emit("El SDK Photon Fusion no está instalado.")


func disconnect_from_photon() -> void:
	pass


func create_singleplayer_room(..._args: Array) -> void:
	connection_failed.emit("El SDK Photon Fusion no está instalado.")


func join_room(..._args: Array) -> void:
	connection_failed.emit("El SDK Photon Fusion no está instalado.")


func join_or_create_room(..._args: Array) -> void:
	connection_failed.emit("El SDK Photon Fusion no está instalado.")


func leave_room() -> void:
	pass


func register_broadcast_receiver(_receiver: Object) -> void:
	pass


func unregister_broadcast_receiver(_receiver: Object) -> void:
	pass


func rpc(..._args: Array) -> void:
	pass


func rpc_to(..._args: Array) -> void:
	pass


func rpc_to_player(..._args: Array) -> void:
	pass


## Mismos campos que FusionRoomOptions, para cuando falta el SDK.
class RoomOptions:
	extends RefCounted
	var max_players := 0
	var is_visible := true
	var is_open := true
	var custom_properties: Dictionary = {}
