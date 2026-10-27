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
class_name ItemView
extends SelectView
## Lists items to equip, inspect, buy, sell, hand out or use.

const ACTION_EQUIP := "EQUIP"
const ACTION_INFO := "INFO"
const ACTION_BUY := "BUY"
const ACTION_SELL := "SELL"
const ACTION_GIVE := "GIVE"
const ACTION_USE := "USE"
const ACTION_DROP := "DROP"

const NONE := "(none)"

var player: Player
var item_action: String
var param
var melee
var summon
var combatant

var items: Array = []
var shop = null
var buy_rate := 0
var sell_rate := 0
var select_action = null
var selling_player: Player = null
var in_combat := false


func _init(p_ruik: Ruik, p_player: Player, p_item_action: String, p_param = null, p_melee = null, p_summon = null, p_combatant = null) -> void:
	super(p_ruik, p_item_action, "X")
	player = p_player
	item_action = p_item_action
	param = p_param
	melee = p_melee
	summon = p_summon
	combatant = p_combatant
	match item_action:
		ACTION_GIVE:
			items = param
		ACTION_BUY:
			shop = param
			items = ruik.game.get_shop_items(shop.x, shop.y)
			buy_rate = shop.get("buyRate", 100)
			sell_rate = shop.get("sellRate", 100)
		ACTION_SELL:
			shop = param
			buy_rate = shop.get("buyRate", 100)
			sell_rate = shop.get("sellRate", 100)
			items = player.items
		ACTION_USE:
			in_combat = Util.truthy(param)


func do_layout() -> void:
	clear()
	match item_action:
		ACTION_EQUIP:
			add_label_centered("%s's Items" % player.get_name(), "#A0A0A0", 0, 1, 128, 8)
			set_button(1, "INFO")
			set_button(7, "BACK")
			if Util.truthy(melee): # True if this is an in-combat wield
				clear_button(9)
			else:
				set_button(9, "EXIT")
			items = player.get_equipable_items_by_type(Item.TYPES[param])
			items.append(NONE)
		ACTION_INFO:
			add_label_centered("%s's Items" % player.get_name(), "#A0A0A0", 0, 1, 128, 8)
			set_button(9, "EXIT")
			set_button(7, "BACK")
			set_button(3, "GIVE")
			set_button(1, "DROP")
			items = player.items
		ACTION_GIVE:
			add_label_centered("Items", "#A0A0A0", 0, 1, 128, 8)
			set_button(1, "INFO")
			set_button(9, "EXIT")
		ACTION_BUY:
			add_label_centered("Gold: %d" % ruik.game.gold, "#E8C627", 0, 1, 128, 8)
			set_button(1, "INFO")
			set_button(3, "SELL...")
			set_button(9, "EXIT")
		ACTION_SELL:
			add_label_centered("%s's Items" % player.get_name(), "#A0A0A0", 0, 1, 128, 8)
			set_button(1, "INFO")
			set_button(7, "BACK")
			set_button(9, "EXIT")
		ACTION_USE:
			add_label_centered("Choose Item to Use", "#A0A0A0", 0, 1, 128, 8)
			set_button(1, "INFO")
			set_button(7, "BACK")
			if not in_combat:
				set_button(9, "EXIT")
			else:
				clear_button(9)
			items = []
			for item in player.items:
				if player.can_employ(item) and (item.is_useable() or (combatant != null and in_combat and item.get_combat_spell() != null and player.is_item_equipped(item) and not combatant.is_combat_spell_used(item))):
					var can_use := false
					if in_combat:
						var spell = item.get_spell()
						if spell.type == "summon" and Util.truthy(summon):
							can_use = true
						elif spell.target != "touch" or Util.truthy(melee) or spell.type == "heal":
							can_use = true
					elif item.can_use_outside_of_combat():
						can_use = true
					if can_use:
						items.append(item)
			if items.is_empty():
				ruik.pop_view(null)
	add_icon(Data.icons.blank, 128 - 17, 1)
	var y := 9
	if items.size() > 0:
		for item in items:
			if Util.eq(item, NONE):
				add_option(NONE, "#A0A0A0", 6, y)
			else:
				var color = item.get_color()
				if player != null and player.is_item_equipped(item) and not in_combat:
					add_label("+", "#FFF", 1, y)
				var item_name: String = item.name
				var spell = null
				if item.charges > 0:
					item_name += " [%d]" % item.charges
					spell = item.get_spell()
				elif item.get_combat_spell() != null and in_combat:
					item_name += " [+]"
					spell = item.get_combat_spell()
				if spell != null and in_combat:
					add_label("|" if Util.truthy(spell.get("fast")) else "=", "#A0A0A0", 1, y)
				var option: String
				var offset: int
				if item_action == ACTION_BUY:
					option = "%s (%d)" % [item_name, item.get_shop_value(buy_rate)]
					add_option(option, "#FFF", 1, y)
					offset = 1
				elif item_action == ACTION_SELL:
					option = "%s (%d)" % [item_name, item.get_shop_value(sell_rate)]
					add_option(option, "#FFF", 6, y)
					offset = 6
				else:
					option = item_name
					add_option(item_name, "#FFF", 6, y)
					offset = 6
				if Util.truthy(item.template.get("legendary")):
					add_label("=", color, offset + get_text_width(option) + 1, y)
			y += 8
	else:
		add_label("(No items)", "#FFF", 6, y)
		clear_button(1)
		clear_button(3)
		clear_button(5)
	start()


func item_highlighted(index: int, item) -> void:
	if Util.eq(item.text, NONE):
		change_icon(0, GearView.slot_icon(param if param is int else 0))
	else:
		var highlighted: Item = items[index]
		change_icon(0, highlighted.template.icon)
		if item_action == ACTION_BUY:
			if ruik.game.gold >= highlighted.get_shop_value(buy_rate):
				set_button(5, "BUY")
			else:
				clear_button(5)


func item_selected(index: int, label) -> void:
	if Util.eq(label, NONE):
		ruik.pop_view(label)
		return
	var item = items[index]
	if item_action == ACTION_EQUIP:
		ruik.pop_view(item)
	if item_action == ACTION_SELL:
		var price: int = item.get_shop_value(sell_rate)
		ruik.push_view(ConfirmView.new(ruik, item.template.icon, "Confirm Sale", "Sell %s for %d gold pieces?" % [item.name, price], "SELL_YES", "SELL_NO"))
	if item_action == ACTION_USE:
		if in_combat:
			ruik.pop_view(item)
		elif Util.eq(item.get_spell().get("healType"), "restore"):
			ruik.push_view(PlayerDialog.new(ruik, PlayerDialog.ACTION_RESTORE, player))
		else:
			ruik.push_view(PlayerDialog.new(ruik, PlayerDialog.ACTION_HEAL, player))


func command(text: String) -> void:
	select_action = text
	match text:
		"BACK":
			ruik.pop_view(null)
		"EXIT":
			ruik.pop_to_top_view(null)
		"INFO":
			if items.size() > selected and items[selected] is Item:
				ruik.push_view(ItemInfoView.new(ruik, items[selected]))
		"GIVE", "BUY":
			ruik.push_view(PlayerDialog.new(ruik, "GIVE"))
		"SELL...":
			ruik.push_view(PlayerDialog.new(ruik, "SELL"))
		"DROP":
			var item: Item = items[selected]
			ruik.push_view(ConfirmView.new(ruik, item.template.icon, "Confirm Drop", "Drop %s? It will be gone forever!" % item.name, "DROP_YES", "DROP_NO"))
		_:
			super(text)


func process_result(result) -> void:
	var item = items[selected] if selected < items.size() else null
	if Util.eq(result, "SELL_YES"):
		ruik.game.gold += item.get_shop_value(sell_rate)
		player.drop_item(item)
		do_layout()
	elif Util.eq(result, "DROP_YES"):
		player.drop_item(item)
		do_layout()
	elif Util.eq(result, "DROP_NO") or Util.eq(result, "SELL_NO"):
		pass
	elif Util.eq(select_action, "SELL..."):
		select_action = "SELL"
		selling_player = ruik.game.bag if Util.eq(result, 3) else ruik.game.players[result]
		ruik.push_view(ItemView.new(ruik, selling_player, "SELL", shop))
	elif Util.eq(select_action, "USE"):
		_use_on(ruik.game.players[result], item)
	else: # GIVE
		var target: Player = ruik.game.bag if Util.eq(result, 3) else ruik.game.players[result]
		if target != null and player != target:
			if player != null:
				player.drop_item(item)
			else:
				items.remove_at(selected)
				if item_action == ACTION_BUY:
					ruik.game.gold -= item.get_shop_value(buy_rate)
			target.add_item(item)
			if items.is_empty():
				ruik.pop_view(null)


func _use_on(target: Player, item: Item) -> void:
	var spell = item.get_spell()
	var bounds := item.get_spell_range()
	item.charges -= 1
	if item.charges == 0:
		player.drop_item(item)
	if Util.eq(spell.get("healType"), "restore"):
		var org_spell_points := target.spell_points
		target.spell_points = mini(target.max_spell_points, target.spell_points + Util.random(bounds.min, bounds.max))
		var restore_amount := target.spell_points - org_spell_points
		ruik.push_view(AlertView.new(ruik, target.character.icon, "Restored", "%s was restored for %d points." % [target.character.name, restore_amount], null))
	else:
		var org_hit_points := target.hit_points
		target.hit_points = mini(target.max_hit_points, target.hit_points + Util.random(bounds.min, bounds.max))
		var heal_amount := target.hit_points - org_hit_points
		ruik.push_view(AlertView.new(ruik, target.character.icon, "Healed", "%s was healed for %d points." % [target.character.name, heal_amount], null))
