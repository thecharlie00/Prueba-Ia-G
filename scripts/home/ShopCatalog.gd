class_name ShopCatalog
## Catálogo de Dadazon, la tienda del ordenador de la habitación («lo tiras hoy, lo tienes
## en un turno»). Decoración para la sala y ropa para el peón. Se paga con fichas, que se
## ganan jugando en las mesas.

const STORE_NAME := "dadazon"
const DECOR := "decor"
const HAT := "hat"
const ACCESSORY := "accessory"

## id → datos. «name» y «blurb» se traducen al mostrarlos; «stars» y «reviews» son de broma.
const ITEMS := {
	# Decoración
	"botito": {"kind": DECOR, "name": "Botito", "price": 240, "stars": 5.0, "reviews": 3120,
		"blurb": "Un bot de bolsillo que te sigue a todas partes. No sabe jugar, pero anima."},
	"sofa": {"kind": DECOR, "name": "Sofá mullido", "price": 180, "stars": 4.8, "reviews": 912,
		"blurb": "Para esperar turno con estilo. Incluye un cojín que nadie usa."},
	"bola_disco": {"kind": DECOR, "name": "Bola de discoteca", "price": 160, "stars": 4.9, "reviews": 1544,
		"blurb": "Gira, brilla y convierte cualquier partida de damas en una fiesta."},
	"pecera": {"kind": DECOR, "name": "Pecera con Pipo", "price": 120, "stars": 4.7, "reviews": 688,
		"blurb": "Pipo no juega al parchís, pero mira las partidas con mucha atención."},
	"lampara": {"kind": DECOR, "name": "Lámpara de pie", "price": 90, "stars": 4.6, "reviews": 402,
		"blurb": "Luz cálida para las partidas que se alargan."},
	"neon": {"kind": DECOR, "name": "Neón «¡A jugar!»", "price": 140, "stars": 4.8, "reviews": 977,
		"blurb": "Por si alguien en la sala aún no lo había entendido."},
	"trofeo": {"kind": DECOR, "name": "Trofeo de peón dorado", "price": 200, "stars": 4.9, "reviews": 230,
		"blurb": "Premio al mejor jugador de la habitación. Spoiler: eres tú."},
	"cactus": {"kind": DECOR, "name": "Cactus Pincho", "price": 40, "stars": 4.4, "reviews": 151,
		"blurb": "No necesita riego ni atención. Como un bot fácil."},
	# Sombreros
	"gorro": {"kind": HAT, "name": "Gorro de lana", "price": 0, "stars": 4.5, "reviews": 88,
		"blurb": "Calentito."},
	"gorra": {"kind": HAT, "name": "Gorra", "price": 60, "stars": 4.5, "reviews": 340,
		"blurb": "Visera hacia delante. Para jugar serio."},
	"cono": {"kind": HAT, "name": "Gorro de fiesta", "price": 40, "stars": 4.7, "reviews": 512,
		"blurb": "Para celebrar cada seis que saques."},
	"flor": {"kind": HAT, "name": "Flor", "price": 50, "stars": 4.6, "reviews": 203,
		"blurb": "Una margarita que nunca se marchita."},
	"auriculares": {"kind": HAT, "name": "Auriculares", "price": 90, "stars": 4.6, "reviews": 266,
		"blurb": "Concentración máxima en la brisca."},
	"chistera": {"kind": HAT, "name": "Chistera", "price": 120, "stars": 4.8, "reviews": 145,
		"blurb": "Elegancia de campeón de ajedrez."},
	"corona": {"kind": HAT, "name": "Corona", "price": 150, "stars": 5.0, "reviews": 999,
		"blurb": "Coronación garantizada, como en las damas."},
	# Complementos
	"gafas": {"kind": ACCESSORY, "name": "Gafas redondas", "price": 0, "stars": 4.4, "reviews": 60,
		"blurb": "Para leer bien las reglas."},
	"pajarita": {"kind": ACCESSORY, "name": "Pajarita", "price": 50, "stars": 4.7, "reviews": 301,
		"blurb": "Imprescindible en una final."},
	"bufanda": {"kind": ACCESSORY, "name": "Bufanda", "price": 70, "stars": 4.6, "reviews": 187,
		"blurb": "Tejida a mano por una abuela que gana al dominó."},
	"bigote": {"kind": ACCESSORY, "name": "Bigote", "price": 40, "stars": 4.3, "reviews": 422,
		"blurb": "Da un aire de jugador veterano."},
}
## Opciones «nada» del armario (siempre tuyas).
const NONE_HAT := "sin_sombrero"
const NONE_ACCESSORY := "sin_complemento"


static func ids(of_kind := "") -> Array:
	var list := []
	for id in ITEMS:
		if of_kind.is_empty() or ITEMS[id]["kind"] == of_kind:
			list.append(id)
	return list


static func kind(id: String) -> String:
	if id == NONE_HAT:
		return HAT
	if id == NONE_ACCESSORY:
		return ACCESSORY
	return str(ITEMS.get(id, {}).get("kind", ""))


static func item_name(id: String) -> String:
	if id == NONE_HAT:
		return "Sin sombrero"
	if id == NONE_ACCESSORY:
		return "Nada"
	return str(ITEMS.get(id, {}).get("name", id))


static func price(id: String) -> int:
	return int(ITEMS.get(id, {}).get("price", 0))


static func thumb_path(id: String) -> String:
	return "res://assets/shop/%s.png" % id
