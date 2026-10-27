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
class_name ConfirmView
extends AlertView
## A YES/NO question.

var yes_result
var no_result


func _init(p_ruik: Ruik, p_icon, p_title, p_text, p_yes_result, p_no_result, p_alt_icon = null) -> void:
	super(p_ruik, p_icon, p_title, p_text, p_no_result, p_alt_icon)
	yes_result = p_yes_result
	no_result = p_no_result
	clear_button(5)
	set_button(1, "YES")
	set_button(3, "NO")


func command(button_text: String) -> void:
	match button_text:
		"YES":
			ruik.pop_view(yes_result)
		"NO":
			ruik.pop_view(no_result)
