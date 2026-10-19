class_name UI
extends RefCounted
## Small builders shared by every screen so they look alike.


static func label(parent: Node, text: String, size := 26, color := Palette.PARCHMENT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func title(parent: Node, text: String, size := 54) -> Label:
	var l := label(parent, text, size, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	return l


static func button(parent: Node, text: String, action: Callable, min_height := 72.0, click_sound := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		if click_sound:
			Audio.play(&"click")
		action.call())
	parent.add_child(b)
	return b


static func spacer(parent: Node, height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)
	return c


static func row(parent: Node, separation := 10) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	parent.add_child(r)
	return r


static func column(parent: Node, separation := 10) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", separation)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c


static func stars_text(count: int, max_count := 3) -> String:
	var s := ""
	for i in max_count:
		s += "★" if i < count else "☆"
	return s


## A full-screen page: safe-area margins, a scrolling column and the theme.
## Returns the content column.
static func page(root: Control, world := 0) -> VBoxContainer:
	root.theme = UITheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Palette.sky(world) if world > 0 else Color(0.09, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := safe_area(root)
	margin.add_theme_constant_override("margin_left", int(safe.position.x) + 20)
	margin.add_theme_constant_override("margin_right", int(root.size.x - safe.end.x) + 20)
	margin.add_theme_constant_override("margin_top", int(safe.position.y) + 16)
	margin.add_theme_constant_override("margin_bottom", int(root.size.y - safe.end.y) + 16)
	root.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	return col


## The usable rectangle in viewport coordinates, inside notches and home bars.
static func safe_area(node: Node) -> Rect2:
	var view := node.get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO, view)
	if OS.has_feature("mobile"):
		var window := Vector2(DisplayServer.window_get_size())
		var screen_safe := Rect2(DisplayServer.get_display_safe_area())
		if window.x > 0.0 and screen_safe.size.x > 0.0:
			var k := view / window
			safe = Rect2(screen_safe.position * k, screen_safe.size * k)
	return safe
