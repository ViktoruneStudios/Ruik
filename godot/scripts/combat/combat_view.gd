class_name CombatView
extends TileView
## Turn-based combat on a 7x7 grid.
##
## Everything that happens is queued as actions; an "animation" action stops
## the queue until its animation calls next_action() again. Actions may queue
## more actions, which run before the rest of the queue (hence the stack).

const FORMATION := [Vector2i(3, 5), Vector2i(2, 6), Vector2i(4, 6)]

const SELECT_OFF := 0
const SELECT_VIEW := 1
const SELECT_ACTIVE := 2
const SELECT_TARGET := 3
const SELECT_TARGETED := 4

const SPELL_NONE := 0
const SPELL_HEAL := 1
const SPELL_DAMAGE := 2
const SPELL_SUMMON := 3
const SPELL_TELEPORT := 4

const SPELL_TARGET_MELEE := 0
const SPELL_TARGET_RANGE := 1

const LEFT_EDGE := 0
const RIGHT_EDGE := 6
const TOP_EDGE := 0
const BOTTOM_EDGE := 6

const BASE_SPEED := 175
const BASE_PAUSE := 625
const FAST_SPEED := 120
const FAST_PAUSE := 450

var combatants: Array = []
## "x_y" -> Combatant
var combat_map: Dictionary = {}

var select_mode := SELECT_OFF
var select_x := 0
var select_y := 0
var target_x := 0
var target_y := 0

var current := 0

var casting_spell = null
var teleport_target: Combatant = null
var using_item = null
var spell_type := SPELL_NONE
var spell_target := SPELL_TARGET_MELEE
var area_spell := false
var area_attack := false
var drain_amount := 0
var selecting_item_for_use := false

var queue: Array = []
var stack: Array = []

var combat_speed := BASE_SPEED
var pause_time := BASE_PAUSE

var is_firing := false
var is_paralyzed := false

var image_processor: ImageProcessor
var strategy: BasicStrategy


func _init(p_gurk: Gurk, p_map_name: String, p_image_processor: ImageProcessor, creatures: Array, ambushed: bool) -> void:
	super(p_gurk, p_map_name)
	image_processor = p_image_processor
	if gurk.get_fast_setting():
		combat_speed = FAST_SPEED
		pause_time = FAST_PAUSE
	strategy = BasicStrategy.new(self)
	offset_x = -GurkScreen.HALF_UNIT
	combatants = []
	combat_map = {}
	queue = []
	stack = []
	if ambushed:
		add_creatures(creatures)
		add_players()
	else:
		add_players()
		add_creatures(creatures)
	set_button(5, "OK")
	current = 0
	start_turn()
	next_action()


func process_icon(combatant: Combatant) -> void:
	combatant.draw_icon(image_processor, draw)


func command(text: String) -> void:
	if text == View.LEFT:
		move(-1, 0)
	elif text == View.UP:
		move(0, -1)
	elif text == View.RIGHT:
		move(1, 0)
	elif text == View.DOWN:
		move(0, 1)
	else:
		match text:
			"OK":
				gurk.pop_view(null)
			"ATT/FIRE", "ATTACK", "FIRE":
				is_firing = text == "FIRE"
				start_player_attack()
			"TARGET", "HEAL", "RESTORE", "CURE", "SUMMON", "TELEPORT":
				if spell_type == SPELL_NONE:
					do_player_attack()
				else:
					do_spell_cast()
			"CAST", "CAST/USE":
				start_player_cast()
			"USE":
				start_player_use()
			"WIELD":
				start_player_wield()
			"PASS":
				pass_turn()
			"CANCEL":
				start_player_turn()
			"VIEW":
				clear_actions()
				set_button(5, "INFO")
				set_button(7, "DONE")
				enable_movement()
				select(select_x, select_y, SELECT_VIEW)
			"DONE":
				start_player_turn()
			"INFO":
				var combatant: Combatant
				if select_mode == SELECT_TARGET:
					combatant = get_combatant(target_x, target_y)
				else:
					combatant = get_combatant(select_x, select_y)
				if combatant != null:
					gurk.push_view(CombatantView.new(gurk, combatant))


func log_action(_text) -> void:
	pass # print(_text)


# --- The action queue --------------------------------------------------------

func next_action() -> bool:
	var next := true
	while (queue.size() > 0 or stack.size() > 0) and next:
		if queue.is_empty() and stack.size() > 0:
			queue = stack.pop_back()
		while queue.size() > 0 and next:
			var entry: Dictionary = queue.pop_front()
			log_action("Action: %s" % entry.info)
			if entry.action is Callable:
				stack.push_back(queue)
				queue = []
				entry.action.call()
				next = not entry.animation
	if queue.is_empty() and stack.size() > 0:
		queue = stack.pop_back()
	return queue.size() > 0


func add_action(action: Callable, info = null) -> void:
	queue.append({"action": action, "animation": false, "info": info})


func add_animation(action: Callable, info = null) -> void:
	queue.append({"action": action, "animation": true, "info": info})


func add_pause(info = null) -> void:
	queue.append({"action": do_pause, "animation": true, "info": info})


func add_sound(sound: String, info = null) -> void:
	add_action(func(): gurk.play_sound(sound), info)


func do_pause() -> void:
	gurk.set_timeout(next_action, pause_time)


func get_custom_animation(sx: int, sy: int, tx: int, ty: int, animation) -> Texture2D:
	if _frames_of(animation) > 1 or Util.truthy(Data.icon_coords.get(animation, {}).get("frames")):
		return null
	var dx := tx - sx
	var dy := ty - sy
	var angle: int
	if absi(dx) > absi(dy):
		angle = ImageProcessor.RIGHT if dx > 0 else ImageProcessor.LEFT
	else:
		angle = ImageProcessor.DOWN if dy > 0 else ImageProcessor.UP
	return image_processor.rotate(animation, angle)


func queue_fly(sx: int, sy: int, tx: int, ty: int, animation, info = null) -> void:
	var custom := get_custom_animation(sx, sy, tx, ty, animation)
	add_animation(func(): fly(animation, sx + 1, tx + 1, sy, ty, combat_speed / 2.0, next_action, custom), info)


func queue_animation(ax: int, ay: int, animation, info = null) -> void:
	add_animation(func(): animate(animation, ax + 1, ay, combat_speed, next_action), info)


func queue_block_animation(ax: int, ay: int, radius: int, animation, info = null) -> void:
	add_animation(func(): animate_block(animation, ax + 1, ay, radius, combat_speed, next_action), info)


# --- Drawing -----------------------------------------------------------------

func draw_combatant(combatant: Combatant) -> void:
	if combatant.custom_image != null:
		draw_custom(combatant.custom_image, combatant.x + 1, combatant.y)
	else:
		draw_tile(combatant.get_icon(), combatant.x + 1, combatant.y)


func do_draw() -> void:
	# Draw map
	for y in height:
		for x in width:
			draw_tile(get_terrain_icon(x, y), x, y)
	draw_selection()
	for combatant in combatants:
		if not combatant.invisible:
			draw_combatant(combatant)
	draw_banner()
	draw_top_banner()


func is_selected(x: int, y: int) -> bool:
	match select_mode:
		SELECT_ACTIVE, SELECT_VIEW:
			return x == select_x and y == select_y
		SELECT_TARGET:
			return (x == select_x and y == select_y) or (x == target_x and y == target_y)
	return false


func _draw_frame(icon: Dictionary, x: int, y: int) -> void:
	draw_tile(icon.center, x + 1, y)
	draw_tile(icon.left, x, y)
	draw_tile(icon.top, x + 1, y - 1)
	draw_tile(icon.right, x + 2, y)
	draw_tile(icon.bottom, x + 1, y + 1)


func draw_selection() -> void:
	if select_mode == SELECT_OFF or select_mode == SELECT_TARGETED:
		return
	var select_icon: Dictionary = Data.icons.selectActive
	match select_mode:
		SELECT_TARGET:
			var target_icon: Dictionary = Data.icons.selectTarget
			if area_spell or area_attack:
				var min_y := maxi(TOP_EDGE, target_y - 1)
				var max_y := mini(BOTTOM_EDGE, target_y + 1)
				var min_x := maxi(LEFT_EDGE, target_x - 1) + 1
				var max_x := mini(RIGHT_EDGE, target_x + 1) + 1
				# Top and bottom edges
				for x in range(min_x, max_x + 1):
					draw_tile(target_icon.top, x, min_y - 1)
					draw_tile(target_icon.bottom, x, max_y + 1)
				# Left and right edges, plus center
				for y in range(min_y, max_y + 1):
					draw_tile(target_icon.left, min_x - 1, y)
					draw_tile(target_icon.right, max_x + 1, y)
					for x in range(min_x, max_x + 1):
						draw_tile(target_icon.center, x, y)
				# Make center darker
				draw_tile(target_icon.center, target_x + 1, target_y)
			else:
				_draw_frame(target_icon, target_x, target_y)
		SELECT_VIEW:
			select_icon = Data.icons.selectView
	if select_mode != SELECT_TARGET or target_x != select_x or target_y != select_y:
		_draw_frame(select_icon, select_x, select_y)


func clear_actions() -> void:
	clear_all_buttons()


# --- Turns -------------------------------------------------------------------

func check_for_loss() -> bool:
	for combatant in combatants:
		if combatant.is_player:
			return false
	return true


func check_for_win() -> bool:
	for combatant in combatants:
		if not combatant.good:
			return false
	return true


func start_turn() -> void:
	# Check for end-of-combat scenarios
	if check_for_loss():
		gurk.pop_view("defeat")
	elif check_for_win():
		gurk.pop_view("victory")
	else:
		var combatant: Combatant = combatants[current]
		combatant.start_turn()
		select(combatant.x, combatant.y, SELECT_ACTIVE)
		if combatant.is_paralyzed():
			clear_actions()
			is_paralyzed = true
			add_pause("Paralyzed Pause 1")
			add_pause("Paralyzed Pause 2")
			add_action(pass_turn, "Paralyzed Pass Turn")
		elif combatant.good:
			start_player_turn()
		else:
			clear_actions()
			add_pause("AI Start Pause")
			var num_moves := 0 if combatant.is_rooted() else combatant.num_moves
			add_action(func(): strategy.do_turn(combatant, num_moves, combatant.num_attacks), "AI Do Turn")


## Player is presented with turn options.
func start_player_turn() -> void:
	casting_spell = null
	area_spell = false
	area_attack = false
	if check_for_loss():
		gurk.pop_view("defeat")
		return
	elif check_for_win():
		gurk.pop_view("victory")
		return
	var player: Combatant = combatants[current]
	select(player.x, player.y, SELECT_ACTIVE)
	spell_type = SPELL_NONE
	clear_actions()
	if player.is_rooted():
		player.moves_left = 0
	if player.moves_left > 0:
		enable_movement()
	set_button(5, "VIEW")
	set_button(7, "PASS")
	if player.is_player:
		var weapons: Array = player.entity.get_equipable_items_by_type(Item.TYPE_WEAPON)
		if weapons.size() > 1 or (weapons.size() == 1 and player.entity.get_weapon() == null):
			set_button(3, "WIELD")
	if can_attack_melee(player) or player.can_attack_range():
		if player.can_attack_range():
			if can_attack_melee(player) and player.entity.can_attack_melee():
				set_button(1, "ATT/FIRE")
			else:
				set_button(1, "FIRE")
		elif can_attack_melee(player):
			set_button(1, "ATTACK")
	var can_cast_now := can_cast(player)
	var can_use_now := can_use(player, can_attack_melee(player), can_summon(player))
	if can_cast_now and can_use_now:
		set_button(9, "CAST/USE")
	elif can_cast_now:
		set_button(9, "CAST")
	elif can_use_now:
		set_button(9, "USE")
	draw()


func _in_bounds(x: int, y: int) -> bool:
	return x >= LEFT_EDGE and x <= RIGHT_EDGE and y >= TOP_EDGE and y <= BOTTOM_EDGE


func move(dx: int, dy: int) -> void:
	if select_mode == SELECT_TARGET:
		var combatant: Combatant = combatants[current]
		var casting := spell_type != SPELL_NONE
		var x := target_x + dx
		var y := target_y + dy
		if not (is_in_melee_range_xy(combatant, x, y) or (not casting and combatant.can_attack_range()) or (casting and (spell_target == SPELL_TARGET_RANGE or spell_type == SPELL_TELEPORT))):
			return
		if not _in_bounds(x, y):
			return
		target_x = x
		target_y = y
		var target := get_combatant(x, y)
		clear_button(5)
		clear_button(1)
		if target != null:
			set_button(1, "INFO")
			if not casting:
				if are_enemies(combatant, target):
					set_button(5, "TARGET")
			elif casting_spell.get("target") == "area":
				set_button(5, "TARGET")
			else:
				match spell_type:
					SPELL_HEAL:
						if not are_enemies(combatant, target) or casting_spell.type == "teleport":
							if casting_spell.type == "heal":
								match casting_spell.get("healType"):
									"restore":
										set_button(5, "RESTORE")
									"remove":
										set_button(5, "CURE")
									_:
										set_button(5, "HEAL")
							else:
								set_button(5, "TARGET")
					SPELL_DAMAGE:
						if are_enemies(combatant, target):
							set_button(5, "TARGET")
		elif casting:
			if spell_type == SPELL_SUMMON:
				set_button(5, "SUMMON")
			elif spell_type == SPELL_TELEPORT:
				set_button(5, "TELEPORT")
			elif casting_spell.get("target") == "area":
				set_button(5, "TARGET")
		elif area_attack:
			set_button(5, "TARGET")
		update_banner()
	elif select_mode == SELECT_VIEW:
		var x := select_x + dx
		var y := select_y + dy
		if _in_bounds(x, y):
			select_x = x
			select_y = y
			if get_combatant(x, y) != null:
				set_button(5, "INFO")
			else:
				clear_button(5)
			update_banner()
	else:
		var combatant: Combatant = combatants[current]
		if combatant.moves_left > 0:
			var x := combatant.x + dx
			var y := combatant.y + dy
			if _in_bounds(x, y) and not combat_map.has(Game.get_key(x, y)):
				add_sound("move", "Move Sound")
				move_combatant(combatant.x, combatant.y, x, y)
				combatant.moves_left -= 1
				if combatant.moves_left == 0:
					combatant.attacks_left = 0
				draw()
				end_turn()


func update_banner() -> void:
	var x: int
	var y: int
	if select_mode == SELECT_TARGET or select_mode == SELECT_TARGETED:
		x = target_x
		y = target_y
	elif select_mode == SELECT_VIEW:
		x = select_x
		y = select_y
	else:
		x = combatants[current].x
		y = combatants[current].y
	var combatant := get_combatant(x, y)
	if combatant != null and select_mode != SELECT_OFF:
		var text := "%s (HP: %d" % [combatant.get_banner(), combatant.hit_points]
		if combatant.good and combatant.entity.max_spell_points > 0:
			text += ", SP: %d)" % combatant.entity.spell_points
		else:
			text += ")"
		set_banner(text)
		if select_mode == SELECT_ACTIVE and combatant.good:
			# Do move/attack banner, if they have more than the normal number of attacks
			if not combatant.is_paralyzed() and (combatant.num_moves > 1 or combatant.num_attacks > 1):
				set_top_banner(combatant.moves_left, combatant.attacks_left, combatant.half_attack)
			else:
				clear_top_banner()
			top_banner_left = select_x > 3
		else:
			clear_top_banner()
	else:
		clear_banner()
		clear_top_banner()
	draw()


func pass_turn() -> void:
	var combatant: Combatant = combatants[current]
	combatant.moves_left = 0
	combatant.attacks_left = 0
	end_turn()


func end_turn() -> void:
	var combatant: Combatant = combatants[current]
	var was_player := combatant.good
	var action: Callable
	if was_player and combatant.not_done():
		action = start_player_turn
	else:
		if combatant.is_poisoned():
			var damage: int = int(combatant.get_effect("Poisoned").value)
			if combatant.hit_points - damage < 1:
				damage = combatant.hit_points - 1
			if damage > 0:
				add_action(_poison_damage.bind(combatant, damage), "Do Poison Damage")
				add_pause("Pause After Poison Damage")
		add_action(func(): combatant.increment_effects(image_processor, draw), "Increment FX")
		action = _advance_turn
	add_action(action, "End Turn")
	# Play through the queue
	if was_player and not is_paralyzed:
		next_action()
	else:
		is_paralyzed = false


func _poison_damage(combatant: Combatant, damage: int) -> void:
	target_x = combatant.x
	target_y = combatant.y
	select_mode = SELECT_TARGETED
	update_banner()
	do_damage(combatant, damage, Data.icons.animPoison)


func _advance_turn() -> void:
	current += 1
	if current >= combatants.size():
		current = 0
	start_turn()


## Player chooses attack target.
func start_player_attack() -> void:
	var player: Combatant = combatants[current]
	var target := get_suggested_enemy_target(player)
	area_attack = player.can_attack_area()
	if target != null:
		select(target.x, target.y, SELECT_TARGET)
		clear_actions()
		enable_movement()
		set_button(1, "INFO")
		set_button(5, "TARGET")
		set_button(7, "CANCEL")
	draw()


func get_suggested_enemy_target(player: Combatant, force_range := false) -> Combatant:
	var target: Combatant = null
	if player.last_target != null and is_still_alive(player.last_target) and can_attack(player, player.last_target):
		target = player.last_target
	if target == null:
		target = get_nearest_attack_target(player, force_range)
	return target


func start_player_cast() -> void:
	area_spell = false
	drain_amount = 0
	var player: Combatant = combatants[current]
	selecting_item_for_use = true
	gurk.push_view(SpellView.new(gurk, player.entity, true, can_attack_melee(player), can_summon(player), player))


func start_player_use() -> void:
	area_spell = false
	var player: Combatant = combatants[current]
	selecting_item_for_use = true
	gurk.push_view(ItemView.new(gurk, player.entity, ItemView.ACTION_USE, true, can_attack_melee(player), can_summon(player), player))


func start_player_wield() -> void:
	var player = combatants[current].entity
	selecting_item_for_use = false
	gurk.push_view(ItemView.new(gurk, player, ItemView.ACTION_EQUIP, 0, true))


func do_player_cast() -> void:
	var player: Combatant = combatants[current]
	clear_actions()
	enable_movement()
	match casting_spell.type:
		"teleport":
			spell_type = SPELL_TELEPORT
			select(player.x, player.y, SELECT_TARGET)
			if casting_spell.get("target") == "self":
				do_spell_cast()
				return
			set_button(5, "TARGET")
		"heal", "enhance":
			spell_type = SPELL_HEAL
			select(player.x, player.y, SELECT_TARGET)
			if casting_spell.get("target") == "self":
				do_spell_cast()
				return
			elif casting_spell.type == "heal":
				set_button(5, "HEAL")
			else:
				set_button(5, "TARGET")
		"damage", "afflict", "drain":
			spell_type = SPELL_DAMAGE
			var target := get_suggested_enemy_target(player, true)
			if target != null:
				select(target.x, target.y, SELECT_TARGET)
			set_button(5, "TARGET")
		"summon":
			spell_type = SPELL_SUMMON
			var square = get_suggested_summon_square(player)
			if square != null: # Shouldn't happen, spell shouldn't appear unless can summon
				select(square.x, square.y, SELECT_TARGET)
				set_button(5, "SUMMON")
	spell_target = SPELL_TARGET_MELEE if casting_spell.get("target") == "touch" else SPELL_TARGET_RANGE
	if casting_spell.get("target") == "area":
		area_spell = true
	set_button(7, "CANCEL")


func compute_spell_timing(combatant: Combatant, spell: Dictionary) -> void:
	if Util.truthy(spell.get("fast")):
		if combatant.half_attack:
			combatant.attacks_left -= 1
			combatant.moves_left = 0
			combatant.half_attack = false
		else:
			combatant.half_attack = true
	else:
		combatant.attacks_left -= 1
		combatant.moves_left = 0


func do_spell_cast() -> void:
	clear_actions()
	var player: Combatant = combatants[current]
	if casting_spell.type == "teleport":
		if teleport_target != null:
			select_mode = SELECT_TARGETED
			add_sound("spell", "Cast Sound")
			add_action(do_spell_result, "Spell Result Action")
			compute_spell_timing(player, casting_spell)
			end_turn()
		else:
			if casting_spell.get("target") == "self":
				teleport_target = combatants[current]
			else:
				teleport_target = get_combatant(target_x, target_y)
			spell_type = SPELL_TELEPORT
			spell_target = SPELL_TARGET_RANGE
			var square = get_suggested_summon_square(teleport_target)
			if square == null:
				square = get_random_square()
			if square != null:
				select(square.x, square.y, SELECT_TARGET)
				enable_movement()
				set_button(5, "TELEPORT")
				set_button(7, "CANCEL")
	else:
		select_mode = SELECT_TARGETED
		add_sound("spell", "Cast Sound")
		queue_animation(player.x, player.y, Data.icons.animSpellCast, "Spell Cast Animation")
		var target_type = casting_spell.get("target")
		if target_type == "range" or target_type == "area":
			queue_fly(player.x, player.y, target_x, target_y, casting_spell.get("animation"), "Spell Range Animation")
		add_action(do_spell_result, "Spell Result Action")
		compute_spell_timing(player, casting_spell)
		end_turn()


func do_spell_result() -> void:
	var caster: Combatant = combatants[current]
	var is_player := caster.is_player
	var spell: Dictionary = casting_spell
	var from_item := using_item != null
	var target := get_combatant(target_x, target_y)
	if from_item and is_player:
		if Util.eq(using_item.get_combat_spell(), spell):
			caster.use_combat_spell(using_item)
		elif using_item.is_useable():
			using_item.charges -= 1
			if using_item.charges == 0:
				caster.entity.drop_item(using_item)
	elif caster.good:
		caster.entity.spell_points -= spell.spellPoints
	match spell.type:
		"heal":
			var bounds: Dictionary = using_item.get_spell_range() if from_item else caster.entity.get_spell_range(spell)
			if spell.get("target") == "area":
				do_area_healing(bounds, spell.get("healType"))
			elif target != null:
				add_sound("heal", "Heal Sound")
				queue_animation(target_x, target_y, Data.icons.animHeal, "Heal Animation")
				target.do_heal(Util.random(bounds.min, bounds.max), spell.get("healType"), image_processor, draw)
				update_banner()
		"drain":
			var bounds: Dictionary = using_item.get_spell_range() if from_item else caster.entity.get_spell_range(spell)
			var amount := 0
			if drain_amount > 0:
				amount = maxi(1, Util.js_round(float(spell.value) * drain_amount / 100.0))
			elif target != null:
				var damage := resist_damage(caster, target, bounds)
				if damage == 0:
					do_resist(target)
				else:
					do_damage(target, damage, Data.icons.animHitSpell)
					amount = maxi(1, Util.js_round(float(spell.value) * damage / 100.0))
			if amount > 0 and not caster.is_fully_healed():
				add_action(_drain_heal.bind(caster, amount), "Drain Heal")
		"damage":
			var bounds: Dictionary = using_item.get_spell_range() if from_item else caster.entity.get_spell_range(spell)
			if spell.get("target") == "area":
				do_area_damage(bounds)
			elif target != null:
				var amount := resist_damage(caster, target, bounds)
				if amount == 0:
					do_resist(target)
				else:
					do_damage(target, amount, Data.icons.animHitSpell)
		"summon":
			add_sound("summon", "Summon Sound")
			queue_animation(target_x, target_y, Data.icons.animHeal, "Summon Animation")
			var bonus: int
			if from_item:
				bonus = using_item.bonus
			elif is_player:
				bonus = int(ceil(caster.entity.get_attribute_bonus(caster.entity.get_awareness()) / 2.0))
			else:
				bonus = caster.entity.bonus
			summon_creature(spell.creature, bonus, caster.good, target_x, target_y)
		"teleport":
			if teleport_target != null:
				if not are_enemies(caster, teleport_target) or not do_saving_throw(caster, teleport_target):
					teleport_target.invisible = true
					add_sound("tele", "Start Teleport Sound")
					queue_animation(teleport_target.x, teleport_target.y, Data.icons.animHeal, "Teleport Start Animation")
					add_action(_complete_teleport, "Complete Teleportation")
				else:
					show_resist(teleport_target)
					teleport_target = null
		"enhance", "afflict":
			if spell.get("target") == "area":
				# Decided to go no bonus for effects
				do_area_effect(spell, 0)
			elif target != null:
				if not are_enemies(caster, target) or not do_saving_throw(caster, target):
					if are_enemies(caster, target):
						add_sound("afflicted", "Afflict Sound")
					else:
						add_sound("enhanced", "Enhance Sound")
					queue_animation(target_x, target_y, Data.icons.animHeal, "Effect Animation")
					target.add_effect(spell.effect, spell.value, Util.random(spell.minAmount, spell.maxAmount), caster)
					add_action(process_icon.bind(target), "Show Effect")
				else:
					show_resist(target)
	casting_spell = null
	using_item = null


func _drain_heal(caster: Combatant, amount: int) -> void:
	add_sound("heal", "Drain Sound")
	queue_animation(caster.x, caster.y, Data.icons.animHeal, "Drain Animation")
	caster.do_heal(amount, "heal", image_processor, draw)
	set_target(caster)
	update_banner()


func _complete_teleport() -> void:
	move_combatant(teleport_target.x, teleport_target.y, target_x, target_y)
	teleport_target.invisible = false
	teleport_target = null
	add_sound("port", "End Teleport Sound")
	queue_animation(target_x, target_y, Data.icons.animHeal, "Teleport Animation")


## Player's attack is executed.
func do_player_attack() -> void:
	var player: Combatant = combatants[current]
	if area_attack:
		add_sound("fire", "Area Fire Sound")
		queue_fly(player.x, player.y, target_x, target_y, player.get_range_animation(), "Area projectile fly")
		add_action(do_area_attack, "Run Area Attack")
		clear_actions()
		select_mode = SELECT_TARGETED
		player.did_attack = true
		player.attacks_left -= 1
		player.moves_left = 0
		end_turn()
	else:
		var target := get_combatant(target_x, target_y)
		if target != null and are_enemies(player, target) and can_attack(player, target):
			player.last_target = target
			clear_actions()
			select_mode = SELECT_TARGETED
			if not is_in_melee_range(player, target) or is_firing:
				add_sound("fire", "Fire Sound")
				queue_fly(player.x, player.y, target.x, target.y, player.get_range_animation(), "Range projectile fly")
				add_action(run_attack, "Run Range Attack")
			else:
				add_action(run_attack, "Run Melee Attack")
			player.did_attack = true
			player.attacks_left -= 1
			player.moves_left = 0
			end_turn()


func run_attack() -> void:
	var target := get_combatant(target_x, target_y)
	if target != null:
		process_attack(combatants[current], target)


func process_attack(attacker: Combatant, target: Combatant, range_override := false) -> void:
	var melee := is_in_melee_range(attacker, target) and not range_override
	var dice := Util.random(1, 20)
	var hit_roll := dice + attacker.get_to_hit_bonus()
	# Note: the original computed a range AC bonus (get_range_ac_bonus) here but
	# compared against the plain armor class; that behavior is kept.
	if dice == 20 or (dice != 1 and hit_roll > target.get_armor_class()):
		var bounds := attacker.get_melee_damage_bounds() if melee else attacker.get_range_damage_bounds()
		var damage := Util.random(bounds.min, bounds.max)
		drain_amount = mini(damage, target.hit_points)
		var dead := do_damage(target, damage)
		var hit_spell = attacker.get_hit_spell()
		if hit_spell != null:
			casting_spell = hit_spell
			if attacker.is_player:
				using_item = attacker.entity.get_weapon()
			if not dead or casting_spell.type == "drain":
				var fail := false
				if casting_spell.type == "teleport":
					teleport_target = target
					if not attacker.good:
						var square = get_random_square()
						if square == null:
							fail = true
						else:
							target_x = square.x
							target_y = square.y
				if not fail:
					add_action(do_spell_result, "Do Hit Spell")
	else:
		add_sound("miss", "Miss Sound")
		queue_animation(target.x, target.y, Data.icons.animMiss, "Miss Animation")


# --- Area effects ------------------------------------------------------------

func _area_targets(include: Callable) -> Array:
	var targets := []
	for y in range(target_y - 1, target_y + 2):
		if y >= 0 and y < height:
			for x in range(target_x - 1, target_x + 2):
				if x >= 0 and x < width:
					var target := get_combatant(x, y)
					if target != null and include.call(target):
						targets.append(target)
	return targets


func do_area_effect(spell: Dictionary, bonus: int) -> void:
	queue_block_animation(target_x, target_y, 1, casting_spell.get("animation"), "Area Spell Animation")
	var caster: Combatant = combatants[current]
	var value = maxf(float(spell.value) + bonus, 1.0)
	if spell.value is int:
		value = int(value)
	add_action(_area_effect_apply.bind(spell, value, caster), "Show Effect")


func _area_effect_apply(spell: Dictionary, value, caster: Combatant) -> void:
	for target in _area_targets(func(t): return spell.type == "enhance" or t != caster):
		if not are_enemies(caster, target) or not do_saving_throw(caster, target):
			add_action(_area_effect_hit.bind(spell, value, caster, target), "Show Area Target Effect")
		else:
			add_action(show_resist.bind(target), "Show Area Target Resist")


func _area_effect_hit(spell: Dictionary, value, caster: Combatant, target: Combatant) -> void:
	if are_enemies(caster, target):
		add_sound("afflicted", "Area Afflict Sound")
	else:
		add_sound("enhanced", "Area Enhance Sound")
	queue_animation(target.x, target.y, Data.icons.animHeal, "Area Effect Animation")
	target.add_effect(spell.effect, value, Util.random(spell.minAmount, spell.maxAmount), caster)
	add_action(_process_icon_and_draw.bind(target), "Do Area Effect Processing")


func _process_icon_and_draw(target: Combatant) -> void:
	process_icon(target)
	draw()


func do_area_healing(bounds: Dictionary, heal_type) -> void:
	queue_block_animation(target_x, target_y, 1, casting_spell.get("animation"), "Area Spell Animation")
	for target in _area_targets(func(_t): return true):
		var amount := Util.random(bounds.min, bounds.max)
		add_action(show_area_healing.bind(target, amount, heal_type), "Do Area Heal")


func do_area_attack() -> void:
	var combatant: Combatant = combatants[current]
	queue_block_animation(target_x, target_y, 1, combatant.get_range_animation(), "Area Attack Animation")
	for target in _area_targets(func(t): return t != combatant):
		add_action(_area_attack_hit.bind(combatant, target))


func _area_attack_hit(combatant: Combatant, target: Combatant) -> void:
	target_x = target.x
	target_y = target.y
	update_banner()
	process_attack(combatant, target, true)


func do_area_damage(bounds: Dictionary) -> void:
	queue_block_animation(target_x, target_y, 1, casting_spell.get("animation"), "Area Spell Animation")
	var caster: Combatant = combatants[current]
	for target in _area_targets(func(t): return t != caster):
		# resist_damage scales the bounds in place, as the original did.
		var amount := resist_damage(caster, target, bounds)
		if amount == 0:
			add_action(show_resist.bind(target), "Do Area Damage")
		else:
			add_action(show_area_damage.bind(target, amount), "Do Area Damage")


func show_area_healing(target: Combatant, heal: int, heal_type) -> void:
	target.do_heal(heal, heal_type, image_processor, draw)
	target_x = target.x
	target_y = target.y
	update_banner()
	add_sound("heal", "Heal Sound")
	queue_animation(target.x, target.y, Data.icons.animHeal, "Heal Animation")


func show_resist(target: Combatant) -> void:
	target_x = target.x
	target_y = target.y
	update_banner()
	add_sound("resist", "Resist Sound")
	queue_animation(target.x, target.y, Data.icons.animResist, "Resist Animation")


func show_area_damage(target: Combatant, damage: int) -> void:
	var dead := target.do_damage(damage)
	target_x = target.x
	target_y = target.y
	update_banner()
	if dead:
		add_sound("died" if target.good else "killed", "Died Sound")
		remove_combatant(target)
	else:
		add_sound("hit", "Hit Sound")
	queue_animation(target.x, target.y, Data.icons.animHitSpell, "Hit Animation")


func do_resist(target: Combatant) -> void:
	show_resist(target)


func do_damage(target: Combatant, damage: int, anim = null) -> bool:
	var dead := target.do_damage(damage)
	update_banner()
	if dead:
		add_sound("died" if target.good else "killed", "Died Sound")
		remove_combatant(target)
	else:
		add_sound("hit", "Hit Sound")
	if anim == null:
		anim = Data.icons.animHit
	queue_animation(target.x, target.y, anim, "Hit Animation")
	return dead


# --- Combatants and the grid -------------------------------------------------

func add_creatures(creatures: Array) -> void:
	for creature in creatures:
		add_combatant(Combatant.new(creature, false, false))


func add_players() -> void:
	var index := 0
	for player in gurk.game.players:
		if player.is_alive():
			var spot: Vector2i = FORMATION[index]
			add_combatant(Combatant.new(player, true, true, spot.x, spot.y))
		index += 1


func add_combatant(combatant: Combatant) -> void:
	var x := combatant.x
	var y := combatant.y
	while x == -1 or combat_map.has(Game.get_key(x, y)):
		x = Util.random(0, 6)
		y = Util.random(0, 3)
	combatant.x = x
	combatant.y = y
	combat_map[Game.get_key(x, y)] = combatant
	combatants.append(combatant)


func summon_creature(creature_name: String, bonus: int, good: bool, x: int, y: int) -> void:
	var template = Library.get_creature_by_name(creature_name)
	if template == null:
		push_warning("Summoned creature not found: %s" % creature_name)
		return
	var combatant := Combatant.new(Creature.new(template, bonus), false, good, x, y)
	combatants.insert(current, combatant)
	current += 1
	combat_map[Game.get_key(x, y)] = combatant


func clear_selection() -> void:
	select_mode = SELECT_OFF
	update_banner()
	draw()


func select(x: int, y: int, mode: int) -> void:
	if mode == SELECT_TARGET:
		target_x = x
		target_y = y
	else:
		select_x = x
		select_y = y
	select_mode = mode
	update_banner()


func get_combatant(x: int, y: int) -> Combatant:
	return combat_map.get(Game.get_key(x, y))


func move_combatant(sx: int, sy: int, tx: int, ty: int) -> void:
	var key := Game.get_key(sx, sy)
	var combatant: Combatant = combat_map.get(key)
	if combatant == null:
		return
	combat_map.erase(key)
	combatant.x = tx
	combatant.y = ty
	combat_map[Game.get_key(tx, ty)] = combatant


func get_surrounding_squares(x: int, y: int, for_enemy := false) -> Array:
	var squares := []
	var y_list := [y + 1, y, y - 1] if for_enemy else [y - 1, y, y + 1]
	for yy in y_list:
		if yy >= TOP_EDGE and yy <= BOTTOM_EDGE:
			for xx in range(x - 1, x + 2):
				if xx >= LEFT_EDGE and xx <= RIGHT_EDGE and (xx != x or yy != y):
					squares.append(Vector2i(xx, yy))
	return squares


func are_enemies(a: Combatant, b: Combatant) -> bool:
	return a.good != b.good


## True if the defender resists the caster's spell.
func do_saving_throw(caster: Combatant, defender: Combatant) -> bool:
	var mod := clampi((defender.get_resistance() - caster.get_potency()) * 5 + 5, 0, 100)
	var result := Util.random(0, 99)
	if result < 3:
		return true
	elif result > 96:
		return false
	return result < mod


## Scales the bounds (in place) by the defender's resistance and rolls damage.
func resist_damage(caster: Combatant, defender: Combatant, bounds: Dictionary) -> int:
	var mod := clampi(100 - (defender.get_resistance() - caster.get_potency() - 3) * 5, 0, 100)
	bounds.min = maxi(0, Util.js_round(bounds.min * mod / 100.0))
	bounds.max = maxi(0, Util.js_round(bounds.max * mod / 100.0))
	return Util.random(bounds.min, bounds.max)


func can_attack_melee(combatant: Combatant) -> bool:
	for square in get_surrounding_squares(combatant.x, combatant.y):
		var other := get_combatant(square.x, square.y)
		if other != null and are_enemies(combatant, other):
			return true
	return false


func can_touch_ally(combatant: Combatant) -> bool:
	for square in get_surrounding_squares(combatant.x, combatant.y):
		var other := get_combatant(square.x, square.y)
		if other != null and not are_enemies(combatant, other):
			return true
	return false


func can_target_with_spell(caster: Combatant, target: Combatant, is_friendly: bool, is_heal: bool, effect = null) -> bool:
	if is_heal and target.hit_points == target.get_max_hit_points():
		return false
	if is_friendly == are_enemies(caster, target):
		return false
	if effect != null and target.has_effect(effect):
		return false
	return true


func get_spell_targets(caster: Combatant, is_range: bool, is_friendly: bool, is_heal: bool, include_self := false) -> Array:
	var targets := []
	if is_range:
		for target in combatants:
			if can_target_with_spell(caster, target, is_friendly, is_heal):
				targets.append(target)
	else:
		for square in get_surrounding_squares(caster.x, caster.y):
			var target := get_combatant(square.x, square.y)
			if target != null and can_target_with_spell(caster, target, is_friendly, is_heal):
				targets.append(target)
	if include_self and can_target_with_spell(caster, caster, is_friendly, is_heal):
		targets.append(caster)
	return targets


func has_allies(combatant: Combatant) -> bool:
	for other in combatants:
		if other != combatant and are_enemies(combatant, other):
			return true
	return false


func get_random_square():
	for tries in 10:
		var x := Util.random(LEFT_EDGE, RIGHT_EDGE)
		var y := Util.random(TOP_EDGE, BOTTOM_EDGE)
		if get_combatant(x, y) == null:
			return Vector2i(x, y)
	return null


func get_suggested_summon_square(combatant: Combatant):
	if combatant == null:
		return null
	for square in get_surrounding_squares(combatant.x, combatant.y, not combatant.good):
		if is_clear(square.x, square.y):
			return square
	return null


func can_summon(combatant: Combatant) -> bool:
	for square in get_surrounding_squares(combatant.x, combatant.y):
		if is_clear(square.x, square.y):
			return true
	return false


func is_in_melee_range(combatant: Combatant, target: Combatant) -> bool:
	return is_in_melee_range_xy(combatant, target.x, target.y)


func is_in_melee_range_xy(combatant: Combatant, x: int, y: int) -> bool:
	return absi(combatant.x - x) <= 1 and absi(combatant.y - y) <= 1


func can_attack(combatant: Combatant, target: Combatant) -> bool:
	return combatant.can_attack_range() or is_in_melee_range(combatant, target)


func get_range_ac_bonus(attacker: Combatant, target: Combatant) -> int:
	return (absi(target.x - attacker.x) + absi(target.y - attacker.y)) / 3


## Picks the closest matching combatant, breaking ties at random.
func _nearest(combatant: Combatant, include: Callable, measure: Callable) -> Combatant:
	var nearest: Combatant = null
	var distance := 100
	var count := 0
	for target in combatants:
		if target != combatant and include.call(target):
			var d: int = measure.call(target)
			if d == distance:
				count += 1
				if Util.random(1, count) == 1:
					nearest = target
			if d < distance:
				distance = d
				nearest = target
				count = 1
	return nearest


func _manhattan(combatant: Combatant, target: Combatant) -> int:
	return absi(target.x - combatant.x) + absi(target.y - combatant.y)


func get_nearest_target(combatant: Combatant, force_range := false) -> Combatant:
	return _nearest(combatant,
		func(t): return are_enemies(combatant, t) and (can_attack(combatant, t) or force_range),
		_manhattan.bind(combatant))


func get_nearest_attack_target(combatant: Combatant, force_range := false) -> Combatant:
	return _nearest(combatant,
		func(t): return are_enemies(combatant, t) and (can_attack(combatant, t) or force_range),
		func(t): return 1 if is_in_melee_range(combatant, t) else _manhattan(combatant, t))


func get_nearest_enemy(combatant: Combatant) -> Combatant:
	return _nearest(combatant, func(t): return are_enemies(combatant, t), _manhattan.bind(combatant))


func get_random_enemy(combatant: Combatant) -> Combatant:
	var enemies := []
	for target in combatants:
		if target != combatant and are_enemies(combatant, target):
			enemies.append(target)
	return Util.random_element(enemies)


func get_best_area_target(caster: Combatant, is_attack: bool):
	var best_score := 0
	var best = null
	for yy in range(TOP_EDGE, BOTTOM_EDGE + 1):
		for xx in range(LEFT_EDGE, RIGHT_EDGE + 1):
			var score := 0
			for y in range(yy - 1, yy + 2):
				for x in range(xx - 1, xx + 2):
					if _in_bounds(x, y):
						var combatant := get_combatant(x, y)
						if combatant != null and (not is_attack or combatant != caster):
							if are_enemies(caster, combatant) == is_attack:
								score += 3
							else:
								score -= 2
						if caster == combatant and is_attack:
							# Not allowed to target self!
							score = -10000
			if score > best_score:
				best_score = score
				best = Vector2i(xx, yy)
	return best


func remove_combatant(combatant: Combatant) -> void:
	combat_map.erase(Game.get_key(combatant.x, combatant.y))
	var index := combatants.find(combatant)
	combatants.erase(combatant)
	if index < current:
		current -= 1


func is_still_alive(combatant: Combatant) -> bool:
	return combatants.has(combatant)


func set_target(target) -> void:
	select_mode = SELECT_TARGETED
	target_x = target.x
	target_y = target.y


func is_clear(x: int, y: int) -> bool:
	return _in_bounds(x, y) and get_combatant(x, y) == null


func can_cast(combatant: Combatant) -> bool:
	for spell in combatant.entity.get_spells():
		if spell.spellPoints <= combatant.entity.spell_points:
			return true
	return false


func can_use(combatant: Combatant, melee: bool, summon: bool) -> bool:
	return combatant.is_player and combatant.entity.has_usable_item(true, melee, summon, combatant)


func process_result(result) -> void:
	if Util.eq(result, "debug1"):
		# Automatically win combat
		gurk.pop_view("victory")
	elif Util.eq(result, "debug2"):
		queue_block_animation(4, 4, 1, Data.icons.animHit, "Test Block Animation")
		next_action()
	elif result is Dictionary and Util.truthy(result.get("spellPoints")):
		# It's a spell
		using_item = null
		casting_spell = result
		do_player_cast()
	elif (Util.eq(result, ItemView.NONE) or result is Item) and not selecting_item_for_use:
		# It's a wield result
		var player: Combatant = combatants[current]
		if Util.eq(result, ItemView.NONE):
			player.entity.unequip_item_by_type(Item.TYPE_WEAPON)
		else:
			player.entity.equip_item(result)
		player.attacks_left -= 1
		player.moves_left = 0
		end_turn()
	elif result is Item:
		# It's a used item
		using_item = result
		casting_spell = using_item.get_spell()
		if casting_spell == null:
			casting_spell = using_item.get_combat_spell()
		if casting_spell != null:
			do_player_cast()
