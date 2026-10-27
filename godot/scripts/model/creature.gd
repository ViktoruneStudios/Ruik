class_name Creature
extends RefCounted
## An instance of a creature template (monsters and summoned allies).

var template: Dictionary
var bonus: int
var hit_points := 0
var max_hit_points := 0
var spell_points := 0
var max_spell_points := 0
var good := false


func _init(p_template: Dictionary, p_bonus: int = 0) -> void:
	template = p_template
	bonus = p_bonus
	max_hit_points = maxi(1, Util.random(template.minHitPoints, template.maxHitPoints) + bonus)
	hit_points = max_hit_points
	if Util.truthy(template.get("minSpellPoints")):
		max_spell_points = Util.random(template.minSpellPoints, template.maxSpellPoints) + bonus
		spell_points = max_spell_points
	good = false


func _t(key: String) -> int:
	var value = template.get(key)
	return int(value) if value != null else 0


func can_attack_range() -> bool:
	return Util.truthy(template.get("rangeMinDamage"))


func can_attack_area() -> bool:
	return Util.eq(template.get("target"), "area")


func can_attack_melee() -> bool:
	return Util.truthy(template.get("meleeMinDamage"))


func get_hit_spell():
	return Library.get_spell_by_name(template.hitSpell) if Util.truthy(template.get("hitSpell")) else null


func get_to_hit_bonus() -> int:
	return _t("hitModifier") + bonus


func get_resistance() -> int:
	return _t("resistance") + bonus


func get_potency() -> int:
	return _t("potency") + int(floor(template.level / 2.0)) + bonus


func get_armor_class() -> int:
	return _t("armorClass") + bonus


func get_melee_damage_bounds() -> Dictionary:
	return {"min": maxi(_t("meleeMinDamage") + bonus, 1), "max": maxi(_t("meleeMaxDamage") + bonus, 1)}


func get_range_damage_bounds() -> Dictionary:
	return {"min": maxi(_t("rangeMinDamage") + bonus, 1), "max": maxi(_t("rangeMaxDamage") + bonus, 1)}


func get_spell_range(spell: Dictionary) -> Dictionary:
	return {"min": maxi(spell.minAmount + bonus, 1), "max": maxi(spell.maxAmount + bonus, 1)}


func get_name() -> String:
	return template.name


func get_spells() -> Array:
	var results := []
	for spell in template.get("spells", []):
		results.append(Library.get_spell_by_name(spell.name))
	return results
