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
class_name Player
extends RefCounted
## A hero. Also used to represent the Bag of Holding.

const TYPE_WARRIOR := "warrior"
const TYPE_ARCHER := "archer"
const TYPE_MAGE := "mage"

const ATTRIBUTES := ["Strength", "Accuracy", "Awareness", "Toughness"]

const MAX_ITEMS := 15

var character: Dictionary
var strength := 0
var accuracy := 0
var awareness := 0
var constitution := 0
var hit_points := 0
var max_hit_points := 0
var spell_points := 0
var max_spell_points := 0
var experience := 0
var level := 0

var items: Array = []
var equipment: Dictionary = {}


func _init(p_character: Dictionary) -> void:
	character = p_character
	level = 1
	experience = 0
	var attributes := [Util.stat_roll(), Util.stat_roll(), Util.stat_roll(), Util.stat_roll()]
	attributes.sort()
	var best: int = attributes[3]
	attributes.pop_back()
	Util.shuffle(attributes)
	match character.get("bestAttribute"):
		"strength":
			strength = best
			accuracy = attributes[0]
			awareness = attributes[1]
			constitution = attributes[2]
		"accuracy":
			accuracy = best
			strength = attributes[0]
			awareness = attributes[1]
			constitution = attributes[2]
		"awareness":
			awareness = best
			accuracy = attributes[0]
			strength = attributes[1]
			constitution = attributes[2]
		"constitution":
			constitution = best
			accuracy = attributes[0]
			awareness = attributes[1]
			strength = attributes[2]
	strength = maxi(1, strength + int(character.get("strength", 0)))
	accuracy = maxi(1, accuracy + int(character.get("accuracy", 0)))
	awareness = maxi(1, awareness + int(character.get("awareness", 0)))
	constitution = maxi(1, constitution + int(character.get("constitution", 0)))
	max_hit_points = maxi(4, compute_next_level_hit_points()) + int(character.get("hitPoints", 0))
	if Library.get_spells_for_character_and_level(character, 1).size() > 0:
		max_spell_points = maxi(2, compute_next_level_spell_points())
	else:
		max_spell_points = 0
	heal_completely()
	_reset_equipment()


func _reset_equipment() -> void:
	items = []
	equipment = {}
	for type in [Item.TYPE_WEAPON, Item.TYPE_SHIELD, Item.TYPE_HAT, Item.TYPE_ARMOR, Item.TYPE_BOOTS, Item.TYPE_AMULET]:
		equipment[type] = null


## Restores a hero from saved data (see to_data()).
func from_data(data: Dictionary) -> void:
	strength = data.get("strength", strength)
	accuracy = data.get("accuracy", accuracy)
	awareness = data.get("awareness", awareness)
	constitution = data.get("constitution", constitution)
	hit_points = data.get("hitPoints", hit_points)
	max_hit_points = data.get("maxHitPoints", max_hit_points)
	spell_points = data.get("spellPoints", spell_points)
	max_spell_points = data.get("maxSpellPoints", max_spell_points)
	experience = data.get("experience", experience)
	level = data.get("level", level)
	_reset_equipment()
	for obj in data.get("items", []):
		var template = Library.get_item_template_by_name(obj.template)
		if template == null:
			push_warning("Saved item template not found: %s" % obj.template)
			continue
		items.append(Item.new(template, obj.id, obj.get("bonus", 0), obj.get("charges", 0)))
	var saved_equipment: Dictionary = data.get("equipment", {})
	for k in saved_equipment:
		if saved_equipment[k] != null:
			equipment[k] = get_item_by_id(saved_equipment[k])


func to_data() -> Dictionary:
	var item_data := []
	for item in items:
		item_data.append(item.to_data())
	var equipment_data := {}
	for k in equipment:
		equipment_data[k] = equipment[k].id if equipment[k] != null else null
	return {
		"character": character,
		"strength": strength,
		"accuracy": accuracy,
		"awareness": awareness,
		"constitution": constitution,
		"hitPoints": hit_points,
		"maxHitPoints": max_hit_points,
		"spellPoints": spell_points,
		"maxSpellPoints": max_spell_points,
		"experience": experience,
		"level": level,
		"items": item_data,
		"equipment": equipment_data,
	}


func get_name() -> String:
	return character.name


func can_carry_more_items() -> bool:
	return items.size() < MAX_ITEMS


func number_of_items() -> int:
	return items.size()


func add_item(item: Item) -> void:
	if can_carry_more_items():
		items.append(item)


func get_item_by_id(item_id) -> Item:
	for item in items:
		if item.id == item_id:
			return item
	return null


func equip_item(item: Item) -> void:
	var type: String = item.template.type
	if type != Item.TYPE_USE:
		equipment[type] = item


func is_item_equipped(item: Item) -> bool:
	var equipped = equipment.get(item.template.type)
	return equipped != null and equipped.id == item.id


func unequip_item(item: Item) -> bool:
	if is_item_equipped(item):
		equipment[item.template.type] = null
		return true
	return false


func unequip_item_by_type(type: String) -> void:
	var item = equipment.get(type)
	if item != null:
		unequip_item(item)


func drop_item(item: Item) -> bool:
	unequip_item(item)
	for i in items.size():
		if items[i].id == item.id:
			items.remove_at(i)
			return true
	return false


func has_item(item_name: String) -> bool:
	for item in items:
		if item.template.name == item_name:
			return true
	return false


func can_employ(item: Item) -> bool:
	return item.is_for(character.type)


func has_usable_item(in_combat: bool, melee := false, summon := false, combatant = null) -> bool:
	for item in items:
		if (item.is_useable() and can_employ(item)) or (combatant != null and in_combat and item.get_combat_spell() != null and not combatant.is_combat_spell_used(item)):
			var spell = item.get_spell()
			if spell != null:
				if in_combat:
					if spell.type == "summon" and summon:
						return true
					if spell.target != "touch" or melee or spell.type == "heal":
						return true
				elif spell.type == "heal" and not Util.eq(spell.get("healType"), "remove"):
					return true
	return false


func get_equipable_items_by_type(type: String) -> Array:
	var result := []
	for item in items:
		if item.template.type == type and item.is_equipable_by(character.type):
			result.append(item)
	return result


func get_equipped_item_by_type(type: String) -> Item:
	return equipment.get(type)


func get_weapon() -> Item:
	return get_equipped_item_by_type(Item.TYPE_WEAPON)


func get_hit_spell():
	var weapon := get_weapon()
	return weapon.get_hit_spell() if weapon != null else null


func get_attribute_bonus(value: int) -> int:
	return Util.trunc((value - 1) / 2.4 - 4)


func compute_next_level_hit_points() -> int:
	return Util.random(1, 8) + get_attribute_bonus(get_constitution())


func compute_next_level_spell_points() -> int:
	return Util.random(1, 5) + get_attribute_bonus(get_awareness())


func is_alive() -> bool:
	return hit_points > 0


func take_damage(amount: int) -> int:
	hit_points = maxi(0, hit_points - amount)
	return hit_points


func is_restored() -> bool:
	return spell_points == max_spell_points


func is_healed() -> bool:
	return hit_points == max_hit_points


func heal_completely() -> void:
	hit_points = max_hit_points
	spell_points = max_spell_points


func heal() -> void:
	if hit_points > 0:
		hit_points = mini(max_hit_points, hit_points + 1)
		spell_points = mini(max_spell_points, spell_points + 1)


func _equipment_sum(method: String) -> int:
	var total := 0
	for k in equipment:
		if equipment[k] != null:
			total += equipment[k].call(method)
	return total


func get_extra_moves() -> int:
	return _equipment_sum("get_extra_moves")


func get_extra_attacks() -> int:
	return _equipment_sum("get_extra_attacks")


func get_armor_class() -> int:
	return get_attribute_bonus(get_awareness()) + _equipment_sum("get_armor_class")


func get_resistance() -> int:
	return get_attribute_bonus(get_constitution()) + _equipment_sum("get_resistance")


func get_potency() -> int:
	return int(floor(level / 2.0))


func get_to_hit_bonus() -> int:
	var to_hit := get_attribute_bonus(get_accuracy())
	var weapon := get_weapon()
	if weapon != null:
		to_hit += weapon.get_to_hit_bonus()
	return to_hit


func get_strength() -> int:
	return strength + _equipment_sum("get_strength_bonus")


func get_accuracy() -> int:
	return accuracy + _equipment_sum("get_accuracy_bonus")


func get_awareness() -> int:
	return awareness + _equipment_sum("get_awareness_bonus")


func get_constitution() -> int:
	return constitution + _equipment_sum("get_constitution_bonus")


func can_attack_range() -> bool:
	var weapon := get_weapon()
	return weapon != null and weapon.is_range_weapon()


func can_attack_area() -> bool:
	var weapon := get_weapon()
	return weapon != null and weapon.is_area_weapon()


func can_attack_melee() -> bool:
	var weapon := get_weapon()
	return weapon != null and weapon.is_melee_weapon()


func get_melee_damage_bounds() -> Dictionary:
	var weapon := get_weapon()
	var lo: int
	var hi: int
	if weapon == null:
		lo = 1
		hi = 1
	elif weapon.is_melee_weapon():
		lo = weapon.get_melee_min_damage()
		hi = weapon.get_melee_max_damage()
	else:
		lo = weapon.get_range_min_damage()
		hi = weapon.get_range_max_damage()
	var bonus := get_attribute_bonus(get_strength())
	return {"min": maxi(lo + bonus, 1), "max": maxi(hi + bonus, 1)}


func get_range_damage_bounds() -> Dictionary:
	var weapon := get_weapon()
	var bonus := get_attribute_bonus(get_strength())
	if weapon != null and weapon.is_range_weapon():
		return {"min": maxi(weapon.get_range_min_damage() + bonus, 1), "max": maxi(weapon.get_range_max_damage() + bonus, 1)}
	return {"min": 0, "max": 0}


func get_spell_range(spell: Dictionary) -> Dictionary:
	var bonus := get_attribute_bonus(get_awareness())
	var level_diff := maxi(0, level - int(spell.level))
	bonus += Util.js_round(float(spell.get("modifyAmount", 0)) * level_diff / 100.0)
	return {"min": maxi(spell.minAmount + bonus, 1), "max": maxi(spell.maxAmount + bonus, 1)}


func has_spells() -> bool:
	return get_spells().size() > 0


func get_spells() -> Array:
	return Library.get_spells_for_character_and_level(character, level)
