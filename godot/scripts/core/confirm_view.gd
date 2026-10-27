class_name ConfirmView
extends AlertView
## A YES/NO question.

var yes_result
var no_result


func _init(p_gurk: Gurk, p_icon, p_title, p_text, p_yes_result, p_no_result, p_alt_icon = null) -> void:
	super(p_gurk, p_icon, p_title, p_text, p_no_result, p_alt_icon)
	yes_result = p_yes_result
	no_result = p_no_result
	clear_button(5)
	set_button(1, "YES")
	set_button(3, "NO")


func command(button_text: String) -> void:
	match button_text:
		"YES":
			gurk.pop_view(yes_result)
		"NO":
			gurk.pop_view(no_result)
