extends Node2D
class_name LetterVisual

# Draws a single letter tile: a rounded, bordered box with a soft drop
# shadow, plus a gentle squash-and-stretch idle animation — noticeably
# calmer than the player's, so tiles read as background elements rather
# than competing with the player for attention.
#
# Every tile looks identical regardless of whether it's a target or decoy
# letter — that's intentional, so there's never a visual hint about which
# letters are "correct."

const TILE_SIZE := Vector2(44, 44)
const CORNER_RADIUS := 10
const BASE_COLOR := Color(0.5, 0.5, 0.58)
const BORDER_COLOR := Color(0.78, 0.78, 0.88, 0.55)
const SHADOW_COLOR := Color(0, 0, 0, 0.28)
const SHADOW_OFFSET := Vector2(2, 3)

const SQUISH_SPEED := 2.0
const SQUISH_AMOUNT := 0.05  # noticeably gentler than the player's 0.16

var squish_time := randf() * TAU  # randomized per tile so they don't all pulse in lockstep
var label: Label
var box_style: StyleBoxFlat
var shadow_style: StyleBoxFlat

func setup(letter: String) -> void:
	_build_styles()

	label = Label.new()
	label.text = letter
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = TILE_SIZE
	label.position = -TILE_SIZE / 2
	add_child(label)

func _build_styles() -> void:
	shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = SHADOW_COLOR
	shadow_style.set_corner_radius_all(CORNER_RADIUS)

	box_style = StyleBoxFlat.new()
	box_style.bg_color = BASE_COLOR
	box_style.border_color = BORDER_COLOR
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(CORNER_RADIUS)

func _process(delta: float) -> void:
	squish_time += delta * SQUISH_SPEED
	var squish := sin(squish_time) * SQUISH_AMOUNT
	scale = Vector2(1.0 + squish, 1.0 - squish)
	queue_redraw()

func _draw() -> void:
	draw_style_box(shadow_style, Rect2(-TILE_SIZE / 2 + SHADOW_OFFSET, TILE_SIZE))
	draw_style_box(box_style, Rect2(-TILE_SIZE / 2, TILE_SIZE))
