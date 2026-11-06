extends Node
## Idioma de la interfaz (queja 12 de TTS): español, inglés y catalán. Los textos de los
## controles se traducen solos (auto_translate de Godot) a partir de UiStrings; los textos
## con números usan tr() con una plantilla. Se recuerda en este equipo.

const LANGUAGES := {"es": "Español", "en": "English", "ca": "Català"}
const ORDER := ["es", "en", "ca"]

signal language_changed(code: String)

var language := "es"
var settings_path := "user://diceon_controls.cfg"


func _ready() -> void:
	# También el español como traducción identidad: si el idioma de reserva del motor fuera
	# otro, el español nunca caería en él.
	for column in [0, 1, 2]:
		var translation := Translation.new()
		translation.locale = ORDER[column]
		for row in UiStrings.ROWS:
			translation.add_message(row[0], row[column])
		TranslationServer.add_translation(translation)
	set_language(_saved_language(), false)


func _saved_language() -> String:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		var saved: Variant = config.get_value("ui", "language", "")
		if saved is String and LANGUAGES.has(saved):
			return saved
	# Sin ajuste guardado: el idioma del sistema si lo tenemos; en pruebas, español.
	if DisplayServer.get_name() == "headless":
		return "es"
	var system := OS.get_locale_language()
	return system if LANGUAGES.has(system) else "es"


func set_language(code: String, save := true) -> void:
	if not LANGUAGES.has(code):
		return
	language = code
	TranslationServer.set_locale(code)
	if save:
		var config := ConfigFile.new()
		config.load(settings_path)
		config.set_value("ui", "language", code)
		config.save(settings_path)
	language_changed.emit(code)


## Selector de idioma listo para poner en un menú.
func make_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "Language"
	for index in ORDER.size():
		selector.add_item(LANGUAGES[ORDER[index]], index)
	selector.selected = ORDER.find(language)
	selector.item_selected.connect(func(index: int) -> void: set_language(ORDER[index]))
	return selector
