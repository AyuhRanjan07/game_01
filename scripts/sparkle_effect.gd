extends CPUParticles2D
class_name SparkleEffect

# A small, calm burst of soft glowing dots for correct-letter feedback.
# Self-contained: instantiate, call setup(position, color), and it configures
# itself, plays once, and removes itself when finished — no manual cleanup
# needed from the caller.

const AMOUNT := 10
const LIFETIME := 1.0
const EXPLOSIVENESS := 0.6  # < 1.0 so dots stagger slightly instead of popping all at once

func setup(spawn_position: Vector2, tint_color: Color) -> void:
	global_position = spawn_position
	one_shot = true
	amount = AMOUNT
	lifetime = LIFETIME
	explosiveness = EXPLOSIVENESS
	direction = Vector2(0, -1)
	spread = 110.0
	gravity = Vector2(0, -16)  # gentle upward drift, like a firefly rising rather than falling
	initial_velocity_min = 14.0
	initial_velocity_max = 42.0
	scale_amount_min = 0.4
	scale_amount_max = 0.9
	angular_velocity_min = -30.0
	angular_velocity_max = 30.0

	texture = _make_soft_dot_texture(tint_color)

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))  # fades to fully transparent by end of life
	color_ramp = ramp

	emitting = true

	await get_tree().create_timer(LIFETIME + 0.3).timeout
	queue_free()

func _make_soft_dot_texture(tint_color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(tint_color.r, tint_color.g, tint_color.b, 0.9))
	g.set_color(1, Color(tint_color.r, tint_color.g, tint_color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 20
	tex.height = 20
	return tex
