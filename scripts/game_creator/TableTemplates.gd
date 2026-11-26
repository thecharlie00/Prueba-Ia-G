# TableTemplates.gd
# Mesas de partida para el editor de juegos: un punto de arranque listo para cambiar.
class_name TableTemplates
extends RefCounted

const NAMES := ["damas", "recorrido", "cartas", "dados", "directo"]
const TITLES := {
	"damas": "Damas",
	"recorrido": "Carrera",
	"cartas": "Cartas",
	"dados": "Dados",
	"directo": "Dragón del chat",
}
const HINTS := {
	"damas": "Tablero de 8×8 con 24 fichas",
	"recorrido": "Tablero de recorrido, 4 peones y un dado",
	"cartas": "Mazo de 20 cartas numeradas, zona de mazo y descarte",
	"dados": "Cinco dados y una zona para tirarlos",
	"directo": "Para streamers: el chat se une a un equipo, ataca con comandos y despierta al dragón con bits",
}
## Plantillas pensadas para jugar en directo con el chat de Twitch.
const FOR_STREAMERS := ["directo"]
const BOARD_COLOR := Color("e8cf9f")


## Auto-setup de una plantilla: acciones que se aplican al cargar la plantilla.
## Cada entrada es { "accion": "repartir"|"mezclar"|"colocar", ... }.
## Acciones soportadas:
##   - repartir: { "zona": "zona_origen", "destino": "zona_destino", "cantidad": N, "etiqueta": "" }
##   - mezclar:  { "zona": "zona_a_mezclar" }
##   - colocar:  { "pieza": "nombre_pieza", "zona": "zona_destino" }
const AUTO_SETUP := {
	"cartas": [
		{ "accion": "mezclar", "zona": "zona_mazo" },
		{ "accion": "repartir", "zona": "zona_mazo", "destino": "zona_mano", "cantidad": 5, "etiqueta": "" },
	],
	"dados": [
		{ "accion": "mezclar", "zona": "zona_tirada" },
	],
	"damas": [],
	"recorrido": [],
	"directo": [],
}


## Devuelve las acciones de auto-setup de la plantilla `name` (o un array vacío).
static func auto_setup(name: String) -> Array:
	return AUTO_SETUP.get(name, [])


## Piezas limpias (como las de TableRecord.valid_piece) de la plantilla `name`.
static func pieces(name: String) -> Array:
	var list: Array = []
	match name:
		"damas":
			list.append(_piece("tablero", _t("Tablero"), Vector3.ZERO, BOARD_COLOR, {"pattern": "ajedrez", "cells": 8, "locked": true, "finish": "madera"}))
			var top := PieceShapes.size_of("tablero").y
			var cell := PieceShapes.size_of("tablero").x / 8.0
			var count := {"red": 0, "white": 0}
			for row in 8:
				if row in [3, 4]:
					continue
				for col in 8:
					if (row + col) % 2 == 0:
						continue
					var red := row < 3
					var at := Vector3((col - 3.5) * cell, top, (row - 3.5) * cell)
					var key := "red" if red else "white"
					count[key] += 1
					list.append(_piece("disco", _t("Roja %d" if red else "Blanca %d") % count[key], at,
						Palette.PLAYER_RED if red else Palette.PLAYER_WHITE, {"scale": 0.4, "finish": "plastico"}))
		"recorrido":
			list.append(_piece("tablero", _t("Tablero"), Vector3.ZERO, BOARD_COLOR, {"pattern": "recorrido", "cells": 10, "locked": true}))
			var top := PieceShapes.size_of("tablero").y
			var corner := PieceShapes.size_of("tablero").x * 0.5 - 0.1
			var spots := [Vector3(-corner, top, -corner), Vector3(corner, top, -corner), Vector3(corner, top, corner), Vector3(-corner, top, corner)]
			var names := ["Peón rojo", "Peón azul", "Peón verde", "Peón amarillo"]
			for i in range(4):
				list.append(_piece("peon", _t(names[i]), spots[i], PieceLooks.CORNER_COLORS[i], {"scale": 0.55, "finish": "plastico"}))
			list.append(_piece("dado", _t("Dado"), Vector3(0, top, 0), Palette.PAPER, {"scale": 0.8}))
		"cartas":
			list.append(_piece("zona", _t("Zona mazo"), Vector3(-0.75, 0, -0.45), Palette.LAVENDER, {"id": "zona_mazo", "label": _t("MAZO"), "scale": 0.9, "locked": true}))
			list.append(_piece("zona", _t("Zona descarte"), Vector3(0.75, 0, -0.45), Palette.LAVENDER, {"id": "zona_descarte", "label": _t("DESCARTE"), "scale": 0.9, "locked": true}))
			list.append(_piece("zona", _t("Zona mano"), Vector3(0, 0, 0.9), Palette.MINT, {"id": "zona_mano", "label": _t("MANO"), "scale": 1.8, "locked": true, "zkind": "mano"}))
			var height := PieceShapes.size_of("zona").y * 0.9
			var card := PieceShapes.size_of("carta").y
			for suit in 2:
				for value in range(1, 11):
					var color: Color = Palette.PLAYER_RED if suit == 0 else Palette.PLAYER_BLUE
					list.append(_piece("carta", _t("Carta %d roja" if suit == 0 else "Carta %d azul") % value, Vector3(-0.75, height, -0.45), color.lightened(0.55), {"label": str(value), "finish": "brillo", "mass": 0.2}))
					height += card
		"directo":
			list.append(_piece("tablero", _t("Tablero"), Vector3.ZERO, Color("9fd8b0"), {"pattern": "liso", "locked": true, "finish": "madera"}))
			var top := PieceShapes.size_of("tablero").y
			list.append(_piece("peon", _t("Dragón"), Vector3(0, top, 0), Palette.CORAL, {"scale": 1.4, "finish": "brillo", "tags": ["dragon"]}))
			for team in 2:
				var red := team == 0
				var x := -0.55 if red else 0.55
				list.append(_piece("zona", _t("Equipo rojo") if red else _t("Equipo azul"), Vector3(x, top, 0), Palette.PLAYER_RED if red else Palette.PLAYER_BLUE,
					{"label": _t("ROJO") if red else _t("AZUL"), "scale": 0.8, "locked": true}))
				for i in 8:
					var at := Vector3(x + (i % 2) * 0.16 - 0.08, top, -0.42 + int(i / 2) * 0.28)
					list.append(_piece("disco", (_t("Soldado rojo %d") if red else _t("Soldado azul %d")) % (i + 1), at,
						Palette.PLAYER_RED if red else Palette.PLAYER_BLUE, {"scale": 0.35, "finish": "plastico", "tags": ["rojo" if red else "azul"]}))
		"dados":
			list.append(_piece("zona", _t("Zona de tirada"), Vector3(0, 0, 0.3), Palette.MINT, {"label": _t("TIRADA"), "scale": 1.6, "locked": true}))
			for i in range(5):
				list.append(_piece("dado", _t("Dado %d") % (i + 1), Vector3(-0.8 + i * 0.4, 0, -0.7), Palette.PAPER, {"finish": "plastico"}))
	var clean: Array = []
	for item in list:
		clean.append(TableRecord.valid_piece(item))
	return clean


## Lógica de partida de cada plantilla (o null): ejemplos de bloques ya montados.
static func logic(name: String) -> Variant:
	match name:
		"cartas":
			# Al empezar: mezclar el mazo y repartir 5 a la mano. Tecla 1: robar una.
			return {"version": 1, "nodes": [
				{"id": 1, "type": "ev_inicio", "pos": [0, 0], "params": {}},
				{"id": 2, "type": "ac_mezclar", "pos": [340, 0], "params": {"zona": "zona_mazo"}},
				{"id": 3, "type": "ac_repartir", "pos": [680, 0], "params": {"cantidad": 5, "de": "zona_mazo", "a": "zona_mano", "etiqueta": ""}},
				{"id": 4, "type": "ev_tecla", "pos": [0, 400], "params": {"tecla": "1"}},
				{"id": 5, "type": "ac_repartir", "pos": [340, 400], "params": {"cantidad": 1, "de": "zona_mazo", "a": "zona_mano", "etiqueta": ""}},
				{"id": 6, "type": "ac_mensaje", "pos": [1020, 0], "params": {"texto": _t("Cinco cartas a la mano. Pulsa 1 para robar.")}},
			], "links": [[1, "out", 2, "in"], [2, "out", 3, "in"], [3, "out", 6, "in"], [4, "out", 5, "in"]]}
		"directo":
			return _stream_logic()
		"dados":
			# Al pararse los dados: un bloque GDScript decide el mensaje según el total.
			return {"version": 1, "nodes": [
				{"id": 1, "type": "ev_dados", "pos": [0, 0], "params": {}},
				{"id": 2, "type": "gd_expresion", "pos": [340, 160], "params": {"codigo": "if a >= 25:\n\treturn \"¡Tirada enorme: %d!\" % a\nreturn \"Total: %d\" % a"}},
				{"id": 3, "type": "ac_mensaje", "pos": [820, 0], "params": {"texto": ""}},
				{"id": 4, "type": "ev_inicio", "pos": [0, 480], "params": {}},
				{"id": 5, "type": "ac_mensaje", "pos": [340, 480], "params": {"texto": _t("Pulsa R para tirar los dados.")}},
			], "links": [[1, "out", 3, "in"], [1, "total", 2, "a"], [2, "resultado", 3, "texto"], [4, "out", 5, "in"]]}
	return null


## «El chat contra el dragón»: ejemplo de juego para directo hecho solo con bloques Twitch.
static func _stream_logic() -> Dictionary:
	return {"version": 1, "nodes": [
		{"id": 1, "type": "ev_inicio", "pos": [0, 0], "params": {}},
		{"id": 2, "type": "tw_mostrar_chat", "pos": [340, 0], "params": {"estilo": "panel lateral", "lado": "derecha", "mensajes": "sin comandos"}},
		{"id": 3, "type": "tw_marcador", "pos": [680, 0], "params": {"equipos": "rojo,azul", "visible": true}},
		{"id": 4, "type": "tw_meta", "pos": [1020, 0], "params": {"nombre": _t("Despertar al dragón"), "maximo": 500, "modo": "poner", "valor": 0}},
		{"id": 5, "type": "ac_mensaje", "pos": [1360, 0], "params": {"texto": _t("Chat: !unirme rojo o azul, y luego !ataque 1-6. Los bits despiertan al dragón.")}},
		{"id": 6, "type": "tw_ev_comando", "pos": [0, 360], "params": {"comando": "!unirme", "alias": "!equipo", "argumento": "opción", "minimo": 1, "maximo": 6,
			"opciones": "rojo,azul", "quien": "todos", "espera": 5, "ayuda": _t("Únete a un equipo")}},
		{"id": 7, "type": "tw_equipo", "pos": [340, 360], "params": {"equipo": "rojo"}},
		{"id": 8, "type": "tw_ficha", "pos": [680, 360], "params": {"etiqueta": "rojo"}},
		{"id": 9, "type": "tw_ev_comando", "pos": [0, 720], "params": {"comando": "!ataque", "alias": "!atk", "argumento": "número", "minimo": 1, "maximo": 6,
			"opciones": "", "quien": "todos", "espera": 10, "ayuda": _t("Suma monedas a tu equipo")}},
		{"id": 10, "type": "tw_monedas", "pos": [340, 720], "params": {"cantidad": 1}},
		{"id": 11, "type": "tw_ev_bits", "pos": [0, 1080], "params": {"minimo": 1}},
		{"id": 12, "type": "tw_alerta", "pos": [340, 1080], "params": {"texto": _t("¡{usuario} lanza {cantidad} bits al dragón!"), "segundos": 4, "sonido": "fanfarria"}},
		{"id": 13, "type": "tw_meta", "pos": [680, 1080], "params": {"nombre": _t("Despertar al dragón"), "maximo": 500, "modo": "sumar"}},
		{"id": 14, "type": "tw_votacion", "pos": [1020, 1080], "params": {"nombre": "dragon", "pregunta": _t("¿A quién ataca el dragón?"), "opciones": _t("Equipo rojo,Equipo azul"), "segundos": 20}},
		{"id": 15, "type": "tw_ev_votacion", "pos": [0, 1440], "params": {"nombre": "dragon"}},
		{"id": 16, "type": "ac_mensaje", "pos": [340, 1440], "params": {"texto": ""}},
		{"id": 17, "type": "tw_ev_raid", "pos": [0, 1800], "params": {"minimo": 1}},
		{"id": 18, "type": "tw_sorteo", "pos": [340, 1800], "params": {"nombre": "raid", "palabra": "!participo", "segundos": 30, "quien": "todos"}},
		{"id": 19, "type": "tw_ev_sorteo", "pos": [0, 2160], "params": {"nombre": "raid"}},
		{"id": 20, "type": "tw_monedas", "pos": [340, 2160], "params": {"cantidad": 50}},
		{"id": 21, "type": "tw_destacar", "pos": [680, 2160], "params": {"segundos": 5}},
		{"id": 22, "type": "nota", "pos": [1360, 360], "params": {"texto": _t("Prueba la mesa y usa el chat de prueba de abajo: escribe !unirme rojo, !ataque 4 o pulsa «100 bits».")}},
	], "links": [
		[1, "out", 2, "in"], [2, "out", 3, "in"], [3, "out", 4, "in"], [4, "out", 5, "in"],
		[6, "out", 7, "in"], [6, "usuario", 7, "usuario"], [6, "valor", 7, "equipo"],
		[7, "out", 8, "in"], [6, "usuario", 8, "usuario"], [6, "valor", 8, "etiqueta"],
		[9, "out", 10, "in"], [9, "usuario", 10, "usuario"], [9, "valor", 10, "cantidad"],
		[11, "out", 12, "in"], [11, "usuario", 12, "usuario"], [11, "cantidad", 12, "cantidad"],
		[12, "out", 13, "in"], [11, "cantidad", 13, "valor"], [13, "llena", 14, "in"],
		[15, "out", 16, "in"], [15, "opcion", 16, "texto"],
		[17, "out", 18, "in"],
		[19, "out", 20, "in"], [19, "ganador", 20, "usuario"], [20, "out", 21, "in"], [19, "ganador", 21, "usuario"],
	]}


## Cartas para varios jugadores: al empezar, mezcla y reparte 5 a la mano de cada uno
## (pasando el turno); la tecla 1 roba para quien tenga el turno.
static func cards_logic_for_players() -> Dictionary:
	return {"version": 1, "nodes": [
		{"id": 1, "type": "ev_inicio", "pos": [0, 0], "params": {}},
		{"id": 2, "type": "ac_mezclar", "pos": [340, 0], "params": {"zona": "zona_mazo"}},
		{"id": 3, "type": "fl_repetir", "pos": [680, 0], "params": {"veces": 2}},
		{"id": 4, "type": "da_jugadores", "pos": [340, 260], "params": {}},
		{"id": 5, "type": "ac_repartir", "pos": [1020, 0], "params": {"cantidad": 5, "de": "zona_mazo", "a": GamePlayers.CURRENT_HAND, "etiqueta": ""}},
		{"id": 6, "type": "ac_pasar_turno", "pos": [1360, 0], "params": {}},
		{"id": 7, "type": "ac_mensaje", "pos": [1020, 400], "params": {"texto": _t("Cinco cartas para cada jugador. 1: robar · T: pasar turno.")}},
		{"id": 8, "type": "ev_tecla", "pos": [0, 600], "params": {"tecla": "1"}},
		{"id": 9, "type": "ac_repartir", "pos": [340, 600], "params": {"cantidad": 1, "de": "zona_mazo", "a": GamePlayers.CURRENT_HAND, "etiqueta": ""}},
		{"id": 10, "type": "nota", "pos": [0, 380], "params": {"texto": _t("Hecho con «Nuevo juego». Cambia cuántas cartas se reparten en «Repartir».")}},
	], "links": [[1, "out", 2, "in"], [2, "out", 3, "in"], [4, "n", 3, "veces"], [3, "cuerpo", 5, "in"], [5, "out", 6, "in"], [3, "fin", 7, "in"], [8, "out", 9, "in"]]}


static func _t(text: String) -> String:
	return TranslationServer.translate(text)


static func _piece(shape: String, name: String, at: Vector3, color: Color, extra := {}) -> Dictionary:
	var piece := {
		"id": "", "name": name, "shape": shape, "color": color.to_html(true), "texture": "",
		"label": "", "pattern": "liso", "cells": 8, "finish": "mate",
		"pos": [at.x, at.y, at.z], "rot": [0, 0, 0], "scale": 1.0, "locked": false, "mass": 1.0, "bounce": 0.1,
	}
	piece.merge(extra, true)
	return piece
