class_name SpellInfoView
extends InfoView
## Details of a single spell.

var player
var spell: Dictionary


func _init(p_gurk: Gurk, p_player, p_spell: Dictionary) -> void:
	super(p_gurk, "DONE")
	player = p_player
	spell = p_spell
	var amount: Dictionary = player.get_spell_range(spell)
	add_icon(Data.icons.spell, 3, 3)
	add_label_centered(spell.name, "#FFF", 0, 4, 128, 16)
	var y := 23
	var x := 3
	add_label("Level: %d" % spell.level, "#FFF", x, y)
	y += 8
	add_label("Casting Cost: %d SP" % spell.spellPoints, "#FFF", x, y)
	y += 8
	add_label("Speed: %s" % ("| Fast" if Util.truthy(spell.get("fast")) else "= Normal"), "#FFF", x, y)
	y += 8
	if spell.type == "summon":
		add_label("Summons: %s" % spell.get("creature"), "#FFF", x, y)
		return
	var effect: String
	match spell.type:
		"damage":
			effect = "Damage %d - %d" % [amount.min, amount.max]
		"drain":
			effect = "Drains Life %d - %d" % [amount.min, amount.max]
		"heal":
			match spell.get("healType"):
				"restore":
					effect = "Restore"
				"remove":
					effect = "Remove Afflictions"
				_:
					effect = "Heal %d - %d" % [amount.min, amount.max]
		"teleport":
			effect = "Teleport"
		_:
			if Util.eq(spell.get("effect"), "Poisoned"):
				effect = "Poisoned (%s)" % spell.get("value")
			else:
				effect = View.s(spell.get("effect"))
	add_label("Effect: %s" % effect, "#FFF", x, y)
	y += 8
	add_label("Target: %s" % ItemInfoView.describe_target(spell), "#FFF", x, y)
