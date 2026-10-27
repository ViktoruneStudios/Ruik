extends Node
## Saves screenshots of key screens to user://screenshots/ (needs a window,
## so run without --headless):
##
##   godot --path godot res://tests/screenshots.tscn

var gurk: Gurk
var _backup := {}


func _ready() -> void:
	seed(7)
	for path in [Device.SAVE_PATH, Device.SETTINGS_PATH]:
		_backup[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	Device.set_setting("music", false)
	Device.set_setting("sound", false)
	Device.clear_game()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	gurk = load("res://main.tscn").instantiate()
	add_child(gurk)
	await _shot("1_title")
	for text in ["NEW", "OK", "CHOOSE", "KEEP", "CHOOSE", "KEEP", "CHOOSE", "KEEP"]:
		gurk.button_pressed(text)
	await _shot("2_town")
	gurk.button_pressed("HEROES")
	await _shot("3_party")
	gurk.button_pressed("VIEW")
	await _shot("4_hero")
	gurk.pop_to_top_view(null)
	gurk.button_pressed("MAP")
	await _shot("5_overview")
	gurk.button_pressed("NO MAP")
	gurk.game.transition_to("sewer", 2, 2)
	gurk.set_view(MapView.new(gurk))
	await _shot("6_dark_dungeon")
	var map_view: MapView = gurk.view
	map_view.encounter = gurk.game.create_encounter()
	map_view.encounter.creatures.append(Creature.new(Library.get_creature_by_name("Orc")))
	map_view.process_result("combat")
	await _shot("7_combat")
	print("SCREENSHOTS: saved to %s" % ProjectSettings.globalize_path("user://screenshots"))
	for path in _backup:
		if _backup[path] == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(_backup[path])
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://screenshots/%s.png" % shot_name)
