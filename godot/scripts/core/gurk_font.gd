class_name GurkFont
extends RefCounted
## Bitmap font. The font image is opaque around each glyph and transparent
## inside it, so text is drawn by filling a rectangle with the text color and
## then drawing the glyphs over it.
##
## A draw target is any object with fill(color: Color, rect: Rect2) and
## blit(texture: Texture2D, source: Rect2, dest: Rect2).

var glyph_map: Dictionary
var image: Texture2D
var font_height: int


func _init(p_glyph_map: Dictionary, p_image: Texture2D) -> void:
	glyph_map = p_glyph_map
	image = p_image
	font_height = glyph_map["A"].size.y


func glyph(c: String) -> Rect2i:
	return glyph_map.get(c, glyph_map[" "])


func draw_char(target, c: String, x: float, y: float) -> int:
	var g := glyph(c)
	target.blit(image, Rect2(g), Rect2(x, y, g.size.x, g.size.y))
	return g.size.x


func draw_text(target, text: String, text_color, x: float, y: float) -> String:
	var width := get_width(text)
	target.fill(Util.color(text_color), Rect2(x, y, width, font_height))
	for i in text.length():
		x += draw_char(target, text[i], x, y)
	return text


func get_width(text: String) -> int:
	var width := 0
	for i in text.length():
		width += glyph(text[i]).size.x
	return width


func center_text(target, text: String, text_color, x: float, y: float, w: float, h: float) -> String:
	var offset_x := floorf((w - get_width(text)) / 2.0)
	var offset_y := floorf((h - font_height) / 2.0)
	return draw_text(target, text, text_color, x + offset_x, y + offset_y)


## Draws text wrapped to the given width; returns the height used.
func wrap_text(target, text: String, text_color, x: float, y: float, width: float) -> int:
	var n := text.length()
	var start := 0
	var last := 0
	var i := 0
	var w := 0
	var total_lines := 1
	while i < n:
		var break_line := false
		var force := false
		var new_line := false
		var c := text[i]
		if c == " ":
			last = i
		elif c == "\n":
			last = i
			break_line = true
			new_line = true
		if not break_line:
			w += glyph(c).size.x
			if w > width:
				break_line = true
		if break_line:
			if last == start and not new_line:
				last = i
				force = true
			draw_text(target, text.substr(start, last - start), text_color, x, y)
			y += font_height
			total_lines += 1
			start = last if force else last + 1
			last = start
			i = start
			w = 0
		else:
			i += 1
	if start < n - 1:
		draw_text(target, text.substr(start), text_color, x, y)
	return total_lines * font_height
