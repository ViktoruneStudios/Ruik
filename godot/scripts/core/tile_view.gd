# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/core.coffee in 2026.
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
class_name TileView
extends View
## A view that draws a tile map, with timed animations and banners.

var width := 0
var height := 0
var pos_x := 0
var pos_y := 0
var offset_x := 0
var offset_y := 0

var map_name: String
var map: Dictionary
var interval: Timer = null

var banner = null
var center_banner := false

var top_banner = null
var top_banner_left := false


func _init(p_ruik: Ruik, p_map_name: String) -> void:
	super(p_ruik.get_screen(), p_ruik)
	map_name = p_map_name
	set_map(map_name, 0, 0)
	enable_movement()
	center_banner = false


func set_map(p_map_name: String, x: int, y: int) -> void:
	map_name = p_map_name
	map = Data.maps[map_name]
	height = map.height
	width = map.width
	pos_x = x
	pos_y = y


func draw_tile(icon, x: float, y: float) -> void:
	screen.draw_icon(icon, x * RuikScreen.UNIT + offset_x, y * RuikScreen.UNIT + offset_y)


func draw_custom(image: Texture2D, x: float, y: float) -> void:
	screen.draw_image(image, x * RuikScreen.UNIT + offset_x - 2, y * RuikScreen.UNIT + offset_y - 2)


func get_terrain(x: int, y: int) -> Dictionary:
	var index := y * int(map.width) + x
	var tiles_string: String = map.map
	if index < 0 or index >= tiles_string.length():
		return {}
	return Data.tiles.get(tiles_string[index], {})


func get_terrain_icon(x: int, y: int):
	return get_terrain(x, y).get("icon")


func _frames_of(anim) -> int:
	var frames = Data.icon_coords.get(anim, {}).get("frames") if anim is String else null
	return frames if frames is int and frames > 0 else 1


## Calls frame_fn(step) now and then every `rate` ms until it returns true,
## then calls callback. Each animation owns its timer, so animations that
## overlap (e.g. a button pressed mid-animation) each stop cleanly. The
## original shared one interval handle, which left the first one running.
func _run_frames(rate: float, frame_fn: Callable, callback: Callable) -> void:
	var state := {"step": 0, "timer": null, "done": false}
	var tick := func():
		if state.done:
			return
		var step: int = state.step
		state.step += 1
		if frame_fn.call(step):
			state.done = true
			ruik.clear_interval(state.timer)
			callback.call()
	tick.call()
	if not state.done:
		state.timer = ruik.set_interval(tick, rate)
		interval = state.timer


func animate_block(anim, x: int, y: int, radius: int, rate: float, callback: Callable) -> void:
	_run_frames(rate, animate_block_frame.bind(anim, x, y, radius), callback)


func animate_block_frame(frame: int, anim, x: int, y: int, radius: int) -> bool:
	draw()
	if frame == _frames_of(anim):
		return true
	for yy in range(y - radius, y + radius + 1):
		if yy >= 0 and yy < height:
			for xx in range(x - radius, x + radius + 1):
				if xx >= 0 and xx < width:
					screen.draw_anim(anim, xx * RuikScreen.UNIT + offset_x, yy * RuikScreen.UNIT + offset_y, frame)
	return false


func animate(anim, x: int, y: int, rate: float, callback: Callable) -> void:
	var px := x * RuikScreen.UNIT + offset_x
	var py := y * RuikScreen.UNIT + offset_y
	_run_frames(rate, animate_frame.bind(anim, px, py), callback)


func animate_frame(frame: int, anim, x: float, y: float) -> bool:
	draw()
	if frame == _frames_of(anim):
		return true
	screen.draw_anim(anim, x, y, frame)
	return false


func fly(anim, x1: int, x2: int, y1: int, y2: int, rate: float, callback: Callable, custom: Texture2D = null) -> void:
	var n := int(floor(sqrt(float((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))) * rate / 50.0)) + 1
	var u := RuikScreen.UNIT
	_run_frames(rate, fly_frame.bind(anim, x1 * u + offset_x, x2 * u + offset_x, y1 * u + offset_y, y2 * u + offset_y, n, custom), callback)


func fly_frame(step: int, anim, x1: float, x2: float, y1: float, y2: float, n: int, custom: Texture2D) -> bool:
	var x := floorf(x1 + (x2 - x1) * step / n)
	var y := floorf(y1 + (y2 - y1) * step / n)
	var frame := step % _frames_of(anim)
	draw()
	if custom != null:
		screen.draw_custom_anim(custom, x, y)
	else:
		screen.draw_anim(anim, x, y, frame)
	if step > n:
		draw()
		return true
	return false


func set_banner(text) -> void:
	banner = text
	draw()


func clear_banner() -> void:
	banner = null
	draw()


func draw_banner() -> void:
	if banner == null or banner == "":
		return
	var x := -RuikScreen.HALF_UNIT
	var y := 7 * RuikScreen.UNIT
	screen.draw_icon(Data.icons.bannerLeft, x, y)
	for i in 7:
		x += RuikScreen.UNIT
		screen.draw_icon(Data.icons.banner, x, y)
	x += RuikScreen.UNIT
	screen.draw_icon(Data.icons.bannerRight, x, y)
	if center_banner:
		screen.draw_text_centered(str(banner), "#FFF", 0, y + 5, 128, 8)
	else:
		screen.draw_text(str(banner), "#FFF", 4, y + 5)


func set_top_banner(num_moves: int, num_attacks: int, half := false) -> void:
	top_banner = {"numMoves": num_moves, "numAttacks": num_attacks, "half": half}


func clear_top_banner() -> void:
	top_banner = null


func draw_top_banner() -> void:
	if top_banner == null:
		return
	var left_x: int
	if top_banner_left:
		left_x = -RuikScreen.HALF_UNIT
	else:
		left_x = 5 * RuikScreen.UNIT - RuikScreen.HALF_UNIT
	var y := 0
	var x := left_x
	screen.draw_icon(Data.icons.bannerLeft, x, y)
	for i in 2:
		x += RuikScreen.UNIT
		screen.draw_icon(Data.icons.banner, x, y)
	x += RuikScreen.UNIT
	screen.draw_icon(Data.icons.bannerRight, x, y)
	x = left_x + RuikScreen.HALF_UNIT + 5
	y = 5
	screen.draw_text("~", "#A0A0A0", x, y)
	x += 10
	screen.draw_text(":", "#A0A0A0", x, y)
	x += 3
	screen.draw_text(str(top_banner.numMoves), "#FFF", x, y)
	x = left_x + RuikScreen.HALF_UNIT + 25
	screen.draw_text("`", "#A0A0A0", x, y)
	x += 6
	screen.draw_text(":", "#A0A0A0", x, y)
	x += 3
	var attacks: String
	if top_banner.half:
		attacks = "%d|" % (top_banner.numAttacks - 1)
	else:
		attacks = str(top_banner.numAttacks)
	screen.draw_text(attacks, "#FFF", x, y)
