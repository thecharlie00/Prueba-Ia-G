class_name HomePrefs
## Lo que se guarda de la habitación (user://tablerama_home.cfg): aspecto del peón, menú
## clásico, fichas, lo comprado en Dadazon, los paquetes sin abrir y la decoración puesta.

const DEFAULT_PATH := "user://tablerama_home.cfg"
const COLORS := [
	Color("ffc83d"), Color("ff6b5e"), Color("4fa3ff"), Color("5fd3a0"),
	Color("b48cff"), Color("ff9d4d"), Color("f3effa"),
]
const COLOR_NAMES := ["Amarillo", "Coral", "Azul", "Menta", "Lavanda", "Naranja", "Nata"]
## Fichas con las que se empieza: para que la primera compra no espere a nadie.
const STARTING_COINS := 150
## Lo que se tiene desde el principio.
const STARTER_ITEMS := ["sin_sombrero", "gorro", "sin_complemento", "gafas"]

## Las pruebas lo cambian para no tocar el archivo del jugador.
static var path := DEFAULT_PATH


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(path)
	return config


static func _value(key: String, fallback: Variant) -> Variant:
	return _load().get_value("home", key, fallback)


static func _store(key: String, value: Variant) -> void:
	var config := _load()
	config.set_value("home", key, value)
	config.save(path)


# --- Peón ------------------------------------------------------------------------

static func color_index() -> int:
	return clampi(int(_value("pawn_color", 0)), 0, COLORS.size() - 1)


static func set_color_index(index: int) -> void:
	_store("pawn_color", posmod(index, COLORS.size()))


static func pawn_color() -> Color:
	return COLORS[color_index()]


static func hat() -> String:
	return str(_value("hat", "sin_sombrero"))


static func set_hat(id: String) -> void:
	_store("hat", id)


static func accessory() -> String:
	return str(_value("accessory", "sin_complemento"))


static func set_accessory(id: String) -> void:
	_store("accessory", id)


# --- Menú clásico ----------------------------------------------------------------

## true: al arrancar y al volver de una mesa se abre la portada clásica, no la habitación.
static func classic_menu() -> bool:
	return bool(_value("classic_menu", false))


static func set_classic_menu(enabled: bool) -> void:
	_store("classic_menu", enabled)


# --- Fichas y compras ----------------------------------------------------------------

static func coins() -> int:
	return int(_value("coins", STARTING_COINS))


static func add_coins(amount: int) -> void:
	_store("coins", maxi(0, coins() + amount))


static func owned() -> Array:
	var list: Array = (_value("owned", []) as Array).duplicate()
	for id in STARTER_ITEMS:
		if not list.has(id):
			list.append(id)
	return list


static func owns(id: String) -> bool:
	return owned().has(id)


## Compra: descuenta las fichas, lo marca como tuyo y deja el paquete en camino.
## Devuelve false si ya lo tienes o no te llegan las fichas.
static func buy(id: String, price: int) -> bool:
	if owns(id) or coins() < price:
		return false
	var list: Array = (_value("owned", []) as Array).duplicate()
	list.append(id)
	var parcels := deliveries()
	parcels.append(id)
	var config := _load()
	config.set_value("home", "coins", coins() - price)
	config.set_value("home", "owned", list)
	config.set_value("home", "deliveries", parcels)
	config.save(path)
	return true


## Paquetes comprados que todavía no se han abierto.
static func deliveries() -> Array:
	return (_value("deliveries", []) as Array).duplicate()


## Abre un paquete: la decoración pasa a estar puesta en la habitación.
static func open_delivery(id: String) -> void:
	var parcels := deliveries()
	parcels.erase(id)
	var placed := placed_decor()
	if ShopCatalog.kind(id) == ShopCatalog.DECOR and not placed.has(id):
		placed.append(id)
	var config := _load()
	config.set_value("home", "deliveries", parcels)
	config.set_value("home", "placed", placed)
	config.save(path)


static func placed_decor() -> Array:
	return (_value("placed", []) as Array).duplicate()
