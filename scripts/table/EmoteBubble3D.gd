class_name EmoteBubble3D
extends Node3D
## Bocadillo de reacción estilo cómic sobre la cabeza de cada jugador (TableSeats).
## Usa una textura procedural cacheada en el SceneTree de globo con cola + borde de tinta
## grueso y texto en Lilita One, compatible con modo headless y gl_compatibility.

const DONE_META := &"toon_style_applied"
const EMOTES := {
	"victory": {"label": "¡TOMA!", "accent": Color("ff9a3d"), "glyph": "★"},
	"shock": {"label": "¡¿QUÉ?!", "accent": Color("ff6b5e"), "glyph": "?!"},
	"laugh": {"label": "¡JAJA!", "accent": Color("4d7cfe"), "glyph": "XD"},
	"hurry": {"label": "¡TU TURNO!", "accent": Color("d99a00"), "glyph": "»"},
	"clap": {"label": "¡BUENA!", "accent": Color("2f9e6e"), "glyph": "♦"},
	"oops": {"label": "¡UPS!", "accent": Color("8a7fd6"), "glyph": "…"},
}
const EMOTE_ORDER := ["victory", "shock", "laugh", "hurry", "clap", "oops"]

var current_emote := ""
var _sprite: Sprite3D
var _text_label: Label3D
var _tween: Tween


static func catalog() -> Dictionary:
	return EMOTES


static func emote_ids() -> Array:
	return EMOTE_ORDER


static func _shared_bubble_texture(context: Node = null) -> ImageTexture:
	var cache := TableVfx.shared_cache(context)
	if cache.has("emote_bubble_tex"):
		return cache["emote_bubble_tex"] as ImageTexture
	var w := 192
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var ink := Palette.INK
	var paper := Palette.PAPER
	var shadow := Color(ink.r, ink.g, ink.b, 0.45)

	_draw_speech_shape(
		img, Rect2(14.0, 13.0, 168.0, 82.0), 26.0, Vector2(98.0, 118.0), shadow, shadow, 0.0
	)
	_draw_speech_shape(
		img, Rect2(10.0, 8.0, 168.0, 82.0), 26.0, Vector2(94.0, 113.0), paper, ink, 5.5
	)

	var tex := ImageTexture.create_from_image(img)
	cache["emote_bubble_tex"] = tex
	return tex


static func _draw_speech_shape(
	img: Image,
	rect: Rect2,
	radius: float,
	tail_tip: Vector2,
	fill: Color,
	border: Color,
	border_w: float
) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var inner_min := rect.position + Vector2(radius, radius)
	var inner_max := rect.position + rect.size - Vector2(radius, radius)
	var tail_a := Vector2(tail_tip.x - 15.0, rect.position.y + rect.size.y - 4.0)
	var tail_b := Vector2(tail_tip.x + 15.0, rect.position.y + rect.size.y - 4.0)

	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var clamped := Vector2(
				clampf(p.x, inner_min.x, inner_max.x),
				clampf(p.y, inner_min.y, inner_max.y)
			)
			var sdf_box := p.distance_to(clamped) - radius
			var sdf_tail := _sdf_triangle(p, tail_a, tail_b, tail_tip)
			var sdf := minf(sdf_box, sdf_tail)
			if sdf <= 0.5:
				var col := fill
				if border_w > 0.0 and sdf >= -border_w:
					col = border
				var prev := img.get_pixel(x, y)
				if col.a >= 0.99 or prev.a <= 0.01:
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, prev.blend(col))


static func _sdf_triangle(p: Vector2, p0: Vector2, p1: Vector2, p2: Vector2) -> float:
	var e0 := p1 - p0
	var e1 := p2 - p1
	var e2 := p0 - p2
	var v0 := p - p0
	var v1 := p - p1
	var v2 := p - p2
	var pq0 := v0 - e0 * clampf(v0.dot(e0) / maxf(e0.length_squared(), 0.0001), 0.0, 1.0)
	var pq1 := v1 - e1 * clampf(v1.dot(e1) / maxf(e1.length_squared(), 0.0001), 0.0, 1.0)
	var pq2 := v2 - e2 * clampf(v2.dot(e2) / maxf(e2.length_squared(), 0.0001), 0.0, 1.0)
	var s := signf(e0.x * e2.y - e0.y * e2.x)
	var d0 := Vector2(pq0.length_squared(), s * (v0.x * e0.y - v0.y * e0.x))
	var d1 := Vector2(pq1.length_squared(), s * (v1.x * e1.y - v1.y * e1.x))
	var d2 := Vector2(pq2.length_squared(), s * (v2.x * e2.y - v2.y * e2.x))
	var min_d := minf(d0.x, minf(d1.x, d2.x))
	var min_sign := minf(d0.y, minf(d1.y, d2.y))
	return -sqrt(min_d) * signf(min_sign)


func _ready() -> void:
	set_meta(DONE_META, true)
	_sprite = Sprite3D.new()
	_sprite.name = "BubbleSprite"
	_sprite.set_meta(DONE_META, true)
	_sprite.texture = _shared_bubble_texture(self)
	_sprite.pixel_size = 0.0046
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.shaded = false
	_sprite.render_priority = 5
	add_child(_sprite)

	_text_label = Label3D.new()
	_text_label.name = "BubbleText"
	_text_label.set_meta(DONE_META, true)
	if has_node("/root/ToonStyle"):
		_text_label.font = get_node("/root/ToonStyle").DISPLAY_FONT
	_text_label.font_size = 46
	_text_label.pixel_size = 0.0033
	_text_label.outline_size = 14
	_text_label.outline_modulate = Palette.INK
	_text_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_text_label.no_depth_test = true
	_text_label.render_priority = 6
	_text_label.position = Vector3(0.0, 0.055, 0.01)
	add_child(_text_label)
	visible = false


func show_emote(emote_id: String, duration: float = 2.15) -> void:
	var entry: Dictionary = EMOTES.get(emote_id, EMOTES["victory"])
	current_emote = emote_id
	var label_str: String = tr(str(entry.get("label", "¡TOMA!")))
	var glyph_str: String = str(entry.get("glyph", "★"))
	var accent: Color = entry.get("accent", Palette.SUN)
	_text_label.text = "%s %s" % [glyph_str, label_str]
	_text_label.modulate = accent.lightened(0.12)
	visible = true

	if _tween != null and _tween.is_valid():
		_tween.kill()
	var style := get_node_or_null("/root/ToonStyle")
	var reduce: bool = style != null and style.get("reduce_motion") == true
	if reduce or not is_inside_tree():
		scale = Vector3.ONE
		if is_inside_tree():
			_tween = create_tween()
			_tween.tween_interval(duration)
			_tween.tween_callback(_hide_bubble)
		return

	scale = Vector3.ONE * 0.15
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3(1.14, 1.14, 1.14), 0.14).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.10).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(maxf(duration - 0.38, 0.4))
	_tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_bubble)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _hide_bubble() -> void:
	visible = false
	current_emote = ""
	scale = Vector3.ONE
