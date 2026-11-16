class_name WardrobeUI
extends PanelContainer
## El armario: panel a la derecha para elegir color, sombrero y complemento del peón.
## Los cambios se ven al momento en el peón (Home acerca la cámara) y se guardan.
## Lo que aún no tienes sale con candado y te manda a Dadazon.

signal changed
signal closed

var _sections := {}


func _init() -> void:
	name = "Wardrobe"
	visible = false
	custom_minimum_size = Vector2(380, 0)
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -410
	offset_right = -24
	offset_top = 90
	offset_bottom = -80
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PANEL
	box.set_corner_radius_all(22)
	box.set_border_width_all(3)
	box.border_color = Palette.INK
	box.set_content_margin_all(20)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 12
	add_theme_stylebox_override("panel", box)
	set_meta(MenuStyle.DONE_META, true)


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(MenuStyle.make_eyebrow("EL ARMARIO", Palette.SUN))
	col.add_child(MenuStyle.make_title("Tu peón", 34))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for section in [["color", "Color"], ["hat", "Sombrero"], ["accessory", "Complemento"]]:
		var label := MenuStyle.make_muted(section[1], 14)
		label.add_theme_color_override("font_color", Palette.LAVENDER)
		list.add_child(label)
		var flow := HFlowContainer.new()
		flow.name = "Options_" + section[0]
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		list.add_child(flow)
		_sections[section[0]] = flow
	var done := Button.new()
	done.name = "Done"
	done.text = "Listo"
	done.custom_minimum_size = Vector2(0, 46)
	MenuStyle.style_primary(done, 12, 5)
	done.pressed.connect(close_wardrobe)
	col.add_child(done)


func open_wardrobe() -> void:
	visible = true
	_refresh()
	(find_child("Done", true, false) as Button).grab_focus.call_deferred()


func close_wardrobe() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for key in _sections:
		var flow := _sections[key] as HFlowContainer
		for child in flow.get_children():
			flow.remove_child(child)
			child.queue_free()
	# Colores: siempre todos.
	for i in HomePrefs.COLORS.size():
		var swatch := Button.new()
		swatch.name = "Color%d" % i
		swatch.custom_minimum_size = Vector2(40, 40)
		swatch.tooltip_text = HomePrefs.COLOR_NAMES[i]
		var box := StyleBoxFlat.new()
		box.bg_color = HomePrefs.COLORS[i]
		box.set_corner_radius_all(20)
		box.set_border_width_all(4 if i == HomePrefs.color_index() else 2)
		box.border_color = Palette.PAPER if i == HomePrefs.color_index() else Palette.INK
		for state in ["normal", "hover", "pressed", "focus"]:
			swatch.add_theme_stylebox_override(state, box)
		swatch.set_meta(MenuStyle.DONE_META, true)
		swatch.pressed.connect(func() -> void:
			HomePrefs.set_color_index(i)
			_changed()
		)
		_sections["color"].add_child(swatch)
	_options("hat", [ShopCatalog.NONE_HAT] + ShopCatalog.ids(ShopCatalog.HAT), HomePrefs.hat())
	_options("accessory", [ShopCatalog.NONE_ACCESSORY] + ShopCatalog.ids(ShopCatalog.ACCESSORY), HomePrefs.accessory())


func _options(section: String, ids: Array, current: String) -> void:
	for id in ids:
		var button := Button.new()
		button.name = "Wear_" + str(id)
		var owned := HomePrefs.owns(id)
		button.text = ShopCatalog.item_name(id) if owned else "🔒 " + tr(ShopCatalog.item_name(id))
		if not owned:
			button.tooltip_text = "Disponible en Dadazon, desde el ordenador."
			button.disabled = true
		if id == current:
			MenuStyle.style_primary(button, 10, 4)
		else:
			MenuStyle.style_secondary(button, 10, 4)
		button.pressed.connect(func() -> void:
			if section == "hat":
				HomePrefs.set_hat(id)
			else:
				HomePrefs.set_accessory(id)
			_changed()
		)
		_sections[section].add_child(button)


func _changed() -> void:
	changed.emit()
	_refresh()
