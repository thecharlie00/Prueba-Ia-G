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
	"color", "texto_de", "escribir", "jugador", "jugadores", "nombre_jugador", "pasar_turno", "dar_turno", "mano",
	"cartas_en_mazo", "carta_arriba", "repartir_mazo",
	"contador_valor", "contador_sumar", "contador_poner", "contador_resetear",
	"bolsa_contar", "bolsa_sacar_azar", "bolsa_agregar",
	"nota_leer", "nota_escribir",
	"reloj_iniciar", "reloj_parar", "reloj_reiniciar", "reloj_tiempo",
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
mesa.jugador() → número del jugador del turno (1, 2…) · mesa.jugadores() · mesa.nombre_jugador(n)
mesa.pasar_turno() · mesa.dar_turno(2) · mesa.mano() → zona de la mano del turno (o mesa.mano(n))
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


func jugador() -> int:
	var e := _editor()
	return e.current_player + 1 if e != null else 1


func jugadores() -> int:
	var e := _editor()
	return e.players if e != null else 1


func nombre_jugador(n := 0) -> String:
	var e := _editor()
	return GamePlayers.player_name((n - 1) if n > 0 else (e.current_player if e != null else 0))


func pasar_turno() -> void:
	var e := _editor()
	if e != null:
		e.logic_pass_turn()


func dar_turno(n: int) -> void:
	var e := _editor()
	if e != null:
		e.logic_give_turn(n - 1)


## Nombre de la zona de mano de un jugador (sin número: la del turno).
func mano(n := 0) -> String:
	var e := _editor()
	if e == null:
		return ""
	var zone: String = e.hand_zone_of((n - 1) if n > 0 else e.current_player)
	return e.logic_piece_name(zone)


## Número de cartas en un mazo (pieza con DeckComponent).
func cartas_en_mazo(pieza: String) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var deck := entity.get_component("DeckComponent") as DeckComponent
	return deck.count() if deck != null else 0


## Nombre de la carta de arriba de un mazo, o "" si no es mazo o está vacío.
func carta_arriba(pieza: String) -> String:
	var e := _editor()
	if e == null:
		return ""
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return ""
	var deck := entity.get_component("DeckComponent") as DeckComponent
	if deck == null or deck.is_empty():
		return ""
	return str(deck.top_card().get("name", ""))


## Reparte `cantidad` cartas de un mazo a una zona. Devuelve cuántas repartió.
func repartir_mazo(pieza: String, cantidad: int, zona: String) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var deck := entity.get_component("DeckComponent") as DeckComponent
	if deck == null:
		return 0
	return deck.deal_to_zone(int(cantidad), e, zona)


## Valor del contador de una pieza (pieza con CounterComponent).
func contador_valor(pieza: String) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var counter := entity.get_component("CounterComponent") as CounterComponent
	return counter.value if counter != null else 0

## Suma `cantidad` al contador de una pieza. Devuelve el valor resultante.
func contador_sumar(pieza: String, cantidad: int) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var counter := entity.get_component("CounterComponent") as CounterComponent
	if counter == null:
		return 0
	return counter.add(int(cantidad))

## Pone el contador de una pieza a `valor`. Devuelve el valor resultante.
func contador_poner(pieza: String, valor: int) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var counter := entity.get_component("CounterComponent") as CounterComponent
	if counter == null:
		return 0
	return counter.set_value(int(valor))

## Pone el contador de una pieza a su mínimo. Devuelve el valor resultante.
func contador_resetear(pieza: String) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var counter := entity.get_component("CounterComponent") as CounterComponent
	if counter == null:
		return 0
	return counter.reset()

## Número de piezas dentro de una bolsa (pieza con BagComponent).
func bolsa_contar(pieza: String) -> int:
	var e := _editor()
	if e == null:
		return 0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0
	var bag := entity.get_component("BagComponent") as BagComponent
	return bag.count() if bag != null else 0

## Saca una pieza al azar de una bolsa y devuelve su entity_id, o "" si está vacía.
func bolsa_sacar_azar(pieza: String) -> String:
	var e := _editor()
	if e == null:
		return ""
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return ""
	var bag := entity.get_component("BagComponent") as BagComponent
	return bag.draw_random() if bag != null else ""

## Añade una pieza (por entity_id) a una bolsa. Devuelve true si se pudo.
func bolsa_agregar(pieza: String, entidad: String) -> bool:
	var e := _editor()
	if e == null:
		return false
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return false
	var bag := entity.get_component("BagComponent") as BagComponent
	if bag == null:
		return false
	return bag.add(str(entidad))

## Lee el texto de una nota (pieza con NoteComponent).
func nota_leer(pieza: String) -> String:
	var e := _editor()
	if e == null:
		return ""
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return ""
	var note := entity.get_component("NoteComponent") as NoteComponent
	return note.get_text() if note != null else ""

## Escribe el texto de una nota (pieza con NoteComponent).
func nota_escribir(pieza: String, texto: String) -> void:
	var e := _editor()
	if e == null:
		return
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return
	var note := entity.get_component("NoteComponent") as NoteComponent
	if note != null:
		note.set_text(str(texto))

## Inicia el reloj de una pieza (pieza con TimerComponent).
func reloj_iniciar(pieza: String) -> void:
	var e := _editor()
	if e == null:
		return
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return
	var timer := entity.get_component("TimerComponent") as TimerComponent
	if timer != null:
		timer.start()

## Para el reloj de una pieza.
func reloj_parar(pieza: String) -> void:
	var e := _editor()
	if e == null:
		return
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return
	var timer := entity.get_component("TimerComponent") as TimerComponent
	if timer != null:
		timer.stop()

## Reinicia el reloj de una pieza a su duración completa.
func reloj_reiniciar(pieza: String) -> void:
	var e := _editor()
	if e == null:
		return
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return
	var timer := entity.get_component("TimerComponent") as TimerComponent
	if timer != null:
		timer.reset()

## Tiempo restante del reloj de una pieza (segundos).
func reloj_tiempo(pieza: String) -> float:
	var e := _editor()
	if e == null:
		return 0.0
	var entity: PropEntity = e._find_piece(pieza) as PropEntity
	if entity == null:
		return 0.0
	var timer := entity.get_component("TimerComponent") as TimerComponent
	return timer.remaining() if timer != null else 0.0


func azar(desde: int, hasta: int) -> int:
	return randi_range(mini(desde, hasta), maxi(desde, hasta))
