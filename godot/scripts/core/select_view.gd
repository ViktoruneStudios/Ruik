# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/core.coffee in 2026.
# This file has been modified from the original.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# -----------------------------------------------------------------------------
class_name SelectView
extends InfoView
## An InfoView with a list of options picked with UP/DOWN and the center button.

const BASIC_COLOR := "#FFF"
const SELECT_COLOR := "#0FF"

var options: Array = []
var selected := 0
var select_verb = null
var cancel_verb = null


func _init(p_gurk: Gurk, p_select_verb = "SELECT", p_cancel_verb = "CANCEL") -> void:
	super(p_gurk)
	select_verb = p_select_verb
	cancel_verb = p_cancel_verb
	options = []
	set_button(2, View.UP)
	set_button(8, View.DOWN)
	set_button(5, select_verb)
	if cancel_verb != null:
		set_button(9, cancel_verb)
	else:
		clear_button(9)


func clear() -> void:
	super()
	options = []


func start() -> void:
	if selected >= options.size():
		selected = 0
	if options.size() > 0:
		item_highlighted(selected, options[selected])


func set_select_verb(verb: String) -> void:
	select_verb = verb
	set_button(5, select_verb)


func turn_off_selection() -> void:
	clear_button(5)


## Override to respond to cancellation differently.
func cancelled() -> void:
	gurk.pop_view(null)


## Override to respond to selection differently.
func item_selected(_index: int, item) -> void:
	gurk.pop_view(item)


## Override to respond to highlighting.
func item_highlighted(_index: int, _item) -> void:
	pass


func add_option(text: String, color, x: float, y: float, highlight_color = SELECT_COLOR) -> int:
	options.append({"text": text, "color": color, "highlightColor": highlight_color, "x": x, "y": y})
	return options.size() - 1


func change_option(index: int, text: String, color) -> void:
	options[index].text = text
	options[index].color = color


func move_up() -> void:
	if options.size() > 0:
		selected -= 1
		if selected < 0:
			selected = options.size() - 1
		item_highlighted(selected, options[selected])
		draw()


func move_down() -> void:
	if options.size() > 0:
		selected += 1
		if selected >= options.size():
			selected = 0
		item_highlighted(selected, options[selected])
		draw()


func make_selection() -> void:
	if options.size() > 0:
		item_selected(selected, options[selected])


func command(text: String) -> void:
	if text == View.UP:
		move_up()
	elif text == View.DOWN:
		move_down()
	elif Util.eq(text, select_verb):
		make_selection()
	elif Util.eq(text, cancel_verb):
		cancelled()


func do_draw() -> void:
	super()
	for i in options.size():
		var option: Dictionary = options[i]
		var color = option.highlightColor if i == selected else option.color
		screen.draw_text(option.text, color, option.x, option.y)
