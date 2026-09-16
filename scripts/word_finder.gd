extends Node2D

const AmbientBackgroundScript := preload("res://scripts/background.gd")
const PlayerVisualScript := preload("res://scripts/player_visual.gd")
const LetterVisualScript := preload("res://scripts/letter_visual.gd")
const PortalVisualScript := preload("res://scripts/portal_visual.gd")
const UIStyleScript := preload("res://scripts/ui_style.gd")
const SparkleEffectScript := preload("res://scripts/sparkle_effect.gd")
const IntroScreenScript := preload("res://scripts/intro_screen.gd")
const WordigoLogoScript := preload("res://scripts/wordigo_logo.gd")
const SettingsMenuScript := preload("res://scripts/settings_menu.gd")

# ---------- CONFIG ----------
const WORD_POOL_SHORT := ["ROOM", "FIND", "CODE", "GAME", "PLAY", "WORD", "MOVE", "JUMP", "LUCK"]        # 4 letters
const WORD_POOL_MEDIUM := ["GODOT", "QUICK", "LEVEL", "SCORE", "TIMER", "SPEED"]                          # 5 letters
const WORD_POOL_LONG := ["PUZZLE", "LETTER", "SHADOW", "GARDEN", "CIRCLE", "SILENT"]                      # 6 letters

const DIFFICULTY_TIMES := [15.0, 20.0, 30.0]
const DIFFICULTY_NAMES := ["15s", "20s", "30s"]
const LENGTH_MODE_KEYS := ["short", "mixed", "long"]
const LENGTH_MODE_NAMES := ["Short", "Mixed", "Long"]
const TIMER_MODE_NAMES := ["Normal", "Fixed"]

# ---------- SECRET ROOM ----------
const SECRET_PORTAL_CHANCE := 0.25       # ~25% chance a portal appears each round
const SECRET_LETTER_WINDOW := 3.5        # seconds to reach each auto-appearing letter
const SECRET_SPAWN_MIN_DIST := 80.0      # letters always spawn within reach of the player
const SECRET_SPAWN_MAX_DIST := 260.0
const SECRET_ROOM_BONUS := 200           # double the normal round-completion baseline of 100
const SECRET_WORDS := ["MAGIC", "HIDDEN", "BONUS", "BOOST", "BRAVO", "LUCKY", "SHINE"]

const ACHIEVEMENTS := [
	{"id": "first_round", "name": "First Steps", "icon": "🥇"},
	{"id": "streak_5", "name": "On a Roll (5 rounds)", "icon": "🔥"},
	{"id": "streak_10", "name": "Word Master (10 rounds)", "icon": "🏆"},
	{"id": "max_speed", "name": "Speed Demon", "icon": "⚡"},
	{"id": "fixed_win", "name": "Focused Finish (Fixed mode)", "icon": "🎯"},
]

# Fixed-mode calibration: average distance between two random points in a
# rectangle ≈ 0.52 × diagonal; at a representative ~300px/s average player
# speed that's ~3.8s of travel per letter, plus ~1.5s to visually spot the
# right tile among decoys ≈ 5.3s/letter. A 4s margin on top targets landing
# a clean run with roughly 3-4s left on the clock.
const FIXED_TIME_PER_LETTER := 5.3
const FIXED_TIME_MARGIN := 4.0

var BASE_ROUND_TIME := 20.0      # round 1 starts with this many seconds; changeable via Settings
var difficulty_index := 1        # default: 20s
var length_mode_index := 1       # default: Mixed
var timer_mode_index := 0        # default: Normal
const TIME_INCREASE_PER_LEVEL := 5.0
const MAX_ROUND_TIME := 60.0     # base time per round stops growing here
const TIME_BONUS_PER_LETTER := 3.0  # added to the live countdown on each correct touch
const MUSIC_MIX_RATE := 44100.0
const SFX_MIX_RATE := 44100.0
const MUSIC_VOLUME_NORMAL := -20.0  # baseline music volume, a bit lower than before
const MUSIC_VOLUME_DUCKED := -28.0  # quieter dip when you hit a wrong letter
const MUSIC_VOLUME_PAUSED := -26.0  # quieter dip while paused
const SAVE_PATH := "user://word_finder_highscore.save"  # filename kept for backward compatibility with existing saves
# Simple pentatonic riff (C D E G A G E D), loops forever as the background music
const MELODY := [
	{"freq": 261.63, "dur": 0.25}, {"freq": 293.66, "dur": 0.25},
	{"freq": 329.63, "dur": 0.25}, {"freq": 392.00, "dur": 0.25},
	{"freq": 440.00, "dur": 0.25}, {"freq": 392.00, "dur": 0.25},
	{"freq": 329.63, "dur": 0.25}, {"freq": 293.66, "dur": 0.25},
]
var ROOM_SIZE := Vector2(1000, 600)  # placeholder — overwritten with the real screen size in _ready()
const PLAYER_SPEED := 250.0
const SPEED_BOOST_PER_LETTER := 35.0   # added each time you touch the correct letter
const MAX_PLAYER_SPEED := 550.0        # cap so it doesn't get uncontrollable
const LETTER_RADIUS := 22.0
const BASE_DECOY_COUNT := 4      # decoys grow each round, up to MAX_DECOY_COUNT
const MAX_DECOY_COUNT := 14

enum State { INTRO, PLAYING, ROUND_END, GAME_OVER, PAUSED, SECRET_ROOM }

# ---------- STATE ----------
var state := State.INTRO
var round_index := 0
var current_index := 0
var current_word := ""
var word_bag: Array = []
var time_left := 0.0
var current_speed := PLAYER_SPEED
var spawn_grace_time_left := 0.0
const SPAWN_GRACE_DURATION := 0.35  # brief immunity right after a round starts, as a safety net
var score := 0
var high_score := 0
var best_streak := 0
var unlocked_achievements: Dictionary = {}
var unlocked_announced: Array = []
var player: CharacterBody2D
var hud_label: Label
var status_label: Label
var timer_label: Label
var toast_label: Label
var achievements_label: Label
var streak_label: Label
var streak_display_value := 0
var streak_count_tween: Tween = null
var streak_punch_tween: Tween = null
var letters_root: Node2D
var room_root: Node2D
var background: Node2D
var resize_timer: Timer
var fullscreen_button: Button
var pause_overlay: ColorRect
var showing_intro_animation := true
var wordigo_logo: Node2D
var settings_button: Button
var settings_menu: Node2D = null

var secret_word := ""
var secret_letter_index := 0
var secret_letter_time_left := 0.0
var secret_current_letter_node: Area2D = null
var saved_before_secret: Dictionary = {}
var secret_bonus_streak := 0  # +1 per secret room cleared this run; counted in streak/achievements, kept separate from round_index so it never affects the round display or difficulty scaling

# -- audio synthesis state --
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var music_note_index := 0
var music_note_time_left := 0.0
var music_phase := 0.0
var music_bass_phase := 0.0
var music_muted := false
var music_target_volume := MUSIC_VOLUME_NORMAL
var mute_button: Button

var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamGeneratorPlayback
var sfx_segments: Array = []
var sfx_seg_time_left := 0.0
var sfx_phase := 0.0

func _ready() -> void:
	randomize()
	for i in AmbientBackgroundScript.PALETTES.size():
		unlocked_announced.append(false)
	for a in ACHIEVEMENTS:
		unlocked_achievements[a.id] = false
	_load_persisted_data()
	_setup_fullscreen()

	_build_room()
	_build_player()
	_build_hud()
	_build_mute_button()
	_build_pause_overlay()
	_build_wordigo_logo()
	_build_settings_button()

	letters_root = Node2D.new()
	add_child(letters_root)

	_setup_audio()
	_setup_resize_listener()

	_play_logo_intro()

# ---------- LOGO INTRO ----------
func _play_logo_intro() -> void:
	var intro := IntroScreenScript.new()
	add_child(intro)
	intro.setup(ROOM_SIZE, background.get_player_color())
	intro.finished.connect(_on_logo_intro_finished)

func _on_logo_intro_finished() -> void:
	showing_intro_animation = false
	_show_intro("WORDIGO — endless rounds, words keep shuffling. Press SPACE to start.")

# ---------- INPUT ----------
func _unhandled_input(event: InputEvent) -> void:
	if showing_intro_animation or (settings_menu != null and is_instance_valid(settings_menu)):
		return
	if event.is_action_pressed("ui_select"):  # Space bar
		match state:
			State.INTRO:
				_start_round()
			State.ROUND_END:
				_advance_round()
			State.GAME_OVER:
				_restart_game()
	elif event.is_action_pressed("ui_cancel"):  # Escape
		if state == State.PLAYING:
			_pause_game()
		elif state == State.PAUSED:
			_resume_game()

# ---------- HIGH SCORE (persists between sessions) ----------
func _load_persisted_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.has("high_score"):
		high_score = int(data["high_score"])
	if data.has("best_streak"):
		best_streak = int(data["best_streak"])
	if data.has("difficulty_index"):
		difficulty_index = clamp(int(data["difficulty_index"]), 0, DIFFICULTY_TIMES.size() - 1)
	if data.has("length_mode_index"):
		length_mode_index = clamp(int(data["length_mode_index"]), 0, LENGTH_MODE_KEYS.size() - 1)
	if data.has("timer_mode_index"):
		timer_mode_index = clamp(int(data["timer_mode_index"]), 0, TIMER_MODE_NAMES.size() - 1)
	BASE_ROUND_TIME = DIFFICULTY_TIMES[difficulty_index]
	if data.has("unlocked_announced") and typeof(data["unlocked_announced"]) == TYPE_ARRAY:
		var saved: Array = data["unlocked_announced"]
		for i in min(saved.size(), unlocked_announced.size()):
			unlocked_announced[i] = bool(saved[i])
	# NOTE: unlocked_achievements is intentionally NOT loaded here — achievements
	# are scoped to the current run and reset on restart, unlike high_score/best_streak.

func _save_persisted_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"high_score": high_score,
		"best_streak": best_streak,
		"difficulty_index": difficulty_index,
		"length_mode_index": length_mode_index,
		"timer_mode_index": timer_mode_index,
		"unlocked_announced": unlocked_announced,
	}))
	f.close()

func _maybe_update_high_score() -> void:
	if score > high_score:
		high_score = score
		_check_theme_unlocks()
		_save_persisted_data()

func _check_theme_unlocks() -> void:
	var palettes: Array = AmbientBackgroundScript.PALETTES
	for i in palettes.size():
		var threshold: int = palettes[i].unlock_score
		if threshold > 0 and high_score >= threshold and not unlocked_announced[i]:
			unlocked_announced[i] = true
			_show_toast("🎉 New theme unlocked: %s!" % palettes[i].name)

func _unlock_achievement(id: String) -> void:
	if unlocked_achievements.get(id, false):
		return  # already have it
	unlocked_achievements[id] = true
	for a in ACHIEVEMENTS:
		if a.id == id:
			_show_toast("%s Achievement unlocked: %s!" % [a.icon, a.name])
			break
	_update_achievements_label()

func _update_achievements_label() -> void:
	var icons: Array = []
	for a in ACHIEVEMENTS:
		if unlocked_achievements.get(a.id, false):
			icons.append(a.icon)
	if icons.is_empty():
		achievements_label.text = ""
	else:
		achievements_label.text = "Achievements: %s  (%d/%d)" % [" ".join(icons), icons.size(), ACHIEVEMENTS.size()]

# ---------- STREAK DISPLAY ----------
func _animate_streak_to(target: int) -> void:
	if streak_count_tween != null and streak_count_tween.is_valid():
		streak_count_tween.kill()
	if streak_punch_tween != null and streak_punch_tween.is_valid():
		streak_punch_tween.kill()

	var start := streak_display_value
	if target == start:
		return

	# Slowly count up the number itself, rather than snapping instantly
	streak_count_tween = create_tween()
	streak_count_tween.tween_method(_set_streak_display, float(start), float(target), 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# A satisfying punch-scale + gold flash, so it actually reads as an achievement
	streak_label.scale = Vector2(1, 1)
	streak_punch_tween = create_tween()
	streak_punch_tween.tween_property(streak_label, "scale", Vector2(1.4, 1.4), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	streak_punch_tween.tween_property(streak_label, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	UIStyleScript.set_color(streak_label, Color(1.0, 0.85, 0.3))
	streak_punch_tween.tween_callback(func(): UIStyleScript.set_color(streak_label, Color(0.92, 0.92, 0.97)))

func _set_streak_display(v: float) -> void:
	streak_display_value = int(round(v))
	streak_label.text = "🔥 Streak: %d" % streak_display_value

func _reset_streak_display() -> void:
	if streak_count_tween != null and streak_count_tween.is_valid():
		streak_count_tween.kill()
	if streak_punch_tween != null and streak_punch_tween.is_valid():
		streak_punch_tween.kill()
	streak_display_value = 0
	streak_label.text = "🔥 Streak: 0"
	streak_label.scale = Vector2(1, 1)
	UIStyleScript.set_color(streak_label, Color(0.92, 0.92, 0.97))

func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.4)
	tw.tween_interval(2.6)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)

# ---------- PAUSE ----------
func _build_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0, 0, 0, 0.55)
	pause_overlay.size = ROOM_SIZE
	pause_overlay.position = Vector2.ZERO
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # keep mute button clickable
	pause_overlay.visible = false

	var label := Label.new()
	label.text = "PAUSED\nPress ESC to resume"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(400, 100)
	label.position = ROOM_SIZE / 2 - Vector2(200, 50)
	pause_overlay.add_child(label)
	UIStyleScript.heading(label, 36)

	add_child(pause_overlay)

func _build_wordigo_logo() -> void:
	wordigo_logo = WordigoLogoScript.new()
	wordigo_logo.setup(background.get_player_color(), ROOM_SIZE, 110.0)
	add_child(wordigo_logo)
	wordigo_logo.visible = false  # only shown on the title/game-over screens, not mid-round

func _build_settings_button() -> void:
	settings_button = Button.new()
	settings_button.text = "⚙ Settings"
	settings_button.custom_minimum_size = Vector2(150, 44)
	settings_button.position = Vector2(ROOM_SIZE.x / 2.0 - 75, ROOM_SIZE.y - 110)
	settings_button.add_theme_font_size_override("font_size", 18)
	settings_button.tooltip_text = "Choose starting time and word length"
	settings_button.pressed.connect(_on_settings_button_pressed)
	add_child(settings_button)
	settings_button.visible = false

func _on_settings_button_pressed() -> void:
	if settings_menu != null and is_instance_valid(settings_menu):
		return
	settings_menu = SettingsMenuScript.new()
	add_child(settings_menu)
	settings_menu.setup(ROOM_SIZE, DIFFICULTY_NAMES, difficulty_index, LENGTH_MODE_NAMES, length_mode_index, TIMER_MODE_NAMES, timer_mode_index)
	settings_menu.difficulty_changed.connect(_on_difficulty_changed)
	settings_menu.length_changed.connect(_on_length_changed)
	settings_menu.timer_mode_changed.connect(_on_timer_mode_changed)
	settings_menu.closed.connect(_on_settings_closed)

func _on_difficulty_changed(index: int) -> void:
	difficulty_index = index
	BASE_ROUND_TIME = DIFFICULTY_TIMES[index]
	_save_persisted_data()

func _on_timer_mode_changed(index: int) -> void:
	timer_mode_index = index
	_save_persisted_data()

func _on_length_changed(index: int) -> void:
	length_mode_index = index
	word_bag.clear()  # force a refill from the newly selected pool next time a word is needed
	_save_persisted_data()

func _on_settings_closed() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null

func _update_logo_visibility() -> void:
	var show_title_ui := (state == State.INTRO or state == State.GAME_OVER)
	wordigo_logo.visible = show_title_ui
	settings_button.visible = show_title_ui
	achievements_label.visible = (state == State.GAME_OVER)
	streak_label.visible = not show_title_ui
	if state == State.GAME_OVER:
		_update_achievements_label()

func _pause_game() -> void:
	state = State.PAUSED
	pause_overlay.visible = true
	music_target_volume = MUSIC_VOLUME_PAUSED
	_sync_music_volume()

func _resume_game() -> void:
	state = State.PLAYING
	pause_overlay.visible = false
	music_target_volume = MUSIC_VOLUME_NORMAL
	_sync_music_volume()

# ---------- AUDIO (fully synthesized, no files) ----------
func _setup_audio() -> void:
	# Music: a generator stream we continuously fill with a square/triangle melody
	var music_gen := AudioStreamGenerator.new()
	music_gen.mix_rate = MUSIC_MIX_RATE
	music_gen.buffer_length = 0.5
	music_player = AudioStreamPlayer.new()
	music_player.stream = music_gen
	music_target_volume = MUSIC_VOLUME_NORMAL
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback()
	music_note_time_left = MELODY[0].dur
	_sync_music_volume()

	# SFX: a second generator we only fill when an effect is triggered
	var sfx_gen := AudioStreamGenerator.new()
	sfx_gen.mix_rate = SFX_MIX_RATE
	sfx_gen.buffer_length = 0.3
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = sfx_gen
	sfx_player.volume_db = -6.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback()

func _process(_delta: float) -> void:
	_fill_music_buffer()
	_fill_sfx_buffer()

func _fill_music_buffer() -> void:
	if music_playback == null:
		return
	var frames := music_playback.get_frames_available()
	for i in frames:
		if music_note_time_left <= 0.0:
			music_note_index = (music_note_index + 1) % MELODY.size()
			music_note_time_left = MELODY[music_note_index].dur
		var freq: float = MELODY[music_note_index].freq

		# Lead: square wave
		var lead := signf(sin(music_phase)) * 0.12
		music_phase += freq * TAU / MUSIC_MIX_RATE
		if music_phase > TAU:
			music_phase -= TAU

		# Soft bass one octave down: triangle wave
		var bass_freq := freq / 2.0
		var bass := (2.0 / PI) * asin(sin(music_bass_phase)) * 0.07
		music_bass_phase += bass_freq * TAU / MUSIC_MIX_RATE
		if music_bass_phase > TAU:
			music_bass_phase -= TAU

		var sample := lead + bass
		music_playback.push_frame(Vector2(sample, sample))
		music_note_time_left -= 1.0 / MUSIC_MIX_RATE

func _fill_sfx_buffer() -> void:
	if sfx_playback == null:
		return
	var frames := sfx_playback.get_frames_available()
	for i in frames:
		var out := 0.0
		if sfx_segments.size() > 0:
			var seg: Dictionary = sfx_segments[0]
			var progress: float = 1.0 - (sfx_seg_time_left / seg.dur)
			var freq: float = lerp(float(seg.freq_a), float(seg.freq_b), clamp(progress, 0.0, 1.0))
			out = signf(sin(sfx_phase)) * float(seg.vol)
			sfx_phase += freq * TAU / SFX_MIX_RATE
			if sfx_phase > TAU:
				sfx_phase -= TAU
			sfx_seg_time_left -= 1.0 / SFX_MIX_RATE
			if sfx_seg_time_left <= 0.0:
				sfx_segments.pop_front()
				if sfx_segments.size() > 0:
					sfx_seg_time_left = sfx_segments[0].dur
					sfx_phase = 0.0
		sfx_playback.push_frame(Vector2(out, out))

func _play_sfx(segments: Array) -> void:
	sfx_segments = segments.duplicate(true)
	sfx_seg_time_left = sfx_segments[0].dur
	sfx_phase = 0.0

func _sfx_pickup() -> void:
	_play_sfx([{"freq_a": 700.0, "freq_b": 1000.0, "dur": 0.08, "vol": 0.22}])

func _sfx_round_complete() -> void:
	_play_sfx([
		{"freq_a": 523.0, "freq_b": 523.0, "dur": 0.09, "vol": 0.2},
		{"freq_a": 659.0, "freq_b": 659.0, "dur": 0.09, "vol": 0.2},
		{"freq_a": 784.0, "freq_b": 784.0, "dur": 0.16, "vol": 0.22},
	])

func _sfx_timeout() -> void:
	_play_sfx([{"freq_a": 220.0, "freq_b": 140.0, "dur": 0.25, "vol": 0.2}])

func _sfx_game_over() -> void:
	_play_sfx([
		{"freq_a": 350.0, "freq_b": 220.0, "dur": 0.18, "vol": 0.28},
		{"freq_a": 220.0, "freq_b": 110.0, "dur": 0.28, "vol": 0.28},
		{"freq_a": 110.0, "freq_b": 55.0, "dur": 0.4, "vol": 0.28},
	])

func _sync_music_volume() -> void:
	music_player.volume_db = -80.0 if music_muted else music_target_volume

func _build_mute_button() -> void:
	mute_button = Button.new()
	mute_button.text = "🔊"
	mute_button.custom_minimum_size = Vector2(48, 48)
	mute_button.position = Vector2(ROOM_SIZE.x - 420, 8)
	mute_button.add_theme_font_size_override("font_size", 22)
	mute_button.tooltip_text = "Mute/unmute music"
	mute_button.pressed.connect(_on_mute_pressed)
	add_child(mute_button)

func _on_mute_pressed() -> void:
	music_muted = not music_muted
	mute_button.text = "🔇" if music_muted else "🔊"
	_sync_music_volume()

# ---------- WINDOW ----------
func _setup_fullscreen() -> void:
	var root := get_tree().root

	if OS.has_feature("web"):
		# Browsers block programmatic fullscreen without a real click/tap,
		# so size the room to the current embed canvas and offer a button instead.
		ROOM_SIZE = root.get_visible_rect().size
		_build_fullscreen_button()
	else:
		var window := get_window()
		window.mode = Window.MODE_FULLSCREEN
		var screen_id := window.current_screen
		var screen_size := DisplayServer.screen_get_size(screen_id)
		ROOM_SIZE = Vector2(screen_size)  # room now fills the entire screen, no gray borders

	# Lock in ROOM_SIZE as the "design resolution" and let Godot auto-scale the
	# rendered scene to fit if the actual window/canvas size ever changes later
	# — this is an instant safety net; _setup_resize_listener() below then does
	# a proper rebuild shortly after so there's never a lingering stretch/bar.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(ROOM_SIZE)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _setup_resize_listener() -> void:
	resize_timer = Timer.new()
	resize_timer.wait_time = 0.15
	resize_timer.one_shot = true
	resize_timer.timeout.connect(_apply_resize)
	add_child(resize_timer)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	resize_timer.start()  # debounce: rebuild once the size settles, not on every pixel

func _apply_resize() -> void:
	var new_size: Vector2 = get_tree().root.get_visible_rect().size
	if new_size.x < 200 or new_size.y < 200:
		return  # ignore degenerate sizes (e.g. mid-minimize)
	if new_size.is_equal_approx(ROOM_SIZE):
		return

	ROOM_SIZE = new_size

	var root := get_tree().root
	root.content_scale_size = Vector2i(ROOM_SIZE)  # keep design res synced to actual size = no stretching needed

	background.resize(ROOM_SIZE)

	# Rebuild the room's visuals/collision to exactly match the new size
	for child in room_root.get_children():
		child.queue_free()
	_populate_room()

	# Reposition HUD/UI elements that depend on ROOM_SIZE
	get_node("ScoreLabel").position = Vector2(ROOM_SIZE.x - 360, 10)
	mute_button.position = Vector2(ROOM_SIZE.x - 420, 8)
	if fullscreen_button != null and is_instance_valid(fullscreen_button):
		fullscreen_button.position = Vector2(20, ROOM_SIZE.y - 66)
	pause_overlay.size = ROOM_SIZE
	pause_overlay.get_child(0).position = ROOM_SIZE / 2 - Vector2(200, 50)
	wordigo_logo.reposition(ROOM_SIZE)
	settings_button.position = Vector2(ROOM_SIZE.x / 2.0 - 75, ROOM_SIZE.y - 110)
	toast_label.position = Vector2(ROOM_SIZE.x / 2.0 - 250, 150)
	achievements_label.position = Vector2(ROOM_SIZE.x / 2.0 - 250, 210)
	streak_label.position = Vector2(ROOM_SIZE.x - 360, 42)
	if settings_menu != null and is_instance_valid(settings_menu):
		_on_settings_closed()  # its layout is built for the old size; simplest to just close it

	# Keep the player inside the new bounds
	player.position.x = clamp(player.position.x, 40.0, ROOM_SIZE.x - 40.0)
	player.position.y = clamp(player.position.y, 40.0, ROOM_SIZE.y - 40.0)

	# If letters are currently on screen, respawn just the remaining ones
	# (fresh positions + fresh decoys) so nothing ends up outside the new room
	if state == State.PLAYING or state == State.PAUSED:
		_clear_letters()
		_spawn_remaining_letters()
		spawn_grace_time_left = SPAWN_GRACE_DURATION
	elif state == State.SECRET_ROOM:
		# Re-spawn the current secret letter fresh within the new bounds,
		# with a full new time window rather than leaving it stranded.
		_spawn_next_secret_letter()

func _build_fullscreen_button() -> void:
	fullscreen_button = Button.new()
	fullscreen_button.text = "⛶ Fullscreen"
	fullscreen_button.custom_minimum_size = Vector2(150, 46)
	fullscreen_button.position = Vector2(20, ROOM_SIZE.y - 66)
	fullscreen_button.add_theme_font_size_override("font_size", 18)
	fullscreen_button.tooltip_text = "Click to enter fullscreen"
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	add_child(fullscreen_button)

func _on_fullscreen_button_pressed() -> void:
	# This runs inside a real click event, so browsers allow it.
	get_window().mode = Window.MODE_FULLSCREEN
	fullscreen_button.queue_free()

func _round_base_time(idx: int) -> float:
	return min(BASE_ROUND_TIME + idx * TIME_INCREASE_PER_LEVEL, MAX_ROUND_TIME)

func _fixed_time_for_word(word: String) -> float:
	return word.length() * FIXED_TIME_PER_LETTER + FIXED_TIME_MARGIN

func _time_for_round(word: String, idx: int) -> float:
	if TIMER_MODE_NAMES[timer_mode_index] == "Fixed":
		return _fixed_time_for_word(word)  # flat per-word calculation: no per-level growth
	return _round_base_time(idx)

# ---------- WORD SHUFFLING ----------
func _active_word_pool() -> Array:
	match LENGTH_MODE_KEYS[length_mode_index]:
		"short": return WORD_POOL_SHORT
		"long": return WORD_POOL_LONG
		_: return WORD_POOL_SHORT + WORD_POOL_MEDIUM + WORD_POOL_LONG  # mixed

func _next_word() -> String:
	if word_bag.is_empty():
		word_bag = _active_word_pool()
		word_bag.shuffle()
		# avoid immediately repeating the word that just ended
		if word_bag.size() > 1 and word_bag[0] == current_word:
			var tmp = word_bag[0]
			word_bag[0] = word_bag[1]
			word_bag[1] = tmp
	return word_bag.pop_front()

# ---------- ROOM ----------
func _build_room() -> void:
	background = AmbientBackgroundScript.new()
	background.setup(ROOM_SIZE)
	add_child(background)

	room_root = Node2D.new()
	add_child(room_root)
	_populate_room()

func _populate_room() -> void:
	var t := 20.0
	var wall_color := Color(0.35, 0.25, 0.2)
	var walls := [
		Rect2(Vector2(0, 0), Vector2(ROOM_SIZE.x, t)),
		Rect2(Vector2(0, ROOM_SIZE.y - t), Vector2(ROOM_SIZE.x, t)),
		Rect2(Vector2(0, 0), Vector2(t, ROOM_SIZE.y)),
		Rect2(Vector2(ROOM_SIZE.x - t, 0), Vector2(t, ROOM_SIZE.y)),
	]
	for w in walls:
		var rect := ColorRect.new()
		rect.color = wall_color
		rect.position = w.position
		rect.size = w.size
		room_root.add_child(rect)

		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = w.size
		shape.shape = rs
		shape.position = w.position + w.size / 2
		body.add_child(shape)
		room_root.add_child(body)

# ---------- PLAYER ----------
func _build_player() -> void:
	player = CharacterBody2D.new()
	player.position = ROOM_SIZE / 2

	var visual := PlayerVisualScript.new()
	visual.setup(background)
	player.add_child(visual)

	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(32, 32)
	shape.shape = rs
	player.add_child(shape)

	add_child(player)

func _physics_process(delta: float) -> void:
	if state == State.PLAYING or state == State.SECRET_ROOM:
		var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		player.velocity = dir * current_speed
		player.move_and_slide()
	else:
		player.velocity = Vector2.ZERO

	if state == State.PLAYING:
		if spawn_grace_time_left > 0.0:
			spawn_grace_time_left = max(0.0, spawn_grace_time_left - delta)

		time_left -= delta
		timer_label.text = "Time: %d s" % max(0, ceil(time_left))
		UIStyleScript.set_color(timer_label, Color(1.0, 0.35, 0.35) if time_left <= 5.0 else Color(1.0, 0.85, 0.4))
		if time_left <= 0:
			_fail_game("timeout")
	elif state == State.SECRET_ROOM:
		secret_letter_time_left -= delta
		timer_label.text = "Time: %d s" % max(0, ceil(secret_letter_time_left))
		UIStyleScript.set_color(timer_label, Color(1.0, 0.35, 0.35) if secret_letter_time_left <= 1.5 else Color(1.0, 0.85, 0.4))
		if secret_letter_time_left <= 0:
			_fail_secret_room()

# ---------- HUD ----------
func _build_hud() -> void:
	hud_label = Label.new()
	hud_label.position = Vector2(30, 10)
	add_child(hud_label)
	UIStyleScript.heading(hud_label, 26)

	timer_label = Label.new()
	timer_label.position = Vector2(30, 45)
	add_child(timer_label)
	UIStyleScript.body(timer_label, 18, Color(1.0, 0.85, 0.4))  # warm amber; shifts to red when time's low

	status_label = Label.new()
	status_label.position = Vector2(30, 75)
	add_child(status_label)
	UIStyleScript.body(status_label, 18)

	var score_corner := Label.new()
	score_corner.name = "ScoreLabel"
	score_corner.size = Vector2(340, 30)
	score_corner.position = Vector2(ROOM_SIZE.x - 360, 10)
	score_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_corner.clip_text = false
	add_child(score_corner)
	UIStyleScript.heading(score_corner, 20)

	toast_label = Label.new()
	toast_label.size = Vector2(500, 40)
	toast_label.position = Vector2(ROOM_SIZE.x / 2.0 - 250, 150)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	add_child(toast_label)
	UIStyleScript.heading(toast_label, 22)

	achievements_label = Label.new()
	achievements_label.size = Vector2(500, 34)
	achievements_label.position = Vector2(ROOM_SIZE.x / 2.0 - 250, 210)
	achievements_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements_label.visible = false
	add_child(achievements_label)
	UIStyleScript.body(achievements_label, 20)

	streak_label = Label.new()
	streak_label.size = Vector2(340, 28)
	streak_label.position = Vector2(ROOM_SIZE.x - 360, 42)
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	streak_label.pivot_offset = Vector2(170, 14)  # center point, so the punch animation scales from the middle
	streak_label.text = "🔥 Streak: 0"
	add_child(streak_label)
	UIStyleScript.body(streak_label, 18)

func _update_hud() -> void:
	var word: String = current_word
	var display := ""
	for i in word.length():
		if i < current_index:
			display += word[i] + " "
		elif i == current_index:
			display += "[%s] " % word[i]
		else:
			display += "_ "
	hud_label.text = "Round %d — Find: %s" % [round_index + 1, display]
	_update_score_label()

func _update_score_label() -> void:
	get_node("ScoreLabel").text = "Score: %d   Best: %d" % [score, high_score]

# ---------- ROUND FLOW ----------
func _show_intro(msg: String) -> void:
	state = State.INTRO
	status_label.text = msg
	hud_label.text = ""
	timer_label.text = ""
	_update_logo_visibility()

func _start_round() -> void:
	current_word = _next_word()
	current_index = 0
	time_left = _time_for_round(current_word, round_index)
	current_speed = PLAYER_SPEED
	state = State.PLAYING
	player.position = ROOM_SIZE / 2
	spawn_grace_time_left = SPAWN_GRACE_DURATION
	status_label.text = "Go! Touch the letters in order."
	background.set_level(round_index, high_score)
	_clear_letters()
	_spawn_letters()
	_update_hud()
	_update_logo_visibility()

func _clear_letters() -> void:
	for child in letters_root.get_children():
		child.queue_free()

const PLAYER_SPAWN_CLEAR_RADIUS := 140.0  # no letter can spawn this close to the player's start position

func _spawn_letters() -> void:
	var used := _spawn_letters_for(current_word, player.position)
	_maybe_spawn_secret_portal(used)

func _spawn_remaining_letters() -> void:
	var remaining := current_word.substr(current_index)
	if remaining.is_empty():
		return
	_spawn_letters_for(remaining, player.position)

func _spawn_letters_for(target_letters: String, spawn_point: Vector2) -> Array:
	var used: Array[Vector2] = []

	for i in target_letters.length():
		var pos := _random_free_position(used, spawn_point)
		used.append(pos)
		_create_letter_tile(target_letters[i], pos, true)

	var full_alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var decoy_pool := ""
	for i in full_alphabet.length():
		var c := full_alphabet[i]
		if not current_word.contains(c):  # exclude every letter of the whole word, not just the remainder
			decoy_pool += c
	if decoy_pool.is_empty():
		return used

	var decoy_count: int = min(BASE_DECOY_COUNT + round_index * 2, MAX_DECOY_COUNT)
	for i in decoy_count:
		var pos := _random_free_position(used, spawn_point)
		used.append(pos)
		var letter := decoy_pool[randi() % decoy_pool.length()]
		_create_letter_tile(letter, pos, false)

	return used

func _random_free_position(used: Array[Vector2], avoid_point: Vector2 = Vector2(-1, -1)) -> Vector2:
	var margin := 60.0
	var pos := Vector2.ZERO
	var tries := 0
	while tries < 100:
		pos = Vector2(
			randf_range(margin, ROOM_SIZE.x - margin),
			randf_range(margin + 90, ROOM_SIZE.y - margin)
		)
		var ok := true
		for u in used:
			if pos.distance_to(u) < 70:
				ok = false
				break
		if ok and avoid_point.x >= 0.0 and pos.distance_to(avoid_point) < PLAYER_SPAWN_CLEAR_RADIUS:
			ok = false
		if ok:
			break
		tries += 1

	# Hard guarantee: even if the random search above timed out without finding
	# a fully valid spot, never actually return a position inside the clear zone.
	if avoid_point.x >= 0.0 and pos.distance_to(avoid_point) < PLAYER_SPAWN_CLEAR_RADIUS:
		var dir := pos - avoid_point
		if dir.length() < 0.01:
			dir = Vector2(1, 0)
		dir = dir.normalized()
		pos = avoid_point + dir * (PLAYER_SPAWN_CLEAR_RADIUS + 10.0)
		pos.x = clamp(pos.x, margin, ROOM_SIZE.x - margin)
		pos.y = clamp(pos.y, margin + 90, ROOM_SIZE.y - margin)

	return pos

func _create_letter_tile(letter: String, pos: Vector2, is_target: bool) -> void:
	var area := Area2D.new()
	area.position = pos

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = LETTER_RADIUS
	shape.shape = circle
	area.add_child(shape)

	var visual := LetterVisualScript.new()
	visual.setup(letter)
	area.add_child(visual)

	area.body_entered.connect(_on_letter_touched.bind(area, letter, is_target))
	letters_root.add_child(area)

# ---------- SECRET ROOM ----------
func _maybe_spawn_secret_portal(used: Array) -> void:
	if state != State.PLAYING:
		return
	if randf() > SECRET_PORTAL_CHANCE:
		return

	var pos := _random_free_position(used, player.position)
	var portal := Area2D.new()
	portal.position = pos

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(40, 40)
	shape.shape = rect_shape
	portal.add_child(shape)

	var visual := PortalVisualScript.new()
	portal.add_child(visual)

	portal.body_entered.connect(_on_portal_touched.bind(portal))
	letters_root.add_child(portal)

func _on_portal_touched(body: Node, portal: Area2D) -> void:
	if state != State.PLAYING or body != player:
		return
	portal.queue_free()
	_enter_secret_room()

func _enter_secret_room() -> void:
	saved_before_secret = {
		"round_index": round_index,
		"current_word": current_word,
		"current_index": current_index,
		"time_left": time_left,
		"current_speed": current_speed,
		"player_position": player.position,
	}

	_clear_letters()
	state = State.SECRET_ROOM
	background.enter_secret_mode()
	music_target_volume = MUSIC_VOLUME_NORMAL
	_sync_music_volume()

	hud_label.text = "✨ SECRET ROOM"
	status_label.text = "Touch each letter before it fades!"

	secret_word = SECRET_WORDS[randi() % SECRET_WORDS.size()]
	secret_letter_index = 0
	_spawn_next_secret_letter()

func _spawn_next_secret_letter() -> void:
	if secret_current_letter_node != null and is_instance_valid(secret_current_letter_node):
		secret_current_letter_node.queue_free()
		secret_current_letter_node = null

	if secret_letter_index >= secret_word.length():
		_complete_secret_room()
		return

	var angle := randf() * TAU
	var dist := randf_range(SECRET_SPAWN_MIN_DIST, SECRET_SPAWN_MAX_DIST)
	var pos: Vector2 = player.position + Vector2(cos(angle), sin(angle)) * dist
	pos.x = clamp(pos.x, 40.0, ROOM_SIZE.x - 40.0)
	pos.y = clamp(pos.y, 130.0, ROOM_SIZE.y - 40.0)  # stay clear of the top HUD area

	var letter := secret_word[secret_letter_index]
	var area := Area2D.new()
	area.position = pos

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = LETTER_RADIUS
	shape.shape = circle
	area.add_child(shape)

	var visual := LetterVisualScript.new()
	visual.setup(letter)
	area.add_child(visual)

	area.body_entered.connect(_on_secret_letter_touched.bind(area))
	letters_root.add_child(area)

	secret_current_letter_node = area
	secret_letter_time_left = SECRET_LETTER_WINDOW
	_update_secret_hud()

func _on_secret_letter_touched(body: Node, area: Area2D) -> void:
	if state != State.SECRET_ROOM or body != player or area != secret_current_letter_node:
		return
	_sfx_pickup()
	_spawn_sparkle(area.global_position)
	secret_current_letter_node = null
	area.queue_free()
	secret_letter_index += 1
	_spawn_next_secret_letter()

func _update_secret_hud() -> void:
	var display := ""
	for i in secret_word.length():
		if i < secret_letter_index:
			display += secret_word[i] + " "
		elif i == secret_letter_index:
			display += "[%s] " % secret_word[i]
		else:
			display += "_ "
	hud_label.text = "✨ SECRET ROOM — %s" % display
	timer_label.text = "Time: %d s" % max(0, ceil(secret_letter_time_left))

func _fail_secret_room() -> void:
	# Timed out reaching a letter — no penalty, no reward, just a return trip.
	if secret_current_letter_node != null and is_instance_valid(secret_current_letter_node):
		secret_current_letter_node.queue_free()
		secret_current_letter_node = null
	_exit_secret_room(false)

func _complete_secret_room() -> void:
	_exit_secret_room(true)

func _exit_secret_room(success: bool) -> void:
	background.exit_secret_mode()

	round_index = saved_before_secret.round_index
	current_word = saved_before_secret.current_word
	current_index = saved_before_secret.current_index
	time_left = saved_before_secret.time_left
	current_speed = saved_before_secret.current_speed
	player.position = saved_before_secret.player_position
	spawn_grace_time_left = SPAWN_GRACE_DURATION
	state = State.PLAYING

	if success:
		secret_bonus_streak += 1  # counted in streak/achievements, but never touches round_index/difficulty
		score += SECRET_ROOM_BONUS
		_maybe_update_high_score()
		_update_score_label()
		_animate_streak_to(round_index + secret_bonus_streak)
		status_label.text = "✨ Secret room cleared! +%d points, streak +1!" % SECRET_ROOM_BONUS
	else:
		status_label.text = "The secret door faded... back to the search!"

	_clear_letters()
	_spawn_remaining_letters()
	_update_hud()
	_update_logo_visibility()

func _on_letter_touched(body: Node, area: Area2D, letter: String, is_target: bool) -> void:
	if state != State.PLAYING or body != player or spawn_grace_time_left > 0.0:
		return

	var word: String = current_word
	if is_target and letter == word[current_index]:
		current_index += 1
		current_speed = min(current_speed + SPEED_BOOST_PER_LETTER, MAX_PLAYER_SPEED)
		if current_speed >= MAX_PLAYER_SPEED:
			_unlock_achievement("max_speed")
		if TIMER_MODE_NAMES[timer_mode_index] != "Fixed":
			time_left = min(time_left + TIME_BONUS_PER_LETTER, MAX_ROUND_TIME)
		_sfx_pickup()
		_spawn_sparkle(area.global_position)
		area.queue_free()
		_update_hud()
		if current_index >= word.length():
			_complete_round()
	else:
		_fail_game()

func _spawn_sparkle(pos: Vector2) -> void:
	var sparkle := SparkleEffectScript.new()
	add_child(sparkle)
	sparkle.setup(pos, background.get_player_color())

func _complete_round() -> void:
	var bonus := int(time_left) * 5 + 100
	score += bonus
	_maybe_update_high_score()
	_update_score_label()
	state = State.ROUND_END
	_clear_letters()
	_sfx_round_complete()
	status_label.text = "Nice! +%d points. Press SPACE for the next round." % bonus
	timer_label.text = ""

	var rounds_cleared := round_index + 1
	_animate_streak_to(rounds_cleared + secret_bonus_streak)
	if round_index == 0:
		_unlock_achievement("first_round")
	if rounds_cleared + secret_bonus_streak >= 5:
		_unlock_achievement("streak_5")
	if rounds_cleared + secret_bonus_streak >= 10:
		_unlock_achievement("streak_10")
	if TIMER_MODE_NAMES[timer_mode_index] == "Fixed":
		_unlock_achievement("fixed_win")

func _fail_game(reason: String = "wrong_letter") -> void:
	state = State.GAME_OVER
	_clear_letters()
	music_target_volume = MUSIC_VOLUME_DUCKED
	_sync_music_volume()
	hud_label.text = "Game Over"
	timer_label.text = ""

	var effective_streak := round_index + secret_bonus_streak
	var is_new_streak := effective_streak > best_streak
	if is_new_streak:
		best_streak = effective_streak
	_save_persisted_data()

	var streak_note := " New best streak!" if is_new_streak and effective_streak > 0 else ""
	if reason == "timeout":
		_sfx_timeout()
		status_label.text = "Time's up! Rounds cleared: %d (Best: %d).%s Score: %d. Press SPACE to restart." % [effective_streak, best_streak, streak_note, score]
	else:
		_sfx_game_over()
		status_label.text = "Wrong letter! Rounds cleared: %d (Best: %d).%s Score: %d. Press SPACE to restart." % [effective_streak, best_streak, streak_note, score]
	_update_logo_visibility()

func _advance_round() -> void:
	round_index += 1
	_start_round()

func _restart_game() -> void:
	round_index = 0
	score = 0
	secret_bonus_streak = 0
	word_bag.clear()
	_update_score_label()
	_reset_streak_display()
	for a in ACHIEVEMENTS:
		unlocked_achievements[a.id] = false
	_update_achievements_label()
	music_target_volume = MUSIC_VOLUME_NORMAL
	_sync_music_volume()
	_show_intro("WORDIGO — endless rounds, words keep shuffling. Press SPACE to start.")
