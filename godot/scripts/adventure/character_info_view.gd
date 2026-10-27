class_name CharacterInfoView
extends InfoView
## Describes a hero class before it is chosen.

const ATTRIBUTES := ["strength", "accuracy", "awareness", "constitution"]

var blurb_y := 0
var character: Dictionary


func _init(p_gurk: Gurk, p_character: Dictionary) -> void:
	super(p_gurk, "BACK")
	character = p_character
	add_icon(character.icon, 3, 3)
	var y := 4
	add_label(character.name, "#FFF", 20, y)
	y += 8
	add_label("Level 1 %s" % character.job, "#A0A0A0", 20, y)
	y += 12
	blurb_y = do_attributes(y) + 4


func do_attributes(y: int) -> int:
	for attribute in ATTRIBUTES:
		if Util.truthy(character.get(attribute)):
			var value = character[attribute]
			var value_text := ("+%s" % value) if value > 0 else str(value)
			var attribute_name := Util.capitalize(attribute)
			if attribute_name == "Constitution":
				attribute_name = "Toughness"
			add_label("%s: %s" % [attribute_name, value_text], "#FFF", 3, y)
			y += 8
	return y


func do_draw() -> void:
	super()
	screen.wrap_text(View.s(character.get("description")), "#A0A0A0", 3, blurb_y, 122)
