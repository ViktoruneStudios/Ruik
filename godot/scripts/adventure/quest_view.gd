class_name QuestView
extends SelectView
## Lists started quests (marked "+" once done).


func _init(p_gurk: Gurk) -> void:
	super(p_gurk, "VIEW", "EXIT")


func do_layout() -> void:
	clear()
	add_label_centered("Quests", "#A0A0A0", 0, 1, 128, 8)
	var have_quests := false
	var y := 9
	for quest in Data.quests:
		var info: Dictionary = Data.quests[quest]
		if gurk.game.has_marker(info.get("started")):
			have_quests = true
			if gurk.game.has_marker(info.get("done")):
				add_label("+", "#FFF", 1, y)
			add_option(quest, "#FFF", 6, y)
			y += 8
	if not have_quests:
		add_label("(No quests yet)", "#FFF", 6, y)


func item_selected(_index: int, label) -> void:
	var quest_info: Dictionary = Data.quests[label.text]
	var info_view := AlertView.new(gurk, quest_info.icon, label.text, quest_info.text, null)
	if gurk.game.has_marker(quest_info.get("done")):
		info_view.subtitle = "(Completed)"
	gurk.push_view(info_view)


func command(text: String) -> void:
	if text == "EXIT":
		gurk.pop_to_top_view(null)
	else:
		super(text)
