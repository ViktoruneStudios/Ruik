# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/adventure.coffee in 2026.
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
class_name CharacterInfoView
extends InfoView
## Describes a hero class before it is chosen.

const ATTRIBUTES := ["strength", "accuracy", "awareness", "constitution"]

var blurb_y := 0
var character: Dictionary


func _init(p_gurk: Gurk, p_character: Dictionary) -> void:
	super(p_gurk, "BACK")
	character = p_character
	add_icon(character.icon, 3, 3)
	var y := 4
	add_label(character.name, "#FFF", 20, y)
	y += 8
	add_label("Level 1 %s" % character.job, "#A0A0A0", 20, y)
	y += 12
	blurb_y = do_attributes(y) + 4


func do_attributes(y: int) -> int:
	for attribute in ATTRIBUTES:
		if Util.truthy(character.get(attribute)):
			var value = character[attribute]
			var value_text := ("+%s" % value) if value > 0 else str(value)
			var attribute_name := Util.capitalize(attribute)
			if attribute_name == "Constitution":
				attribute_name = "Toughness"
			add_label("%s: %s" % [attribute_name, value_text], "#FFF", 3, y)
			y += 8
	return y


func do_draw() -> void:
	super()
	screen.wrap_text(View.s(character.get("description")), "#A0A0A0", 3, blurb_y, 122)
