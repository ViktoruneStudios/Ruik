# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from tools/gurk/GameCompiler.java in 2026.
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
extends Node
## Autoload "Data": the game data and the icon atlas map.
##
## The original build ran GameCompiler.java to inline the map files into
## game.js. Here the same source files are read at startup instead:
## data/ruikDemo.js (the `Data` object literal), data/icons.js (the `Icons`
## object literal) and data/maps/*.txt for every map declared as "@file.txt".
##
## Exported builds must include these non-resource files: in the export
## preset, add "data/*" to "Filters to export non-resource files/folders".

const GAME_FILE := "res://data/ruikDemo.js"
const ICONS_FILE := "res://data/icons.js"
const MAPS_DIR := "res://data/maps/"

# Top-level fields of the game data (see data/ruikDemo.js for documentation).
var icons: Dictionary = {}
var levels: Array = []
var splash_music: String = ""
var combat_music: String = ""
var boat_music: String = ""
var level_transformations: Array = []
var treasure_chance: Array = []
var effects: Dictionary = {}
var characters: Array = []
var spells: Array = []
var items: Array = []
var creatures: Array = []
var tiles: Dictionary = {}
var quests: Dictionary = {}
var keys: Dictionary = {}
var maps: Dictionary = {}
var start: Array = []

## Icon name -> {block, x, y[, frames]} (from icons.js).
var icon_coords: Dictionary = {}

var _src: String = ""
var _pos: int = 0
var _len: int = 0
var _file: String = ""


func _init() -> void:
	load_all()


func load_all() -> void:
	var game = _parse_file(GAME_FILE, "Data")
	if not (game is Dictionary):
		push_error("Could not load game data from %s" % GAME_FILE)
		return
	icons = game.get("icons", {})
	levels = game.get("levels", [])
	splash_music = game.get("splashMusic", "")
	combat_music = game.get("combatMusic", "")
	boat_music = game.get("boatMusic", "")
	level_transformations = game.get("levelTransformations", [])
	treasure_chance = game.get("treasureChance", [])
	effects = game.get("effects", {})
	characters = game.get("characters", [])
	spells = game.get("spells", [])
	items = game.get("items", [])
	creatures = game.get("creatures", [])
	tiles = game.get("tiles", {})
	quests = game.get("quests", {})
	keys = game.get("keys", {})
	maps = game.get("maps", {})
	start = game.get("start", [])
	for map_name in maps:
		_inline_map(maps[map_name])
	var coords = _parse_file(ICONS_FILE, "Icons")
	if coords is Dictionary:
		icon_coords = coords
	else:
		push_error("Could not load icon map from %s" % ICONS_FILE)


## Same job as GameCompiler.java: replace "@file.txt" with the file's rows
## joined together, and record the width and height.
func _inline_map(map: Dictionary) -> void:
	var ref = map.get("map")
	if not (ref is String) or not ref.begins_with("@"):
		return
	var path: String = MAPS_DIR + ref.substr(1)
	if not FileAccess.file_exists(path):
		push_error("Map file not found: %s" % path)
		return
	var rows: Array = []
	for row in FileAccess.get_file_as_string(path).split("\n"):
		rows.append(row.trim_suffix("\r"))
	while rows.size() > 0 and rows[rows.size() - 1] == "":
		rows.pop_back()
	map["map"] = "".join(PackedStringArray(rows))
	map["width"] = rows[0].length() if rows.size() > 0 else 0
	map["height"] = rows.size()


# -----------------------------------------------------------------------------
# A small parser for JavaScript object literals: objects (quoted or bare keys),
# arrays, strings (with escapes and line continuations), numbers, booleans and
# null, plus // and /* */ comments and trailing commas.

func _parse_file(path: String, var_name: String):
	if not FileAccess.file_exists(path):
		push_error("File not found: %s" % path)
		return null
	_file = path
	_src = FileAccess.get_file_as_string(path)
	_len = _src.length()
	var decl := _src.find(var_name)
	_pos = _src.find("{", decl if decl >= 0 else 0)
	if _pos < 0:
		push_error("No object literal found in %s" % path)
		return null
	var result = _parse_value()
	_src = ""
	return result


func _fail(message: String) -> void:
	var line := _src.substr(0, _pos).count("\n") + 1
	push_error("%s:%d: %s" % [_file, line, message])


func _peek() -> int:
	return _src.unicode_at(_pos) if _pos < _len else 0


func _skip_ws() -> void:
	while _pos < _len:
		var c := _src.unicode_at(_pos)
		if c == 32 or c == 9 or c == 10 or c == 13:
			_pos += 1
		elif c == 47 and _pos + 1 < _len and _src.unicode_at(_pos + 1) == 47: # //
			var e := _src.find("\n", _pos)
			_pos = _len if e < 0 else e + 1
		elif c == 47 and _pos + 1 < _len and _src.unicode_at(_pos + 1) == 42: # /*
			var e := _src.find("*/", _pos + 2)
			_pos = _len if e < 0 else e + 2
		else:
			return


func _parse_value():
	_skip_ws()
	var c := _peek()
	if c == 123: # {
		return _parse_object()
	if c == 91: # [
		return _parse_array()
	if c == 34 or c == 39: # " or '
		return _parse_string()
	if c == 45 or c == 43 or c == 46 or (c >= 48 and c <= 57):
		return _parse_number()
	var word := _parse_identifier()
	match word:
		"true":
			return true
		"false":
			return false
		"null", "undefined":
			return null
	_fail("Unexpected token '%s'" % (word if word != "" else char(c)))
	_pos += 1
	return null


func _parse_object() -> Dictionary:
	var result := {}
	_pos += 1
	while true:
		_skip_ws()
		var c := _peek()
		if c == 125: # }
			_pos += 1
			return result
		if c == 0:
			_fail("Unterminated object")
			return result
		var key: String
		if c == 34 or c == 39:
			key = _parse_string()
		else:
			key = _parse_identifier()
			if key == "":
				_fail("Expected a key")
				_pos += 1
				continue
		_skip_ws()
		if _peek() != 58: # :
			_fail("Expected ':' after key '%s'" % key)
		else:
			_pos += 1
		result[key] = _parse_value()
		_skip_ws()
		if _peek() == 44: # ,
			_pos += 1
	return result


func _parse_array() -> Array:
	var result := []
	_pos += 1
	while true:
		_skip_ws()
		var c := _peek()
		if c == 93: # ]
			_pos += 1
			return result
		if c == 0:
			_fail("Unterminated array")
			return result
		result.append(_parse_value())
		_skip_ws()
		if _peek() == 44:
			_pos += 1
	return result


func _parse_string() -> String:
	var quote := _src.unicode_at(_pos)
	_pos += 1
	var parts := PackedStringArray()
	var chunk_start := _pos
	while _pos < _len:
		var c := _src.unicode_at(_pos)
		if c == quote:
			parts.append(_src.substr(chunk_start, _pos - chunk_start))
			_pos += 1
			return "".join(parts)
		if c == 92: # backslash
			parts.append(_src.substr(chunk_start, _pos - chunk_start))
			_pos += 1
			var e := _src.unicode_at(_pos)
			match e:
				110: parts.append("\n")
				116: parts.append("\t")
				114: parts.append("\r")
				98: parts.append("\b")
				102: parts.append("\f")
				48: parts.append(char(0))
				117: # \uXXXX
					parts.append(char(_src.substr(_pos + 1, 4).hex_to_int()))
					_pos += 4
				13: # line continuation (\r\n)
					if _pos + 1 < _len and _src.unicode_at(_pos + 1) == 10:
						_pos += 1
				10: # line continuation
					pass
				_:
					parts.append(char(e))
			_pos += 1
			chunk_start = _pos
		else:
			_pos += 1
	_fail("Unterminated string")
	return "".join(parts)


func _parse_number():
	var begin := _pos
	var is_float := false
	while _pos < _len:
		var c := _src.unicode_at(_pos)
		if c >= 48 and c <= 57 or c == 45 or c == 43:
			_pos += 1
		elif c == 46 or c == 101 or c == 69: # . e E
			is_float = true
			_pos += 1
		else:
			break
	var text := _src.substr(begin, _pos - begin)
	return text.to_float() if is_float else text.to_int()


func _parse_identifier() -> String:
	var begin := _pos
	while _pos < _len:
		var c := _src.unicode_at(_pos)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 36:
			_pos += 1
		else:
			break
	return _src.substr(begin, _pos - begin)
