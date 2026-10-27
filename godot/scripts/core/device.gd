# -----------------------------------------------------------------------------
#
# Copyright (C) 2013 by John Watkinson
#
# Ported to Godot (GDScript) from src/device.coffee in 2026.
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
class_name Device
## Saved game and settings storage (the original used localStorage).

const SAVE_PATH := "user://saved_game.json"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "settings"

static var _settings: ConfigFile = null


static func has_saved_game() -> bool:
	return not load_game().is_empty()


static func save_game(game_json: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write saved game: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(game_json)


static func load_game() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	return FileAccess.get_file_as_string(SAVE_PATH)


static func clear_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _get_settings() -> ConfigFile:
	if _settings == null:
		_settings = ConfigFile.new()
		_settings.load(SETTINGS_PATH)
	return _settings


static func get_setting(setting_name: String, default_value: bool) -> bool:
	return bool(_get_settings().get_value(SETTINGS_SECTION, setting_name, default_value))


static func set_setting(setting_name: String, value: bool) -> void:
	var settings := _get_settings()
	settings.set_value(SETTINGS_SECTION, setting_name, value)
	settings.save(SETTINGS_PATH)
