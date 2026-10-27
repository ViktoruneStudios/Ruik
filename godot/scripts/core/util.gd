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
class_name Util
## Static helpers (port of the CoffeeScript Util class), plus a few shims for
## JavaScript semantics the game logic relies on.

static var _colors: Dictionary = {}


## Random integer in [lo, hi], computed exactly like the original so that
## degenerate ranges (hi < lo) behave the same.
static func random(lo, hi) -> int:
	var diff: float = float(hi) - float(lo) + 1.0
	return int(floor(randf() * diff)) + int(lo)


static func random_chance(num, den) -> bool:
	return randf() * den < num


static func random_element(array: Array):
	if array.is_empty():
		return null
	return array[random(0, array.size() - 1)]


static func stat_roll() -> int:
	return random(1, 6) + random(1, 6) + random(1, 6)


static func shuffle(a: Array) -> Array:
	var b := a.size()
	while b > 0:
		var c := int(floor(randf() * b))
		b -= 1
		var d = a[b]
		a[b] = a[c]
		a[c] = d
	return a


static func as_array(value) -> Array:
	if value is Array:
		return value
	if value == null:
		return []
	return [value]


static func has_common_elements(array1, array2) -> bool:
	for a in as_array(array1):
		for b in as_array(array2):
			if eq(a, b):
				return true
	return false


static func has_element(array: Array, element) -> bool:
	for a in array:
		if eq(a, element):
			return true
	return false


static func create_2d_array(width: int, height: int, value = null) -> Array:
	var a := []
	for y in height:
		var row := []
		row.resize(width)
		row.fill(value)
		a.append(row)
	return a


static func rgb(red: int, green: int, blue: int) -> Dictionary:
	return {"red": red, "green": green, "blue": blue}


static func blend_colors(color1: Dictionary, color2: Dictionary, p1: float, p2: float) -> Dictionary:
	return {
		"red": js_round(color1.red * p1 + color2.red * p2),
		"green": js_round(color1.green * p1 + color2.green * p2),
		"blue": js_round(color1.blue * p1 + color2.blue * p2),
	}


static func capitalize(word: String) -> String:
	if word.is_empty():
		return word
	return word.substr(0, 1).to_upper() + word.substr(1)


static func array_to_string(array: Array):
	if array.is_empty():
		return null
	var parts := PackedStringArray()
	for item in array:
		parts.append(str(item))
	return ", ".join(parts)


## JavaScript Math.round (halves round towards +infinity).
static func js_round(x: float) -> int:
	return int(floor(x + 0.5))


## JavaScript `x | 0` (truncate towards zero).
static func trunc(x: float) -> int:
	return int(x)


## JavaScript truthiness: unlike GDScript, empty arrays/dictionaries are true.
static func truthy(value) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return value != ""
		TYPE_OBJECT:
			return is_instance_valid(value)
	return true


## Equality that never raises on mismatched types (GDScript errors on e.g.
## Object == String, which the original JavaScript compared freely).
static func eq(a, b) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb:
		return a == b
	var na := ta == TYPE_INT or ta == TYPE_FLOAT
	var nb := tb == TYPE_INT or tb == TYPE_FLOAT
	if na and nb:
		return a == b
	var sa := ta == TYPE_STRING or ta == TYPE_STRING_NAME
	var sb := tb == TYPE_STRING or tb == TYPE_STRING_NAME
	if sa and sb:
		return String(a) == String(b)
	return false


## Parses a CSS-style color ("#FFF", "#004c62", "transparent").
static func color(value) -> Color:
	if value is Color:
		return value
	if value == null:
		return Color.WHITE
	if _colors.has(value):
		return _colors[value]
	var c: Color
	if value == "transparent":
		c = Color(0, 0, 0, 0)
	else:
		c = Color.html(value)
	_colors[value] = c
	return c


## JSON.parse_string turns every number into a float; restore whole numbers to
## ints so map keys like "3_4" and array indexes keep working after a load.
static func normalize_numbers(value):
	match typeof(value):
		TYPE_FLOAT:
			if value == floor(value) and abs(value) < 9.0e15:
				return int(value)
			return value
		TYPE_ARRAY:
			for i in value.size():
				value[i] = normalize_numbers(value[i])
			return value
		TYPE_DICTIONARY:
			for k in value.keys():
				value[k] = normalize_numbers(value[k])
			return value
	return value
