class_name InfoView
extends View
## A view made of icons and text labels, closed with the center button.

var icons: Array = []
var labels: Array = []
var done_verb: String


func _init(p_gurk: Gurk, p_done_verb: String = "DONE") -> void:
	super(p_gurk.get_screen(), p_gurk)
	icons = []
	labels = []
	done_verb = p_done_verb
	set_button(5, done_verb)


func clear() -> void:
	icons = []
	labels = []


func add_icon(icon, x: float, y: float) -> int:
	icons.append({"icon": icon, "x": x, "y": y})
	return icons.size() - 1


func change_icon(index: int, icon) -> void:
	icons[index].icon = icon


func add_label(text: String, color, x: float, y: float) -> int:
	labels.append({"text": text, "color": color, "x": x, "y": y})
	return labels.size() - 1


func add_label_centered(text: String, color, x: float, y: float, width: float, height: float) -> int:
	var w := GurkScreen.FONT.get_width(text)
	var h := GurkScreen.FONT.font_height
	var xx := x + floorf((width - w) / 2.0)
	var yy := y + floorf((height - h) / 2.0)
	return add_label(text, color, xx, yy)


func do_draw() -> void:
	screen.clear_color(GurkScreen.GURK_BLUE)
	for icon in icons:
		screen.draw_icon(icon.icon, icon.x, icon.y)
	for label in labels:
		screen.draw_text(label.text, label.color, label.x, label.y)


func command(text: String) -> void:
	if text == done_verb:
		gurk.pop_view(null)
