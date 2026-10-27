class_name GurkScreen
extends Control
## The 128x128 game display (port of the CoffeeScript Screen class).
##
## The original drew straight onto a canvas whenever it liked; here every draw
## call is recorded and replayed in _draw(). Clearing the whole screen starts
## a new list, so a view redraw replaces what was there, and animation frames
## drawn after a redraw land on top of it, exactly as on the canvas.

const SIZE := 128
const UNIT := 16
const HALF_UNIT := 8
const WIN_SIZE := 9
const CENTER_OFFSET := 4
const ICONS_PER_ROW := 7
const GURK_BLUE := "#004c62"

const MICRO_GLYPHS := {
	"A": Rect2i(0, 0, 5, 8), "B": Rect2i(5, 0, 5, 8), "C": Rect2i(10, 0, 4, 8),
	"D": Rect2i(14, 0, 5, 8), "E": Rect2i(19, 0, 4, 8), "F": Rect2i(23, 0, 4, 8),
	"G": Rect2i(27, 0, 5, 8), "H": Rect2i(32, 0, 5, 8), "I": Rect2i(37, 0, 4, 8),
	"J": Rect2i(41, 0, 5, 8), "K": Rect2i(46, 0, 5, 8), "L": Rect2i(51, 0, 4, 8),
	"M": Rect2i(55, 0, 6, 8), "N": Rect2i(61, 0, 5, 8), "O": Rect2i(66, 0, 5, 8),
	"P": Rect2i(71, 0, 5, 8), "Q": Rect2i(76, 0, 5, 8), "R": Rect2i(81, 0, 5, 8),
	"S": Rect2i(86, 0, 5, 8), "T": Rect2i(91, 0, 4, 8), "U": Rect2i(95, 0, 5, 8),
	"V": Rect2i(100, 0, 5, 8), "W": Rect2i(105, 0, 6, 8), "X": Rect2i(111, 0, 5, 8),
	"Y": Rect2i(116, 0, 5, 8), "Z": Rect2i(121, 0, 4, 8),
	"a": Rect2i(0, 8, 5, 8), "b": Rect2i(5, 8, 5, 8), "c": Rect2i(10, 8, 4, 8),
	"d": Rect2i(14, 8, 5, 8), "e": Rect2i(19, 8, 5, 8), "f": Rect2i(24, 8, 4, 8),
	"g": Rect2i(28, 8, 5, 8), "h": Rect2i(33, 8, 5, 8), "i": Rect2i(38, 8, 2, 8),
	"j": Rect2i(40, 8, 3, 8), "k": Rect2i(43, 8, 5, 8), "l": Rect2i(48, 8, 2, 8),
	"m": Rect2i(50, 8, 6, 8), "n": Rect2i(56, 8, 5, 8), "o": Rect2i(61, 8, 5, 8),
	"p": Rect2i(66, 8, 5, 8), "q": Rect2i(71, 8, 5, 8), "r": Rect2i(76, 8, 4, 8),
	"s": Rect2i(80, 8, 5, 8), "t": Rect2i(85, 8, 4, 8), "u": Rect2i(89, 8, 5, 8),
	"v": Rect2i(94, 8, 5, 8), "w": Rect2i(99, 8, 6, 8), "x": Rect2i(105, 8, 4, 8),
	"y": Rect2i(109, 8, 5, 8), "z": Rect2i(114, 8, 5, 8), "#": Rect2i(119, 8, 6, 8),
	"1": Rect2i(0, 17, 3, 8), "2": Rect2i(3, 17, 5, 8), "3": Rect2i(8, 17, 5, 8),
	"4": Rect2i(13, 17, 5, 8), "5": Rect2i(18, 17, 5, 8), "6": Rect2i(23, 17, 5, 8),
	"7": Rect2i(28, 17, 5, 8), "8": Rect2i(33, 17, 5, 8), "9": Rect2i(38, 17, 5, 8),
	"0": Rect2i(43, 17, 5, 8), ",": Rect2i(48, 17, 3, 8), ".": Rect2i(51, 17, 2, 8),
	"?": Rect2i(53, 17, 5, 8), "!": Rect2i(58, 17, 2, 8), "'": Rect2i(60, 17, 2, 8),
	"\"": Rect2i(65, 17, 4, 8), "/": Rect2i(69, 17, 6, 8), "(": Rect2i(81, 17, 3, 8),
	")": Rect2i(84, 17, 3, 8), "[": Rect2i(87, 17, 3, 8), "]": Rect2i(90, 17, 3, 8),
	":": Rect2i(103, 17, 2, 8), "-": Rect2i(105, 17, 4, 8), "*": Rect2i(109, 17, 4, 8),
	"+": Rect2i(114, 17, 4, 8), " ": Rect2i(122, 17, 4, 8),
	"~": Rect2i(0, 25, 10, 8), # Move icon
	"`": Rect2i(10, 25, 6, 8), # Attack icon
	"=": Rect2i(16, 25, 4, 8), # Full spell
	"|": Rect2i(20, 25, 4, 8), # Half spell
}

static var FONT: GurkFont = null

var icons: Array = []
var screen_overlay: Texture2D

var _commands: Array = []
var _alpha := 1.0
var _missing_icons := {}


func _init() -> void:
	size = Vector2(SIZE, SIZE)
	custom_minimum_size = size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	FONT = GurkFont.new(MICRO_GLYPHS, load("res://assets/images/font_micro.png"))
	icons = [load("res://assets/images/icons0.png"), load("res://assets/images/icons1.png")]
	screen_overlay = load("res://assets/images/screen.png")


func _draw() -> void:
	for cmd in _commands:
		if cmd[0] == 0:
			draw_rect(cmd[1], cmd[2])
		else:
			draw_texture_rect_region(cmd[1], cmd[2], cmd[3], Color(1, 1, 1, cmd[4]))


func clear() -> void:
	clear_color("#000")


func clear_color(fill_color) -> void:
	_commands.clear()
	fill_rect(fill_color, 0, 0, WIN_SIZE * UNIT, WIN_SIZE * UNIT)


## Font draw-target interface.
func fill(fill_color: Color, rect: Rect2) -> void:
	if fill_color.a <= 0.0:
		return
	_commands.append([0, rect, Color(fill_color, fill_color.a * _alpha)])
	queue_redraw()


## Font draw-target interface.
func blit(texture: Texture2D, source: Rect2, dest: Rect2) -> void:
	if texture == null:
		return
	_commands.append([1, texture, dest, source, _alpha])
	queue_redraw()


func draw_screen() -> void:
	draw_image(screen_overlay, 0, 0)


func icon_info(icon) -> Dictionary:
	var coords = Data.icon_coords.get(icon) if icon is String else null
	if coords == null:
		if not _missing_icons.has(str(icon)):
			_missing_icons[str(icon)] = true
			push_warning("Unknown icon: %s" % str(icon))
		return {}
	return coords


func draw_icon(icon, x: float, y: float) -> void:
	var coords := icon_info(icon)
	if coords.is_empty():
		return
	blit(icons[coords.block], Rect2(UNIT * coords.x, UNIT * coords.y, UNIT, UNIT), Rect2(x, y, UNIT, UNIT))


func draw_image(image: Texture2D, x: float, y: float) -> void:
	if image:
		blit(image, Rect2(Vector2.ZERO, image.get_size()), Rect2(Vector2(x, y), image.get_size()))


func draw_anim(anim, x: float, y: float, frame: int) -> void:
	var coords := icon_info(anim)
	if coords.is_empty():
		return
	var ix: int = coords.x
	var iy: int = coords.y
	var m: int = icons[coords.block].get_width() / UNIT
	for i in frame:
		ix += 1
		if ix == m:
			ix = 0
			iy += 1
	blit(icons[coords.block], Rect2(UNIT * ix, UNIT * iy, UNIT, UNIT), Rect2(x, y, UNIT, UNIT))


## Custom (processed) images are 20x20 with a 2 pixel margin.
func draw_custom_anim(custom: Texture2D, x: float, y: float) -> void:
	draw_image(custom, x - 2, y - 2)


func draw_text(text: String, text_color, x: float, y: float) -> void:
	FONT.draw_text(self, text, text_color, x, y)


func draw_text_centered(text: String, text_color, x: float, y: float, width: float, height: float) -> void:
	FONT.center_text(self, text, text_color, x, y, width, height)


func wrap_text(text: String, text_color, x: float, y: float, width: float) -> int:
	return FONT.wrap_text(self, text, text_color, x, y, width)


func set_alpha(alpha: float) -> void:
	_alpha = alpha


func draw_pixel(pixel_color, x: float, y: float) -> void:
	fill(Util.color(pixel_color), Rect2(x, y, 1, 1))


func fill_rect(fill_color, x: float, y: float, width: float, height: float) -> void:
	fill(Util.color(fill_color), Rect2(x, y, width, height))
