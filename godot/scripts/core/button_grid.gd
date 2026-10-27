class_name ButtonGrid
extends Control
## The 3x3 grid of command buttons under (beside) the screen.
##
##   1 2 3
##   4 5 6
##   7 8 9

const GURKOID_GLYPHS := {
	"A": Rect2i(1, 1, 5, 9), "B": Rect2i(6, 1, 5, 9), "C": Rect2i(11, 1, 5, 9),
	"D": Rect2i(16, 1, 5, 9), "E": Rect2i(21, 1, 4, 9), "F": Rect2i(25, 1, 4, 9),
	"G": Rect2i(29, 1, 5, 9), "H": Rect2i(34, 1, 5, 9), "I": Rect2i(39, 1, 4, 9),
	"J": Rect2i(43, 1, 4, 9), "K": Rect2i(47, 1, 5, 9), "L": Rect2i(52, 1, 5, 9),
	"M": Rect2i(57, 1, 6, 9), "N": Rect2i(63, 1, 6, 9), "O": Rect2i(69, 1, 5, 9),
	"P": Rect2i(74, 1, 5, 9), "Q": Rect2i(79, 1, 5, 9), "R": Rect2i(84, 1, 5, 9),
	"S": Rect2i(89, 1, 5, 9), "T": Rect2i(94, 1, 6, 9), "U": Rect2i(100, 1, 5, 9),
	"V": Rect2i(105, 1, 5, 9), "W": Rect2i(110, 1, 6, 9), "X": Rect2i(116, 1, 6, 9),
	"Y": Rect2i(122, 1, 6, 9), "Z": Rect2i(128, 1, 5, 9),
	"1": Rect2i(133, 1, 8, 9), "2": Rect2i(141, 1, 10, 9), "3": Rect2i(151, 1, 8, 9),
	"4": Rect2i(159, 1, 10, 9), "/": Rect2i(169, 1, 2, 9), ".": Rect2i(171, 1, 2, 9),
	" ": Rect2i(173, 1, 4, 9),
}

const BUTTON_WIDTH := 45
const BUTTON_HEIGHT := 23
const GAP_X := 6
const GAP_Y := 11
const GRID_WIDTH := 159
const GRID_HEIGHT := 113

var font: GurkFont
var on_image: Texture2D
var off_image: Texture2D
var top_image: Texture2D
var gurk: Gurk

## buttons[y][x] = {"x", "y", "on", "text"}
var buttons: Array = []


func _init(p_gurk: Gurk) -> void:
	gurk = p_gurk
	size = Vector2(GRID_WIDTH, GRID_HEIGHT)
	custom_minimum_size = size
	font = GurkFont.new(GURKOID_GLYPHS, load("res://assets/images/font_gurkoid.png"))
	on_image = load("res://assets/images/button.png")
	off_image = load("res://assets/images/buttonoff.png")
	top_image = load("res://assets/images/buttontop.png")
	var yy := GAP_Y
	for y in 3:
		var row := []
		var xx := GAP_X
		for x in 3:
			row.append({"x": xx, "y": yy, "on": false, "text": "BLAM"})
			xx += BUTTON_WIDTH + GAP_X
		buttons.append(row)
		yy += GAP_Y + BUTTON_HEIGHT
	enable_movement()


func _draw() -> void:
	for row in buttons:
		for button in row:
			var pos := Vector2(button.x, button.y)
			draw_texture(on_image if button.on else off_image, pos)
			if button.on:
				font.center_text(self, button.text, "transparent", button.x + 1, button.y, BUTTON_WIDTH, BUTTON_HEIGHT)
			draw_texture(top_image, pos)


## Font draw-target interface (only valid while drawing).
func fill(fill_color: Color, rect: Rect2) -> void:
	if fill_color.a > 0.0:
		draw_rect(rect, fill_color)


## Font draw-target interface (only valid while drawing).
func blit(texture: Texture2D, source: Rect2, dest: Rect2) -> void:
	draw_texture_rect_region(texture, dest, source)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		clicked(mouse.position)
		accept_event()


func clicked(point: Vector2) -> void:
	var x := clampi(int(floor(point.x * 3 / GRID_WIDTH)), 0, 2)
	var y := clampi(int(floor(point.y * 3 / GRID_HEIGHT)), 0, 2)
	var button: Dictionary = buttons[y][x]
	if button.on:
		gurk.button_pressed(button.text)


func get_button_by_key_num(key_num: int) -> Dictionary:
	key_num -= 1
	return buttons[key_num / 3][key_num % 3]


func force_click(key_num: int) -> void:
	var button := get_button_by_key_num(key_num)
	if button.on:
		gurk.button_pressed(button.text)


func redraw() -> void:
	queue_redraw()


func clear() -> void:
	for row in buttons:
		for button in row:
			button.on = false
	redraw()


func enable_movement() -> void:
	set_button_by_position(0, 1, "1")
	set_button_by_position(1, 0, "2")
	set_button_by_position(2, 1, "3")
	set_button_by_position(1, 2, "4")


func set_button(key_num: int, text: String) -> void:
	var button := get_button_by_key_num(key_num)
	button.text = text
	button.on = true
	redraw()


func set_button_by_position(x: int, y: int, text: String) -> void:
	var button: Dictionary = buttons[y][x]
	button.text = text
	button.on = true
	redraw()


func disable_button_by_position(x: int, y: int) -> void:
	buttons[y][x].on = false
	redraw()
