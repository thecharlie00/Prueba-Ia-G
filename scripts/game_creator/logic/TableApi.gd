# TableApi.gd
# «mesa»: lo que el código de los bloques GDScript puede hacer en el juego. Las piezas se
# manejan por su id (un texto) y las zonas y contadores, por su nombre. No tiene variables
# propias: el editor se busca en LogicHost, fuera del alcance del código.
class_name TableApi
extends RefCounted

const METHODS := [
	"ayuda", "piezas", "piezas_en_zona", "piezas_con_etiqueta", "nombre", "etiquetas", "tiene_etiqueta",
	"zona_de", "zonas", "mover", "repartir", "mezclar", "voltear", "tirar_dados", "ultima_tirada",
	"contador", "sumar", "poner", "mensaje", "variable", "guardar", "rango", "azar", "mostrar",
	"color", "texto_de", "escribir",
]

const HELP := """mesa.piezas() → todas las piezas (ids)
mesa.piezas_en_zona("Mazo") → piezas de una zona, de arriba abajo
mesa.piezas_con_etiqueta("rojo") → piezas con esa etiqueta
mesa.nombre(pieza) · mesa.etiquetas(pieza) · mesa.tiene_etiqueta(pieza, "rojo")
mesa.texto_de(pieza) · mesa.escribir(pieza, "7") · mesa.color(pieza)
mesa.zona_de(pieza) → nombre de su zona o "" · mesa.zonas() → nombres de las zonas
mesa.mover(pieza, "Mano") · mesa.repartir(5, "Mazo", "Mano") · mesa.mezclar("Mazo")
mesa.voltear(pieza) · mesa.tirar_dados() · mesa.ultima_tirada()
mesa.contador("Puntos") · mesa.sumar("Puntos", 3) · mesa.poner("Puntos", 0)
mesa.mostrar("Reglas", true) · mesa.mensaje("¡Tu turno!")
mesa.variable("turno") · mesa.guardar("turno", 2)
mesa.rango(10) → [0..9] para «for» · mesa.azar(1, 6)"""


func _editor() -> Node:
	return LogicHost.editor_for(self)


func ayuda() -> String:
	return HELP


func piezas() -> Array:
	var e := _editor()
	return e.logic_pieces("", "") if e != null else []


func piezas_en_zona(zona: String, etiqueta := "") -> Array:
	var e := _editor()
	return e.logic_pieces(e.logic_zone_id(zona), etiqueta) if e != null else []


func piezas_con_etiqueta(etiqueta: String) -> Array:
	var e := _editor()
	return e.logic_pieces("", etiqueta) if e != null else []


func nombre(pieza: String) -> String:
	var e := _editor()
	return e.logic_piece_name(pieza) if e != null else ""


func etiquetas(pieza: String) -> Array:
	var e := _editor()
	return e.logic_piece_tags(pieza) if e != null else []


func tiene_etiqueta(pieza: String, etiqueta: String) -> bool:
	return etiqueta.strip_edges().to_lower() in etiquetas(pieza)


func texto_de(pieza: String) -> String:
	var e := _editor()
	return e.logic_piece_label(pieza) if e != null else ""


func escribir(pieza: String, texto: Variant) -> void:
	var e := _editor()
	if e != null:
		e.logic_set_label(pieza, str(texto))


func color(pieza: String) -> Color:
	var e := _editor()
	return e.logic_piece_color(pieza) if e != null else Color.WHITE


func zona_de(pieza: String) -> String:
	var e := _editor()
	return e.logic_zone_of(pieza) if e != null else ""


func zonas() -> Array:
	var e := _editor()
	return e.logic_zone_names() if e != null else []


func mover(pieza: String, zona: String) -> void:
	var e := _editor()
	if e != null:
		e.logic_move(pieza, e.logic_zone_id(zona))


func repartir(cantidad: int, de: String, a: String, etiqueta := "") -> int:
	var e := _editor()
	return e.logic_deal(cantidad, e.logic_zone_id(de), e.logic_zone_id(a), etiqueta) if e != null else 0


func mezclar(zona: String) -> void:
	var e := _editor()
	if e != null:
		e.logic_shuffle(e.logic_zone_id(zona))


func voltear(pieza: String) -> void:
	var e := _editor()
	if e != null:
		e.logic_flip(pieza)


func tirar_dados() -> void:
	var e := _editor()
	if e != null:
		e.roll_dice()


func ultima_tirada() -> int:
	var e := _editor()
	if e == null:
		return 0
	var total := 0
	for value in e.last_roll:
		total += value
	return total


func contador(nombre_contador: Variant) -> int:
	var e := _editor()
	return e.logic_counter(nombre_contador) if e != null else 0


func sumar(nombre_contador: Variant, cantidad := 1) -> void:
	var e := _editor()
	if e != null:
		e.logic_set_counter(nombre_contador, e.logic_counter(nombre_contador) + int(cantidad))


func poner(nombre_contador: Variant, valor: Variant) -> void:
	var e := _editor()
	if e != null:
		e.logic_set_counter(nombre_contador, int(valor))


func mostrar(elemento: Variant, visible := true) -> void:
	var e := _editor()
	if e != null:
		e.logic_show_element(elemento, visible)


func mensaje(texto: Variant) -> void:
	var e := _editor()
	if e != null:
		e.logic_message(str(texto))


func variable(nombre_variable: String) -> Variant:
	var e := _editor()
	return e.logic_variable(nombre_variable) if e != null else null


func guardar(nombre_variable: String, valor: Variant) -> void:
	var e := _editor()
	if e != null:
		e.logic_store(nombre_variable, valor)


## Lista 0..n-1 para recorrer con «for». Comparte un límite por ejecución: un bucle sin fin
## no puede colgar el juego.
func rango(n: int) -> Array:
	var granted := LogicHost.spend(self, maxi(n, 0))
	if granted < n:
		var e := _editor()
		if e != null:
			e.logic_message("Un bloque GDScript ha repetido demasiadas veces y se ha cortado.")
	return range(granted)


func azar(desde: int, hasta: int) -> int:
	return randi_range(mini(desde, hasta), maxi(desde, hasta))
