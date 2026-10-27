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
class_name ChooseCharacterView
extends SelectView
## Pick one hero of a given type (warrior, archer or mage).

var characters: Array = []
var fiddles := 0
var type: String
var game: Game


func _init(p_ruik: Ruik, p_type: String, p_game: Game) -> void:
	super(p_ruik, "CHOOSE", "DONE")
	type = p_type
	game = p_game


func do_layout() -> void:
	characters = []
	for character in Data.characters:
		if character.type == type:
			var after = character.get("after")
			if not Util.truthy(after) or Device.get_setting(after, false):
				characters.append(character)
	clear_button(7)
	clear_button(9)
	set_button(1, "INFO")
	clear()
	var y := 3
	var article := "an" if type == "archer" else "a"
	add_label_centered("Choose %s %s" % [article, Util.capitalize(type)], "#FFF", 0, y, 128, RuikScreen.FONT.font_height)
	y += 8
	add_label_centered("(Press INFO to learn more)", "#A0A0A0", 0, y, 128, RuikScreen.FONT.font_height)
	y += 12
	for character in characters:
		add_icon(character.icon, 2, y)
		add_option(character.name, "#FFF", 20, y)
		y += 8
		add_label("Level 1 %s" % character.job, "#A0A0A0", 20, y)
		y += 20


func item_selected(_index: int, _item) -> void:
	ruik.push_view(CharacterRollView.new(ruik, game, characters[selected]))


func item_highlighted(index: int, _item) -> void:
	# Fiddling with the first entry unlocks the characters normally only
	# available after winning.
	if index == 0:
		fiddles += 1
		if fiddles > 10:
			Device.set_setting("won", true)
			do_layout()
			fiddles = 0


func command(text: String) -> void:
	if text == "INFO":
		ruik.push_view(CharacterInfoView.new(ruik, characters[selected]))
	else:
		super(text)


func process_result(result) -> void:
	if Util.eq(result, "NEXT"):
		ruik.pop_view(result)
