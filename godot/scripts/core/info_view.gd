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
class_name InfoView
extends View
## A view made of icons and text labels, closed with the center button.

var icons: Array = []
var labels: Array = []
var done_verb: String


func _init(p_ruik: Ruik, p_done_verb: String = "DONE") -> void:
	super(p_ruik.get_screen(), p_ruik)
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
	var w := RuikScreen.FONT.get_width(text)
	var h := RuikScreen.FONT.font_height
	var xx := x + floorf((width - w) / 2.0)
	var yy := y + floorf((height - h) / 2.0)
	return add_label(text, color, xx, yy)


func do_draw() -> void:
	screen.clear_color(RuikScreen.RUIK_BLUE)
	for icon in icons:
		screen.draw_icon(icon.icon, icon.x, icon.y)
	for label in labels:
		screen.draw_text(label.text, label.color, label.x, label.y)


func command(text: String) -> void:
	if text == done_verb:
		ruik.pop_view(null)
