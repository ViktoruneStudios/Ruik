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
class_name QuestView
extends SelectView
## Lists started quests (marked "+" once done).


func _init(p_ruik: Ruik) -> void:
	super(p_ruik, "VIEW", "EXIT")


func do_layout() -> void:
	clear()
	add_label_centered("Quests", "#A0A0A0", 0, 1, 128, 8)
	var have_quests := false
	var y := 9
	for quest in Data.quests:
		var info: Dictionary = Data.quests[quest]
		if ruik.game.has_marker(info.get("started")):
			have_quests = true
			if ruik.game.has_marker(info.get("done")):
				add_label("+", "#FFF", 1, y)
			add_option(quest, "#FFF", 6, y)
			y += 8
	if not have_quests:
		add_label("(No quests yet)", "#FFF", 6, y)


func item_selected(_index: int, label) -> void:
	var quest_info: Dictionary = Data.quests[label.text]
	var info_view := AlertView.new(ruik, quest_info.icon, label.text, quest_info.text, null)
	if ruik.game.has_marker(quest_info.get("done")):
		info_view.subtitle = "(Completed)"
	ruik.push_view(info_view)


func command(text: String) -> void:
	if text == "EXIT":
		ruik.pop_to_top_view(null)
	else:
		super(text)
