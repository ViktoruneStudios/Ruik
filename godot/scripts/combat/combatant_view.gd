# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/combat.coffee in 2026.
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
class_name CombatantView
extends FlowView
## Details of a combatant, opened with INFO during combat.

var combatant: Combatant


func _init(p_ruik: Ruik, p_combatant: Combatant) -> void:
	super(p_ruik, p_combatant.get_icon(), p_combatant.get_name(), null)
	combatant = p_combatant
	add_paragraph("Hit Points: %d/%d" % [combatant.hit_points, combatant.get_max_hit_points()], "#FFF")
	if combatant.is_player and combatant.entity.max_spell_points > 0:
		add_paragraph("Spell Points: %d/%d" % [combatant.entity.spell_points, combatant.entity.max_spell_points], "#FFF")
	add_gap()
	var effects_list := []
	for effect in combatant.effects:
		if combatant.effects[effect] != null:
			effects_list.append(effect)
	if effects_list.size() > 0:
		add_paragraph("Effects: " + Util.array_to_string(effects_list), "#FFF")
		set_button(1, "EFFECTS")
	if not combatant.is_player:
		add_paragraph(combatant.entity.template.get("description"), "#A0A0A0")


func command(text: String) -> void:
	if text == "EFFECTS":
		var flow := FlowView.new(ruik, combatant.get_icon(), "Combat Effects", null)
		for effect in combatant.effects:
			if combatant.effects[effect] != null:
				flow.add_paragraph(effect, "#FFF")
				flow.add_paragraph(Data.effects.get(effect, ""), "#A0A0A0")
				flow.add_gap()
		ruik.push_view(flow)
	else:
		super(text)
