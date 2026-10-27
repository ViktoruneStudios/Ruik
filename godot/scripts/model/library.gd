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
class_name Library
## Static lookups into the game data.


static func get_item_template_by_name(item_name: String):
	for item in Data.items:
		if item.name == item_name:
			return item
	return null


static func get_item_templates(level: int, groups) -> Array:
	var results := []
	for item in Data.items:
		if item.level == level and (groups == null or Util.has_common_elements(groups, item.groups)):
			results.append(item)
	return results


static func get_character_by_name(character_name: String):
	for character in Data.characters:
		if character.name == character_name:
			return character
	return null


static func get_creature_by_name(creature_name: String):
	for creature in Data.creatures:
		if creature.name == creature_name:
			return creature
	return null


static func get_creatures(level: int, groups) -> Array:
	var results := []
	for creature in Data.creatures:
		if creature.level == level and (groups == null or Util.has_common_elements(groups, creature.groups)):
			results.append(creature)
	return results


## Picks a level near the given one, using the levelTransformations table.
static func get_level_near(level: int) -> int:
	var table: Array = Data.level_transformations
	var a: Array = table[clampi(level, 1, table.size()) - 1]
	var x := Util.random(0, 9999)
	var i := 0
	while i < a.size() - 1 and x > a[i]:
		x -= a[i]
		i += 1
	return i + 1


static func get_spells_for_character_and_level(character: Dictionary, level: int) -> Array:
	var results := []
	for spell in Data.spells:
		if (Util.eq(spell.get("who"), character.type) or Util.eq(spell.get("who"), character.job)) and spell.level <= level:
			results.append(spell)
	return results


static func new_spells_for_character_and_level(character: Dictionary, level: int) -> bool:
	for spell in Data.spells:
		if (Util.eq(spell.get("who"), character.type) or Util.eq(spell.get("who"), character.job)) and spell.level == level:
			return true
	return false


static func get_spell_by_name(spell_name) -> Variant:
	for spell in Data.spells:
		if Util.eq(spell.name, spell_name):
			return spell
	return null
