extends Node2D
class_name PortalVisual

# A rare, hidden portal tile — visually distinct from every letter tile so
# it's unmistakable when it appears. A soft glowing violet square with a
# gentle outer glow that pulses continuously.

const SIZE := Vector2(40, 40)
const BASE_COLOR := Color(0.68, 0.42, 0.95)
const GLOW_COLOR := Color(0.75, 0.55, 1.0, 0.30)
const PULSE_SPEED := 2.2

var pulse_time := randf() * TAU
var box_style: StyleBoxFlat

func _ready() -> void:
	box_style = StyleBoxFlat.new()
	box_style.bg_color = BASE_COLOR
	box_style.border_color = Color(0.9, 0.8, 1.0, 0.7)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(9)

func _process(delta: float) -> void:
	pulse_time += delta * PULSE_SPEED
	queue_redraw()

func _draw() -> void:
	var pulse := sin(pulse_time) * 0.5 + 0.5
	var glow_radius := 26.0 + pulse * 12.0
	draw_circle(Vector2.ZERO, glow_radius, GLOW_COLOR)
	box_style.bg_color = BASE_COLOR.lightened(pulse * 0.2)
	draw_style_box(box_style, Rect2(-SIZE / 2, SIZE))
