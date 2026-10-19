class_name UITheme
extends RefCounted
## Builds the game's Theme in code: parchment-and-wood buttons with big touch
## targets, readable at arm's length on a phone.

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, border: Color, radius := 12, border_width := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 26

	theme.set_stylebox("normal", "Button", _box(Palette.WOOD, Palette.WOOD_LIGHT))
	theme.set_stylebox("hover", "Button", _box(Palette.WOOD.lightened(0.1), Palette.GOLD))
	theme.set_stylebox("pressed", "Button", _box(Palette.WOOD.darkened(0.3), Palette.GOLD))
	theme.set_stylebox("disabled", "Button", _box(Color(0.22, 0.2, 0.18), Color(0.35, 0.33, 0.3)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Palette.PARCHMENT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.GOLD)
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.52, 0.48))
	theme.set_color("font_outline_color", "Button", Palette.INK)
	theme.set_constant("outline_size", "Button", 4)

	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.08, 0.07, 0.92), Palette.WOOD_LIGHT, 14, 2))
	theme.set_stylebox("panel", "Panel", _box(Color(0.1, 0.08, 0.07, 0.92), Palette.WOOD_LIGHT, 14, 2))

	theme.set_color("font_color", "Label", Palette.PARCHMENT)
	theme.set_color("font_outline_color", "Label", Palette.INK)
	theme.set_constant("outline_size", "Label", 4)

	var check := _box(Palette.WOOD, Palette.WOOD_LIGHT)
	theme.set_stylebox("normal", "CheckButton", check)
	theme.set_stylebox("hover", "CheckButton", check)
	theme.set_stylebox("pressed", "CheckButton", check)
	theme.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "CheckButton", Palette.PARCHMENT)
	theme.set_color("font_outline_color", "CheckButton", Palette.INK)
	theme.set_constant("outline_size", "CheckButton", 4)
	return theme


## Big primary button (Start Wave, Play, Buy).
static func style_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(Color(0.72, 0.5, 0.15), Palette.GOLD))
	button.add_theme_stylebox_override("hover", _box(Color(0.8, 0.58, 0.2), Palette.GOLD))
	button.add_theme_stylebox_override("pressed", _box(Color(0.55, 0.38, 0.1), Palette.GOLD))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 30)


static func style_danger(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(Color(0.45, 0.15, 0.12), Color(0.8, 0.3, 0.25)))
	button.add_theme_stylebox_override("hover", _box(Color(0.55, 0.2, 0.15), Color(0.9, 0.4, 0.3)))
	button.add_theme_stylebox_override("pressed", _box(Color(0.35, 0.1, 0.08), Color(0.9, 0.4, 0.3)))
