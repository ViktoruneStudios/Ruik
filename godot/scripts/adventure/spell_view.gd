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
class_name SpellView
extends SelectView
## A caster's spell list, in or out of combat. In combat, pops the chosen
## spell (or item, via "Use...").

const USE_NAME := "Use..."

var player # Player, or a Creature for summoned casters
var creature: Creature = null
var spells: Array = []
var castable: Array = []
var result_mode = null
var in_combat := false
var melee := false
var has_summon_room := false
var combatant = null


func _init(p_ruik: Ruik, p_player, p_in_combat := false, p_melee := false, p_has_summon_room := false, p_combatant = null) -> void:
	super(p_ruik, "CAST", "X")
	player = p_player
	in_combat = p_in_combat
	melee = p_melee
	has_summon_room = p_has_summon_room
	combatant = p_combatant
	if player is Creature:
		creature = player
	if not in_combat:
		set_button(9, "EXIT")
		set_button(7, "BACK")
	else:
		set_button(7, "CANCEL")
		clear_button(9)
	set_button(1, "INFO")


func do_layout() -> void:
	clear()
	spells = player.get_spells()
	castable = []
	var caster_name: String = creature.template.name if creature != null else player.character.name
	add_label_centered("%s's Spells (SP: %d)" % [caster_name, player.spell_points], "#A0A0A0", 0, 1, 128, 8)
	var y := 9
	var spell_points: int = player.spell_points
	for spell in spells:
		var active := false
		if spell.spellPoints <= spell_points:
			var heal_type = spell.get("healType")
			if (spell.type == "heal" and (in_combat or not Util.eq(heal_type, "remove"))) or ((spell.type == "enhance" or spell.type == "teleport") and in_combat):
				active = true
			elif in_combat:
				if spell.type == "summon" and has_summon_room:
					active = true
				elif spell.target == "touch" and melee:
					active = true
				elif spell.target == "range" or spell.target == "area":
					active = true
		castable.append(active)
		if active and in_combat:
			add_label("|" if Util.truthy(spell.get("fast")) else "=", "#A0A0A0", 1, y)
		add_option("%s (%d)" % [spell.name, spell.spellPoints], "#FFF" if active else "#888", 6, y)
		y += 8
	if creature == null and player.has_usable_item(in_combat, melee, has_summon_room, combatant):
		add_option(USE_NAME, "#FFF", 6, y)
	start()


func item_highlighted(index: int, item) -> void:
	if Util.eq(item.text, USE_NAME):
		set_button(5, "USE")
	elif index < castable.size() and castable[index]:
		set_button(5, "CAST")
	else:
		clear_button(5)


func item_selected(index: int, _item) -> void:
	if index < castable.size() and castable[index]:
		if in_combat:
			ruik.pop_view(spells[index])
		elif ruik.game.players_need_healing():
			ruik.push_view(PlayerDialog.new(ruik, PlayerDialog.ACTION_HEAL))
		else:
			ruik.push_view(AlertView.new(ruik, Data.icons.party, "Fully Healed", "There is nobody to target with that spell, all of the adventures are fully healed!", null))


func command(text: String) -> void:
	result_mode = "NORMAL"
	match text:
		"BACK", "CANCEL":
			ruik.pop_view(null)
		"EXIT":
			ruik.pop_to_top_view(null)
		"INFO":
			if selected < spells.size():
				ruik.push_view(SpellInfoView.new(ruik, player, spells[selected]))
		"USE":
			result_mode = "USE"
			ruik.push_view(ItemView.new(ruik, player, ItemView.ACTION_USE, in_combat, melee, has_summon_room, combatant))
		_:
			super(text)


func process_result(result) -> void:
	if result_mode == "USE":
		ruik.pop_view(result)
		return
	if not (result is int):
		return
	var target: Player = ruik.game.players[result]
	var spell: Dictionary = spells[selected]
	player.spell_points -= spell.spellPoints
	var bounds: Dictionary = player.get_spell_range(spell)
	if Util.eq(spell.get("healType"), "restore"):
		var org_spell_points := target.spell_points
		target.spell_points = mini(target.max_spell_points, target.spell_points + Util.random(bounds.min, bounds.max))
		var restore_amount := target.spell_points - org_spell_points
		ruik.push_view(AlertView.new(ruik, target.character.icon, "Restored", "%s was restored for %d points, now at %d/%d." % [target.character.name, restore_amount, target.spell_points, target.max_spell_points], null))
	else:
		var org_hit_points := target.hit_points
		target.hit_points = mini(target.max_hit_points, target.hit_points + Util.random(bounds.min, bounds.max))
		var heal_amount := target.hit_points - org_hit_points
		ruik.push_view(AlertView.new(ruik, target.character.icon, "Healed", "%s was healed for %d points, now at %d/%d." % [target.character.name, heal_amount, target.hit_points, target.max_hit_points], null))
