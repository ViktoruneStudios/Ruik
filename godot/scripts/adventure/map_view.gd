class_name MapView
extends TileView
## The main exploration view: walking the party around the current map.

const MAP_ICONS := {
	"shop": [
		["#764F00", "#FFFF48", "#764F00"],
		["#764F00", "#000000", "#764F00"],
		["#764F00", "#000000", "#764F00"],
	],
	"ship": [
		[null, "#FFFFFF", null],
		["#FFFFFF", "#FFFFFF", null],
		["#AF7300", "#AF7300", "#AF7300"],
	],
	"temple": [
		["#FFFFFF", "#FF0000", "#FFFFFF"],
		["#FF0000", "#FF0000", "#FF0000"],
		["#FFFFFF", "#FF0000", "#FFFFFF"],
	],
}

const TRANSITION_ICONS := {
	"outdoor": [
		["#3CF000", "#3CF000", "#3CF000"],
		["#32C800", "#32C800", "#32C800"],
		[null, "#AF7300", null],
	],
	"dungeon": [
		[null, "#FFFFFF", null],
		["#FFFFFF", "#FFFFFF", "#FFFFFF"],
		["#FFFFFF", "#000000", "#FFFFFF"],
	],
	"up": [
		[null, null, "#FFFFFF"],
		[null, "#FFFFFF", "#FFFFFF"],
		["#FFFFFF", "#FFFFFF", "#FFFFFF"],
	],
	"down": [
		["#FFFFFF", null, null],
		["#FFFFFF", "#FFFFFF", null],
		["#FFFFFF", "#FFFFFF", "#FFFFFF"],
	],
	"town": [
		["#FFFFFF", null, "#FFFFFF"],
		["#FFFFFF", "#FFFFFF", "#FFFFFF"],
		["#FFFFFF", "#AF7300", "#FFFFFF"],
	],
}

## In priority order: the first one present on a square is the one shown/used.
const FEATURE_TYPES := [
	"block",
	"barrier",
	"encounter",
	"goal",
	"alert",
	"dispatch",
	"transition",
	"shop",
	"temple",
	"ship",
	"sign",
	"override",
]

var game: Game
var shadows: Array = []
var map_mode := false
var encounter = null
var upgrades: Array = []
var shadow_overlay: Texture2D


func _init(p_gurk: Gurk) -> void:
	super(p_gurk, p_gurk.game.map)
	name = "MapView"
	offset_x = -GurkScreen.HALF_UNIT
	offset_y = -GurkScreen.HALF_UNIT
	game = p_gurk.game
	pos_x = game.x
	pos_y = game.y
	map_mode = false
	shadow_overlay = load("res://assets/images/shadow.png")
	set_button(1, "HEROES")
	set_button(9, "MAP")
	set_button(3, "SAVE")
	set_button(7, "QUESTS")
	shadows = Util.create_2d_array(GurkScreen.WIN_SIZE, GurkScreen.WIN_SIZE, true)
	for y in range(-1, 2):
		for x in range(-1, 2):
			shadows[y + GurkScreen.CENTER_OFFSET][x + GurkScreen.CENTER_OFFSET] = false
	center_banner = true
	move(0, 0)


func toggle_map() -> void:
	map_mode = not map_mode
	set_button(9, "NO MAP" if map_mode else "MAP")
	draw()


func command(text: String) -> void:
	if text == View.LEFT:
		move(-1, 0)
		return
	if text == View.UP:
		move(0, -1)
		return
	if text == View.RIGHT:
		move(1, 0)
		return
	if text == View.DOWN:
		move(0, 1)
		return
	match text:
		"MAP", "NO MAP":
			toggle_map()
		"HEROES":
			gurk.push_view(PartyView.new(gurk))
		"QUESTS":
			gurk.push_view(QuestView.new(gurk))
		"SAVE":
			Device.save_game(JSON.stringify(game.save_game()))
			gurk.push_view(AlertView.new(gurk, Data.icons.party, "Game Saved", "Your game has been saved!", null))
		_:
			process_feature(text)


func _opaque(x: int, y: int) -> bool:
	return Util.truthy(get_terrain(x, y).get("opaque"))


func check_visibility(x: int, y: int) -> void:
	var dx := x - GurkScreen.CENTER_OFFSET
	var dy := y - GurkScreen.CENTER_OFFSET
	var yy := dy + pos_y
	var xx := dx + pos_x
	if yy >= 0 and yy < height and xx >= 0 and xx < width:
		var nx := -1 if dx > 0 else 1
		var ny := -1 if dy > 0 else 1
		if dx == 0:
			shadows[y][x] = shadows[ny + y][x] or _opaque(xx, ny + yy)
		elif dy == 0:
			shadows[y][x] = shadows[y][nx + x] or _opaque(nx + xx, yy)
		elif dx == dy or dx == -dy:
			shadows[y][x] = shadows[ny + y][nx + x] or _opaque(nx + xx, ny + yy)
		else:
			var t1: bool = shadows[ny + y][x] or _opaque(xx, ny + yy)
			var t2: bool = shadows[y][nx + x] or _opaque(nx + xx, yy)
			var t3: bool = shadows[ny + y][nx + x] or _opaque(nx + xx, ny + yy)
			shadows[y][x] = t1 and t2 and t3
	else:
		shadows[y][x] = true


func compute_shadows() -> void:
	# Immediate surroundings are always visible
	var c := GurkScreen.CENTER_OFFSET
	# Move in a spiral pattern, inductively computing visibility
	for k in range(2, 5):
		for i in range(0, k + 1):
			check_visibility(i + c, k + c)
			check_visibility(i + c, -k + c)
			if i < k:
				check_visibility(k + c, i + c)
				check_visibility(-k + c, i + c)
			if i > 0:
				check_visibility(-i + c, k + c)
				check_visibility(-i + c, -k + c)
				if i < k:
					check_visibility(k + c, -i + c)
					check_visibility(-k + c, -i + c)


func track_visited() -> void:
	var dark := Util.truthy(map.get("dark"))
	for y in GurkScreen.WIN_SIZE:
		var yy := y + pos_y - GurkScreen.CENTER_OFFSET
		if yy >= 0 and yy < height:
			for x in GurkScreen.WIN_SIZE:
				var xx := x + pos_x - GurkScreen.CENTER_OFFSET
				if xx >= 0 and xx < width:
					if not dark or not shadows[y][x]:
						game.mark_visited(xx, yy)


func get_terrain(x: int, y: int) -> Dictionary:
	return Data.tiles.get(game.get_tile(x, y), {})


func do_draw() -> void:
	var dark := Util.truthy(map.get("dark"))
	for y in GurkScreen.WIN_SIZE:
		var yy := y + pos_y - GurkScreen.CENTER_OFFSET
		if yy >= 0 and yy < height:
			for x in GurkScreen.WIN_SIZE:
				var xx := x + pos_x - GurkScreen.CENTER_OFFSET
				if xx >= 0 and xx < width:
					if not dark or not shadows[y][x]:
						draw_tile(get_terrain_icon(xx, yy), x, y)
						if game.get_features(xx, yy) != null:
							var feature = get_top_feature(xx, yy)
							if feature != null and feature.get("icon") != null:
								draw_tile(feature.icon, x, y)
	var party_icon = Data.icons.ship if game.aboard != null else Data.icons.party
	draw_tile(party_icon, GurkScreen.CENTER_OFFSET, GurkScreen.CENTER_OFFSET)
	if dark:
		screen.draw_image(shadow_overlay, 0, 0)
	if map_mode:
		_draw_overview()
	else:
		draw_banner()
		draw_top_banner()


func _draw_overview() -> void:
	var sx: float = 128 - width - 5
	if sx < 10:
		sx = (128 - width) / 2.0
	var sy := 5.0
	screen.set_alpha(0.5)
	screen.fill_rect("#000", sx - 3, sy - 3, width + 6, height + 6)
	screen.set_alpha(1)
	screen.fill_rect("#aaa", sx - 1, sy - 1, width + 2, height + 2)
	for y in height:
		for x in width:
			var color = get_terrain(x, y).get("color", "#000") if game.was_visited(x, y) else "#000"
			screen.draw_pixel(color, x + sx, y + sy)
	# Next: features
	for y in height:
		for x in width:
			if game.was_visited(x, y):
				var feature = get_top_feature(x, y)
				if feature != null:
					var icon = null
					match feature.type:
						"shop", "ship", "temple":
							icon = MAP_ICONS[feature.type]
						"transition":
							icon = TRANSITION_ICONS.get(feature.get("transitionType"))
					if icon != null:
						for yy in 3:
							for xx in 3:
								var color = icon[yy][xx]
								if color != null:
									screen.draw_pixel(color, sx + x + xx - 1, sy + y + yy - 1)
	# Finally, the adventurers
	screen.draw_pixel("#F00", pos_x + sx - 1, pos_y + sy)
	screen.draw_pixel("#F00", pos_x + sx + 1, pos_y + sy)
	screen.draw_pixel("#F00", pos_x + sx, pos_y + sy + 1)
	screen.draw_pixel("#F00", pos_x + sx, pos_y + sy - 1)


func get_top_feature(x: int, y: int):
	for type in FEATURE_TYPES:
		var feature = game.get_feature(x, y, type)
		if feature != null:
			return feature
	return null


func _play_map_music() -> void:
	if Util.truthy(map.get("music")):
		gurk.play_music(map.music)


func _play_boat_music() -> void:
	if Util.truthy(map.get("boatMusic")):
		gurk.play_music(map.boatMusic)
	else:
		gurk.play_music(Data.boat_music)


func move(x: int, y: int) -> void:
	var real_move := not (x == 0 and y == 0)
	var tx := pos_x + x
	var ty := pos_y + y
	if tx < 0 or tx >= width or ty < 0 or ty >= height:
		return
	if game.get_feature(tx, ty, "block") != null:
		return
	var barrier = game.get_feature(tx, ty, "barrier")
	if barrier != null:
		var title = barrier.title if Util.truthy(barrier.get("title")) else "Cannot Pass"
		gurk.push_view(AlertView.new(gurk, barrier.get("icon"), title, barrier.get("text"), null))
		return
	var terrain := get_terrain(tx, ty)
	if not (Util.truthy(terrain.get("passable")) or Util.truthy(terrain.get("shipPassable")) and (game.aboard != null or game.get_feature(tx, ty, "ship") != null)):
		return
	clear_banner()
	if real_move and game.aboard != null and game.get_feature(tx, ty, "ship") != null:
		# Move onto the next ship
		game.disembark()
		_play_map_music()
	pos_x = tx
	pos_y = ty
	if game.aboard != null and not Util.truthy(terrain.get("shipPassable")):
		game.disembark()
		_play_map_music()
	if real_move:
		game.move_to(pos_x, pos_y)
		game.move_num += 1
		if game.move_num % 20 == 0:
			game.regenerate_party()
	if Util.truthy(map.get("dark")):
		compute_shadows()
	track_visited()
	var have_feature := false
	if game.aboard == null and game.get_feature(tx, ty, "ship") != null:
		var ship = game.get_feature(tx, ty, "ship")
		if game.is_chartered(ship.get("id")) or not Util.truthy(ship.get("charter")):
			clear_button(5)
			game.board_ship(ship.get("id"))
			_play_boat_music()
		else:
			set_button(5, "CHARTER")
			have_feature = true
	if game.get_features(pos_x, pos_y) != null:
		var feature = get_top_feature(pos_x, pos_y)
		if feature != null and feature.type != "ship": # ships are handled above
			have_feature = true
			match feature.type:
				"encounter":
					encounter = game.get_encounter(feature)
					if encounter.creatures.is_empty():
						game.set_markers(feature.get("id"))
						game.set_markers(feature.get("sets"))
						var found_gold: int = encounter.get("gold", 0)
						var text := View.s(feature.get("text"))
						if found_gold > 0:
							game.gold += found_gold
							text += "\n\nYou find %d gold pieces!" % found_gold
						var next = null if encounter.items.is_empty() else "treasure"
						gurk.push_view(AlertView.new(gurk, feature.get("icon"), "Treasure", text, next, feature.get("altIcon")))
					else:
						gurk.play_combat_music()
						gurk.push_view(AlertView.new(gurk, feature.get("icon"), "Encounter", feature.get("text"), "combat"))
					return
				"alert":
					if real_move:
						game.set_markers(feature.get("sets"))
						gurk.push_view(AlertView.new(gurk, feature.get("icon"), feature.get("title"), feature.get("text"), "alert", feature.get("altIcon")))
						return
				"goal":
					game.set_markers(feature.get("sets"))
					gurk.push_view(AlertView.new(gurk, feature.get("icon"), feature.get("title"), feature.get("text"), "goal", feature.get("altIcon")))
					return
				_:
					add_button_for_feature(feature, real_move)
	if not have_feature:
		clear_button(5)
		# Make sure it's a "real" move
		if real_move and game.check_for_random_encounter():
			encounter = game.create_encounter()
			if encounter.creatures.size() > 0:
				var text := "Your adventurers have been ambushed!" if encounter.ambushed else "Your adventurers have been attacked!"
				gurk.play_combat_music()
				gurk.push_view(AlertView.new(gurk, Data.icons.combat, "Encounter", text, "combat"))
				return
	draw()


func set_map(p_map_name: String, x: int, y: int) -> void:
	super(p_map_name, x, y)
	_play_map_music()


func add_button_for_feature(feature: Dictionary, real_move: bool) -> void:
	clear_button(5)
	match feature.type:
		"sign":
			if Util.truthy(feature.get("text")):
				set_button(5, feature.get("action", "LOOK"))
		"transition":
			if real_move:
				set_banner(Data.maps[feature.target].name)
			set_button(5, "GO")
		"shop":
			set_banner(feature.get("name"))
			set_button(5, "SHOP")
		"temple":
			set_button(5, "HEAL")
		"dispatch":
			set_button(5, View.s(feature.get("action")))


func process_feature(_command: String) -> void:
	var feature = get_top_feature(pos_x, pos_y)
	if feature == null:
		return
	match feature.type:
		"sign":
			game.set_markers(feature.get("sets"))
			var title = feature.get("title") if feature.get("title") != null else "Sign"
			gurk.push_view(AlertView.new(gurk, feature.get("icon"), title, feature.get("text"), "sign", feature.get("altIcon")))
		"transition":
			gurk.push_view(ConfirmView.new(gurk, feature.get("icon"), "Go", feature.get("text"), "transition", null))
		"shop":
			gurk.push_view(ItemView.new(gurk, null, ItemView.ACTION_BUY, feature))
		"temple":
			if feature.cost > game.gold:
				gurk.push_view(AlertView.new(gurk, feature.get("icon"), "Cannot Pay", "The priests of the temple demand a tribute of %d gold pieces, but you cannot pay it!" % feature.cost, null))
			else:
				gurk.push_view(ConfirmView.new(gurk, feature.get("icon"), "Tribute", "To heal the adventurers, the priests require a tribute of %d gold pieces, will you pay it?" % feature.cost, "heal", null))
		"ship":
			if feature.charter > game.gold:
				gurk.push_view(AlertView.new(gurk, feature.get("icon"), "Cannot Pay", "The crew demand %d gold pieces to charter this vessel, but you cannot pay it!" % feature.charter, null))
			else:
				gurk.push_view(ConfirmView.new(gurk, feature.get("icon"), "Charter Ship", "Will you pay the crew %d gold pieces to charter this ship?" % feature.charter, "charter", null))
		"dispatch":
			gurk.push_view(ConfirmView.new(gurk, feature.get("icon"), feature.get("title"), feature.get("text"), "dispatch", null, feature.get("altIcon")))


func process_result(result) -> void:
	if not (result is String):
		return
	match result:
		"goal", "alert", "sign":
			move(0, 0)
			draw()
		"transition":
			var feature = get_top_feature(pos_x, pos_y)
			game.transition_to(feature.target, feature.targetX, feature.targetY)
			set_map(feature.target, feature.targetX, feature.targetY)
			# Process it as a move
			move(0, 0)
			if map_mode:
				toggle_map()
			draw()
		"victory":
			_victory()
		"levelup":
			var next_action = "treasure" if encounter.items.size() > 0 else null
			gurk.push_view(LevelUpView.new(gurk, upgrades, next_action))
		"treasure":
			gurk.push_view(ItemView.new(gurk, null, ItemView.ACTION_GIVE, encounter.items))
		"combat":
			gurk.push_view(CombatView.new(gurk, game.get_combat_map(), gurk.image_processor, encounter.creatures, encounter.ambushed))
		"heal":
			var temple = get_top_feature(pos_x, pos_y)
			game.gold -= temple.cost
			game.heal_party()
		"charter":
			var ship = get_top_feature(pos_x, pos_y)
			game.gold -= ship.charter
			game.board_ship(ship.get("id"))
			_play_boat_music()
			clear_button(5)
		"dispatch":
			var feature = get_top_feature(pos_x, pos_y)
			game.set_markers(feature.get("sets"))
		"defeat":
			game.death()
			var start: Dictionary = game.get_start()
			game.transition_to(start.map, start.x, start.y)
			set_map(start.map, start.x, start.y)
			move(0, 0)
			gurk.push_view(AlertView.new(gurk, Data.icons.death, "Defeat", "You have been defeated! As blackness closes in, a strange feeling comes over the adventurers...", null))
		"debug1":
			game.players[0].take_damage(3)
			var image := gurk.image_processor.rotate(Data.icons.death, ImageProcessor.LEFT)
			fly(Data.icons.death, 1, 7, 7, 1, 75, func(): pass, image)


func _victory() -> void:
	if game.aboard != null:
		_play_boat_music()
	else:
		_play_map_music()
	var feature = game.get_feature(pos_x, pos_y, "encounter")
	if feature != null:
		game.set_markers(feature.get("id"))
		game.set_markers(feature.get("sets"))
	move(0, 0) # Compute shadows, set visited, etc.
	var treasure: Array = encounter.items
	var found_gold: int = encounter.gold
	game.gold += found_gold
	var action = null
	var icon
	var text: String
	if treasure.size() > 0:
		action = "treasure"
		icon = Data.icons.treasure
		if found_gold > 0:
			text = "You find %d gold pieces and treasure amongst your defeated foes!" % found_gold
		else:
			text = "You find treasure amongst your defeated your foes!"
	elif found_gold > 0:
		icon = Data.icons.gold
		text = "You find %d gold pieces amongst your defeated foes!" % found_gold
	else:
		icon = Data.icons.party
		text = "You have defeated your foes!"
	upgrades = game.give_experience(encounter.creatures)
	if upgrades.size() > 0:
		text += "\n"
		for upgrade in upgrades:
			text += "\n%s gained a level!" % upgrade.player.character.name
		action = "levelup"
	gurk.push_view(AlertView.new(gurk, icon, "Victory", text, action))
