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
