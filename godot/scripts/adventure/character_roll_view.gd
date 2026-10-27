class_name CharacterRollView
extends InfoView
## Rolls a new hero's attributes until the player keeps one.

var player: Player = null
var game: Game
var character: Dictionary


func _init(p_gurk: Gurk, p_game: Game, p_character: Dictionary) -> void:
	super(p_gurk, "KEEP")
	game = p_game
	character = p_character
	set_button(1, "REROLL")
	set_button(7, "BACK")
	roll()


func roll() -> void:
	player = Player.new(character)
	clear()
	add_icon(player.character.icon, 3, 3)
	var y := 4
	add_label(player.character.name, "#FFF", 20, y)
	y += 8
	add_label("Level %d %s" % [player.level, player.character.job], "#FFF", 20, y)
	y += 8
	add_label("XP: %d/%s" % [player.experience, Data.levels[player.level + 1]], "#FFF", 20, y)
	y += 8
	if player.max_spell_points > 0:
		add_label("HP: %d/%d, SP: %d/%d" % [player.hit_points, player.max_hit_points, player.spell_points, player.max_spell_points], "#FFF", 20, y)
	else:
		add_label("Hit Points: %d/%d" % [player.hit_points, player.max_hit_points], "#FFF", 20, y)
	y += 8
	add_label("Armor Class: %d" % player.get_armor_class(), "#FFF", 20, y)
	y += 16
	y = _add_attribute("Strength", player.get_strength(), "Damage Bonus", y)
	y = _add_attribute("Accuracy", player.get_accuracy(), "To-Hit Bonus", y)
	y = _add_attribute("Awareness", player.get_awareness(), "Armor Class Bonus", y)
	_add_attribute("Toughness", player.get_constitution(), "HP Bonus/Level", y)


func _add_attribute(label: String, value: int, bonus_label: String, y: int) -> int:
	add_label("%s: %d" % [label, value], "#FFF", 20, y)
	y += 8
	var bonus := player.get_attribute_bonus(value)
	if bonus != 0:
		add_label("%s: %d" % [bonus_label, bonus], "#A0A0A0", 28, y)
	return y + 10


func command(text: String) -> void:
	match text:
		"KEEP":
			game.add_player(player)
			gurk.pop_view("NEXT")
		"BACK":
			gurk.pop_view("BACK")
		"REROLL":
			roll()
			draw()
