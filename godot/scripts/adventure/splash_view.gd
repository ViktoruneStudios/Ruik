class_name SplashView
extends TileView
## The title screen.

const TYPES := ["warrior", "archer", "mage"]

var index := 0
var game: Game = null


func _init(p_gurk: Gurk) -> void:
	super(p_gurk, "splashScreen")
	name = "Splash"
	offset_x = -GurkScreen.HALF_UNIT
	offset_y = -GurkScreen.HALF_UNIT
	index = 0


func do_layout() -> void:
	set_button(1, "NEW")
	if Device.has_saved_game():
		set_button(3, "LOAD")
	else:
		clear_button(3)
	set_button(7, "OPTIONS")
	# A hook to validate the game data (prints to the output log)
	set_button(9, "CHECK")


func do_draw() -> void:
	for y in height:
		for x in width:
			draw_tile(get_terrain_icon(x, y), x, y)
	for feature in map.get("features", []):
		draw_tile(feature.icon, feature.x, feature.y)


func show_intro() -> void:
	gurk.push_view(AlertView.new(gurk, Data.icons.party, "Welcome", "Welcome to realm of Gurk!\n\nRoll the stats for your Warrior, Archer and Mage, then lead them on to thrilling adventure!", "CREATE"))


func command(text: String) -> void:
	match text:
		"NEW":
			if Device.has_saved_game():
				gurk.push_view(ConfirmView.new(gurk, Data.icons.party, "Warning!", "Creating a new game will delete your existing game. Are you sure you want to do this?", "NEW", "CANCEL"))
			else:
				show_intro()
		"LOAD":
			gurk.start_saved_game()
		"OPTIONS":
			gurk.show_settings()
		"CHECK":
			Validate.run()
			gurk.push_view(AlertView.new(gurk, Data.icons.party, "Data Check", "The game data has been checked. Any problems were printed to the output log.", null))


func process_result(result) -> void:
	if not (result is String):
		return
	match result:
		"NEW":
			show_intro()
		"CREATE":
			game = Game.new()
			index = 0
			gurk.push_view(ChooseCharacterView.new(gurk, TYPES[index], game))
		"NEXT":
			index += 1
			if index == TYPES.size():
				gurk.start_new_game(game)
			else:
				gurk.push_view(ChooseCharacterView.new(gurk, TYPES[index], game))
