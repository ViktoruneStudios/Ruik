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
class_name PartyView
extends SelectView
## The party overview: gold, location, heroes and the Bag of Holding.

var game: Game


func _init(p_ruik: Ruik) -> void:
	super(p_ruik, "VIEW", "EXIT")
	game = ruik.game
	set_button(1, "OPTIONS")


func do_layout() -> void:
	clear()
	for marker in Data.keys:
		var key: Dictionary = Data.keys[marker]
		if game.has_marker(marker) and not game.has_marker(key.get("until")):
			add_icon(key.icon, 110, 10)
	var y := 2
	add_label_centered("The Adventurers", "#FFF", 0, y, 128, RuikScreen.FONT.font_height)
	y += 10
	add_label("In: %s" % Data.maps[game.map].name, "#FFF", 3, y)
	y += 8
	add_label("Gold: %d" % game.gold, "#E8C627", 3, y)
	y += 10
	for player in game.players:
		add_icon(player.character.icon, 2, y)
		add_option(player.character.name, "#FFF" if player.is_alive() else "#999", 20, y)
		y += 8
		add_label("Level %d %s" % [player.level, player.character.job], "#FFF", 20, y)
		var stats := "HP: %d/%d" % [player.hit_points, player.max_hit_points]
		if player.max_spell_points > 0:
			stats += " SP: %d/%d" % [player.spell_points, player.max_spell_points]
		y += 8
		add_label(stats, "#FFF", 20, y)
		y += 10
	if game.bag != null:
		add_icon(game.bag.character.icon, 2, y)
		add_option(game.bag.character.name, "#BBB", 20, y)
		y += 8
		var count := game.bag.items.size()
		if count == 0:
			add_label("Empty", "#FFF", 20, y)
		elif count == 1:
			add_label("1 item", "#FFF", 20, y)
		else:
			add_label("%d items" % count, "#FFF", 20, y)


func item_selected(index: int, _item) -> void:
	if index == 3:
		ruik.push_view(ItemView.new(ruik, game.bag, ItemView.ACTION_INFO))
	else:
		ruik.push_view(PlayerView.new(ruik, game.players[index]))


func command(text: String) -> void:
	if text == "OPTIONS":
		ruik.show_settings()
	else:
		super(text)
