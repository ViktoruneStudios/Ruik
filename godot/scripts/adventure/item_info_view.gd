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
class_name ItemInfoView
extends InfoView
## Details of a single item.

var item: Item


static func get_used_by(template: Dictionary) -> String:
	var names := PackedStringArray()
	for type in template.get("usedBy", []):
		match type:
			"warrior":
				names.append("Warriors")
			"archer":
				names.append("Archers")
			"mage":
				names.append("Mages")
			_:
				names.append("")
	return ", ".join(names)


static func describe_target(spell: Dictionary) -> String:
	match spell.get("target"):
		"touch":
			return "Touch"
		"self":
			return "Self"
		"range":
			return "Range"
		"area":
			return "Area"
	return ""


func _init(p_ruik: Ruik, p_item: Item) -> void:
	super(p_ruik, "DONE")
	item = p_item
	var template := item.template
	add_icon(template.icon, 3, 3)
	var y := 23
	var x := 3
	if Util.truthy(template.get("legendary")):
		add_label_centered(item.name, item.get_color(), 0, 3, 128, 8)
		add_label_centered("(Legendary Artifact)", "#A0A0A0", 0, 12, 128, 8)
	else:
		add_label_centered(item.name, item.get_color(), 0, 4, 128, 16)
	add_label("(%s)" % ItemInfoView.get_used_by(template), "#FFF", x, y)
	y += 8
	# todo - show charges, and spell effect for usable items
	if item.is_melee_weapon():
		add_label("Melee Damage: %d - %d" % [maxi(1, item.get_melee_min_damage()), maxi(1, item.get_melee_max_damage())], "#FFF", x, y)
		y += 8
	if item.is_range_weapon():
		add_label("Range Damage: %d - %d" % [maxi(1, item.get_range_min_damage()), maxi(1, item.get_range_max_damage())], "#FFF", x, y)
		y += 8
	if item.get_hit_spell() != null:
		add_label("Hit Effect", "#A0A0A0", x, y)
		y += 8
		y = show_spell(item.get_hit_spell(), 8, y, false, false)
	if item.get_combat_spell() != null:
		var speed := "|" if Util.truthy(item.get_combat_spell().get("fast")) else "="
		add_label("Once per Combat %s" % speed, "#A0A0A0", x, y)
		y += 8
		y = show_spell(item.get_combat_spell(), 8, y, true, true)
	y = _add_stat("Extra Moves", item.get_extra_moves(), true, x, y)
	y = _add_stat("Extra Attacks", item.get_extra_attacks(), true, x, y)
	y = _add_stat("To-Hit Bonus", item.get_to_hit_bonus(), false, x, y)
	y = _add_stat("Armor Class Bonus", item.get_armor_class(), false, x, y)
	y = _add_stat("Resistance Bonus", item.get_resistance(), false, x, y)
	y = _add_stat("Strength Bonus", item.get_strength_bonus(), false, x, y)
	y = _add_stat("Accuracy Bonus", item.get_accuracy_bonus(), false, x, y)
	y = _add_stat("Awareness Bonus", item.get_awareness_bonus(), false, x, y)
	y = _add_stat("Toughness Bonus", item.get_constitution_bonus(), false, x, y)
	if item.is_useable():
		add_label("Charges Left: %d" % item.charges, "#FFF", x, y)
		y += 8
		var spell = item.get_spell()
		if spell != null:
			add_label("Speed: %s" % ("| Fast" if Util.truthy(spell.get("fast")) else "= Normal"), "#FFF", x, y)
			y += 8
			show_spell(spell, x, y, true, true)


## Adds "label: value" when the value is non-zero (or positive, if positive_only).
func _add_stat(label: String, value: int, positive_only: bool, x: int, y: int) -> int:
	if value > 0 or (value != 0 and not positive_only):
		add_label("%s: %d" % [label, value], "#FFF", x, y)
		y += 8
	return y


func show_spell(spell: Dictionary, x: int, y: int, show_range := true, show_drain_damage := false) -> int:
	if spell.type == "summon":
		add_label("Summons: %s" % spell.get("creature"), "#FFF", x, y)
		return y + 8
	var amount := item.get_spell_range(spell)
	var effect: String
	match spell.type:
		"damage":
			effect = "Damage %d - %d" % [amount.min, amount.max]
		"teleport":
			effect = "Teleport"
		"drain":
			effect = ("Drains Life %d - %d" % [amount.min, amount.max]) if show_drain_damage else "Drains Life"
		"heal":
			match spell.get("healType"):
				"restore":
					effect = "Restore %d - %d" % [amount.min, amount.max]
				"remove":
					effect = "Cure Afflictions"
				_:
					effect = "Heal %d - %d" % [amount.min, amount.max]
		_:
			effect = View.s(spell.get("effect"))
			if effect == "Poisoned":
				effect += " (%s)" % spell.get("value")
	if show_range:
		add_label("Effect: %s" % effect, "#FFF", x, y)
	else:
		add_label(effect, "#FFF", x, y)
	y += 8
	if show_range:
		add_label("Target: %s" % ItemInfoView.describe_target(spell), "#FFF", x, y)
		y += 8
	return y
