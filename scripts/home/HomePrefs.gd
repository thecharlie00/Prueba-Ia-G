class_name HomePrefs
## Preferencias de la habitación: color del peón y si se prefiere el menú clásico.

const PATH := "user://tablerama_home.cfg"
const COLORS := [
	Color("ffc83d"), Color("ff6b5e"), Color("4fa3ff"), Color("5fd3a0"),
	Color("b48cff"), Color("ff9d4d"), Color("f3effa"),
]
const COLOR_NAMES := ["Amarillo", "Coral", "Azul", "Menta", "Lavanda", "Naranja", "Nata"]


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config


static func _store(key: String, value: Variant) -> void:
	var config := _load()
	config.set_value("home", key, value)
	config.save(PATH)


static func color_index() -> int:
	return clampi(int(_load().get_value("home", "pawn_color", 0)), 0, COLORS.size() - 1)


static func set_color_index(index: int) -> void:
	_store("pawn_color", posmod(index, COLORS.size()))


static func pawn_color() -> Color:
	return COLORS[color_index()]


## true: al arrancar y al volver de una mesa se abre la portada clásica, no la habitación.
static func classic_menu() -> bool:
	return bool(_load().get_value("home", "classic_menu", false))


static func set_classic_menu(enabled: bool) -> void:
	_store("classic_menu", enabled)
