class_name Validate
## Checks the game data for missing references and prints what it finds.


static func require(object: Dictionary, field: String, owner_name) -> void:
	if not object.has(field):
		print("%s is missing '%s'." % [owner_name, field])


static func run() -> void:
	print("--- VALIDATING ...")
	print("-- SPELLS")
	for spell in Data.spells:
		if spell.get("type") == "summon":
			if not Util.truthy(spell.get("creature")):
				print(" No creature for summon spell %s." % spell.name)
			elif Library.get_creature_by_name(spell.creature) == null:
				print(" Creature for summon spell %s not found: '%s'." % [spell.name, spell.creature])
		if (spell.get("target") == "range" or spell.get("target") == "area") and not Util.truthy(spell.get("animation")):
			print(" Animation missing for spell %s" % spell.name)
	print("-- CREATURES")
	var spell_set := {}
	for creature in Data.creatures:
		for field in ["icon", "groups", "meleeMinDamage", "meleeMaxDamage", "level", "minHitPoints", "maxHitPoints", "experienceValue", "numAttacks", "numMoves", "armorClass", "description"]:
			require(creature, field, creature.get("name"))
		if Util.truthy(creature.get("rangeMinDamage")) and not Util.truthy(creature.get("rangeAnimation")):
			print(" No range animation for %s." % creature.name)
		if Util.truthy(creature.get("hitSpell")):
			if Library.get_spell_by_name(creature.hitSpell) == null:
				print(" Missing hit spell %s for %s." % [creature.hitSpell, creature.name])
			spell_set[creature.hitSpell] = true
		for spell in creature.get("spells", []):
			if Library.get_spell_by_name(spell.name) == null:
				print(" Missing spell %s for %s." % [spell.name, creature.name])
			else:
				spell_set[spell.name] = true
	print("-- ITEMS")
	for item in Data.items:
		for field in ["icon", "type", "groups", "rarity", "baseValue", "level", "usedBy"]:
			require(item, field, item.get("name"))
		if Util.truthy(item.get("rangeMinDamage")) and not Util.truthy(item.get("rangeAnimation")):
			print(" No range animation for %s." % item.name)
		for field in ["spell", "hitSpell", "combatSpell"]:
			if Util.truthy(item.get(field)):
				if Library.get_spell_by_name(item[field]) == null:
					print(" Missing %s %s for %s." % [field, item[field], item.name])
				spell_set[item[field]] = true
	print("-- MAPS")
	var id_set := {}
	var location_set := {}
	for map_name in Data.maps:
		var map: Dictionary = Data.maps[map_name]
		if Util.truthy(map.get("encounterChance")) and map.encounterChance > 0 and not Util.truthy(map.get("combatMap")):
			print(" Missing combat map for %s." % map_name)
		for feature in map.get("features", []):
			if feature.type == "transition":
				if not Util.truthy(feature.get("target")):
					print(" Missing transition target in %s." % map_name)
				elif not Data.maps.has(feature.target):
					print(" Transition target %s not found in %s." % [feature.target, map_name])
				else:
					var target: Dictionary = Data.maps[feature.target]
					if feature.targetX >= target.width or feature.targetY >= target.height:
						print(" Transition target location is not valid in %s for %s." % [feature.target, map_name])
			elif feature.type == "encounter":
				var location := "%s-%s-%s" % [map_name, feature.x, feature.y]
				if location_set.has(location):
					print(" More than one encounter at '%s : %s, %s'." % [map_name, feature.x, feature.y])
				else:
					location_set[location] = true
				if id_set.has(feature.get("id")):
					print(" More than one encounter with id '%s'." % feature.get("id"))
				else:
					id_set[feature.get("id")] = true
				for creature in feature.get("creatures", []):
					if Library.get_creature_by_name(creature.name) == null:
						print(" Creature %s not found in %s." % [creature.name, map_name])
				for item in feature.get("items", []):
					if Library.get_item_template_by_name(item.name) == null:
						print(" Item %s not found in %s." % [item.name, map_name])
	for spell in Data.spells:
		if not spell_set.has(spell.name) and not Util.truthy(spell.get("who")):
			print(" Unused spell: %s" % spell.name)
	print("--- VALIDATION COMPLETE.")
