# TableTemplates.gd
# Mesas de partida para el editor de juegos: un punto de arranque listo para cambiar.
class_name TableTemplates
extends RefCounted

const NAMES := ["damas", "recorrido", "cartas", "dados"]
const TITLES := {
	"damas": "Damas",
	"recorrido": "Carrera",
	"cartas": "Cartas",
	"dados": "Dados",
}
const HINTS := {
	"damas": "Tablero de 8×8 con 24 fichas",
	"recorrido": "Tablero de recorrido, 4 peones y un dado",
	"cartas": "Mazo de 20 cartas numeradas, zona de mazo y descarte",
	"dados": "Cinco dados y una zona para tirarlos",
}
const BOARD_COLOR := Color("e8cf9f")


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
			for i in 4:
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
		"dados":
			list.append(_piece("zona", _t("Zona de tirada"), Vector3(0, 0, 0.3), Palette.MINT, {"label": _t("TIRADA"), "scale": 1.6, "locked": true}))
			for i in 5:
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
