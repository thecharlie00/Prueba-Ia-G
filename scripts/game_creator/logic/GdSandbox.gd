# GdSandbox.gd
# Comprueba y compila el código de los bloques GDScript de la lógica de un juego.
#
# Los juegos se comparten como archivos, así que su código no puede tocar nada fuera de la
# mesa: sólo se permite usar `mesa` (la API del juego), las entradas `a` y `b`, variables
# propias y funciones de cálculo. Cualquier otro nombre (OS, FileAccess, load, get_tree,
# call…) se rechaza antes de compilar, igual que `while`, `func`, `await` o `$`. Los bucles
# se hacen con `for` sobre listas o sobre `mesa.rango(n)`, que tiene un límite por ejecución.
class_name GdSandbox
extends RefCounted

const KEYWORDS := [
	"if", "elif", "else", "for", "in", "var", "const", "return", "and", "or", "not", "match",
	"pass", "break", "continue", "is", "as", "when", "true", "false", "null",
]
const BANNED_KEYWORDS := [
	"while", "func", "class", "class_name", "extends", "signal", "await", "static", "preload",
	"load", "breakpoint", "super", "self", "enum", "yield", "assert", "set", "get", "tool",
]
const GLOBALS := [
	"mesa", "a", "b", "PI", "TAU", "INF", "NAN",
	"abs", "absf", "absi", "ceil", "ceili", "floor", "floori", "round", "roundi", "sign", "signf", "signi",
	"clamp", "clampf", "clampi", "min", "minf", "mini", "max", "maxf", "maxi", "sqrt", "pow", "exp", "log",
	"sin", "cos", "tan", "atan2", "lerp", "lerpf", "inverse_lerp", "remap", "snapped", "snappedf",
	"wrapi", "wrapf", "fmod", "fposmod", "posmod", "is_equal_approx", "deg_to_rad", "rad_to_deg",
	"randi_range", "randf_range", "randf", "randi", "str", "int", "float", "bool", "len", "typeof",
	"print", "Vector2", "Vector3", "Color", "Array", "Dictionary", "String",
	"TYPE_NIL", "TYPE_BOOL", "TYPE_INT", "TYPE_FLOAT", "TYPE_STRING", "TYPE_ARRAY", "TYPE_DICTIONARY",
]
## Métodos y campos que se pueden usar tras un punto: los de `mesa` y los de listas,
## diccionarios, textos y vectores que no salen de la mesa.
const MEMBERS := [
	"size", "append", "push_back", "push_front", "pop_back", "pop_front", "pop_at", "has", "find", "rfind",
	"erase", "clear", "keys", "values", "sort", "shuffle", "pick_random", "slice", "is_empty", "count",
	"join", "split", "to_upper", "to_lower", "strip_edges", "begins_with", "ends_with", "contains",
	"replace", "length", "x", "y", "z", "r", "g", "b", "a", "reverse", "insert", "remove_at", "front",
	"back", "max", "min", "capitalize", "to_int", "to_float", "is_valid_int", "is_valid_float",
	"pad_zeros", "left", "right", "substr", "abs", "floor", "ceil", "round", "normalized", "distance_to",
	"lerp", "merge",
]


## Nombres de la API `mesa` (TableApi), que también valen tras un punto.
static func api_names() -> Array:
	return TableApi.METHODS


## Comprueba el código. Devuelve "" si vale, o el motivo y la línea si no.
static func check(code: String) -> String:
	if code.length() > LogicGraph.MAX_CODE:
		return "El código es demasiado largo."
	var tokens: Variant = _tokens(code)
	if tokens is String:
		return tokens
	var locals := {}
	for i in tokens.size():
		var token: Dictionary = tokens[i]
		if token["kind"] == "id" and token["text"] in ["var", "const", "for"] and i + 1 < tokens.size() and tokens[i + 1]["kind"] == "id":
			locals[tokens[i + 1]["text"]] = true
	for i in tokens.size():
		var token: Dictionary = tokens[i]
		var text: String = token["text"]
		if token["kind"] == "symbol":
			if text in ["$", "@"]:
				return _at(token, "«%s» no se puede usar aquí." % text)
			continue
		if token["kind"] != "id":
			continue
		if text in BANNED_KEYWORDS:
			return _at(token, "«%s» no se puede usar en un bloque (usa «for» con mesa.rango(n) para repetir)." % text)
		var member: bool = i > 0 and tokens[i - 1]["kind"] == "symbol" and tokens[i - 1]["text"] == "."
		if member:
			if not (text in MEMBERS or text in api_names()):
				return _at(token, "«.%s» no está permitido. Mira mesa.ayuda() para ver qué se puede usar." % text)
			continue
		if text in KEYWORDS or text in GLOBALS or locals.has(text):
			continue
		return _at(token, "«%s» no existe aquí. Usa variables con «var», o mesa.ayuda()." % text)
	return ""


## Compila el código como función `ejecutar(mesa, a, b)`. {"script": GDScript} o {"error": texto}.
static func compile(code: String) -> Dictionary:
	var problem := check(code)
	if problem != "":
		return {"error": problem}
	var lines: Array = []
	var least := 1000
	for line in code.replace("\r", "").split("\n"):
		# Cuatro espacios equivalen a un tabulador: así no se mezclan en la sangría.
		var depth := 0
		var rest: String = line
		while true:
			if rest.begins_with("\t"):
				rest = rest.substr(1)
				depth += 1
			elif rest.begins_with("    "):
				rest = rest.substr(4)
				depth += 1
			else:
				break
		lines.append([depth, rest])
		if rest.strip_edges() != "":
			least = mini(least, depth)
	var body := PackedStringArray()
	for item in lines:
		# Si todo el código venía sangrado, se quita la sangría común.
		body.append("\t".repeat(maxi(int(item[0]) - least, 0) + 1) + str(item[1]))
	var source := "extends RefCounted\n\nfunc ejecutar(mesa, a, b):\n" + "\n".join(body) + "\n\treturn null\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return {"error": "El código tiene un error de escritura (revisa la sangría, los paréntesis y los dos puntos)."}
	return {"script": script}


static func _at(token: Dictionary, message: String) -> String:
	return "Línea %d: %s" % [int(token["line"]), message]


## Trocea el código en nombres, números, textos y símbolos (sin comentarios).
static func _tokens(code: String) -> Variant:
	var tokens: Array = []
	var i := 0
	var line := 1
	var n := code.length()
	while i < n:
		var c := code[i]
		if c == "\n":
			line += 1
			i += 1
		elif c == " " or c == "\t" or c == "\r":
			i += 1
		elif c == "#":
			while i < n and code[i] != "\n":
				i += 1
		elif c == "\"" or c == "'":
			var triple := code.substr(i, 3) == c.repeat(3)
			var quote := c.repeat(3) if triple else c
			var j := i + quote.length()
			var closed := false
			while j < n:
				if code[j] == "\\":
					j += 2
					continue
				if code.substr(j, quote.length()) == quote:
					closed = true
					break
				if code[j] == "\n":
					if not triple:
						break
					line += 1
				j += 1
			if not closed:
				return "Línea %d: falta cerrar unas comillas." % line
			tokens.append({"kind": "string", "text": code.substr(i, j + quote.length() - i), "line": line})
			i = j + quote.length()
		elif c.is_valid_identifier() or c == "_":
			var j := i
			while j < n and (code[j].is_valid_identifier() or code[j] == "_" or code[j].is_valid_int()):
				j += 1
			tokens.append({"kind": "id", "text": code.substr(i, j - i), "line": line})
			i = j
		elif c.is_valid_int():
			var j := i
			while j < n and (code[j].is_valid_int() or code[j] in [".", "_", "e", "x", "b"] or code[j].to_lower() in ["a", "c", "d", "f"]):
				# Un punto seguido de letra es un acceso a miembro, no parte del número.
				if code[j] == "." and j + 1 < n and code[j + 1].is_valid_identifier() and not code[j + 1].is_valid_int():
					break
				j += 1
			tokens.append({"kind": "number", "text": code.substr(i, j - i), "line": line})
			i = j
		else:
			tokens.append({"kind": "symbol", "text": c, "line": line})
			i += 1
	return tokens
