extends Node2D
class_name IntroScreen

# A short (~5.5s), skippable logo intro: the title flies in letter by letter
# with a bouncy overshoot, glows softly in the current theme's accent color,
# holds for a beat, then fades out into the normal game intro screen.

signal finished

const TITLE := "WORDBOUND"
const SUBTITLE := "find the word"
const DURATION := 5.5
const FONT_SIZE := 68
const LETTER_SPACING := 46.0  # fixed-width spacing; tuned for this font size/title
const LETTER_STAGGER := 0.08
const REVEAL_DURATION := 0.5
const HUE_STEP := 0.09  # ~32° hue rotation per letter, spread across the title

var room_size: Vector2
var accent_color: Color
var elapsed := 0.0
var letters: Array = []
var letter_colors: Array = []
var subtitle_label: Label
var skip_label: Label
var finished_emitted := false

func setup(size: Vector2, color: Color) -> void:
	room_size = size
	accent_color = color

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = room_size
	add_child(dim)

	var letter_box := Vector2(LETTER_SPACING, FONT_SIZE * 1.2)
	var total_width := TITLE.length() * LETTER_SPACING
	var start_x := room_size.x / 2.0 - total_width / 2.0
	var y := room_size.y / 2.0 - letter_box.y / 2.0

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
		l.position = Vector2(start_x + i * LETTER_SPACING, y)
		l.pivot_offset = letter_box / 2.0
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.add_theme_color_override("font_color", letter_color)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
		l.add_theme_constant_override("shadow_offset_x", 3)
		l.add_theme_constant_override("shadow_offset_y", 4)
		l.modulate.a = 0.0
		l.scale = Vector2(0.3, 0.3)
		add_child(l)
		letters.append(l)

	subtitle_label = Label.new()
	subtitle_label.text = SUBTITLE
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.size = Vector2(300, 30)
	subtitle_label.position = Vector2(room_size.x / 2.0 - 150, y + letter_box.y + 6)
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	subtitle_label.modulate.a = 0.0
	add_child(subtitle_label)

	skip_label = Label.new()
	skip_label.text = "click or press any key to skip"
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.size = Vector2(300, 20)
	skip_label.position = Vector2(room_size.x / 2.0 - 150, room_size.y - 50)
	skip_label.add_theme_font_size_override("font_size", 14)
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	skip_label.modulate.a = 0.0
	add_child(skip_label)

func _process(delta: float) -> void:
	if finished_emitted:
		return
	elapsed += delta

	for i in letters.size():
		var l: Label = letters[i]
		var t: float = clamp((elapsed - i * LETTER_STAGGER) / REVEAL_DURATION, 0.0, 1.0)
		var eased := _ease_out_back(t)
		l.modulate.a = clamp(t * 2.0, 0.0, 1.0)
		l.scale = Vector2(eased, eased)

	var subtitle_t: float = clamp((elapsed - 1.0) / 0.6, 0.0, 1.0)
	subtitle_label.modulate.a = subtitle_t

	var skip_t: float = clamp((elapsed - 1.6) / 0.6, 0.0, 1.0)
	skip_label.modulate.a = skip_t * 0.6

	if elapsed > 1.4:
		var pulse := sin((elapsed - 1.4) * 2.0) * 0.5 + 0.5
		for i in letters.size():
			var l: Label = letters[i]
			var base_color: Color = letter_colors[i]
			l.add_theme_color_override("font_color", base_color.lightened(pulse * 0.25))

	if elapsed > DURATION - 0.8:
		var fade_t: float = clamp((elapsed - (DURATION - 0.8)) / 0.8, 0.0, 1.0)
		modulate.a = 1.0 - fade_t

	if elapsed >= DURATION:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if finished_emitted:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if finished_emitted:
		return
	finished_emitted = true
	finished.emit()
	queue_free()

func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
