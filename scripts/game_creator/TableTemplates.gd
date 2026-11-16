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
			list.append(_piece("zona", _t("Zona mazo"), Vector3(-0.75, 0, 0), Palette.LAVENDER, {"label": _t("MAZO"), "scale": 0.9, "locked": true}))
			list.append(_piece("zona", _t("Zona descarte"), Vector3(0.75, 0, 0), Palette.LAVENDER, {"label": _t("DESCARTE"), "scale": 0.9, "locked": true}))
			var height := PieceShapes.size_of("zona").y * 0.9
			var card := PieceShapes.size_of("carta").y
			for suit in 2:
				for value in range(1, 11):
					var color: Color = Palette.PLAYER_RED if suit == 0 else Palette.PLAYER_BLUE
					list.append(_piece("carta", _t("Carta %d roja" if suit == 0 else "Carta %d azul") % value, Vector3(-0.75, height, 0), color.lightened(0.55), {"label": str(value), "finish": "brillo", "mass": 0.2}))
					height += card
		"dados":
			list.append(_piece("zona", _t("Zona de tirada"), Vector3(0, 0, 0.3), Palette.MINT, {"label": _t("TIRADA"), "scale": 1.6, "locked": true}))
			for i in 5:
				list.append(_piece("dado", _t("Dado %d") % (i + 1), Vector3(-0.8 + i * 0.4, 0, -0.7), Palette.PAPER, {"finish": "plastico"}))
	var clean: Array = []
	for item in list:
		clean.append(TableRecord.valid_piece(item))
	return clean


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
