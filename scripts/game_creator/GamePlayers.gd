# GamePlayers.gd
# Jugadores de un juego creado en el editor: cuántos son, su nombre y color, y dónde va la
# mano de cada uno alrededor de la mesa. El turno se lleva al probar (y desde la lógica).
class_name GamePlayers
extends RefCounted

const MAX := 6
const NAMES := ["Rojo", "Azul", "Verde", "Amarillo", "Naranja", "Morado"]
const COLORS := [Color("ee6f60"), Color("5a8ae8"), Color("58c08f"), Color("f5c549"), Color("f09a50"), Color("b58cf0")]
## Zona especial en la lógica: la mano del jugador que tiene el turno.
const CURRENT_HAND := "@mano"
const HAND_RADIUS := 1.9


static func clamp_count(count: Variant) -> int:
	return clampi(int(count) if (count is int or count is float) else 2, 1, MAX)


static func player_name(index: int) -> String:
	return TranslationServer.translate(NAMES[clampi(index, 0, MAX - 1)])


static func player_color(index: int) -> Color:
	return COLORS[clampi(index, 0, MAX - 1)]


## Dónde va la mano del jugador `index` (0 = el que mira desde la cámara) entre `count`.
static func hand_transform(index: int, count: int) -> Transform3D:
	var angle := TAU * float(index) / float(maxi(count, 1))
	var at := Vector3(sin(angle), 0, cos(angle)) * HAND_RADIUS
	return Transform3D(Basis(Vector3.UP, angle), at)


static func record(count: int) -> Dictionary:
	return {"players": clamp_count(count)}


static func from_record(data: Variant) -> int:
	if data is Dictionary:
		return clamp_count(data.get("players", 2))
	return 2
