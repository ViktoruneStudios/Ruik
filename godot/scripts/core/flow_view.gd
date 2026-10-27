class_name FlowView
extends AlertView
## An AlertView whose body is a list of colored paragraphs.

var paragraphs: Array = []


func _init(p_gurk: Gurk, p_icon, p_title, p_result, p_alt_icon = null) -> void:
	super(p_gurk, p_icon, p_title, "", p_result, p_alt_icon)
	paragraphs = []


func add_paragraph(paragraph_text, color) -> void:
	paragraphs.append({"text": View.s(paragraph_text), "color": color})


func add_gap() -> void:
	paragraphs.append({"text": null})


func do_draw() -> void:
	super()
	var y := AlertView.ICON_Y * 2 + GurkScreen.UNIT
	var x := AlertView.ICON_X
	for paragraph in paragraphs:
		if paragraph.text == null or paragraph.text == "":
			y += 4
		else:
			y += screen.wrap_text(paragraph.text, paragraph.color, x, y, GurkScreen.SIZE - 2 * x)
