class_name Hud
extends CanvasLayer
## In-game HUD: top bar (gold, lives, wave, speed, pause), next-wave preview,
## bottom build menu / tower panel / Start Wave, and the pause and result overlays.
## Emits intent signals only; the level decides what they do.

signal start_wave_pressed
signal build_pressed(kind: StringName)
signal sell_pressed
signal targeting_pressed
signal close_pressed
signal speed_pressed
signal pause_pressed
signal retry_pressed

const TOP_HEIGHT := 112.0
const BOTTOM_HEIGHT := 236.0

var _root: Control
var _top: VBoxContainer
var _bottom: VBoxContainer
var _gold: Label
var _lives: Label
var _wave: Label
var _next: Label
var _speed: Button
var _toast: Label
var _toast_time := 0.0
var _panel: PanelContainer
var _panel_box: VBoxContainer
var _start: Button
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_detail: Label
var _overlay_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font_size = 28
	add_child(_root)

	_top = VBoxContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_top.add_child(bar)
	_gold = _label(bar, "Gold 0", Color(1, 0.85, 0.3))
	_lives = _label(bar, "Lives 0", Color(1, 0.5, 0.5))
	_wave = _label(bar, "Wave 0/0", Color(0.85, 0.9, 1))
	_speed = _button(bar, "1x", speed_pressed.emit, Vector2(84, 64))
	_button(bar, "II", pause_pressed.emit, Vector2(72, 64))
	_next = _label(_top, "", Color(0.9, 0.9, 0.9))
	_next.add_theme_font_size_override("font_size", 22)

	_bottom = VBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	_toast = _label(_bottom, "", Color(1, 0.75, 0.4))
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel = PanelContainer.new()
	_panel.visible = false
	_bottom.add_child(_panel)
	_panel_box = VBoxContainer.new()
	_panel.add_child(_panel_box)
	_start = _button(_bottom, "Start Wave", start_wave_pressed.emit, Vector2(0, 80))

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	_overlay.add_child(center)
	_overlay_title = _label(center, "", Color.WHITE)
	_overlay_title.add_theme_font_size_override("font_size", 56)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_detail = _label(center, "", Color(1, 0.85, 0.3))
	_overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_button = _button(center, "", func() -> void: pass, Vector2(320, 90))


## Places the top bar and bottom area inside the safe area.
func layout(safe: Rect2) -> void:
	_top.position = safe.position + Vector2(16, 8)
	_top.size = Vector2(safe.size.x - 32, TOP_HEIGHT - 8)
	_bottom.position = Vector2(safe.position.x + 16, safe.end.y - BOTTOM_HEIGHT)
	_bottom.size = Vector2(safe.size.x - 32, BOTTOM_HEIGHT - 12)
	_overlay.get_child(0).position = safe.get_center() - Vector2(160, 160)
	_overlay.get_child(0).size = Vector2(320, 320)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta / maxf(Engine.time_scale, 0.001)
		if _toast_time <= 0.0:
			_toast.text = ""


func set_gold(gold: int) -> void:
	_gold.text = "Gold %d" % gold


func set_lives(lives: int) -> void:
	_lives.text = "Lives %d" % lives


func set_wave(current: int, total: int) -> void:
	_wave.text = "Wave %d/%d" % [current, total]


func set_next_wave(description: String) -> void:
	_next.text = ("Next: " + description) if description else ""


func set_speed(multiplier: int) -> void:
	_speed.text = "%dx" % multiplier


func set_start_wave(visible_now: bool, text := "Start Wave") -> void:
	_start.visible = visible_now
	_start.text = text


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5


## options: [{kind: StringName, label: String, cost: int, enabled: bool}]
func show_build_menu(options: Array[Dictionary], message: String) -> void:
	_clear_panel()
	var info := _label(_panel_box, message if message else "Build here:", Color(1, 0.6, 0.5) if message else Color.WHITE)
	info.add_theme_font_size_override("font_size", 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel_box.add_child(row)
	for option in options:
		var kind: StringName = option.kind
		var button := _button(row, "%s\n%dg" % [option.label, option.cost], func() -> void: build_pressed.emit(kind), Vector2(0, 96))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = not option.enabled
	_button(row, "X", close_pressed.emit, Vector2(72, 96))
	_panel.visible = true


func show_structure_panel(title: String, sell_label: String, targeting_label: String) -> void:
	_clear_panel()
	_label(_panel_box, title, Color.WHITE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel_box.add_child(row)
	if targeting_label:
		var target := _button(row, "Target: " + targeting_label, targeting_pressed.emit, Vector2(0, 80))
		target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sell := _button(row, sell_label, sell_pressed.emit, Vector2(0, 80))
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(row, "X", close_pressed.emit, Vector2(72, 80))
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false
	_clear_panel()


func show_pause(paused: bool) -> void:
	_show_overlay(paused, "Paused", "", "Resume", pause_pressed.emit)


func show_result(won: bool, stars: int) -> void:
	var detail := "%d / 3 stars" % stars if won else "The keep has fallen"
	_show_overlay(true, "Victory!" if won else "Defeat", detail, "Play Again", retry_pressed.emit)


func _show_overlay(show: bool, title: String, detail: String, button_text: String, action: Callable) -> void:
	_overlay.visible = show
	_overlay_title.text = title
	_overlay_detail.text = detail
	_overlay_button.text = button_text
	for connection in _overlay_button.pressed.get_connections():
		_overlay_button.pressed.disconnect(connection.callable)
	_overlay_button.pressed.connect(action)


func _clear_panel() -> void:
	for child in _panel_box.get_children():
		child.queue_free()


func _label(parent: Node, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button
