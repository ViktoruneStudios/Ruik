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
class_name BasicStrategy
extends RefCounted
## The enemy AI: picks an attack, a move or a spell by weighted chance.

## Held weakly, since the combat view owns this strategy.
var combat: CombatView:
	get:
		return _combat.get_ref()
var _combat: WeakRef


func _init(p_combat: CombatView) -> void:
	_combat = weakref(p_combat)


func get_castable_spells(me: Combatant) -> Array:
	var casts := []
	for spell_info in me.entity.template.get("spells", []):
		var spell = Library.get_spell_by_name(spell_info.name)
		if spell == null:
			continue
		var weight: int = spell_info.get("weight", 0)
		if spell.type == "summon":
			if combat.can_summon(me):
				casts.append({"spell": spell, "weight": weight, "targets": null})
			continue
		var is_heal: bool = spell.type == "heal"
		var is_friendly: bool = spell.type == "heal" or spell.type == "enhance" or spell.type == "teleport"
		var is_range: bool = spell.get("target") == "area" or spell.get("target") == "range"
		var include_self: bool = spell.type == "heal" or spell.type == "teleport"
		var targets := []
		if spell.get("target") == "self":
			if combat.can_target_with_spell(me, me, is_friendly, is_heal, spell.get("effect")):
				targets = [me]
		elif spell.get("target") == "area":
			var target = combat.get_best_area_target(me, not is_friendly)
			if target != null:
				targets = [target]
		else:
			targets = combat.get_spell_targets(me, is_range, is_friendly, is_heal, include_self)
		if targets.size() > 0:
			casts.append({"spell": spell, "weight": weight, "targets": targets})
	return casts


func do_turn(me: Combatant, num_moves: int, num_attacks: int) -> void:
	combat.clear_selection()
	combat.using_item = null
	# Get all castable spells (if any)
	var casts := get_castable_spells(me)
	var can_attack_melee := combat.can_attack_melee(me)
	var can_attack_range := me.can_attack_range()
	var can_attack_area := me.can_attack_area()
	var template: Dictionary = me.entity.template
	var move_weight := 0
	var attack_weight := 0
	if can_attack_melee:
		attack_weight = template.get("attackWeight", 75)
	else:
		move_weight = template.get("moveWeight", 25)
		if can_attack_range:
			attack_weight = template.get("attackWeight", 75)
	if num_attacks == 0:
		attack_weight = 0
	if num_moves == 0:
		move_weight = 0
	var total_weight := attack_weight + move_weight
	for cast in casts:
		total_weight += cast.weight
	var k := Util.random(0, total_weight - 1)
	var did_action := false
	if k < attack_weight:
		if can_attack_area:
			var target = combat.get_best_area_target(me, true)
			if target != null:
				num_moves = 0
				num_attacks -= 1
				me.did_attack = true
				combat.set_target(target)
				combat.queue_fly(me.x, me.y, target.x, target.y, me.get_range_animation(), "AI Area Projectile Fly")
				combat.add_action(combat.do_area_attack, "Run AI Area Attack")
				did_action = true
		else:
			var nearest := combat.get_nearest_attack_target(me)
			var target: Combatant
			if me.last_target != null and combat.is_still_alive(me.last_target) and combat.can_attack(me, me.last_target):
				target = me.last_target
			elif can_attack_range:
				target = combat.get_random_enemy(me)
			else:
				target = combat.get_nearest_attack_target(me)
			if nearest != null and target != null and combat.is_in_melee_range(me, nearest) and not combat.is_in_melee_range(me, target):
				target = nearest
			if target != null:
				me.last_target = target
				# Can't move after attacking
				num_moves = 0
				num_attacks -= 1
				me.did_attack = true
				combat.set_target(target)
				if can_attack_melee:
					combat.add_action(combat.run_attack, "Run AI Melee Attack")
				elif can_attack_range:
					combat.queue_fly(me.x, me.y, target.x, target.y, me.get_range_animation(), "AI Projectile Fly")
					combat.add_action(combat.run_attack, "Run AI Range Attack")
				did_action = true
	else:
		k -= attack_weight
	if not did_action and k < move_weight:
		var target := combat.get_nearest_enemy(me)
		num_moves -= 1
		if num_moves == 0:
			num_attacks = 0
		if target != null:
			combat.add_action(move_towards.bind(me, target), "Do Move")
		did_action = true
	else:
		k -= move_weight
	if not did_action:
		for cast in casts:
			if not did_action and k < cast.weight:
				did_action = _cast(me, cast)
				if did_action:
					var spell: Dictionary = cast.spell
					if Util.truthy(spell.get("fast")):
						if me.half_attack:
							num_moves = 0
							num_attacks -= 1
							me.half_attack = false
						else:
							me.half_attack = true
					else:
						num_moves = 0
						num_attacks -= 1
			else:
				k -= cast.weight
	if not did_action:
		num_moves = 0
		num_attacks = 0
	if num_moves <= 0 and num_attacks <= 0:
		combat.end_turn()
	else:
		combat.add_action(reselect.bind(me), "AI Reselect")
		combat.add_pause("AI Action Pause")
		combat.add_action(do_turn.bind(me, num_moves, num_attacks), "AI Turn Continuation")


## Queues a spell cast; returns false if it couldn't be cast after all.
func _cast(me: Combatant, cast: Dictionary) -> bool:
	var spell: Dictionary = cast.spell
	combat.casting_spell = spell
	var target = null
	if spell.type == "summon":
		target = combat.get_suggested_summon_square(me)
		if target != null:
			combat.target_x = target.x
			combat.target_y = target.y
	else:
		target = Util.random_element(cast.targets)
		if spell.type == "teleport":
			var enemy := combat.get_random_enemy(me)
			var destination = combat.get_suggested_summon_square(enemy)
			if destination == null:
				destination = combat.get_random_square()
			if destination == null:
				return false
			combat.teleport_target = target
			combat.target_x = destination.x
			combat.target_y = destination.y
		else:
			combat.target_x = target.x
			combat.target_y = target.y
	combat.add_sound("spell", "AI Cast Sound")
	combat.queue_animation(me.x, me.y, Data.icons.animSpellCast, "Enemy Cast Animation")
	if target != null and (spell.get("target") == "range" or spell.get("target") == "area"):
		combat.queue_fly(me.x, me.y, target.x, target.y, spell.get("animation"), "Enemy Spell Range Animation")
	combat.select_mode = CombatView.SELECT_TARGETED
	combat.add_action(combat.do_spell_result, "Do Enemy Spell Result")
	return true


func reselect(me: Combatant) -> void:
	combat.select(me.x, me.y, CombatView.SELECT_ACTIVE)


func move_towards(me: Combatant, target: Combatant) -> void:
	var dx := target.x - me.x
	var dy := target.y - me.y
	var sx := signi(dx)
	var sy := signi(dy)
	var moved := false
	if absi(dy) >= absi(dx):
		if combat.is_clear(me.x, me.y + sy):
			combat.move_combatant(me.x, me.y, me.x, me.y + sy)
			moved = true
		elif combat.is_clear(me.x + sx, me.y):
			combat.move_combatant(me.x, me.y, me.x + sx, me.y)
			moved = true
	else:
		if combat.is_clear(me.x + sx, me.y):
			combat.move_combatant(me.x, me.y, me.x + sx, me.y)
			moved = true
		elif combat.is_clear(me.x, me.y + sy):
			combat.move_combatant(me.x, me.y, me.x, me.y + sy)
			moved = true
	if moved:
		combat.add_sound("move", "AI Move Sound")
	combat.draw()
