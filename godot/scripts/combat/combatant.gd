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
class_name Combatant
extends RefCounted
## A hero or creature taking part in a combat.

const EFFECT_COLORS := {
	"Berserk": {"type": "glow", "color": {"red": 108, "green": 255, "blue": 108}},
	"Strong": {"type": "glow", "color": {"red": 255, "green": 108, "blue": 108}},
	"Protected": {"type": "glow", "color": {"red": 108, "green": 108, "blue": 255}},
	"Blessed": {"type": "glow", "color": {"red": 255, "green": 255, "blue": 255}},
	"Quick": {"type": "glow", "color": {"red": 255, "green": 192, "blue": 64}},
	"Eagle-eyed": {"type": "glow", "color": {"red": 255, "green": 108, "blue": 255}},
	"Resistant": {"type": "glow", "color": {"red": 108, "green": 255, "blue": 255}},
	"Paralyzed": {"type": "shade", "color": {"red": -64, "green": -64, "blue": 96}},
	"Rooted": {"type": "shade", "color": {"red": 32, "green": 32, "blue": -96}},
	"Poisoned": {"type": "shade", "color": {"red": -64, "green": 96, "blue": -64}},
	"Weakened": {"type": "shade", "color": {"red": 72, "green": 72, "blue": -64}},
	"Blinded": {"type": "shade", "color": {"red": -64, "green": -64, "blue": -64}},
	"Sluggish": {"type": "shade", "color": {"red": -64, "green": 72, "blue": 72}},
}

var entity # Player or Creature
var is_player: bool
var good: bool
var x: int
var y: int
var hit_points := 0
## Held weakly: combatants targeting each other would otherwise form a
## reference cycle and never be freed.
var last_target: Combatant:
	get:
		return _last_target.get_ref() if _last_target != null else null
	set(value):
		_last_target = weakref(value) if value != null else null
var _last_target: WeakRef = null
var custom_image: Texture2D = null
var num_moves := 1
var num_attacks := 1
var moves_left := 0
var attacks_left := 0
## Effect name -> {"value", "duration"}, or null once removed.
var effects: Dictionary = {}
var used_combat_spells: Dictionary = {}
var half_attack := false
var did_attack := false
var invisible := false
var drain_amount := 0
var using_item = null


func _init(p_entity, p_is_player: bool, p_good: bool, p_x: int = -1, p_y: int = -1) -> void:
	entity = p_entity
	is_player = p_is_player
	good = p_good
	x = p_x
	y = p_y
	hit_points = entity.hit_points
	effects = {}
	used_combat_spells = {}


func start_turn() -> void:
	if is_player:
		num_moves = 1 + entity.get_extra_moves()
		num_attacks = 1 + entity.get_extra_attacks()
	else:
		num_moves = int(entity.template.get("numMoves", 1))
		num_attacks = int(entity.template.get("numAttacks", 1))
	if has_effect("Berserk"):
		num_attacks += 1
	if has_effect("Quick"):
		num_moves += int(get_effect("Quick").value)
	moves_left = num_moves
	attacks_left = num_attacks
	half_attack = false
	did_attack = false
	drain_amount = 0
	using_item = null


func not_done() -> bool:
	return moves_left > 0 or attacks_left > 0


func use_combat_spell(item: Item) -> void:
	used_combat_spells[item.id] = true


func is_combat_spell_used(item: Item) -> bool:
	return used_combat_spells.get(item.id, false)


## Returns true if this killed the combatant.
func do_damage(damage: int) -> bool:
	if has_effect("Blessed"):
		damage = maxi(1, Util.js_round(damage / float(get_effect("Blessed").value)))
	hit_points = maxi(0, hit_points - damage)
	if is_player:
		entity.hit_points = hit_points
	return hit_points == 0


func do_heal(amount: int, heal_type, image_processor: ImageProcessor, callback: Callable) -> void:
	if Util.eq(heal_type, "remove"):
		clear_all_afflictions(image_processor, callback)
	elif Util.eq(heal_type, "restore"):
		entity.spell_points = mini(entity.max_spell_points, entity.spell_points + amount)
	else:
		hit_points = mini(get_max_hit_points(), hit_points + amount)
		if is_player:
			entity.hit_points = hit_points


func get_name() -> String:
	return entity.get_name()


func get_banner() -> String:
	var banner := get_name()
	for k in effects:
		if effects[k] != null:
			banner = "[%s]" % k
	return banner


func get_icon():
	return entity.character.icon if is_player else entity.template.icon


func get_max_hit_points() -> int:
	return entity.max_hit_points


func get_resistance() -> int:
	var r: int = entity.get_resistance()
	if has_effect("Resistant"):
		r += int(get_effect("Resistant").value)
	return r


func get_potency() -> int:
	return entity.get_potency()


func is_fully_healed() -> bool:
	return hit_points == get_max_hit_points()


func can_attack_range() -> bool:
	return entity.can_attack_range()


func can_attack_area() -> bool:
	return entity.can_attack_area()


func get_to_hit_bonus() -> int:
	var to_hit: int = entity.get_to_hit_bonus()
	if has_effect("Eagle-eyed"):
		to_hit += int(get_effect("Eagle-eyed").value)
	if has_effect("Blinded"):
		to_hit -= int(get_effect("Blinded").value)
	return to_hit


func get_armor_class() -> int:
	var ac: int = entity.get_armor_class()
	if has_effect("Protected"):
		ac += int(get_effect("Protected").value)
	if has_effect("Sluggish"):
		ac -= int(get_effect("Sluggish").value)
	return ac


func get_melee_damage_bounds() -> Dictionary:
	return compute_damage_bounds(entity.get_melee_damage_bounds())


func get_range_damage_bounds() -> Dictionary:
	return compute_damage_bounds(entity.get_range_damage_bounds())


func get_hit_spell():
	return entity.get_hit_spell()


func is_paralyzed() -> bool:
	return has_effect("Paralyzed")


func is_rooted() -> bool:
	return has_effect("Rooted")


func is_poisoned() -> bool:
	return has_effect("Poisoned")


func compute_damage_bounds(bounds: Dictionary) -> Dictionary:
	if has_effect("Strong"):
		var value: float = get_effect("Strong").value
		bounds.min = Util.js_round(bounds.min * value)
		bounds.max = Util.js_round(bounds.max * value)
	if has_effect("Weakened"):
		var value: float = get_effect("Weakened").value
		bounds.min = maxi(1, Util.js_round(bounds.min / value))
		bounds.max = maxi(1, Util.js_round(bounds.max / value))
	return bounds


func get_range_animation():
	if is_player:
		var weapon = entity.get_weapon()
		return weapon.template.get("rangeAnimation") if weapon != null else null
	return entity.template.get("rangeAnimation")


func can_summon() -> bool:
	return not is_player and Util.truthy(entity.template.get("summons"))


func add_effect(effect: String, value, duration: int, caster: Combatant) -> void:
	var already := has_effect(effect)
	effects[effect] = {"value": value, "duration": duration}
	if caster == self and not already:
		if effect == "Berserk":
			attacks_left += int(value)
		elif effect == "Quick":
			moves_left += int(value)


func remove_effect(effect: String) -> void:
	effects[effect] = null


func has_effect(effect: String) -> bool:
	return effects.get(effect) != null


func get_effect(effect: String):
	return effects.get(effect)


static func _effect_kind(effect: String) -> String:
	var info = EFFECT_COLORS.get(effect)
	return info.type if info != null else ""


func clear_all_afflictions(image_processor: ImageProcessor, callback: Callable) -> void:
	for effect in effects.keys():
		if Combatant._effect_kind(effect) == "shade":
			remove_effect(effect)
	draw_icon(image_processor, callback)


func increment_effects(image_processor: ImageProcessor, callback: Callable) -> void:
	var remove_list := []
	for effect in effects.keys():
		var info = effects[effect]
		if effect == "Berserk":
			if not did_attack:
				remove_list.append(effect)
		elif info != null:
			info.duration -= 1
			if info.duration <= 0:
				remove_list.append(effect)
	if remove_list.size() > 0:
		for effect in remove_list:
			remove_effect(effect)
		draw_icon(image_processor, callback)


## Rebuilds the tinted/haloed icon that shows the current effects.
func draw_icon(image_processor: ImageProcessor, callback: Callable) -> void:
	var shade_colors := []
	var halo_colors := []
	for effect in effects:
		if effects[effect] != null and EFFECT_COLORS.has(effect):
			var info: Dictionary = EFFECT_COLORS[effect]
			if info.type == "shade":
				shade_colors.append(info.color)
			else:
				halo_colors.append(info.color)
	if shade_colors.is_empty() and halo_colors.is_empty():
		custom_image = null
	else:
		custom_image = image_processor.process(get_icon(), shade_colors, halo_colors)
	callback.call()
