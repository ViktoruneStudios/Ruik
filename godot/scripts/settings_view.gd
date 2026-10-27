# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/gurk.coffee in 2026.
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
class_name SettingsView
extends SelectView


func _init(p_ruik: Ruik) -> void:
	super(p_ruik, "TOGGLE", "DONE")


func do_layout() -> void:
	clear()
	var y := 3
	add_label_centered("Settings", "#FFF", 0, y, 128, RuikScreen.FONT.font_height)
	y += 12
	add_option("Music is %s" % _on_off(ruik.get_music_setting()), "#FFF", 8, y)
	y += 8
	add_option("Combat music is %s" % _on_off(ruik.get_combat_music_setting()), "#FFF", 8, y)
	y += 8
	add_option("Sound FX are %s" % _on_off(ruik.get_sound_setting()), "#FFF", 8, y)
	y += 8
	add_option("Fast combat is %s" % _on_off(ruik.get_fast_setting()), "#FFF", 8, y)
	start()


static func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func item_selected(index: int, _item) -> void:
	match index:
		0:
			ruik.set_music_setting(not ruik.get_music_setting())
		1:
			ruik.set_combat_music_setting(not ruik.get_combat_music_setting())
		2:
			ruik.set_sound_setting(not ruik.get_sound_setting())
		3:
			ruik.set_fast_setting(not ruik.get_fast_setting())
	do_layout()
	draw()
