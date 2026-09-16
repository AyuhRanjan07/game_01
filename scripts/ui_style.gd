extends RefCounted
class_name UIStyle

# Small shared helper so every on-screen Label gets a consistent, readable,
# non-plain look — a crisp dark outline plus a soft drop shadow — instead of
# flat default text. Call one of these once right after creating a Label.

static func heading(label: Label, size: int = 26, color: Color = Color(1, 1, 1)) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

static func body(label: Label, size: int = 18, color: Color = Color(0.92, 0.92, 0.97)) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)

static func set_color(label: Label, color: Color) -> void:
	# Cheap live re-tint without rebuilding the whole style (e.g. timer urgency)
	label.add_theme_color_override("font_color", color)
