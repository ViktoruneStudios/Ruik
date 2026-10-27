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
class_name GearView
extends SelectView
## A hero's equipment slots.

var player: Player


## Icon shown for an empty equipment slot (slots are in Item.TYPES order).
static func slot_icon(index: int):
	var icons := [Data.icons.noWeapon, Data.icons.noShield, Data.icons.noHat, Data.icons.noArmor, Data.icons.noBoots, Data.icons.noAmulet]
	return icons[clampi(index, 0, icons.size() - 1)]


func _init(p_gurk: Gurk, p_player: Player) -> void:
	super(p_gurk, "EQUIP", "X")
	player = p_player
	set_button(7, "BACK")
	set_button(9, "EXIT")


func do_layout() -> void:
	clear()
	add_icon(player.character.icon, 2, 2)
	add_label_centered("%s's Gear" % player.character.name, "#FFF", 0, 4, 128, 16)
	var y := 2 + 16 + 2
	var index := 0
	for k in player.equipment:
		var item = player.equipment[k]
		var icon
		var label: String
		var color = "#FFF"
		if item != null:
			icon = item.template.icon
			label = item.name
			color = item.get_color()
		else:
			icon = GearView.slot_icon(index)
			label = "(none)"
		add_icon(icon, 2, y)
		add_option(label, color, 21, y + 4)
		index += 1
		y += 18
	start()


func item_selected(index: int, _item) -> void:
	gurk.push_view(ItemView.new(gurk, player, ItemView.ACTION_EQUIP, index))


func item_highlighted(index: int, _item) -> void:
	var type: String = Item.TYPES[index]
	if player.get_equipable_items_by_type(type).size() > 0:
		set_button(5, "EQUIP")
	else:
		clear_button(5)
	if player.get_equipped_item_by_type(type) != null:
		set_button(1, "INFO")
	else:
		clear_button(1)


func command(text: String) -> void:
	match text:
		"BACK":
			gurk.pop_view(null)
		"EXIT":
			gurk.pop_to_top_view(null)
		"INFO":
			gurk.push_view(ItemInfoView.new(gurk, player.get_equipped_item_by_type(Item.TYPES[selected])))
		_:
			super(text)


func process_result(item) -> void:
	if item == null:
		return
	if Util.eq(item, ItemView.NONE):
		player.unequip_item_by_type(Item.TYPES[selected])
	elif item is Item:
		player.equip_item(item)
		change_icon(selected + 1, item.template.icon)
		change_option(selected, item.name, "#FFF")
