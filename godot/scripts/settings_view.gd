class_name SettingsView
extends SelectView


func _init(p_gurk: Gurk) -> void:
	super(p_gurk, "TOGGLE", "DONE")


func do_layout() -> void:
	clear()
	var y := 3
	add_label_centered("Settings", "#FFF", 0, y, 128, GurkScreen.FONT.font_height)
	y += 12
	add_option("Music is %s" % _on_off(gurk.get_music_setting()), "#FFF", 8, y)
	y += 8
	add_option("Combat music is %s" % _on_off(gurk.get_combat_music_setting()), "#FFF", 8, y)
	y += 8
	add_option("Sound FX are %s" % _on_off(gurk.get_sound_setting()), "#FFF", 8, y)
	y += 8
	add_option("Fast combat is %s" % _on_off(gurk.get_fast_setting()), "#FFF", 8, y)
	start()


static func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func item_selected(index: int, _item) -> void:
	match index:
		0:
			gurk.set_music_setting(not gurk.get_music_setting())
		1:
			gurk.set_combat_music_setting(not gurk.get_combat_music_setting())
		2:
			gurk.set_sound_setting(not gurk.get_sound_setting())
		3:
			gurk.set_fast_setting(not gurk.get_fast_setting())
	do_layout()
	draw()
