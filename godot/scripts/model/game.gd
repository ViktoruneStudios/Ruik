class_name Game
extends RefCounted
## The state of a game in progress: the party, where it is, and what it has done.

const MAX_ENCOUNTER_CREATURES := 18
const NUM_SHOP_ITEMS := 15

var players: Array = []
var bag: Player = null
var gold := 0
var map: String
var x := 0
var y := 0
var item_id := 0
var move_num := 0

## Map name -> 2D array of 0/1, which squares have been seen.
var visited: Dictionary = {}

## Transient: "x_y" -> {feature type -> feature} for the current map.
var features: Dictionary = {}

## Ship ID -> {"x", "y"} (only chartered ships are present).
var ships: Dictionary = {}

## Game variables that have been set.
var markers: Dictionary = {}

## Transient: "x_y" -> Array of Items for each shop on the current map.
var shops: Dictionary = {}

## The ID of the ship the party is aboard, if any.
var aboard = null


func _init() -> void:
	var first: Dictionary = Data.start[0]
	map = first.map
	x = first.x
	y = first.y
	gold = first.gold
	build_features()


func save_game() -> Dictionary:
	var player_data := []
	for player in players:
		player_data.append(player.to_data())
	return {
		"players": player_data,
		"bag": bag.to_data() if bag != null else null,
		"gold": gold,
		"map": map,
		"x": x,
		"y": y,
		"itemId": item_id,
		"moveNum": move_num,
		"visited": visited,
		"ships": ships,
		"markers": markers,
		"aboard": aboard,
	}


func load_game(json: String) -> bool:
	var saved = JSON.parse_string(json)
	if not (saved is Dictionary):
		push_error("Saved game could not be read.")
		return false
	saved = Util.normalize_numbers(saved)
	players = []
	for obj in saved.players:
		var player := Player.new(_saved_character(obj.character))
		player.from_data(obj)
		players.append(player)
	map = saved.map
	x = saved.x
	y = saved.y
	gold = saved.gold
	ships = saved.get("ships", {})
	markers = saved.get("markers", {})
	visited = saved.get("visited", {})
	move_num = saved.get("moveNum", 0)
	item_id = saved.get("itemId", 0)
	if saved.get("bag") != null:
		bag = Player.new(_saved_character(saved.bag.character))
		bag.from_data(saved.bag)
	build_features()
	return true


## Prefer the current definition of a saved character (by name).
func _saved_character(saved: Dictionary) -> Dictionary:
	var current = Library.get_character_by_name(saved.get("name", ""))
	return current if current != null else saved


func create_bag() -> void:
	if bag == null:
		bag = Player.new(Library.get_character_by_name("Bag of Holding"))


func death() -> void:
	ships = {}
	for player in players:
		player.heal_completely()
	gold = 0
	build_features()


func get_start() -> Dictionary:
	var best: Dictionary = Data.start[0]
	for start in Data.start:
		if start.get("after") != null and has_marker(start.after):
			best = start
	return best


static func get_key(kx, ky) -> String:
	return "%d_%d" % [kx, ky]


func set_markers(list_or_single) -> bool:
	if Util.eq(list_or_single, "bagOfHolding") and bag == null:
		create_bag()
	if Util.eq(list_or_single, "gameOver"):
		Device.set_setting("won", true)
	var new_markers := false
	if Util.truthy(list_or_single):
		for a in Util.as_array(list_or_single):
			if not markers.get(a, false):
				markers[a] = true
				new_markers = true
	if new_markers:
		build_features()
	return new_markers


func has_marker(marker) -> bool:
	return marker != null and Util.truthy(markers.get(marker))


func has_all_markers(list_or_single) -> bool:
	if Util.truthy(list_or_single):
		for a in Util.as_array(list_or_single):
			if not has_marker(a):
				return false
	return true


func has_any_markers(list_or_single) -> bool:
	if Util.truthy(list_or_single):
		for a in Util.as_array(list_or_single):
			if has_marker(a):
				return true
	return false


func build_features() -> void:
	features = {}
	shops = {}
	for feature in Data.maps[map].get("features", []):
		if has_all_markers(feature.get("after")) and not has_any_markers(feature.get("until")) and not has_any_markers(feature.get("id")):
			var fx = feature.x
			var fy = feature.y
			# If it's a ship, it may have moved
			if feature.type == "ship" and ships.has(feature.get("id")):
				fx = ships[feature.id].x
				fy = ships[feature.id].y
			var key := Game.get_key(fx, fy)
			if not features.has(key):
				features[key] = {}
			features[key][feature.type] = feature
			if feature.type == "shop":
				populate_shop_items(key, feature)


func populate_shop_items(key: String, shop: Dictionary) -> void:
	var shop_items := []
	shops[key] = shop_items
	for i in NUM_SHOP_ITEMS:
		var item = get_random_item(shop.level, shop.get("groups"))
		if item != null:
			shop_items.append(item)


func get_shop_items(sx, sy) -> Array:
	return shops.get(Game.get_key(sx, sy), [])


func is_chartered(ship_id) -> bool:
	return ships.has(ship_id)


func board_ship(ship_id) -> void:
	aboard = ship_id
	move_ship(x, y)


func move_ship(sx: int, sy: int) -> void:
	var feature = null
	var old_pos = ships.get(aboard)
	if old_pos != null:
		var old_key := Game.get_key(old_pos.x, old_pos.y)
		var object = features.get(old_key)
		if object != null:
			feature = object.get("ship")
			object.erase("ship")
			if object.is_empty():
				features.erase(old_key)
	else:
		feature = get_feature(sx, sy, "ship")
	var key := Game.get_key(sx, sy)
	ships[aboard] = {"x": sx, "y": sy}
	if not features.has(key):
		features[key] = {}
	features[key]["ship"] = feature


func disembark() -> void:
	aboard = null


func get_combat_map() -> String:
	return get_terrain_info().combatMap


func get_features(fx, fy):
	return features.get(Game.get_key(fx, fy))


func get_feature(fx, fy, type: String):
	var object = features.get(Game.get_key(fx, fy))
	if object == null:
		return null
	return object.get(type)


func add_player(player: Player) -> void:
	players.append(player)


func get_visited_array() -> Array:
	if not visited.has(map):
		visited[map] = Util.create_2d_array(Data.maps[map].width, Data.maps[map].height, 0)
	return visited[map]


func mark_visited(vx: int, vy: int) -> void:
	var row: Array = get_visited_array()[vy]
	row[vx] = 1


func was_visited(vx: int, vy: int) -> bool:
	return get_visited_array()[vy][vx] == 1


func move_to(mx: int, my: int) -> void:
	x = mx
	y = my
	if aboard != null:
		move_ship(mx, my)


func transition_to(map_name: String, tx: int, ty: int) -> void:
	map = map_name
	build_features()
	x = tx
	y = ty


func does_item_exist(item_name: String) -> bool:
	# 1) Check all players
	for player in players:
		if player.has_item(item_name):
			return true
	if bag != null and bag.has_item(item_name):
		return true
	# 2) Check all shops
	for k in shops:
		for item in shops[k]:
			if item.template.name == item_name:
				return true
	return false


func create_item(template: Dictionary, bonus: int = 0, charges: int = 0) -> Item:
	item_id += 1
	return Item.new(template, item_id, bonus, charges)


func _rarity(template: Dictionary) -> int:
	var rarity = template.get("rarity")
	return int(rarity) if rarity != null else 1000


func get_random_template(templates: Array):
	var total := 0
	for template in templates:
		total += _rarity(template)
	var value := Util.random(0, total - 1)
	for template in templates:
		var rarity := _rarity(template)
		if rarity > value:
			return template
		value -= rarity
	return null


func get_random_item(map_level: int, groups):
	var level := Library.get_level_near(map_level)
	var templates := Library.get_item_templates(level, groups)
	if templates.is_empty():
		return null
	var attempts := 0
	var template = null
	while template == null and attempts < 5:
		attempts += 1
		template = get_random_template(templates)
		if template != null and Util.truthy(template.get("legendary")) and does_item_exist(template.name):
			template = null
	if template == null:
		return null
	var bonus := 0
	if not Util.truthy(template.get("legendary")):
		var mod_chance := 1
		var level_diff_factor := map_level - level + 2
		for i in maxi(level_diff_factor, 0):
			mod_chance *= 2
		mod_chance = mini(mod_chance, 75)
		var chance := Util.random(0, 99)
		while chance < mod_chance and bonus < 6:
			bonus += 1
			chance = Util.random(0, 99)
	var charges := 0
	if Util.truthy(template.get("chargesMin")):
		charges = Util.random(template.chargesMin, template.chargesMax)
	return create_item(template, bonus, charges)


func players_need_healing() -> bool:
	for player in players:
		if player.hit_points < player.max_hit_points:
			return true
	return false


func heal_party() -> void:
	for player in players:
		player.heal_completely()


func regenerate_party() -> void:
	for player in players:
		if player.is_alive():
			if player.hit_points < player.max_hit_points:
				player.hit_points += 1
			if player.spell_points < player.max_spell_points:
				player.spell_points += 1


static func get_creature_quantity(creature_level: int, map_level: int, limit := false) -> int:
	var diff := clampi(creature_level - map_level, -3, 3)
	var amount: int
	match diff:
		-3:
			amount = Util.random(3, 9)
		-2:
			amount = Util.random(2, 5)
		-1:
			amount = Util.random(1, 4)
		0:
			amount = Util.random(1, 3)
		_:
			amount = 1
	if limit:
		amount = clampi(Util.js_round(amount / 2.0), 1, 2)
	return amount


func get_encounter(feature: Dictionary) -> Dictionary:
	var creatures := []
	for info in feature.get("creatures", []):
		var template = Library.get_creature_by_name(info.name)
		if template == null:
			push_warning("Creature not found: %s" % info.name)
			continue
		var creature := Creature.new(template, info.get("bonus", 0))
		var hp_bonus: int = info.get("hitPoints", 0)
		creature.max_hit_points += hp_bonus
		creature.hit_points += hp_bonus
		creatures.append(creature)
	var found_items := []
	for info in feature.get("items", []):
		var template = Library.get_item_template_by_name(info.name)
		if template == null:
			push_warning("Item not found: %s" % info.name)
			continue
		var charges := 0
		if Util.truthy(template.get("chargesMin")):
			charges = Util.random(template.chargesMin, template.chargesMax)
		found_items.append(create_item(template, info.get("bonus", 0), charges))
	return {
		"creatures": creatures,
		"items": found_items,
		"gold": feature.get("gold", 0),
		"ambushed": Util.truthy(feature.get("ambushed")),
	}


func give_experience(creatures: Array) -> Array:
	var total_xp := 0
	for creature in creatures:
		total_xp += creature.template.experienceValue
	var total_players := 0
	for player in players:
		if player.is_alive():
			total_players += 1
	var xp := int(ceil(float(total_xp) / maxi(total_players, 1)))
	var upgrades := []
	for player in players:
		if not player.is_alive():
			continue
		player.experience += xp
		if player.level < Data.levels.size() and player.experience >= Data.levels[player.level]:
			# Level up
			player.level += 1
			var attr_bonuses := [0, 0, 0, 0]
			for i in 2:
				var attr := Util.random(0, 3)
				attr_bonuses[attr] += 1
				match attr:
					0:
						player.strength += 1
					1:
						player.accuracy += 1
					2:
						player.awareness += 1
					3:
						player.constitution += 1
			var constitution_bonus: int = player.get_attribute_bonus(player.get_constitution())
			var awareness_bonus: int = player.get_attribute_bonus(player.get_awareness())
			var hit_point_bonus := maxi(1, Util.random(2, 8) + constitution_bonus)
			var spell_point_bonus := 0
			if player.has_spells():
				spell_point_bonus = maxi(1, Util.random(1, 5) + awareness_bonus)
				if player.max_spell_points == 0:
					player.spell_points = 0
			player.max_hit_points += hit_point_bonus
			player.hit_points += hit_point_bonus
			player.max_spell_points += spell_point_bonus
			player.spell_points += spell_point_bonus
			var new_spells := Library.new_spells_for_character_and_level(player.character, player.level)
			upgrades.append({"player": player, "attrBonuses": attr_bonuses, "hitPointBonus": hit_point_bonus, "spellPointBonus": spell_point_bonus, "newSpells": new_spells})
	return upgrades


func get_average_player_level() -> float:
	var total := 0
	for player in players:
		if player.is_alive():
			total += player.level
	return total / 3.0


func get_tile(tx: int, ty: int) -> String:
	var override = get_feature(tx, ty, "override")
	if override != null:
		return override.tile
	var map_data: Dictionary = Data.maps[map]
	var index := ty * int(map_data.width) + tx
	var tiles_string: String = map_data.map
	if index < 0 or index >= tiles_string.length():
		return ""
	return tiles_string[index]


func get_terrain_info() -> Dictionary:
	var tile := get_tile(x, y)
	var map_data: Dictionary = Data.maps[map]
	var terrain = map_data.get("terrain", {}).get(tile)
	if terrain != null:
		return terrain
	return {
		"level": map_data.get("level", 1),
		"encounterChance": map_data.get("encounterChance"),
		"combatMap": map_data.get("combatMap"),
		"groups": map_data.get("groups"),
	}


func check_for_random_encounter() -> bool:
	var terrain := get_terrain_info()
	var encounter_chance = terrain.get("encounterChance")
	if Util.truthy(encounter_chance):
		var dungeon_level: int = terrain.level
		var chance := float(encounter_chance)
		if dungeon_level < 10: # Don't filter encounters over a certain level, for indefinite play
			chance = chance / maxf(1.0, get_average_player_level() - dungeon_level - 1.5)
		if Util.random_chance(chance, 1000):
			return true
	return false


func create_encounter() -> Dictionary:
	var terrain := get_terrain_info()
	var map_level: int = terrain.level
	var groups = terrain.get("groups")
	var creatures := []
	var k := Util.random(1, 3)
	var full := false
	for i in k:
		if full:
			break
		var level := Library.get_level_near(map_level)
		var candidates := Library.get_creatures(level, groups)
		while candidates.is_empty() and level > 0:
			level -= 1
			candidates = Library.get_creatures(level, groups)
		if candidates.size() > 0:
			var template: Dictionary = Util.random_element(candidates)
			var n := Game.get_creature_quantity(template.level, map_level, Util.truthy(template.get("limit")))
			if Util.truthy(template.get("summons")):
				n = mini(n, 2)
			for j in n:
				# Todo - maybe have a chance of an "uber" version of creature here, with a bonus?
				creatures.append(Creature.new(template, 0))
				if creatures.size() == MAX_ENCOUNTER_CREATURES:
					full = true
					break
	var found_items := []
	var found_gold := 0
	for creature in creatures:
		var max_gold := 2.0
		for i in maxi(creature.template.level - 1, 0):
			if i > 9:
				max_gold *= 1.1
			elif i > 2:
				max_gold *= 1.4
			else:
				max_gold *= 1.8
		found_gold += Util.random(0, Util.js_round(max_gold))
		var treasure_level := mini(int(creature.template.level), 10)
		if Util.random_chance(Data.treasure_chance[treasure_level - 1], 1000):
			var item = get_random_item(creature.template.level, groups)
			if item != null and Util.truthy(item.template.get("legendary")):
				for other in found_items:
					if other.template.name == item.template.name:
						item = null
						break
			if item != null:
				found_items.append(item)
			if found_items.size() == 5:
				break
	return {"creatures": creatures, "items": found_items, "gold": found_gold, "ambushed": Util.random_chance(25, 100)}
