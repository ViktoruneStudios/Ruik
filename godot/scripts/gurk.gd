class_name Gurk
extends Control
## Entry point: builds the screen and button grid, owns the view stack, and
## handles input, sound, music and timers.

const SCREEN_POSITION := Vector2(4, 4)
const GRID_POSITION := Vector2(136, 11)
const SOUND_VOLUME_DB := -12.0 # The web version played effects at 25% volume.

var stack: Array = []
var view: View = null
var screen: GurkScreen
var button_grid: ButtonGrid
var game: Game = null
var image_processor: ImageProcessor
var music = null

var _music_player: AudioStreamPlayer
var _current_track = null
var _sound_players: Dictionary = {}


func _ready() -> void:
	randomize()
	screen = GurkScreen.new()
	screen.position = SCREEN_POSITION
	add_child(screen)
	button_grid = ButtonGrid.new(self)
	button_grid.position = GRID_POSITION
	add_child(button_grid)
	image_processor = ImageProcessor.new(screen.icons)
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	stack = []
	set_view(SplashView.new(self))
	play_music(Data.splash_music)


func _exit_tree() -> void:
	_music_player.stop()
	_music_player.stream = null


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var key_num := 0
	match key.keycode:
		KEY_LEFT, KEY_A, KEY_KP_4:
			key_num = 4
		KEY_UP, KEY_W, KEY_KP_8:
			key_num = 2
		KEY_RIGHT, KEY_D, KEY_KP_6:
			key_num = 6
		KEY_DOWN, KEY_X, KEY_KP_2:
			key_num = 8
		KEY_ENTER, KEY_KP_ENTER, KEY_S, KEY_KP_0, KEY_KP_5:
			key_num = 5
		KEY_Q, KEY_KP_7:
			key_num = 1
		KEY_E, KEY_KP_9:
			key_num = 3
		KEY_Z, KEY_KP_1:
			key_num = 7
		KEY_C, KEY_KP_3:
			key_num = 9
		KEY_G:
			if OS.is_debug_build() and not key.echo:
				view.process_result("debug1") # Debug hook 1
		KEY_H:
			if OS.is_debug_build() and not key.echo:
				view.process_result("debug2") # Debug hook 2
	if key_num > 0:
		button_grid.force_click(key_num)
		get_viewport().set_input_as_handled()


# --- Timers (stand-ins for setInterval / setTimeout) --------------------------

func set_interval(fn: Callable, ms: float) -> Timer:
	var timer := Timer.new()
	timer.wait_time = maxf(ms, 1.0) / 1000.0
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(fn)
	timer.start()
	return timer


func clear_interval(timer) -> void:
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()


func set_timeout(fn: Callable, ms: float) -> void:
	get_tree().create_timer(maxf(ms, 1.0) / 1000.0).timeout.connect(fn, CONNECT_ONE_SHOT)


# --- Settings ----------------------------------------------------------------

func get_sound_setting() -> bool:
	return Device.get_setting("sound", true)


func set_sound_setting(value: bool) -> void:
	Device.set_setting("sound", value)


func get_music_setting() -> bool:
	return Device.get_setting("music", true)


func set_music_setting(value: bool) -> void:
	Device.set_setting("music", value)
	if value:
		resume_music()
	else:
		stop_music()


func get_combat_music_setting() -> bool:
	return Device.get_setting("combatMusic", true)


func set_combat_music_setting(value: bool) -> void:
	Device.set_setting("combatMusic", value)


func get_fast_setting() -> bool:
	return Device.get_setting("fast", false)


func set_fast_setting(value: bool) -> void:
	Device.set_setting("fast", value)


# --- Games -------------------------------------------------------------------

func start_saved_game() -> void:
	game = Game.new()
	if game.load_game(Device.load_game()):
		set_view(MapView.new(self))


func start_new_game(new_game: Game) -> void:
	game = new_game
	var club := game.create_item(Library.get_item_template_by_name("Crude Club"))
	var sling := game.create_item(Library.get_item_template_by_name("Sling"))
	var short_staff := game.create_item(Library.get_item_template_by_name("Short Staff"))
	game.players[0].add_item(club)
	game.players[0].equip_item(club)
	game.players[1].add_item(sling)
	game.players[1].equip_item(sling)
	game.players[2].add_item(short_staff)
	game.players[2].equip_item(short_staff)
	set_view(MapView.new(self))


# --- Sound and music ---------------------------------------------------------

func play_sound(sound: String) -> void:
	if not get_sound_setting():
		return
	if not _sound_players.has(sound):
		var path := "res://assets/sounds/%s.wav" % sound
		if not ResourceLoader.exists(path):
			_sound_players[sound] = null
		else:
			var player := AudioStreamPlayer.new()
			player.stream = load(path)
			player.volume_db = SOUND_VOLUME_DB
			add_child(player)
			_sound_players[sound] = player
	var sound_player: AudioStreamPlayer = _sound_players[sound]
	if sound_player != null:
		sound_player.play()


func play_music(track) -> void:
	music = track
	if get_music_setting():
		_play_track(track)


func play_combat_music() -> void:
	if get_combat_music_setting():
		_play_track(Data.combat_music)


func stop_music() -> void:
	_music_player.stream_paused = true


func resume_music() -> void:
	if music != null:
		play_music(music)


func _play_track(track) -> void:
	if track == null or track == "":
		return
	if Util.eq(track, _current_track):
		_music_player.stream_paused = false
		if not _music_player.playing:
			_music_player.play()
		return
	_current_track = track
	var path := "res://assets/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		push_warning("Music track not found: %s" % path)
		return
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	_music_player.stream = stream
	_music_player.stream_paused = false
	_music_player.play()


# --- View stack --------------------------------------------------------------

func get_screen() -> GurkScreen:
	return screen


func set_view(new_view: View) -> void:
	stack = []
	view = new_view
	show_view()


func show_settings() -> void:
	push_view(SettingsView.new(self))


func show_view() -> void:
	view.do_layout()
	view.set_buttons(button_grid)
	view.draw()


func push_view(new_view: View) -> void:
	stack.push_front(view)
	view = new_view
	show_view()


func pop_view(result) -> void:
	if stack.is_empty():
		return
	var parent = stack.pop_front()
	if parent != null:
		view = parent
		if result != null:
			view.process_result(result)
		show_view()


func pop_to_top_view(result) -> void:
	if stack.size() > 0:
		view = stack.pop_back()
		stack.clear()
		if result != null:
			view.process_result(result)
		show_view()


func button_pressed(text: String) -> void:
	view.command(text)


func show_alert(icon, title, text, result) -> void:
	push_view(AlertView.new(self, icon, title, text, result))


func show_confirm(icon, title, text, yes_result, no_result) -> void:
	push_view(ConfirmView.new(self, icon, title, text, yes_result, no_result))


func is_current_view(other: View) -> bool:
	return view == other
