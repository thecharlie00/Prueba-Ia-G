class_name ShopUI
extends ColorRect
## Dadazon en el ordenador de la habitación: una web de tienda dentro del juego.
## «Lo tiras hoy, lo tienes en un turno». Al comprar, el pedido llega en una caja a la puerta.

signal purchased(id: String)
signal closed

const TABS := [["decor", "Decoración"], ["wear", "Ropa para tu peón"]]

var _grid: GridContainer
var _balance: Label
var _notice: Label
var _tab := "decor"
var _tab_buttons := {}


## La sonrisa del logo: un arco con punta de flecha, como el de cierta tienda (pero de dado).
class Smile:
	extends Control
	func _draw() -> void:
		var w := size.x
		var points := PackedVector2Array()
		for i in 21:
			var t := float(i) / 20.0
			points.append(Vector2(lerpf(4.0, w - 10.0, t), 4.0 + sin(t * PI) * 9.0))
		draw_polyline(points, Palette.SUN, 4.0, true)
		var tip := points[points.size() - 1]
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, -8), tip + Vector2(8, -3), tip + Vector2(-2, 6)]), Palette.SUN)


func _init() -> void:
	name = "Shop"
	color = Color(MenuBackdrop.VEIL, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var window := PanelContainer.new()
	window.name = "Browser"
	window.custom_minimum_size = Vector2(980, 600)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Palette.PAPER
	frame.set_corner_radius_all(18)
	frame.set_border_width_all(4)
	frame.border_color = Palette.INK
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 8)
	window.add_theme_stylebox_override("panel", frame)
	window.set_meta(MenuStyle.DONE_META, true)
	center.add_child(window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	window.add_child(col)

	# Barra del navegador.
	var chrome := PanelContainer.new()
	var chrome_box := StyleBoxFlat.new()
	chrome_box.bg_color = Color("e9e3f2")
	chrome_box.corner_radius_top_left = 14
	chrome_box.corner_radius_top_right = 14
	chrome_box.set_content_margin_all(10)
	chrome.add_theme_stylebox_override("panel", chrome_box)
	chrome.set_meta(MenuStyle.DONE_META, true)
	col.add_child(chrome)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	chrome.add_child(bar)
	for dot in [Palette.CORAL, Palette.SUN, Palette.MINT]:
		var light := Panel.new()
		light.custom_minimum_size = Vector2(14, 14)
		light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pip_box := StyleBoxFlat.new()
		pip_box.bg_color = dot
		pip_box.set_corner_radius_all(7)
		light.add_theme_stylebox_override("panel", pip_box)
		bar.add_child(light)
	var url := MenuStyle.make_pill("🔒  www.dadazon.tab/ofertas", Palette.PAPER, Palette.INK.lightened(0.3), 13, 14, 4)
	url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bar.add_child(url)
	var close := Button.new()
	close.name = "Close"
	close.text = "✕  Cerrar"
	MenuStyle.style_secondary(close, 10, 4)
	close.pressed.connect(close_shop)
	bar.add_child(close)

	# Cabecera de la tienda.
	var header := PanelContainer.new()
	var header_box := StyleBoxFlat.new()
	header_box.bg_color = Palette.INK
	header_box.content_margin_left = 24
	header_box.content_margin_right = 24
	header_box.content_margin_top = 12
	header_box.content_margin_bottom = 12
	header.add_theme_stylebox_override("panel", header_box)
	header.set_meta(MenuStyle.DONE_META, true)
	col.add_child(header)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 18)
	header.add_child(head_row)
	var logo_col := VBoxContainer.new()
	logo_col.add_theme_constant_override("separation", -6)
	head_row.add_child(logo_col)
	var logo := Label.new()
	logo.name = "Logo"
	logo.text = "dadazon"
	logo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	logo.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	logo.add_theme_font_size_override("font_size", 40)
	logo.add_theme_color_override("font_color", Palette.PAPER)
	logo_col.add_child(logo)
	var smile := Smile.new()
	smile.custom_minimum_size = Vector2(150, 18)
	logo_col.add_child(smile)
	var tagline := Label.new()
	tagline.text = "Lo tiras hoy, lo tienes en un turno."
	tagline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tagline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tagline.add_theme_color_override("font_color", Palette.LAVENDER)
	tagline.add_theme_font_size_override("font_size", 15)
	head_row.add_child(tagline)
	_balance = Label.new()
	_balance.name = "Balance"
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_balance.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	_balance.add_theme_font_size_override("font_size", 22)
	_balance.add_theme_color_override("font_color", Palette.SUN)
	head_row.add_child(_balance)

	# Pestañas y aviso.
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 22)
	body.add_theme_constant_override("margin_top", 14)
	body.add_theme_constant_override("margin_bottom", 10)
	col.add_child(body)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	body.add_child(inner)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	inner.add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.name = "Tab_" + tab[0]
		button.text = tab[1]
		button.pressed.connect(_show_tab.bind(tab[0]))
		tabs.add_child(button)
		_tab_buttons[tab[0]] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_notice = Label.new()
	_notice.name = "Notice"
	_notice.add_theme_color_override("font_color", Palette.CORAL.darkened(0.15))
	_notice.add_theme_font_size_override("font_size", 14)
	_notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(_notice)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "Products"
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	var footer := Label.new()
	footer.text = "Envío gratis con Dadazon Prisa. Las fichas se ganan jugando en las mesas."
	footer.add_theme_color_override("font_color", Palette.INK.lightened(0.35))
	footer.add_theme_font_size_override("font_size", 13)
	inner.add_child(footer)


func open_shop() -> void:
	visible = true
	_notice.text = ""
	_show_tab(_tab)
	var close := find_child("Close", true, false) as Button
	close.grab_focus.call_deferred()


func close_shop() -> void:
	visible = false
	closed.emit()


func _show_tab(tab: String) -> void:
	_tab = tab
	for key in _tab_buttons:
		var button := _tab_buttons[key] as Button
		if key == tab:
			MenuStyle.style_primary(button, 10, 4)
		else:
			MenuStyle.style_secondary(button, 10, 4)
	_refresh()


func _refresh() -> void:
	_balance.text = tr("%d fichas") % HomePrefs.coins()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var ids := []
	if _tab == "decor":
		ids = ShopCatalog.ids(ShopCatalog.DECOR)
	else:
		ids = ShopCatalog.ids(ShopCatalog.HAT) + ShopCatalog.ids(ShopCatalog.ACCESSORY)
	for id in ids:
		if ShopCatalog.price(id) <= 0:
			continue
		_grid.add_child(_product(id))


func _product(id: String) -> Control:
	var data: Dictionary = ShopCatalog.ITEMS[id]
	var card := PanelContainer.new()
	card.name = "Product_" + id
	card.custom_minimum_size = Vector2(218, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.set_corner_radius_all(14)
	box.set_border_width_all(2)
	box.border_color = Color("e3dcef")
	box.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", box)
	card.set_meta(MenuStyle.DONE_META, true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var thumb := TextureRect.new()
	thumb.texture = load(ShopCatalog.thumb_path(id)) if ResourceLoader.exists(ShopCatalog.thumb_path(id)) else null
	thumb.custom_minimum_size = Vector2(0, 120)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(thumb)
	var title := Label.new()
	title.text = str(data["name"])
	title.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Palette.INK)
	col.add_child(title)
	var stars := Label.new()
	var full := int(round(float(data["stars"])))
	stars.text = "★".repeat(full) + "☆".repeat(5 - full) + "  %s" % _thousands(int(data["reviews"]))
	stars.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	stars.add_theme_color_override("font_color", Color("e0a92a"))
	stars.add_theme_font_size_override("font_size", 13)
	col.add_child(stars)
	var blurb := Label.new()
	blurb.text = str(data["blurb"])
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(190, 52)
	blurb.add_theme_color_override("font_color", Palette.INK.lightened(0.35))
	blurb.add_theme_font_size_override("font_size", 12)
	col.add_child(blurb)
	var price := Label.new()
	price.text = tr("%d fichas") % int(data["price"])
	price.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	price.add_theme_font_size_override("font_size", 20)
	price.add_theme_color_override("font_color", Palette.INK)
	col.add_child(price)
	var buy := Button.new()
	buy.name = "Buy"
	var owned := HomePrefs.owns(id)
	var missing := int(data["price"]) - HomePrefs.coins()
	if owned:
		buy.text = "Ya es tuyo"
		buy.disabled = true
	elif missing > 0:
		buy.text = tr("Te faltan %d fichas") % missing
		buy.disabled = true
	else:
		buy.text = "Comprar"
	if owned or missing > 0:
		MenuStyle.style_secondary(buy, 10, 4)
	else:
		MenuStyle.style_primary(buy, 10, 4)
	buy.pressed.connect(buy_item.bind(id))
	col.add_child(buy)
	return card


func buy_item(id: String) -> bool:
	if not HomePrefs.buy(id, ShopCatalog.price(id)):
		return false
	_notice.text = tr("¡Pedido hecho! %s llega en un turno.") % tr(ShopCatalog.item_name(id))
	purchased.emit(id)
	_refresh()
	return true


static func _thousands(value: int) -> String:
	var text := str(value)
	if text.length() > 3:
		text = text.substr(0, text.length() - 3) + "." + text.substr(text.length() - 3)
	return text
