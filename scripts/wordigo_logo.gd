extends Node2D
class_name WordigoLogo

# A smaller, static (non-flying-in) version of the WORDBOUND wordmark, reusing
# the same per-letter rainbow-hue treatment as the intro animation, with a
# gentle continuous idle pulse. Meant to be shown persistently on the title
# and game-over screens for actual brand recognition, not just once at boot.

const TITLE := "WORDBOUND"
const FONT_SIZE := 42
const LETTER_SPACING := 30.0
const HUE_STEP := 0.09
const PULSE_SPEED := 1.2
const PULSE_AMOUNT := 0.12

var letters: Array = []
var letter_colors: Array = []
var pulse_time := randf() * TAU
var top_y := 40.0

func setup(accent_color: Color, room_size: Vector2, y: float = 40.0) -> void:
	top_y = y
	var letter_box := Vector2(LETTER_SPACING, FONT_SIZE * 1.2)

	for i in TITLE.length():
		var letter_color := Color.from_hsv(
			fmod(accent_color.h + i * HUE_STEP, 1.0),
			accent_color.s,
			accent_color.v
		)
		letter_colors.append(letter_color)

		var l := Label.new()
		l.text = TITLE[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = letter_box
		l.pivot_offset = letter_box / 2.0
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.add_theme_color_override("font_color", letter_color)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 3)
		add_child(l)
		letters.append(l)

	reposition(room_size)

func reposition(room_size: Vector2) -> void:
	var total_width := TITLE.length() * LETTER_SPACING
	var start_x := room_size.x / 2.0 - total_width / 2.0
	for i in letters.size():
		letters[i].position = Vector2(start_x + i * LETTER_SPACING, top_y)

func _process(delta: float) -> void:
	if not visible:
		return
	pulse_time += delta * PULSE_SPEED
	var pulse := sin(pulse_time) * 0.5 + 0.5
	for i in letters.size():
		var l: Label = letters[i]
		var base_color: Color = letter_colors[i]
		l.add_theme_color_override("font_color", base_color.lightened(pulse * PULSE_AMOUNT))
