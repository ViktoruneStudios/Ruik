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
class_name View
extends RefCounted
## Base class for every screen of the game. A view draws itself onto the
## RuikScreen and declares which of the nine buttons are active.

const LEFT := "1"
const UP := "2"
const RIGHT := "3"
const DOWN := "4"

## buttons[y][x] is the button's text, or null when disabled.
var buttons: Array = []
var name := "No Name"
var screen: RuikScreen
var ruik: Ruik


func _init(p_screen: RuikScreen, p_ruik: Ruik) -> void:
	screen = p_screen
	ruik = p_ruik
	buttons = [[null, null, null], [null, null, null], [null, null, null]]


## Called with the result of a view that was pushed on top of this one.
func process_result(_result) -> void:
	pass


func draw() -> void:
	screen.clear()
	do_draw()
	screen.draw_screen()


func do_draw() -> void:
	pass


func do_layout() -> void:
	pass


func command(_text: String) -> void:
	pass


func set_buttons(grid: ButtonGrid) -> void:
	grid.clear()
	for y in 3:
		for x in 3:
			if buttons[y][x] != null:
				grid.set_button_by_position(x, y, buttons[y][x])


func enable_movement() -> void:
	buttons[1][0] = LEFT
	buttons[0][1] = UP
	buttons[1][2] = RIGHT
	buttons[2][1] = DOWN
	if ruik.is_current_view(self):
		set_buttons(ruik.button_grid)


static func coords(key_num: int) -> Vector2i:
	key_num -= 1
	return Vector2i(key_num % 3, key_num / 3)


func clear_button(key_num: int) -> void:
	var c := View.coords(key_num)
	buttons[c.y][c.x] = null
	if ruik.is_current_view(self):
		ruik.button_grid.disable_button_by_position(c.x, c.y)


func clear_all_buttons() -> void:
	for i in range(1, 10):
		clear_button(i)


func set_button(key_num: int, text: String) -> void:
	var c := View.coords(key_num)
	buttons[c.y][c.x] = text
	if ruik.is_current_view(self):
		ruik.button_grid.set_button_by_position(c.x, c.y, text)


func get_text_width(text: String) -> int:
	return RuikScreen.FONT.get_width(text)


## Stringifies possibly-missing data fields the way the UI needs them.
static func s(value) -> String:
	return "" if value == null else str(value)
