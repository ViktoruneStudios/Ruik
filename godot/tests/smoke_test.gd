extends Node
## Headless smoke test: creates a party, walks through the menus, then presses
## random enabled buttons (with a bias towards walking) to exercise maps,
## shops, combat, spells and items. Script errors show up in the output log.
##
##   godot --headless --path godot res://tests/smoke_test.tscn
##
## Your saved game and settings are backed up and restored afterwards.

const RANDOM_STEPS := 6000
const COMBATS := 40
const COMBAT_MAPS := ["wilderness", "ruins", "sewer", "fortress1", "crypt", "keep", "tower1", "lair"]
const COMBAT_PREFERENCES := ["TARGET", "HEAL", "RESTORE", "CURE", "SUMMON", "TELEPORT", "CAST", "CAST/USE", "ATTACK", "FIRE", "ATT/FIRE", "USE", "OK"]
const TIME_SCALE := 25.0

var ruik: Ruik
var views_seen := {}
var buttons_pressed := {}
var _backup := {}


func _ready() -> void:
	seed(12345)
	_backup_user_data()
	Device.set_setting("fast", true)
	Device.set_setting("music", false)
	Device.set_setting("sound", false)
	Device.clear_game()
	Engine.time_scale = TIME_SCALE
	ruik = load("res://main.tscn").instantiate()
	add_child(ruik)
	await get_tree().process_frame
	_check_icons()
	Validate.run()
	await _new_game()
	await _scripted_tour()
	await _save_and_load()
	await _combat_play(COMBATS)
	await _random_play(RANDOM_STEPS)
	_finish()


# --- Helpers -----------------------------------------------------------------

func _enabled_buttons() -> Array:
	var texts := []
	for row in ruik.button_grid.buttons:
		for button in row:
			if button.on:
				texts.append(button.text)
	return texts


func _press(text: String) -> bool:
	_note_view()
	if not _enabled_buttons().has(text):
		print("SMOKE: button '%s' not available in %s (have %s)" % [text, _view_name(), _enabled_buttons()])
		return false
	buttons_pressed[text] = buttons_pressed.get(text, 0) + 1
	ruik.button_pressed(text)
	await get_tree().process_frame
	_note_view()
	return true


func _view_name() -> String:
	if ruik.view == null:
		return "null"
	var script: Script = ruik.view.get_script()
	return script.get_global_name()


func _note_view() -> void:
	var view_name := _view_name()
	views_seen[view_name] = views_seen.get(view_name, 0) + 1


## Waits (in game time) until some button is enabled, e.g. during enemy turns.
func _wait_for_buttons(max_seconds := 30.0) -> void:
	var waited := 0.0
	while _enabled_buttons().is_empty() and waited < max_seconds:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _enabled_buttons().is_empty():
		print("SMOKE: stuck with no buttons in %s" % _view_name())


# --- Phases ------------------------------------------------------------------

func _check_icons() -> void:
	var missing := {}
	var check := func(icon):
		if icon is String and not Data.icon_coords.has(icon):
			missing[icon] = true
	for list in [Data.characters, Data.items, Data.creatures]:
		for entry in list:
			check.call(entry.get("icon"))
			check.call(entry.get("rangeAnimation"))
	for spell in Data.spells:
		check.call(spell.get("animation"))
	for tile in Data.tiles.values():
		check.call(tile.get("icon"))
	for map in Data.maps.values():
		for feature in map.get("features", []):
			check.call(feature.get("icon"))
			check.call(feature.get("altIcon"))
	for icon in Data.icons.values():
		if icon is Dictionary:
			for part in icon.values():
				check.call(part)
		else:
			check.call(icon)
	print("SMOKE: maps=%d items=%d creatures=%d spells=%d icons=%d missing icons=%s" % [Data.maps.size(), Data.items.size(), Data.creatures.size(), Data.spells.size(), Data.icon_coords.size(), missing.keys()])


func _new_game() -> void:
	await _press("NEW")
	await _press("OK") # Welcome
	for i in 3:
		await _press("INFO")
		await _press("BACK")
		await _press(View.DOWN)
		await _press("CHOOSE")
		await _press("REROLL")
		await _press("KEEP")
	print("SMOKE: new game -> %s, party of %d" % [_view_name(), ruik.game.players.size() if ruik.game else 0])


func _scripted_tour() -> void:
	await _press("HEROES")
	await _press("VIEW")
	await _press("GEAR")
	await _press("EQUIP")
	await _press("INFO")
	await _press("DONE")
	await _press("BACK")
	await _press("BACK")
	await _press("ITEMS")
	await _press("BACK")
	await _press("EXIT")
	await _press("QUESTS")
	await _press("EXIT")
	await _press("MAP")
	await _press("NO MAP")
	# Spend some gold and buy things so items and spells get exercised.
	ruik.game.gold = 5000
	for player in ruik.game.players:
		player.level = 5
		player.max_spell_points = 30
		player.spell_points = 30
	print("SMOKE: tour done in %s" % _view_name())


func _save_and_load() -> void:
	await _press("SAVE")
	await _press("OK")
	# Loading rebuilds the shops, which creates items and advances itemId (as
	# in the original), so that one field is left out of the comparison.
	var saved := ruik.game.save_game()
	saved.erase("itemId")
	var before := JSON.stringify(saved)
	ruik.start_saved_game()
	await get_tree().process_frame
	var loaded := ruik.game.save_game()
	loaded.erase("itemId")
	var after := JSON.stringify(loaded)
	print("SMOKE: save/load round trip %s" % ("matches" if before == after else "DIFFERS"))
	if before != after:
		print("  before: %s\n  after:  %s" % [before.left(400), after.left(400)])


func _random_play(steps: int) -> void:
	var moves := [View.LEFT, View.UP, View.RIGHT, View.DOWN]
	var teleports := ["wilderness", "ruins", "sewer", "fortress1", "crypt", "port", "castle"]
	for step in steps:
		await _wait_for_buttons()
		var texts := _enabled_buttons()
		if texts.is_empty():
			break
		# Now and then, jump to another map so more of the game gets visited.
		if step % 750 == 749 and ruik.view is MapView and ruik.stack.is_empty():
			var map_name: String = teleports[(step / 750) % teleports.size()]
			_teleport(map_name)
			continue
		var walkable := texts.filter(func(t): return moves.has(t))
		var text: String
		if ruik.view is MapView and walkable.size() > 0 and randf() < 0.75:
			text = walkable.pick_random()
		elif texts.has("TARGET") and randf() < 0.8:
			text = "TARGET"
		else:
			var others := texts.filter(func(t): return t != "NEW" and t != "SAVE")
			text = (others if others.size() > 0 else texts).pick_random()
		await _press(text)
		# Keep the party alive often enough to see more of the game.
		if step % 200 == 0 and ruik.game != null:
			ruik.game.heal_party()
	print("SMOKE: random play done in %s" % _view_name())


## Starts fights on maps of rising level and plays them out, preferring
## attacks and spells over walking.
func _combat_play(count: int) -> void:
	var outcomes := {}
	for i in count:
		_teleport(COMBAT_MAPS[i * COMBAT_MAPS.size() / count])
		var map_view: MapView = ruik.view
		ruik.game.heal_party()
		var encounter := ruik.game.create_encounter()
		if encounter.creatures.is_empty():
			continue
		map_view.encounter = encounter
		map_view.process_result("combat")
		var steps := 0
		while steps < 600 and not (ruik.view is MapView and ruik.stack.is_empty()):
			steps += 1
			await _wait_for_buttons()
			var texts := _enabled_buttons()
			if texts.is_empty():
				break
			var text: String = texts.pick_random()
			for preferred in COMBAT_PREFERENCES:
				if texts.has(preferred) and randf() < 0.7:
					text = preferred
					break
			if ruik.view is SelectView and not texts.has("CAST") and texts.has(View.DOWN) and randf() < 0.5:
				text = View.DOWN
			await _press(text)
		var outcome := "finished" if ruik.view is MapView else "unfinished in %s" % _view_name()
		outcomes[outcome] = outcomes.get(outcome, 0) + 1
		while not (ruik.view is MapView and ruik.stack.is_empty()):
			var texts := _enabled_buttons()
			var leave := ["OK", "DONE", "EXIT", "X", "CANCEL", "BACK", "NO"].filter(func(t): return texts.has(t))
			if leave.is_empty():
				break
			await _press(leave[0])
	print("SMOKE: combat outcomes %s" % outcomes)


func _teleport(map_name: String) -> void:
	var map: Dictionary = Data.maps[map_name]
	for feature in map.get("features", []):
		if feature.type == "transition":
			ruik.game.transition_to(map_name, feature.x, feature.y)
			ruik.set_view(MapView.new(ruik))
			print("SMOKE: teleported to %s" % map_name)
			return


func _finish() -> void:
	print("SMOKE: views seen: %s" % views_seen)
	print("SMOKE: buttons pressed: %s" % buttons_pressed)
	_restore_user_data()
	print("SMOKE: DONE")
	get_tree().quit()


# --- User data ----------------------------------------------------------------

func _backup_user_data() -> void:
	for path in [Device.SAVE_PATH, Device.SETTINGS_PATH]:
		_backup[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null


func _restore_user_data() -> void:
	for path in _backup:
		if _backup[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(_backup[path])
			file.close()
