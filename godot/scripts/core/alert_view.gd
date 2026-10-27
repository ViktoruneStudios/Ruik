class_name AlertView
extends View
## A message with an icon and a title; OK pops it with the given result.

const ICON_X := 3
const ICON_Y := 3
const TITLE_Y := 7

var icon
var title: String
var text: String
var result
var alt_icon
var subtitle = null


func _init(p_gurk: Gurk, p_icon, p_title, p_text, p_result, p_alt_icon = null) -> void:
	super(p_gurk.get_screen(), p_gurk)
	icon = p_icon
	title = View.s(p_title)
	text = View.s(p_text)
	result = p_result
	alt_icon = p_alt_icon
	set_button(5, "OK")


func do_draw() -> void:
	screen.clear_color(GurkScreen.GURK_BLUE)
	screen.draw_icon(icon, ICON_X, ICON_Y)
	if alt_icon != null:
		screen.draw_icon(alt_icon, GurkScreen.SIZE - GurkScreen.UNIT - ICON_X, ICON_Y)
	if subtitle != null:
		screen.draw_text_centered(title, "#FFF", 0, 1, GurkScreen.SIZE, GurkScreen.UNIT)
		screen.draw_text_centered(subtitle, "#A0A0A0", 0, 9, GurkScreen.SIZE, GurkScreen.UNIT)
	else:
		screen.draw_text_centered(title, "#FFF", 0, ICON_Y + 1, GurkScreen.SIZE, GurkScreen.UNIT)
	screen.wrap_text(text, "#FFF", ICON_X, ICON_Y * 2 + GurkScreen.UNIT, GurkScreen.SIZE - 2 * ICON_X)


func command(button_text: String) -> void:
	if button_text == "OK":
		gurk.pop_view(result)
