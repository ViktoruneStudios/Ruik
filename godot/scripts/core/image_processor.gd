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
class_name ImageProcessor
extends RefCounted
## Builds 20x20 variants of icons: tinted ("shade"), haloed ("glow") and
## rotated. Used for combat effects and projectile animations.

const UP := 0
const RIGHT := 90
const DOWN := 180
const LEFT := 270

const LENGTH := GurkScreen.UNIT + 4

var _atlases: Array = []
var _work: Image


func _init(icon_textures: Array) -> void:
	for texture in icon_textures:
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_atlases.append(image)
	_work = Image.create(LENGTH, LENGTH, false, Image.FORMAT_RGBA8)


func clear() -> void:
	_work.fill(Color(0, 0, 0, 0))


func draw_icon(icon) -> void:
	var coords = Data.icon_coords.get(icon) if icon is String else null
	if coords == null:
		return
	var k := GurkScreen.UNIT
	_work.blit_rect(_atlases[coords.block], Rect2i(k * coords.x, k * coords.y, k, k), Vector2i(2, 2))


func _texture() -> ImageTexture:
	return ImageTexture.create_from_image(_work.duplicate())


func paint(colors: Array) -> ImageTexture:
	var arcs := ImageProcessor.compute_arcs(colors, 12)
	for y in GurkScreen.UNIT:
		for x in GurkScreen.UNIT:
			var px := _work.get_pixel(x + 2, y + 2)
			var r := px.r8
			var g := px.g8
			var b := px.b8
			var a := px.a8
			if a > 0 and (r > 0 or g > 0 or b > 0):
				var c := ImageProcessor.blend(colors, arcs, GurkScreen.HALF_UNIT - y, GurkScreen.HALF_UNIT - x)
				r = mini(255, r + c.red) if c.red > 0 else maxi(0, r + c.red)
				g = mini(255, g + c.green) if c.green > 0 else maxi(0, g + c.green)
				b = mini(255, b + c.blue) if c.blue > 0 else maxi(0, b + c.blue)
				# The canvas fill used an alpha above 1, i.e. fully opaque.
				_work.set_pixel(x + 2, y + 2, Color8(r, g, b, 255))
	return _texture()


static func blend(colors: Array, arcs: int, x: float, y: float) -> Dictionary:
	if colors.size() == 1:
		return colors[0]
	var max_angle := -2.0 * PI
	var min_angle := 2.0 * PI
	for yy in [y, y + 1]:
		for xx in [x, x + 1]:
			var angle := atan2(yy, xx)
			if angle > max_angle:
				max_angle = angle
			if angle < min_angle:
				min_angle = angle
	if min_angle < 0:
		min_angle += 2 * PI
	if max_angle < 0:
		max_angle += 2 * PI
	var a1 := int(floor(min_angle * arcs / PI / 2))
	var a2 := int(floor(max_angle * arcs / PI / 2))
	var n := colors.size()
	if a1 == a2:
		return colors[a1 % n]
	var p1: float = a2 - min_angle * arcs / PI / 2
	var p2: float = max_angle * arcs / PI / 2 - a2
	if p1 + p2 == 0:
		return colors[a1 % n]
	return Util.blend_colors(colors[a1 % n], colors[a2 % n], p1 / (p1 + p2), p2 / (p1 + p2))


static func compute_arcs(colors: Array, target: int) -> int:
	var n := colors.size()
	if n == 1:
		return 1
	return Util.js_round(float(target) / n) * n


func glow(colors: Array, intensity: float) -> ImageTexture:
	var arcs := ImageProcessor.compute_arcs(colors, 30)
	var length := LENGTH
	var cells := Util.create_2d_array(length, length, 0)
	for y in length - 2:
		for x in length:
			cells[y][x] = 3 if _work.get_pixel(x, y).a8 > 0 else 0
	for y in length - 3:
		for x in length:
			if cells[y][x] == 0:
				if x > 0 and cells[y][x - 1] == 3:
					cells[y][x] = 2
				if x + 1 < length and cells[y][x + 1] == 3:
					cells[y][x] = 2
				if y > 0 and cells[y - 1][x] == 3:
					cells[y][x] = 2
				if y + 1 < length and cells[y + 1][x] == 3:
					cells[y][x] = 2
	for y in length - 2:
		for x in length:
			if cells[y][x] == 0:
				if x > 0 and cells[y][x - 1] == 2:
					cells[y][x] = 1
				if x + 1 < length and cells[y][x + 1] == 2:
					cells[y][x] = 1
				if y > 0 and cells[y - 1][x] == 2:
					cells[y][x] = 1
				if y + 1 < length and cells[y + 1][x] == 2:
					cells[y][x] = 1
	for y in length - 2:
		for x in length:
			if cells[y][x] > 0 and cells[y][x] < 3:
				var alpha := intensity / 100.0
				if cells[y][x] == 1:
					alpha /= 3.0
				var c := ImageProcessor.blend(colors, arcs, length / 2.0 - y, length / 2.0 - x)
				_work.set_pixel(x, y, Color8(clampi(c.red, 0, 255), clampi(c.green, 0, 255), clampi(c.blue, 0, 255), Util.js_round(alpha * 255)))
	return _texture()


func shade(icon, colors: Array) -> ImageTexture:
	clear()
	draw_icon(icon)
	return paint(colors)


func halo(icon, colors: Array, intensity: float) -> ImageTexture:
	clear()
	draw_icon(icon)
	return glow(colors, intensity)


func process(icon, shade_colors: Array, halo_colors: Array) -> ImageTexture:
	clear()
	draw_icon(icon)
	var result: ImageTexture = null
	if shade_colors.size() > 0:
		result = paint(shade_colors)
	if halo_colors.size() > 0:
		result = glow(halo_colors, 80)
	return result


func rotate(icon, direction: int) -> ImageTexture:
	clear()
	draw_icon(icon)
	match direction:
		RIGHT:
			_work.rotate_90(CLOCKWISE)
		DOWN:
			_work.rotate_180()
		LEFT:
			_work.rotate_90(COUNTERCLOCKWISE)
	return _texture()
