extends Node2D
class_name SettingsMenu

# A simple settings overlay: cycle through starting-time difficulty and
# word-length range with < / > buttons, then Back to return. Emits signals;
# the caller (main script) owns actually applying/persisting the choice.

signal difficulty_changed(index: int)
signal length_changed(index: int)
signal timer_mode_changed(index: int)
signal closed

var dim: ColorRect
var difficulty_label: Label
var length_label: Label
var timer_mode_label: Label
var difficulty_names: Array = []
var length_names: Array = []
var timer_mode_names: Array = []
var difficulty_index := 0
var length_index := 0
var timer_mode_index := 0

func setup(room_size: Vector2, diff_names: Array, diff_index: int, len_names: Array, len_index: int, mode_names: Array, mode_index: int) -> void:
	difficulty_names = diff_names
	length_names = len_names
	timer_mode_names = mode_names
	difficulty_index = diff_index
	length_index = len_index
	timer_mode_index = mode_index

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = room_size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks from reaching the game underneath
	add_child(dim)

	var center := room_size / 2.0

	var title := Label.new()
	title.text = "Settings"
	title.size = Vector2(400, 50)
	title.position = center - Vector2(200, 180)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_style_heading(title, 30)

	# Difficulty row
	var diff_prev := _make_arrow_button("<", center + Vector2(-160, -90))
	diff_prev.pressed.connect(_on_difficulty_prev)
	var diff_next := _make_arrow_button(">", center + Vector2(120, -90))
	diff_next.pressed.connect(_on_difficulty_next)

	difficulty_label = Label.new()
	difficulty_label.size = Vector2(260, 40)
	difficulty_label.position = center + Vector2(-130, -95)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(difficulty_label)
	_style_body(difficulty_label, 20)

	# Word length row
	var len_prev := _make_arrow_button("<", center + Vector2(-160, -20))
	len_prev.pressed.connect(_on_length_prev)
	var len_next := _make_arrow_button(">", center + Vector2(120, -20))
	len_next.pressed.connect(_on_length_next)

	length_label = Label.new()
	length_label.size = Vector2(260, 40)
	length_label.position = center + Vector2(-130, -25)
	length_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(length_label)
	_style_body(length_label, 20)

	# Timer mode row
	var mode_prev := _make_arrow_button("<", center + Vector2(-160, 50))
	mode_prev.pressed.connect(_on_timer_mode_prev)
	var mode_next := _make_arrow_button(">", center + Vector2(120, 50))
	mode_next.pressed.connect(_on_timer_mode_next)

	timer_mode_label = Label.new()
	timer_mode_label.size = Vector2(260, 40)
	timer_mode_label.position = center + Vector2(-130, 45)
	timer_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_mode_label)
	_style_body(timer_mode_label, 20)

	var hint := Label.new()
	hint.text = "Fixed: no time growth per round, no bonus on pickup —\ntightly calculated so a clean run leaves ~3-4s to spare."
	hint.size = Vector2(420, 40)
	hint.position = center + Vector2(-210, 85)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_style_body(hint, 13)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 44)
	back_button.position = center + Vector2(-60, 140)
	back_button.pressed.connect(func(): closed.emit())
	add_child(back_button)

	_refresh_labels()

func _make_arrow_button(label_text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(44, 40)
	b.position = pos
	add_child(b)
	return b

func _on_difficulty_prev() -> void:
	difficulty_index = (difficulty_index - 1 + difficulty_names.size()) % difficulty_names.size()
	difficulty_changed.emit(difficulty_index)
	_refresh_labels()

func _on_difficulty_next() -> void:
	difficulty_index = (difficulty_index + 1) % difficulty_names.size()
	difficulty_changed.emit(difficulty_index)
	_refresh_labels()

func _on_length_prev() -> void:
	length_index = (length_index - 1 + length_names.size()) % length_names.size()
	length_changed.emit(length_index)
	_refresh_labels()

func _on_length_next() -> void:
	length_index = (length_index + 1) % length_names.size()
	length_changed.emit(length_index)
	_refresh_labels()

func _on_timer_mode_prev() -> void:
	timer_mode_index = (timer_mode_index - 1 + timer_mode_names.size()) % timer_mode_names.size()
	timer_mode_changed.emit(timer_mode_index)
	_refresh_labels()

func _on_timer_mode_next() -> void:
	timer_mode_index = (timer_mode_index + 1) % timer_mode_names.size()
	timer_mode_changed.emit(timer_mode_index)
	_refresh_labels()

func _refresh_labels() -> void:
	difficulty_label.text = "Starting Time: %s" % difficulty_names[difficulty_index]
	length_label.text = "Word Length: %s" % length_names[length_index]
	timer_mode_label.text = "Timer Mode: %s" % timer_mode_names[timer_mode_index]

func _style_heading(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 5)

func _style_body(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.97))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 3)
