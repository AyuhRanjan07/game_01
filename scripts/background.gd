extends Node2D
class_name AmbientBackground

# A calming animated backdrop for the room: a soft vertical color gradient
# plus a handful of slow, softly-glowing drifting blobs. Call setup() once
# when the room is built, resize() whenever the room size changes, and
# set_level() to smoothly fade to a new calming palette between rounds.

const PALETTES := [
	{"name": "Dusk Lavender",   "top": Color(0.16, 0.14, 0.24), "bottom": Color(0.28, 0.20, 0.32), "blob": Color(0.55, 0.45, 0.75, 0.10), "player": Color(0.75, 0.55, 0.95), "unlock_score": 0},
	{"name": "Ocean Teal",      "top": Color(0.07, 0.16, 0.20), "bottom": Color(0.10, 0.28, 0.30), "blob": Color(0.30, 0.65, 0.70, 0.10), "player": Color(0.30, 0.85, 0.85), "unlock_score": 0},
	{"name": "Sage Meadow",     "top": Color(0.12, 0.18, 0.14), "bottom": Color(0.20, 0.30, 0.20), "blob": Color(0.55, 0.75, 0.50, 0.10), "player": Color(0.55, 0.90, 0.40), "unlock_score": 0},
	{"name": "Warm Sand",       "top": Color(0.22, 0.16, 0.12), "bottom": Color(0.34, 0.24, 0.16), "blob": Color(0.85, 0.65, 0.40, 0.10), "player": Color(0.95, 0.70, 0.30), "unlock_score": 0},
	{"name": "Midnight Indigo", "top": Color(0.05, 0.06, 0.14), "bottom": Color(0.12, 0.10, 0.26), "blob": Color(0.45, 0.45, 0.85, 0.10), "player": Color(0.55, 0.55, 0.98), "unlock_score": 0},
	{"name": "Rose Quartz",     "top": Color(0.20, 0.12, 0.16), "bottom": Color(0.32, 0.18, 0.24), "blob": Color(0.80, 0.55, 0.65, 0.10), "player": Color(0.95, 0.50, 0.65), "unlock_score": 0},
	{"name": "Golden Hour",     "top": Color(0.24, 0.12, 0.10), "bottom": Color(0.42, 0.22, 0.12), "blob": Color(0.95, 0.60, 0.30, 0.12), "player": Color(1.00, 0.75, 0.25), "unlock_score": 500},
	{"name": "Neon Nights",     "top": Color(0.10, 0.04, 0.18), "bottom": Color(0.22, 0.06, 0.30), "blob": Color(0.90, 0.30, 0.85, 0.12), "player": Color(0.95, 0.35, 0.90), "unlock_score": 1200},
	{"name": "Arctic Frost",    "top": Color(0.10, 0.16, 0.20), "bottom": Color(0.20, 0.30, 0.36), "blob": Color(0.75, 0.90, 0.98, 0.12), "player": Color(0.80, 0.95, 1.00), "unlock_score": 2500},
	{"name": "Cosmic Dust",     "top": Color(0.04, 0.03, 0.10), "bottom": Color(0.10, 0.06, 0.22), "blob": Color(0.55, 0.45, 0.90, 0.12), "player": Color(0.70, 0.60, 1.00), "unlock_score": 4000},
]

const BLOB_COUNT := 7
const TRANSITION_DURATION := 1.6  # seconds to smoothly fade between palettes

# Distinct look for the secret room: deep violet/gold, much more energetic than
# any normal calming palette, so it's immediately obvious something changed.
const SECRET_TOP := Color(0.08, 0.02, 0.16)
const SECRET_BOTTOM := Color(0.30, 0.08, 0.42)
const SECRET_BLOB := Color(1.0, 0.82, 0.35, 0.14)
const SECRET_PLAYER := Color(1.0, 0.85, 0.35)
const SECRET_BLOB_SPEED_MULT := 3.0

var room_size := Vector2(1000, 600)
var top_color: Color
var bottom_color: Color
var blob_color: Color
var player_color: Color
var blobs: Array = []
var current_palette_index := -1
var active_tween: Tween
var secret_mode := false
var pre_secret_top: Color
var pre_secret_bottom: Color
var pre_secret_blob: Color
var pre_secret_player: Color

func setup(size: Vector2) -> void:
	room_size = size
	_apply_palette(0, true)
	_spawn_blobs()
	queue_redraw()

func resize(size: Vector2) -> void:
	room_size = size
	# keep existing blobs, just make sure they stay within the new bounds
	for b in blobs:
		b.base_pos.x = clamp(b.base_pos.x, 0.0, room_size.x)
		b.base_pos.y = clamp(b.base_pos.y, 0.0, room_size.y)
	queue_redraw()

func set_level(level_index: int, high_score: int = 0) -> void:
	var unlocked := get_unlocked_indices(high_score)
	var target_index: int = unlocked[level_index % unlocked.size()]
	if target_index == current_palette_index:
		return
	_tween_to_palette(target_index)

func get_unlocked_indices(high_score: int) -> Array:
	var result := []
	for i in PALETTES.size():
		if high_score >= PALETTES[i].unlock_score:
			result.append(i)
	return result

func get_palette_name(index: int) -> String:
	return PALETTES[index].name

func get_player_color() -> Color:
	return player_color

func enter_secret_mode() -> void:
	if active_tween:
		active_tween.kill()
	pre_secret_top = top_color
	pre_secret_bottom = bottom_color
	pre_secret_blob = blob_color
	pre_secret_player = player_color
	secret_mode = true
	top_color = SECRET_TOP
	bottom_color = SECRET_BOTTOM
	blob_color = SECRET_BLOB
	player_color = SECRET_PLAYER
	queue_redraw()

func exit_secret_mode() -> void:
	secret_mode = false
	top_color = pre_secret_top
	bottom_color = pre_secret_bottom
	blob_color = pre_secret_blob
	player_color = pre_secret_player
	queue_redraw()

func _spawn_blobs() -> void:
	blobs.clear()
	for i in BLOB_COUNT:
		blobs.append({
			"base_pos": Vector2(randf_range(0.0, room_size.x), randf_range(0.0, room_size.y)),
			"radius": randf_range(70.0, 160.0),
			"speed": randf_range(0.15, 0.35),
			"phase": randf_range(0.0, TAU),
			"pos": Vector2.ZERO,
		})

func _apply_palette(index: int, _instant: bool) -> void:
	var p: Dictionary = PALETTES[index]
	top_color = p.top
	bottom_color = p.bottom
	blob_color = p.blob
	player_color = p.player
	current_palette_index = index

func _tween_to_palette(index: int) -> void:
	if active_tween:
		active_tween.kill()

	var p: Dictionary = PALETTES[index]
	var start_top := top_color
	var start_bottom := bottom_color
	var start_blob := blob_color
	var start_player := player_color
	current_palette_index = index

	active_tween = create_tween()
	active_tween.tween_method(
		func(t: float):
			top_color = start_top.lerp(p.top, t)
			bottom_color = start_bottom.lerp(p.bottom, t)
			blob_color = start_blob.lerp(p.blob, t)
			player_color = start_player.lerp(p.player, t)
			queue_redraw(),
		0.0, 1.0, TRANSITION_DURATION
	)

func _process(delta: float) -> void:
	var speed_mult := SECRET_BLOB_SPEED_MULT if secret_mode else 1.0
	for b in blobs:
		b.phase += delta * b.speed * speed_mult
		b.pos = b.base_pos + Vector2(sin(b.phase) * 50.0, cos(b.phase * 0.6) * 35.0)
	queue_redraw()

func _draw() -> void:
	# Vertical gradient across the whole room, via a 4-corner colored quad
	var points := PackedVector2Array([
		Vector2(0, 0), Vector2(room_size.x, 0),
		Vector2(room_size.x, room_size.y), Vector2(0, room_size.y)
	])
	var colors := PackedColorArray([top_color, top_color, bottom_color, bottom_color])
	draw_polygon(points, colors)

	# Soft drifting blobs for a calm, ambient feel
	for b in blobs:
		draw_circle(b.pos, b.radius, blob_color)
