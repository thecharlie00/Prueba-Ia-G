# LogicNodes.gd
# Catálogo de bloques de la lógica visual (blueprints) del editor de juegos.
# Cada bloque tiene entradas y salidas tipadas (flujo, número, sí/no, texto, pieza, lista,
# cualquiera) y parámetros que se editan dentro del propio bloque. Una entrada de valor sin
# cable usa el parámetro del mismo nombre.
class_name LogicNodes
extends RefCounted

enum { EXEC, NUM, BOOL, TEXT, PIECE, LIST, ANY }

const TYPE_NAMES := {EXEC: "flujo", NUM: "número", BOOL: "sí/no", TEXT: "texto", PIECE: "pieza", LIST: "lista", ANY: "cualquiera"}
const TYPE_COLORS := {
	EXEC: Color("fff8ec"), NUM: Color("5fd0a0"), BOOL: Color("ee6f60"), TEXT: Color("f5c549"),
	PIECE: Color("5a8ae8"), LIST: Color("b58cf0"), ANY: Color("a8a4c8"),
}

const CATEGORIES := ["eventos", "flujo", "acciones", "jugadores", "datos", "codigo", "notas"]
const CATEGORY_NAMES := {
	"eventos": "Eventos", "flujo": "Flujo", "acciones": "Acciones", "jugadores": "Jugadores y turnos",
	"datos": "Datos", "codigo": "GDScript", "notas": "Notas",
}
const CATEGORY_COLORS := {
	"eventos": Color("ee6f60"), "flujo": Color("8b87b3"), "acciones": Color("5a8ae8"),
	"jugadores": Color("d98ad6"), "datos": Color("58c08f"), "codigo": Color("f09a50"), "notas": Color("6e6a92"),
}

const COMPARE_OPS := ["==", "!=", "<", ">", "<=", ">="]
const MATH_OPS := ["+", "-", "×", "÷", "resto", "mín", "máx"]
const LOGIC_OPS := ["y", "o", "no"]
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

## Código de ejemplo de los bloques GDScript.
const CODE_EXAMPLE := "# a y b son las entradas; devuelve un valor con return.\n# mesa.ayuda() lista lo que puedes usar.\nvar total = 0\nfor pieza in mesa.piezas_en_zona(\"\"):\n\ttotal += 1\nreturn total"
const EXPR_EXAMPLE := "return a * 2 + b"

## [nombre, tipo, etiqueta]
## Parámetros: [nombre, clase, etiqueta, valor por defecto]. Clases: zone, button, counter,
## element, number, text, bool, key, choice:<lista>, code, tag.
const DEFS := {
	# ---------------------------------------------------------------- Eventos
	"ev_inicio": {
		"cat": "eventos", "title": "Al empezar la partida",
		"help": "Se dispara una vez al pulsar «Probar la mesa».",
		"in": [], "out": [["out", EXEC, ""]], "params": [],
	},
	"ev_boton": {
		"cat": "eventos", "title": "Al pulsar un botón",
		"help": "Un botón de la interfaz del juego.",
		"in": [], "out": [["out", EXEC, ""]], "params": [["boton", "button", "Botón", 0]],
	},
	"ev_soltar": {
		"cat": "eventos", "title": "Al soltar en una zona",
		"help": "Cuando un jugador suelta una pieza dentro de la zona.",
		"in": [], "out": [["out", EXEC, ""], ["pieza", PIECE, "pieza"]], "params": [["zona", "zone", "Zona", ""]],
	},
	"ev_dados": {
		"cat": "eventos", "title": "Al pararse los dados",
		"help": "Tras una tirada, con el total y cada valor.",
		"in": [], "out": [["out", EXEC, ""], ["total", NUM, "total"], ["valores", LIST, "valores"]], "params": [],
	},
	"ev_tecla": {
		"cat": "eventos", "title": "Al pulsar una tecla",
		"help": "Teclas 1 a 9 mientras se prueba.",
		"in": [], "out": [["out", EXEC, ""]], "params": [["tecla", "key", "Tecla", "1"]],
	},
	"ev_cada": {
		"cat": "eventos", "title": "Cada cierto tiempo",
		"help": "Se repite mientras se prueba (relojes, turnos con tiempo).",
		"in": [], "out": [["out", EXEC, ""]], "params": [["segundos", "number", "Segundos", 5.0]],
	},
	"ev_turno": {
		"cat": "jugadores", "title": "Al empezar un turno",
		"help": "Cada vez que el turno pasa a un jugador (también el primero).",
		"in": [], "out": [["out", EXEC, ""], ["jugador", NUM, "jugador"], ["nombre", TEXT, "nombre"]], "params": [],
	},
	"ac_pasar_turno": {
		"cat": "jugadores", "title": "Pasar turno",
		"help": "Al siguiente jugador (tras el último, vuelve el primero).",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [],
	},
	"ac_dar_turno": {
		"cat": "jugadores", "title": "Dar el turno a",
		"in": [["in", EXEC, ""], ["jugador", NUM, "jugador"]], "out": [["out", EXEC, ""]],
		"params": [["jugador", "number", "Jugador (1, 2…)", 1]],
	},
	"da_jugador": {
		"cat": "jugadores", "title": "Jugador del turno",
		"in": [], "out": [["jugador", NUM, "número"], ["nombre", TEXT, "nombre"]], "params": [],
	},
	"da_jugadores": {
		"cat": "jugadores", "title": "Número de jugadores",
		"in": [], "out": [["n", NUM, "jugadores"]], "params": [],
	},
	"nota": {
		"cat": "notas", "title": "Nota",
		"help": "Un comentario para explicar la lógica. No hace nada al jugar.",
		"in": [], "out": [], "params": [["texto", "note", "", "Explica aquí qué hace esta parte."]],
	},
	# ---------------------------------------------------------------- Flujo
	"fl_si": {
		"cat": "flujo", "title": "Si",
		"help": "Sigue por «sí» o por «no».",
		"in": [["in", EXEC, ""], ["condicion", BOOL, "condición"]], "out": [["si", EXEC, "sí"], ["no", EXEC, "no"]],
		"params": [["condicion", "bool", "Condición", false]],
	},
	"fl_secuencia": {
		"cat": "flujo", "title": "Secuencia",
		"help": "Hace 1, luego 2, luego 3.",
		"in": [["in", EXEC, ""]], "out": [["1", EXEC, "1"], ["2", EXEC, "2"], ["3", EXEC, "3"]], "params": [],
	},
	"fl_repetir": {
		"cat": "flujo", "title": "Repetir",
		"help": "Repite el cuerpo N veces (como mucho 1000) y sigue por «al acabar».",
		"in": [["in", EXEC, ""], ["veces", NUM, "veces"]],
		"out": [["cuerpo", EXEC, "cuerpo"], ["indice", NUM, "vuelta"], ["fin", EXEC, "al acabar"]],
		"params": [["veces", "number", "Veces", 3]],
	},
	"fl_paracada": {
		"cat": "flujo", "title": "Para cada",
		"help": "Recorre una lista (por ejemplo, las piezas de una zona).",
		"in": [["in", EXEC, ""], ["lista", LIST, "lista"]],
		"out": [["cuerpo", EXEC, "cuerpo"], ["elemento", ANY, "elemento"], ["fin", EXEC, "al acabar"]], "params": [],
	},
	"fl_esperar": {
		"cat": "flujo", "title": "Esperar",
		"help": "Sigue al cabo de unos segundos.",
		"in": [["in", EXEC, ""], ["segundos", NUM, "segundos"]], "out": [["out", EXEC, ""]],
		"params": [["segundos", "number", "Segundos", 1.0]],
	},
	# ---------------------------------------------------------------- Acciones
	"ac_repartir": {
		"cat": "acciones", "title": "Repartir",
		"help": "Pasa las piezas de arriba de una zona a otra, boca arriba y en fila.",
		"in": [["in", EXEC, ""], ["cantidad", NUM, "cuántas"]], "out": [["out", EXEC, ""]],
		"params": [["cantidad", "number", "Cuántas", 1], ["de", "zone", "De", ""], ["a", "zone", "A", ""], ["etiqueta", "tag", "Sólo con etiqueta", ""]],
	},
	"ac_mover": {
		"cat": "acciones", "title": "Mover pieza a zona",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"]], "out": [["out", EXEC, ""]],
		"params": [["a", "zone", "A", ""]],
	},
	"ac_mezclar": {
		"cat": "acciones", "title": "Mezclar zona",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [["zona", "zone", "Zona", ""]],
	},
	"ac_voltear": {
		"cat": "acciones", "title": "Voltear pieza",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"]], "out": [["out", EXEC, ""]], "params": [],
	},
	"ac_voltear_zona": {
		"cat": "acciones", "title": "Voltear zona",
		"help": "Da la vuelta a todo lo que hay en la zona.",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [["zona", "zone", "Zona", ""]],
	},
	"ac_tirar": {
		"cat": "acciones", "title": "Tirar los dados",
		"help": "Todos los dados que no estén fijos.",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [],
	},
	"ac_sumar": {
		"cat": "acciones", "title": "Sumar al contador",
		"in": [["in", EXEC, ""], ["cantidad", NUM, "cantidad"]], "out": [["out", EXEC, ""]],
		"params": [["contador", "counter", "Contador", 0], ["cantidad", "number", "Cantidad", 1]],
	},
	"ac_poner": {
		"cat": "acciones", "title": "Poner el contador a",
		"in": [["in", EXEC, ""], ["valor", NUM, "valor"]], "out": [["out", EXEC, ""]],
		"params": [["contador", "counter", "Contador", 0], ["valor", "number", "Valor", 0]],
	},
	"ac_mensaje": {
		"cat": "acciones", "title": "Mostrar mensaje",
		"in": [["in", EXEC, ""], ["texto", ANY, "texto"]], "out": [["out", EXEC, ""]],
		"params": [["texto", "text", "Texto", "¡Tu turno!"]],
	},
	"ac_interfaz": {
		"cat": "acciones", "title": "Mostrar u ocultar",
		"help": "Un elemento de la interfaz del juego (un panel de reglas, un cartel).",
		"in": [["in", EXEC, ""], ["visible", BOOL, "visible"]], "out": [["out", EXEC, ""]],
		"params": [["elemento", "element", "Elemento", 0], ["visible", "bool", "Visible", true]],
	},
	"ac_variable": {
		"cat": "acciones", "title": "Guardar variable",
		"help": "Recuerda un valor con un nombre (turno, ronda, jugador…).",
		"in": [["in", EXEC, ""], ["valor", ANY, "valor"]], "out": [["out", EXEC, ""]],
		"params": [["nombre", "text", "Nombre", "turno"], ["valor", "number", "Valor", 0]],
	},
	# ---------------------------------------------------------------- Datos
	"da_numero": {
		"cat": "datos", "title": "Número", "in": [], "out": [["valor", NUM, "valor"]],
		"params": [["valor", "number", "Valor", 1]],
	},
	"da_texto": {
		"cat": "datos", "title": "Texto", "in": [], "out": [["valor", TEXT, "texto"]],
		"params": [["valor", "text", "Texto", ""]],
	},
	"da_piezas": {
		"cat": "datos", "title": "Piezas en zona",
		"help": "De arriba abajo. Sin zona: todas las de la mesa.",
		"in": [], "out": [["lista", LIST, "piezas"]],
		"params": [["zona", "zone", "Zona", ""], ["etiqueta", "tag", "Sólo con etiqueta", ""]],
	},
	"da_contar": {
		"cat": "datos", "title": "Contar", "in": [["lista", LIST, "lista"]], "out": [["n", NUM, "cuántos"]], "params": [],
	},
	"da_azar": {
		"cat": "datos", "title": "Al azar",
		"in": [["min", NUM, "desde"], ["max", NUM, "hasta"]], "out": [["valor", NUM, "valor"]],
		"params": [["min", "number", "Desde", 1], ["max", "number", "Hasta", 6]],
	},
	"da_operar": {
		"cat": "datos", "title": "Operar",
		"in": [["a", NUM, "a"], ["b", NUM, "b"]], "out": [["valor", NUM, "resultado"]],
		"params": [["op", "choice:+,-,×,÷,resto,mín,máx", "Operación", "+"], ["a", "number", "a", 0], ["b", "number", "b", 0]],
	},
	"da_comparar": {
		"cat": "datos", "title": "Comparar",
		"in": [["a", ANY, "a"], ["b", ANY, "b"]], "out": [["valor", BOOL, "¿se cumple?"]],
		"params": [["op", "choice:==,!=,<,>,<=,>=", "Comparación", ">="], ["a", "number", "a", 0], ["b", "number", "b", 0]],
	},
	"da_logica": {
		"cat": "datos", "title": "Y / O / No",
		"in": [["a", BOOL, "a"], ["b", BOOL, "b"]], "out": [["valor", BOOL, "resultado"]],
		"params": [["op", "choice:y,o,no", "Operación", "y"]],
	},
	"da_variable": {
		"cat": "datos", "title": "Leer variable", "in": [], "out": [["valor", ANY, "valor"]],
		"params": [["nombre", "text", "Nombre", "turno"]],
	},
	"da_contador": {
		"cat": "datos", "title": "Valor del contador", "in": [], "out": [["valor", NUM, "valor"]],
		"params": [["contador", "counter", "Contador", 0]],
	},
	"da_dados": {
		"cat": "datos", "title": "Última tirada", "in": [], "out": [["total", NUM, "total"]], "params": [],
	},
	"da_unir": {
		"cat": "datos", "title": "Unir texto",
		"in": [["a", ANY, "a"], ["b", ANY, "b"]], "out": [["valor", TEXT, "texto"]],
		"params": [["a", "text", "a", ""], ["b", "text", "b", ""]],
	},
	"da_etiqueta": {
		"cat": "datos", "title": "¿Tiene etiqueta?",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", BOOL, "¿la tiene?"]],
		"params": [["etiqueta", "tag", "Etiqueta", ""]],
	},
	"da_nombre": {
		"cat": "datos", "title": "Nombre de la pieza",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", TEXT, "nombre"]], "params": [],
	},
	# ---------------------------------------------------------------- GDScript
	"gd_bloque": {
		"cat": "codigo", "title": "Bloque GDScript",
		"help": "Código con flujo: hace cosas en la mesa con «mesa» y puede devolver un valor.",
		"in": [["in", EXEC, ""], ["a", ANY, "a"], ["b", ANY, "b"]],
		"out": [["out", EXEC, ""], ["resultado", ANY, "resultado"]],
		"params": [["codigo", "code", "Código", CODE_EXAMPLE]],
	},
	"gd_expresion": {
		"cat": "codigo", "title": "Calcular con GDScript",
		"help": "Un cálculo sin flujo: devuelve un valor a partir de a y b.",
		"in": [["a", ANY, "a"], ["b", ANY, "b"]], "out": [["resultado", ANY, "resultado"]],
		"params": [["codigo", "code", "Código", EXPR_EXAMPLE]],
	},
}


static func has(type: String) -> bool:
	return DEFS.has(type)


static func inputs(type: String) -> Array:
	return DEFS[type]["in"]


static func outputs(type: String) -> Array:
	return DEFS[type]["out"]


static func params(type: String) -> Array:
	return DEFS[type]["params"]


static func is_event(type: String) -> bool:
	return DEFS.has(type) and DEFS[type]["cat"] == "eventos"


## Bloques que se calculan cuando se les pide un valor (sin flujo).
static func is_pure(type: String) -> bool:
	if not DEFS.has(type):
		return false
	for port in DEFS[type]["in"] + DEFS[type]["out"]:
		if port[1] == EXEC:
			return false
	return true


static func port_index(ports: Array, name: String) -> int:
	for i in ports.size():
		if ports[i][0] == name:
			return i
	return -1


static func port_type(ports: Array, name: String) -> int:
	var index := port_index(ports, name)
	return ports[index][1] if index >= 0 else -1


## ¿Se puede unir una salida de tipo `from` con una entrada de tipo `to`?
static func compatible(from: int, to: int) -> bool:
	if from == EXEC or to == EXEC:
		return from == to
	if from == to or from == ANY or to == ANY:
		return true
	# Un número se puede escribir como texto.
	return to == TEXT and from == NUM


static func default_params(type: String) -> Dictionary:
	var result := {}
	for param in params(type):
		result[param[0]] = param[3]
	return result


static func choice_options(kind: String) -> Array:
	return Array(kind.trim_prefix("choice:").split(","))
