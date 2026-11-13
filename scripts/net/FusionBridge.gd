class_name FusionBridge
## Puente hacia el SDK Photon Fusion (GDExtension propietaria en addons/fusion).
##
## El SDK no se versiona en el repositorio público: cada máquina de desarrollo lo instala
## a mano (ver docs/RED-ONLINE.md). Para que el proyecto compile y funcione en modo local
## sin él, ningún script nombra el singleton «Fusion» directamente: todos pasan por aquí.
## Sin SDK, sdk() devuelve un sustituto inerte (FusionStub) que nunca está en sala.

## Constantes copiadas del singleton Fusion (ClassDB, SDK 4.x).
const STATUS_DISCONNECTED := 0
const STATUS_CONNECTING_TO_PHOTON := 1
const STATUS_CONNECTED_TO_PHOTON := 2
const STATUS_JOINING_ROOM := 3
const STATUS_IN_ROOM := 4
const STATUS_ERROR := 5
const STATUS_DISCONNECTING := 6
const TARGET_ALL := 0
const TARGET_MASTER := -1
const TARGET_PLUGIN := -2
const TARGET_OWNER := -3

const SINGLETON := "Fusion"

static var _stub: FusionStub


## true si el SDK está instalado y cargado.
static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


## El singleton real o, si falta el SDK, un sustituto que no hace nada.
static func sdk() -> Object:
	if Engine.has_singleton(SINGLETON):
		return Engine.get_singleton(SINGLETON)
	if _stub == null:
		_stub = FusionStub.new()
	return _stub


## Atajo frecuente: hay SDK y estamos dentro de una sala.
static func in_room() -> bool:
	return available() and bool(sdk().is_in_room())


## Opciones de sala nativas (FusionRoomOptions) o un sustituto con los mismos campos.
static func room_options() -> RefCounted:
	if ClassDB.class_exists("FusionRoomOptions"):
		return ClassDB.instantiate("FusionRoomOptions")
	return FusionStub.RoomOptions.new()
