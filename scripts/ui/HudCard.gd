class_name HudCard
extends RefCounted
## Tarjetas de la interfaz de mesa que no llenan la pantalla: tan altas como su contenido y con
## una sección «Más» plegada donde va lo que no hace falta en cada turno (bots, guardar,
## reglas, atajos). La usan las mesas con panel propio (parchís, ludo, isla).

## Añade al encabezado el botón «⋯» y devuelve el contenedor plegable, ya añadido a `column`.
## Lo que se meta en él solo se ve al desplegar.
static func more_section(column: VBoxContainer, header: HBoxContainer) -> VBoxContainer:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var toggle := Button.new()
	toggle.name = "MoreToggle"
	toggle.text = "⋯"
	toggle.toggle_mode = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.tooltip_text = "Más opciones: bots, guardar, reglas y atajos"
	toggle.custom_minimum_size = Vector2(40, 32)
	MenuStyle.style_subtle(toggle, 14)
	header.add_child(toggle)
	var more := VBoxContainer.new()
	more.name = "More"
	more.visible = false
	more.add_theme_constant_override("separation", 7)
	column.add_child(more)
	toggle.toggled.connect(func(open: bool) -> void:
		more.visible = open
		toggle.text = "✕" if open else "⋯"
		var card := column.get_parent() as Control
		if card != null:
			card.reset_size.call_deferred()
	)
	return more


## Coloca una tarjeta arriba a la izquierda, con su ancho y la altura de su contenido.
static func float_top_left(card: Control, width: float, margin: float = 18.0) -> void:
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = margin
	card.offset_top = margin
	card.offset_right = margin + width
	card.offset_bottom = margin
	card.custom_minimum_size.x = width
