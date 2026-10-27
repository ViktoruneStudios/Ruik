class_name LevelUpView
extends InfoView
## Shows what each hero gained on levelling up.

var next_action


func _init(p_gurk: Gurk, upgrades: Array, p_next_action) -> void:
	super(p_gurk, "OK")
	next_action = p_next_action
	var y := AlertView.ICON_Y
	var text_x := AlertView.ICON_X * 2 + GurkScreen.UNIT
	add_label_centered("Levelling Up", "#FFF", 0, y, 128, y + 8)
	y += 12
	for upgrade in upgrades:
		var player: Player = upgrade.player
		add_icon(player.character.icon, AlertView.ICON_X, y)
		add_label(player.character.name, "#FFF", text_x, y)
		y += 8
		var text := "HP +%d" % upgrade.hitPointBonus
		if upgrade.spellPointBonus > 0:
			text += ", SP +%d" % upgrade.spellPointBonus
		if upgrade.newSpells:
			text += " +spells"
		add_label(text, "#A0A0A0", text_x, y)
		y += 8
		for i in 4:
			var attr_bonus: int = upgrade.attrBonuses[i]
			if attr_bonus > 0:
				add_label("%s +%d" % [Player.ATTRIBUTES[i], attr_bonus], "#A0A0A0", text_x, y)
				y += 8
		y += 4


func command(_text: String) -> void:
	gurk.pop_view(next_action)
