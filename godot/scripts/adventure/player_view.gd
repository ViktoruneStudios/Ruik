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
class_name PlayerView
extends InfoView
## A hero's character sheet.

var player: Player


func _init(p_gurk: Gurk, p_player: Player) -> void:
	super(p_gurk, "X")
	player = p_player
	set_button(7, "BACK")
	set_button(9, "EXIT")
	set_button(5, "GEAR")
	set_button(1, "ITEMS")


func do_layout() -> void:
	var has_spells := player.has_spells()
	var has_use := player.has_usable_item(false)
	if player.is_alive():
		if has_spells and has_use:
			set_button(3, "CAST/USE")
		elif has_spells:
			set_button(3, "SPELLS")
		elif has_use:
			set_button(3, "USE")
	clear()
	add_icon(player.character.icon, 3, 3)
	var y := 4
	add_label(player.character.name, "#FFF", 20, y)
	y += 8
	add_label("Level %d %s" % [player.level, player.character.job], "#FFF", 20, y)
	y += 8
	add_label("XP: %d/%s" % [player.experience, Data.levels[mini(player.level, Data.levels.size() - 1)]], "#FFF", 20, y)
	y += 8
	if player.max_spell_points > 0:
		add_label("HP: %d/%d, SP: %d/%d" % [player.hit_points, player.max_hit_points, player.spell_points, player.max_spell_points], "#FFF", 20, y)
	else:
		add_label("Hit Points: %d/%d" % [player.hit_points, player.max_hit_points], "#FFF", 20, y)
	y += 8
	add_label("Armor Class: %d" % player.get_armor_class(), "#FFF", 20, y)
	y += 8
	add_label("Resistance: %d" % player.get_resistance(), "#FFF", 20, y)
	y += 12
	y = _add_attribute("Strength", player.get_strength(), "Damage Bonus", y)
	y = _add_attribute("Accuracy", player.get_accuracy(), "To-Hit Bonus", y)
	y = _add_attribute("Awareness", player.get_awareness(), "Armor Class Bonus", y)
	_add_attribute("Toughness", player.get_constitution(), "Resistance Bonus", y)


func _add_attribute(label: String, value: int, bonus_label: String, y: int) -> int:
	add_label("%s: %d" % [label, value], "#FFF", 20, y)
	y += 8
	var bonus := player.get_attribute_bonus(value)
	if bonus != 0:
		add_label("%s: %d" % [bonus_label, bonus], "#A0A0A0", 28, y)
	return y + 10


func command(text: String) -> void:
	match text:
		"ITEMS":
			gurk.push_view(ItemView.new(gurk, player, ItemView.ACTION_INFO))
		"GEAR":
			gurk.push_view(GearView.new(gurk, player))
		"SPELLS", "CAST/USE":
			gurk.push_view(SpellView.new(gurk, player))
		"USE":
			gurk.push_view(ItemView.new(gurk, player, ItemView.ACTION_USE, false))
		"BACK":
			gurk.pop_view(null)
		"EXIT":
			gurk.pop_to_top_view(null)
