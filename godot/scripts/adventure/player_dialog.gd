class_name PlayerDialog
extends SelectView
## Choose a hero (or the bag) for an action; pops the chosen index (bag = 3).

const ACTION_HEAL := "HEAL"
const ACTION_RESTORE := "RESTORE"
const ACTION_GIVE := "GIVE"
const ACTION_SELL := "SELL"

var game: Game
var can_select: Array = []
var action: String
var preselect = null


func _init(p_gurk: Gurk, p_action: String, p_preselect = null) -> void:
	super(p_gurk, p_action, "CANCEL")
	action = p_action
	preselect = p_preselect
	game = gurk.game
	can_select = []
	var y := 3
	var show_bag := false
	var message: String
	match action:
		ACTION_HEAL:
			message = "Heal which Adventurer?"
		ACTION_RESTORE:
			message = "Restore which Adventurer?"
		ACTION_GIVE:
			message = "Give to which Adventurer?"
			show_bag = true
		ACTION_SELL:
			message = "Which Adventurer will Sell?"
			show_bag = true
		_:
			message = "Choose an Adventurer"
	add_label_centered(message, "#FFF", 0, y, 128, GurkScreen.FONT.font_height)
	y += 12
	var index := 0
	var select_index := -1
	for player in game.players:
		add_icon(player.character.icon, 2, y)
		var active := true
		match action:
			ACTION_HEAL:
				active = player.is_alive() and not player.is_healed()
			ACTION_RESTORE:
				active = player.is_alive() and not player.is_restored()
			ACTION_GIVE:
				active = player.can_carry_more_items()
			ACTION_SELL:
				active = player.number_of_items() > 0
		can_select.append(active)
		if active and preselect != null and preselect == player:
			select_index = index
		add_option(player.character.name, "#FFF" if active else "#999", 20, y)
		y += 8
		match action:
			ACTION_HEAL:
				add_label("Hit Points: %d/%d" % [player.hit_points, player.max_hit_points], "#999", 20, y)
			ACTION_RESTORE:
				add_label("Spell Points: %d/%d" % [player.spell_points, player.max_spell_points], "#999", 20, y)
			ACTION_GIVE:
				add_label("Can carry %d more items." % (Player.MAX_ITEMS - player.number_of_items()), "#999", 20, y)
			ACTION_SELL:
				add_label("Carrying %d items." % player.number_of_items(), "#999", 20, y)
		y += 20
		index += 1
	if show_bag and game.bag != null:
		var bag := game.bag
		add_icon(bag.character.icon, 2, y)
		var active := true
		match action:
			ACTION_GIVE:
				active = bag.can_carry_more_items()
			ACTION_SELL:
				active = bag.number_of_items() > 0
		can_select.append(active)
		add_option(bag.character.name, "#FFF" if active else "#999", 20, y)
		y += 8
		match action:
			ACTION_GIVE:
				add_label("Room for %d more items." % (Player.MAX_ITEMS - bag.number_of_items()), "#999", 20, y)
			ACTION_SELL:
				add_label("Carrying %d items." % bag.number_of_items(), "#999", 20, y)
	if select_index >= 0:
		selected = select_index
	start()


func item_highlighted(index: int, _item) -> void:
	if can_select[index]:
		set_select_verb(action)
	else:
		turn_off_selection()


func item_selected(index: int, _item) -> void:
	gurk.pop_view(index)
