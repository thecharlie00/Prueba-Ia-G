class_name GameCovers
## Portadas de los juegos (assets/covers/<clave>.png, 512×640, sin texto para que valgan en
## todos los idiomas). Las genera tools/covers/make_covers.py a partir de SVG.
## Claves: las de GameThemes (sandbox, cards, chess, checkers, domino, ludo, island, brisca, parchis).

const ASPECT := 0.8  # ancho / alto


static func has_cover(key: String) -> bool:
	return ResourceLoader.exists(path(key))


static func path(key: String) -> String:
	return "res://assets/covers/%s.png" % key


static func texture(key: String) -> Texture2D:
	return load(path(key)) as Texture2D if has_cover(key) else null


## Nombre del juego (en español: se traduce al mostrarlo).
static func title(key: String) -> String:
	return str(GameThemes.THEMES.get(key, {}).get("name", key))


## Miniatura de portada para la interfaz: altura en píxeles, esquinas redondeadas y sombra.
static func thumb(key: String, height := 56.0, dimmed := false) -> Control:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.set_meta(MenuStyle.DONE_META, true)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Palette.INK
	frame.set_corner_radius_all(int(height * 0.12))
	frame.set_content_margin_all(2)
	frame.shadow_color = Color(0, 0, 0, 0.28)
	frame.shadow_size = 3
	frame.shadow_offset = Vector2(0, 2)
	frame.anti_aliasing = true
	holder.add_theme_stylebox_override("panel", frame)
	var art := TextureRect.new()
	art.name = "Cover"
	art.texture = texture(key)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(height * ASPECT, height)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dimmed:
		art.modulate = Color(0.75, 0.75, 0.8, 0.85)
	holder.add_child(art)
	return holder
