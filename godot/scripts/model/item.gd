# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/model.coffee in 2026.
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
class_name Item
extends RefCounted
## An instance of an item template.

const TYPE_WEAPON := "weapon"
const TYPE_SHIELD := "shield"
const TYPE_HAT := "hat"
const TYPE_ARMOR := "armor"
const TYPE_BOOTS := "boots"
const TYPE_AMULET := "amulet"
const TYPE_USE := "use"

const TYPES := [TYPE_WEAPON, TYPE_SHIELD, TYPE_HAT, TYPE_ARMOR, TYPE_BOOTS, TYPE_AMULET, TYPE_USE]

var template: Dictionary
var id: int
var bonus: int
var charges: int
var name: String


func _init(p_template: Dictionary, p_id: int, p_bonus: int = 0, p_charges: int = 0) -> void:
	template = p_template
	id = p_id
	bonus = p_bonus
	charges = p_charges
	name = template.name
	if bonus > 0:
		name += " +%d" % bonus
	elif bonus < 0:
		name += " -%d" % -bonus


func _t(key: String) -> int:
	var value = template.get(key)
	return int(value) if value != null else 0


func get_color():
	var legendary = template.get("legendary")
	return legendary if legendary != null else "#FFF"


func get_type() -> String:
	return template.type


func is_weapon() -> bool:
	return template.type == TYPE_WEAPON


func get_hit_spell():
	return Library.get_spell_by_name(template.hitSpell) if Util.truthy(template.get("hitSpell")) else null


func get_combat_spell():
	return Library.get_spell_by_name(template.combatSpell) if Util.truthy(template.get("combatSpell")) else null


func is_useable() -> bool:
	return template.type == TYPE_USE


func is_equipable_by(character_type: String) -> bool:
	return not is_useable() and is_for(character_type)


func is_for(character_type: String) -> bool:
	return Util.has_element(template.get("usedBy", []), character_type)


func get_spell():
	if Util.truthy(template.get("spell")):
		return Library.get_spell_by_name(template.spell)
	elif Util.truthy(template.get("combatSpell")):
		return Library.get_spell_by_name(template.combatSpell)
	return null


func get_spell_range(spell = null) -> Dictionary:
	if spell == null:
		spell = get_spell()
	if spell == null:
		spell = get_hit_spell()
	var modify: int = spell.get("modifyAmount", 0)
	return {"min": spell.minAmount + bonus * modify, "max": spell.maxAmount + bonus * modify}


func can_use_outside_of_combat() -> bool:
	var spell = get_spell()
	if not is_useable() or spell == null:
		return false
	var heal_type = spell.get("healType")
	return spell.type == "heal" and (heal_type == null or heal_type == "restore" or heal_type == "heal")


func is_melee_weapon() -> bool:
	return is_weapon() and Util.truthy(template.get("meleeMinDamage"))


func is_range_weapon() -> bool:
	return is_weapon() and Util.truthy(template.get("rangeMinDamage"))


func is_area_weapon() -> bool:
	return is_weapon() and Util.eq(template.get("target"), "area")


func get_melee_min_damage() -> int:
	return _t("meleeMinDamage") + bonus


func get_melee_max_damage() -> int:
	return _t("meleeMaxDamage") + bonus


func get_range_min_damage() -> int:
	return _t("rangeMinDamage") + bonus


func get_range_max_damage() -> int:
	return _t("rangeMaxDamage") + bonus


func get_to_hit_bonus() -> int:
	if is_weapon():
		return _t("toHitBonus") + bonus if Util.truthy(template.get("toHitBonus")) else bonus
	return 0


func _bonus_stat(key: String) -> int:
	return _t(key) + bonus if Util.truthy(template.get(key)) else 0


func get_armor_class() -> int:
	return _bonus_stat("armorClass")


func get_resistance() -> int:
	return _bonus_stat("resistance")


func get_extra_moves() -> int:
	return _t("extraMoves")


func get_extra_attacks() -> int:
	return _t("extraAttacks")


func get_strength_bonus() -> int:
	return _bonus_stat("strengthBonus")


func get_accuracy_bonus() -> int:
	return _bonus_stat("accuracyBonus")


func get_awareness_bonus() -> int:
	return _bonus_stat("awarenessBonus")


func get_constitution_bonus() -> int:
	return _bonus_stat("constitutionBonus")


func get_value() -> int:
	var value: float = template.get("baseValue", 0)
	if is_useable():
		value *= charges
		value = Util.js_round(value + (value * bonus / 2.0))
	else:
		if bonus > 0:
			for i in bonus:
				value *= 1.8
		elif bonus < 0:
			for i in -bonus:
				value /= 1.5
			value = maxf(1.0, value)
	return Util.js_round(value)


func get_shop_value(mod_per_cent) -> int:
	var value := int(floor(get_value() * float(mod_per_cent) / 100.0))
	return maxi(value, 1)


func get_spell_name():
	return template.get("spell")


func to_data() -> Dictionary:
	return {"template": template.name, "id": id, "bonus": bonus, "charges": charges, "name": name}
