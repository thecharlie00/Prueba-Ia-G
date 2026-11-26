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

const CATEGORIES := ["eventos", "flujo", "acciones", "jugadores", "datos", "twitch", "codigo", "notas"]
const CATEGORY_NAMES := {
	"eventos": "Eventos", "flujo": "Flujo", "acciones": "Acciones", "jugadores": "Jugadores y turnos",
	"datos": "Datos", "twitch": "Twitch", "codigo": "GDScript", "notas": "Notas",
}
const CATEGORY_COLORS := {
	"eventos": Color("ee6f60"), "flujo": Color("8b87b3"), "acciones": Color("5a8ae8"),
	"jugadores": Color("d98ad6"), "datos": Color("58c08f"), "twitch": Color("a78bff"), "codigo": Color("f09a50"), "notas": Color("6e6a92"),
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
## «event»: true marca como evento un bloque de otra categoría (los de Twitch).
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
	"ac_escribir": {
		"cat": "acciones", "title": "Escribir en la pieza",
		"help": "Pone texto en una pieza (se ve en su etiqueta).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"], ["texto", TEXT, "texto"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	"ac_color": {
		"cat": "acciones", "title": "Color de la pieza",
		"help": "Pone el color de una pieza (#RRGGBBAA o nombre de la paleta).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"], ["color", TEXT, "color"]], "out": [["out", EXEC, ""]],
		"params": [],
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
	"da_todas_piezas": {
		"cat": "datos", "title": "Todas las piezas",
		"help": "IDs de todas las piezas de la mesa (sin zona: todas).",
		"in": [], "out": [["lista", LIST, "piezas"]], "params": [],
	},
	"da_etiquetas_pieza": {
		"cat": "datos", "title": "Etiquetas de la pieza",
		"help": "Lista de etiquetas de una pieza.",
		"in": [["pieza", PIECE, "pieza"]], "out": [["lista", LIST, "etiquetas"]], "params": [],
	},
	"da_texto_de": {
		"cat": "datos", "title": "Texto de la pieza",
		"help": "Lee el texto escrito en una pieza.",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", TEXT, "texto"]], "params": [],
	},
	"da_zona_de": {
		"cat": "datos", "title": "Zona de la pieza",
		"help": "Nombre de la zona donde está la pieza, o \"\" si no está en ninguna.",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", TEXT, "zona"]], "params": [],
	},
	"da_zonas": {
		"cat": "datos", "title": "Todas las zonas",
		"help": "Nombres de todas las zonas de la mesa.",
		"in": [], "out": [["lista", LIST, "zonas"]], "params": [],
	},
	"da_mano": {
		"cat": "jugadores", "title": "Mano del turno",
		"help": "ID de la zona de mano del jugador que tiene el turno.",
		"in": [], "out": [["valor", PIECE, "zona"]], "params": [],
	},
	"da_nombre_jugador": {
		"cat": "jugadores", "title": "Nombre del jugador",
		"help": "Nombre de un jugador por número (1, 2…).",
		"in": [["jugador", NUM, "jugador"]], "out": [["valor", TEXT, "nombre"]], "params": [["jugador", "number", "Jugador", 1]],
	},
	"da_rango": {
		"cat": "datos", "title": "Rango",
		"help": "Lista [0, 1, …, n-1] para recorrer con «Para cada».",
		"in": [["n", NUM, "n"]], "out": [["lista", LIST, "índices"]], "params": [["n", "number", "N", 5]],
	},
	"da_color": {
		"cat": "datos", "title": "Color de la pieza",
		"help": "Color de una pieza (como texto #RRGGBBAA).",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", TEXT, "color"]], "params": [],
	},
	"da_cartas_en_mazo": {
		"cat": "datos", "title": "Cartas en el mazo",
		"help": "Número de cartas que tiene un mazo (pieza con DeckComponent).",
		"in": [["mazo", PIECE, "mazo"]], "out": [["valor", NUM, "cuántas"]], "params": [],
	},
	"da_carta_arriba": {
		"cat": "datos", "title": "Carta de arriba",
		"help": "Nombre de la carta de arriba de un mazo, o \"\" si está vacío.",
		"in": [["mazo", PIECE, "mazo"]], "out": [["valor", TEXT, "nombre"]], "params": [],
	},
	"ac_repartir_mazo": {
		"cat": "acciones", "title": "Repartir del mazo",
		"help": "Saca cartas de arriba de un mazo y las pone en una zona.",
		"in": [["in", EXEC, ""], ["mazo", PIECE, "mazo"], ["cantidad", NUM, "cuántas"], ["zona", PIECE, "zona destino"]], "out": [["out", EXEC, ""]],
		"params": [["cantidad", "number", "Cuántas", 1]],
	},
	"da_contador_valor": {
		"cat": "datos", "title": "Valor del contador",
		"help": "Valor actual del contador de una pieza (CounterComponent).",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", NUM, "valor"]], "params": [],
	},
	"da_bolsa_contar": {
		"cat": "datos", "title": "Piezas en la bolsa",
		"help": "Número de piezas dentro de una bolsa (BagComponent).",
		"in": [["bolsa", PIECE, "bolsa"]], "out": [["valor", NUM, "cuántas"]], "params": [],
	},
	"da_nota_leer": {
		"cat": "datos", "title": "Leer nota",
		"help": "Texto de la nota de una pieza (NoteComponent).",
		"in": [["pieza", PIECE, "pieza"]], "out": [["valor", TEXT, "texto"]], "params": [],
	},
	"da_reloj_tiempo": {
		"cat": "datos", "title": "Tiempo del reloj",
		"help": "Tiempo restante del reloj de una pieza (TimerComponent), en segundos.",
		"in": [["reloj", PIECE, "reloj"]], "out": [["valor", NUM, "segundos"]], "params": [],
	},
	"ac_contador_sumar": {
		"cat": "acciones", "title": "Sumar al contador",
		"help": "Suma una cantidad al contador de una pieza (CounterComponent).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"], ["cantidad", NUM, "cuánto"]], "out": [["out", EXEC, ""]],
		"params": [["cantidad", "number", "Cuánto", 1]],
	},
	"ac_contador_poner": {
		"cat": "acciones", "title": "Poner contador a",
		"help": "Pone el contador de una pieza a un valor (CounterComponent).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"], ["valor", NUM, "valor"]], "out": [["out", EXEC, ""]],
		"params": [["valor", "number", "Valor", 0]],
	},
	"ac_contador_resetear": {
		"cat": "acciones", "title": "Resetear contador",
		"help": "Pone el contador de una pieza a su mínimo (CounterComponent).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	"ac_bolsa_sacar_azar": {
		"cat": "acciones", "title": "Sacar de la bolsa",
		"help": "Saca una pieza al azar de una bolsa y la deja en la mesa (BagComponent).",
		"in": [["in", EXEC, ""], ["bolsa", PIECE, "bolsa"]], "out": [["out", EXEC, ""], ["pieza", PIECE, "pieza salida"]],
		"params": [],
	},
	"ac_bolsa_agregar": {
		"cat": "acciones", "title": "Agregar a la bolsa",
		"help": "Agrega una pieza a una bolsa (BagComponent).",
		"in": [["in", EXEC, ""], ["bolsa", PIECE, "bolsa"], ["pieza", PIECE, "pieza"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	"ac_nota_escribir": {
		"cat": "acciones", "title": "Escribir nota",
		"help": "Escribe texto en la nota de una pieza (NoteComponent).",
		"in": [["in", EXEC, ""], ["pieza", PIECE, "pieza"], ["texto", TEXT, "texto"]], "out": [["out", EXEC, ""]],
		"params": [["texto", "text", "Texto", ""]],
	},
	"ac_reloj_iniciar": {
		"cat": "acciones", "title": "Iniciar reloj",
		"help": "Arranca la cuenta atrás del reloj de una pieza (TimerComponent).",
		"in": [["in", EXEC, ""], ["reloj", PIECE, "reloj"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	"ac_reloj_parar": {
		"cat": "acciones", "title": "Parar reloj",
		"help": "Para la cuenta atrás del reloj de una pieza (TimerComponent).",
		"in": [["in", EXEC, ""], ["reloj", PIECE, "reloj"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	"ac_reloj_reiniciar": {
		"cat": "acciones", "title": "Reiniciar reloj",
		"help": "Reinicia el reloj de una pieza a su duración completa (TimerComponent).",
		"in": [["in", EXEC, ""], ["reloj", PIECE, "reloj"]], "out": [["out", EXEC, ""]],
		"params": [],
	},
	# ---------------------------------------------------------------- Twitch
	# Eventos del chat y del canal. «event» los marca como eventos aunque estén en su categoría.
	"tw_ev_mensaje": {
		"cat": "twitch", "event": true, "title": "Al escribir en el chat",
		"help": "Cualquier mensaje del chat que pase el filtro. Da el nombre, nunca el texto.",
		"in": [], "out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"], ["emotes", NUM, "emotes"]],
		"params": [["filtro", "choice:todos,empieza por,contiene,solo emotes", "Filtro", "todos"], ["texto", "text", "Texto del filtro", ""], ["quien", "choice:todos,suscriptores,VIP,moderadores", "Quién", "todos"]],
	},
	"tw_ev_comando": {
		"cat": "twitch", "event": true, "title": "Al usar un comando",
		"help": "Define un comando del chat: nombre, alias, argumento con tipo, quién puede y espera. Aparece solo en !ayuda.",
		"in": [], "out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"], ["valor", ANY, "valor"]],
		"params": [
			["comando", "text", "Comando", "!ataque"], ["alias", "text", "Alias (separados por comas)", ""],
			["argumento", "choice:ninguno,número,opción,casilla,jugador", "Argumento", "ninguno"],
			["minimo", "number", "Mínimo", 1], ["maximo", "number", "Máximo", 6], ["opciones", "text", "Opciones (rojo,azul…)", ""],
			["quien", "choice:todos,suscriptores,VIP,moderadores", "Quién puede", "todos"], ["espera", "number", "Espera por persona (s)", 5],
			["ayuda", "text", "Explicación para !ayuda", ""],
		],
	},
	"tw_ev_votacion": {
		"cat": "twitch", "event": true, "title": "Al cerrar una votación",
		"help": "Cuando termina la votación con ese nombre. Ganadora 0 = nadie votó.",
		"in": [], "out": [["out", EXEC, ""], ["ganadora", NUM, "ganadora"], ["opcion", TEXT, "opción"], ["votos", NUM, "votos"], ["total", NUM, "votantes"]],
		"params": [["nombre", "text", "Votación", "votación"]],
	},
	"tw_ev_bits": {
		"cat": "twitch", "event": true, "title": "Al animar con bits",
		"help": "Necesita el permiso de bits.", "in": [],
		"out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"], ["cantidad", NUM, "cantidad"]],
		"params": [["minimo", "number", "Desde (bits)", 1]],
	},
	"tw_ev_sub": {
		"cat": "twitch", "event": true, "title": "Al suscribirse",
		"help": "Nueva suscripción, renovación o regalo.", "in": [],
		"out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"], ["meses", NUM, "meses"], ["regalo", BOOL, "regalo"]],
		"params": [],
	},
	"tw_ev_follow": {
		"cat": "twitch", "event": true, "title": "Al seguir el canal",
		"help": "Un espectador nuevo sigue el canal.", "in": [],
		"out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"]], "params": [],
	},
	"tw_ev_raid": {
		"cat": "twitch", "event": true, "title": "Al llegar una raid",
		"help": "Otro canal llega con sus espectadores.", "in": [],
		"out": [["out", EXEC, ""], ["canal", TEXT, "canal"], ["espectadores", NUM, "espectadores"]],
		"params": [["minimo", "number", "Desde (espectadores)", 1]],
	},
	"tw_ev_canje": {
		"cat": "twitch", "event": true, "title": "Al canjear una recompensa",
		"help": "Puntos de canal: la recompensa la crea el bloque «Crear recompensa». Solo Afiliados y Partners.",
		"in": [], "out": [["out", EXEC, ""], ["usuario", TEXT, "usuario"]],
		"params": [["recompensa", "text", "Recompensa", "Girar la ruleta"]],
	},
	"tw_ev_hype": {
		"cat": "twitch", "event": true, "title": "Hype Train",
		"help": "Empieza, sube de nivel o termina el Hype Train del canal.", "in": [],
		"out": [["out", EXEC, ""], ["nivel", NUM, "nivel"]],
		"params": [["fase", "choice:empieza,sube de nivel,termina", "Cuándo", "empieza"]],
	},
	"tw_ev_anuncio": {
		"cat": "twitch", "event": true, "title": "Al empezar un anuncio",
		"help": "Ideal para pausar o lanzar una votación mientras pasan los anuncios.", "in": [],
		"out": [["out", EXEC, ""], ["segundos", NUM, "segundos"]], "params": [],
	},
	"tw_ev_conexion": {
		"cat": "twitch", "event": true, "title": "Al conectarse el chat",
		"help": "Cuando el chat (real o de prueba) empieza a llegar.", "in": [],
		"out": [["out", EXEC, ""]], "params": [],
	},
	# Acciones
	"tw_votacion": {
		"cat": "twitch", "title": "Abrir votación",
		"help": "El chat vota con !1, !2… Si le das piezas, cada opción lleva su número encima.",
		"in": [["in", EXEC, ""], ["piezas", LIST, "piezas"]], "out": [["out", EXEC, ""]],
		"params": [["nombre", "text", "Votación", "votación"], ["pregunta", "text", "Pregunta", "¿Qué hace el dragón?"], ["opciones", "text", "Opciones (separadas por comas)", "Atacar,Defender,Huir"], ["segundos", "number", "Segundos", 20]],
	},
	"tw_cerrar_votacion": {
		"cat": "twitch", "title": "Cerrar la votación ya",
		"help": "Cierra la votación abierta sin esperar al tiempo.",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [],
	},
	"tw_mostrar_chat": {
		"cat": "twitch", "title": "Mostrar el chat",
		"help": "El chat dentro del juego. Respeta la moderación y el filtro de palabras del streamer.",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]],
		"params": [["estilo", "choice:panel lateral,marquesina,pizarra,cartas que caen,bocadillos sobre fichas,solo reacciones", "Estilo", "panel lateral"], ["lado", "choice:derecha,izquierda", "Lado", "derecha"], ["mensajes", "choice:sin comandos,todo,solo comandos", "Mensajes", "sin comandos"]],
	},
	"tw_ocultar_chat": {
		"cat": "twitch", "title": "Ocultar el chat",
		"help": "Quita el chat de la pantalla.", "in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]], "params": [],
	},
	"tw_alerta": {
		"cat": "twitch", "title": "Mostrar alerta",
		"help": "Aviso grande en pantalla. Usa {usuario} y {cantidad} en el texto.",
		"in": [["in", EXEC, ""], ["usuario", TEXT, "usuario"], ["cantidad", NUM, "cantidad"]], "out": [["out", EXEC, ""]],
		"params": [["texto", "text", "Texto", "¡{usuario} anima con {cantidad} bits!"], ["segundos", "number", "Segundos", 4], ["sonido", "choice:fanfarria,pop,ninguno", "Sonido", "fanfarria"]],
	},
	"tw_meta": {
		"cat": "twitch", "title": "Barra de meta",
		"help": "Una barra de progreso en pantalla. Al llegar al máximo se llena entera.",
		"in": [["in", EXEC, ""], ["valor", NUM, "valor"]], "out": [["out", EXEC, ""]],
		"params": [["nombre", "text", "Meta", "Despertar al dragón"], ["maximo", "number", "Máximo", 500]],
	},
	"tw_monedas": {
		"cat": "twitch", "title": "Dar monedas al espectador",
		"help": "Monedas del juego (no de Twitch). Una cantidad negativa las quita.",
		"in": [["in", EXEC, ""], ["usuario", TEXT, "usuario"], ["cantidad", NUM, "cantidad"]], "out": [["out", EXEC, ""]], "params": [],
	},
	"tw_equipo": {
		"cat": "twitch", "title": "Asignar a un equipo",
		"help": "El espectador pasa a ese equipo.",
		"in": [["in", EXEC, ""], ["usuario", TEXT, "usuario"]], "out": [["out", EXEC, ""]],
		"params": [["equipo", "text", "Equipo", "rojo"]],
	},
	"tw_ficha": {
		"cat": "twitch", "title": "Dar ficha al espectador",
		"help": "Le asigna una pieza libre con esa etiqueta y escribe su nombre encima.",
		"in": [["in", EXEC, ""], ["usuario", TEXT, "usuario"]], "out": [["out", EXEC, ""], ["pieza", PIECE, "pieza"]],
		"params": [["etiqueta", "tag", "Etiqueta de las fichas", "espectador"]],
	},
	"tw_recompensa": {
		"cat": "twitch", "title": "Crear recompensa",
		"help": "Recompensa de puntos de canal mientras dura la partida. Solo Afiliados y Partners.",
		"in": [["in", EXEC, ""]], "out": [["out", EXEC, ""]],
		"params": [["titulo", "text", "Título", "Girar la ruleta"], ["coste", "number", "Coste (puntos)", 500]],
	},
	"tw_escribir": {
		"cat": "twitch", "title": "Escribir en el chat",
		"help": "El juego escribe en el chat del canal (un mensaje cada 3 s como mucho). El streamer puede desactivarlo.",
		"in": [["in", EXEC, ""], ["texto", TEXT, "texto"]], "out": [["out", EXEC, ""]], "params": [],
	},
	"tw_si_rol": {
		"cat": "twitch", "title": "Si el espectador es…",
		"help": "Elige un camino según el rol del espectador en el chat.",
		"in": [["in", EXEC, ""], ["usuario", TEXT, "usuario"]], "out": [["si", EXEC, "sí"], ["no", EXEC, "no"]],
		"params": [["rol", "choice:suscriptor,VIP,moderador,streamer", "Rol", "suscriptor"]],
	},
	# Datos
	"tw_da_monedas": {
		"cat": "twitch", "title": "Monedas de",
		"help": "Monedas del juego de un espectador.",
		"in": [["usuario", TEXT, "usuario"]], "out": [["monedas", NUM, "monedas"]], "params": [],
	},
	"tw_da_equipo": {
		"cat": "twitch", "title": "Equipo de",
		"help": "Equipo de un espectador (vacío si no tiene).",
		"in": [["usuario", TEXT, "usuario"]], "out": [["equipo", TEXT, "equipo"]], "params": [],
	},
	"tw_da_puntos_equipo": {
		"cat": "twitch", "title": "Monedas del equipo",
		"help": "Suma de las monedas de todo un equipo.",
		"in": [], "out": [["monedas", NUM, "monedas"]], "params": [["equipo", "text", "Equipo", "rojo"]],
	},
	"tw_da_ranking": {
		"cat": "twitch", "title": "Ranking de espectadores",
		"help": "Los que más monedas tienen, listos para escribir en una nota o una alerta.",
		"in": [], "out": [["texto", TEXT, "ranking"]], "params": [["cuantos", "number", "Cuántos", 3]],
	},
	"tw_da_azar": {
		"cat": "twitch", "title": "Espectador al azar",
		"help": "Uno de los que han escrito en los últimos 10 minutos (de un equipo, si lo pones).",
		"in": [], "out": [["usuario", TEXT, "usuario"]], "params": [["equipo", "text", "Equipo (opcional)", ""]],
	},
	"tw_da_activos": {
		"cat": "twitch", "title": "Espectadores activos",
		"help": "Cuántos han escrito en los últimos 10 minutos.",
		"in": [], "out": [["cantidad", NUM, "activos"]], "params": [],
	},
	"tw_da_votos": {
		"cat": "twitch", "title": "Votos de una opción",
		"help": "Recuento en directo de la votación abierta.",
		"in": [], "out": [["votos", NUM, "votos"]], "params": [["opcion", "number", "Opción", 1]],
	},
	"tw_da_ficha": {
		"cat": "twitch", "title": "Ficha de",
		"help": "La pieza que se dio a ese espectador.",
		"in": [["usuario", TEXT, "usuario"]], "out": [["pieza", PIECE, "pieza"]], "params": [],
	},
	"tw_da_conectado": {
		"cat": "twitch", "title": "¿Hay chat?",
		"help": "Sí si llega el chat de Twitch o el chat de prueba. Para que el juego funcione también sin directo.",
		"in": [], "out": [["si", BOOL, "sí/no"]], "params": [],
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
	return DEFS.has(type) and (DEFS[type]["cat"] == "eventos" or bool(DEFS[type].get("event", false)))


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
