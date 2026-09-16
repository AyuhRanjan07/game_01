extends Node2D
class_name PlayerVisual

# Draws the player as a glowing, gently pulsing square whose color always
# matches whatever the ambient background's current theme color is —
# including mid-fade, since it just reads the live value every frame.

const PULSE_SPEED := 2.2       # how fast the glow pulses ("blinks")
const GLOW_LAYERS := 4         # soft halo rings behind the body
const GLOW_MAX_RADIUS := 34.0
const BODY_SIZE := Vector2(32, 32)
const FALLBACK_COLOR := Color(0.2, 0.6, 1.0)
const SQUISH_SPEED := 3.0      # how fast the body squashes/stretches
const SQUISH_AMOUNT := 0.16    # max scale deviation (volume-preserving)

var background_ref: Node2D  # the AmbientBackground instance; must expose `player_color`
var pulse_time := randf() * TAU  # randomized start so it doesn't look synced to anything else
var squish_time := randf() * TAU  # separate rhythm from the glow pulse, for a more organic feel

func setup(bg: Node2D) -> void:
	background_ref = bg

func _process(delta: float) -> void:
	pulse_time += delta * PULSE_SPEED
	squish_time += delta * SQUISH_SPEED
	queue_redraw()

func _current_theme_color() -> Color:
	if background_ref != null and "player_color" in background_ref:
		return background_ref.player_color
	return FALLBACK_COLOR

func _draw() -> void:
	var theme_color := _current_theme_color()
	var pulse := (sin(pulse_time) + 1.0) / 2.0  # smooth 0..1 breathing pulse

	# Soft glow halo: several translucent rings, brighter/wider at the pulse peak
	for i in range(GLOW_LAYERS, 0, -1):
		var t := float(i) / GLOW_LAYERS
		var radius: float = lerp(BODY_SIZE.x * 0.55, GLOW_MAX_RADIUS * (0.7 + 0.3 * pulse), t)
		var alpha := 0.5 * (1.0 - t) * (0.4 + 0.6 * pulse)
		draw_circle(Vector2.ZERO, radius, Color(theme_color.r, theme_color.g, theme_color.b, alpha))

	# Solid body, subtly brighter at the pulse peak, with a gentle jelly-like squish
	var body_color := theme_color.lightened(0.1 + pulse * 0.2)
	var squish := sin(squish_time) * SQUISH_AMOUNT
	var body_size_now := Vector2(BODY_SIZE.x * (1.0 + squish), BODY_SIZE.y * (1.0 - squish))
	draw_rect(Rect2(-body_size_now / 2, body_size_now), body_color)
