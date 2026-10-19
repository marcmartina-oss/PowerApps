class_name Hud
extends CanvasLayer
## In-game HUD: top bar (gold, lives, wave, speed, pause), next-wave preview,
## bottom build menu / tower panel / Start Wave, tutorial prompts, and the pause
## and result overlays. Emits intent signals only; the level decides what they do.

signal start_wave_pressed
signal build_pressed(kind: StringName)
signal upgrade_pressed(spec: TowerSpec)
signal sell_pressed
signal targeting_pressed
signal close_pressed
signal speed_pressed
signal pause_pressed
signal retry_pressed
signal quit_pressed
signal next_pressed
signal tutorial_dismissed
signal tutorial_skipped

const TOP_HEIGHT := 118.0
const BOTTOM_HEIGHT := 330.0

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
var _tutorial: PanelContainer
var _tutorial_text: Label
var _overlay: ColorRect
var _overlay_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_top = VBoxContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top)
	var bar := UI.row(_top, 10)
	_gold = UI.label(bar, "0", 28, Palette.GOLD)
	_lives = UI.label(bar, "0", 28, Palette.LIVES)
	_wave = UI.label(bar, "", 26, Color(0.85, 0.9, 1))
	_speed = UI.button(bar, "1x", speed_pressed.emit, 60)
	_speed.size_flags_horizontal = Control.SIZE_SHRINK_END
	_speed.custom_minimum_size = Vector2(84, 60)
	var pause := UI.button(bar, "II", pause_pressed.emit, 60)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause.custom_minimum_size = Vector2(68, 60)
	_next = UI.label(_top, "", 21, Color(0.9, 0.9, 0.9))

	_bottom = VBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_END
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override("separation", 8)
	_root.add_child(_bottom)
	_tutorial = PanelContainer.new()
	_tutorial.visible = false
	_bottom.add_child(_tutorial)
	var tut_col := UI.column(_tutorial, 8)
	_tutorial_text = UI.label(tut_col, "", 22, Palette.PARCHMENT)
	var tut_row := UI.row(tut_col, 8)
	UI.button(tut_row, "Got it", tutorial_dismissed.emit, 56)
	var skip := UI.button(tut_row, "Skip tutorial", tutorial_skipped.emit, 56)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.add_theme_font_size_override("font_size", 20)
	_toast = UI.label(_bottom, "", 22, Color(1, 0.75, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	_panel = PanelContainer.new()
	_panel.visible = false
	_bottom.add_child(_panel)
	_panel_box = UI.column(_panel, 6)
	_start = UI.button(_bottom, "Start Wave", start_wave_pressed.emit, 78)
	UITheme.style_primary(_start)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.72)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	_overlay_box = UI.column(panel, 14)


## Places the top bar and bottom area inside the safe area.
func layout(safe: Rect2) -> void:
	_top.position = safe.position + Vector2(14, 8)
	_top.size = Vector2(safe.size.x - 28, TOP_HEIGHT - 8)
	_bottom.position = Vector2(safe.position.x + 14, safe.end.y - BOTTOM_HEIGHT)
	_bottom.size = Vector2(safe.size.x - 28, BOTTOM_HEIGHT - 12)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta / maxf(Engine.time_scale, 0.001)
		if _toast_time <= 0.0:
			_toast.text = ""


func set_gold(gold: int) -> void:
	_gold.text = "◆ %d" % gold


func set_lives(lives: int) -> void:
	_lives.text = "♥ %d" % lives


func set_wave(current: int, total: int) -> void:
	_wave.text = "Wave %d/%d" % [current, total] if total > 0 else "Wave %d" % current


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


## options: [{kind: StringName, label: String, cost: int, enabled: bool, color: Color}]
func show_build_menu(options: Array[Dictionary], message: String) -> void:
	_clear_panel()
	UI.label(_panel_box, message if message else "Build here", 21, Color(1, 0.6, 0.5) if message else Palette.PARCHMENT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_panel_box.add_child(grid)
	for option in options:
		var kind: StringName = option.kind
		var button := UI.button(grid, "%s\n%d" % [option.label, option.cost], func() -> void: build_pressed.emit(kind), 76)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", option.color.lightened(0.3))
		button.disabled = not option.enabled
	var close := UI.button(grid, "✕", close_pressed.emit, 76)
	close.add_theme_font_size_override("font_size", 24)
	_panel.visible = true


## Panel for a selected tower: stats, upgrade or spec choice, targeting, sell.
func show_tower_panel(tower: Tower, sell_value: int, can_afford_upgrade: bool) -> void:
	_clear_panel()
	var header := UI.row(_panel_box, 8)
	UI.label(header, "%s  ·  Tier %d%s" % [tower.data.display_name, tower.tier, (" · " + tower.spec.display_name) if tower.spec else ""], 24, Palette.GOLD)
	var close := UI.button(header, "✕", close_pressed.emit, 48)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(56, 48)
	if tower.is_support():
		UI.label(_panel_box, tower.data.description, 19)
	else:
		UI.label(_panel_box, "Damage %d · Range %.1f · %.1f shots/s%s" % [roundi(tower.damage()), tower.attack_range(), 1.0 / tower.fire_interval(), "  (rallied)" if tower.buff_speed > 1.0 else ""], 19)
	if tower.can_upgrade():
		var cost := tower.upgrade_cost()
		if tower.tier == TowerData.MAX_TIER - 1:
			UI.label(_panel_box, "Choose a specialization:", 19)
			var choices := UI.row(_panel_box, 6)
			for spec in [tower.data.spec_a, tower.data.spec_b]:
				var b := UI.button(choices, "%s  %dg\n%s" % [spec.display_name, cost, spec.description], func() -> void: upgrade_pressed.emit(spec), 72)
				b.add_theme_font_size_override("font_size", 17)
				b.disabled = not can_afford_upgrade
		else:
			var up := UI.button(_panel_box, "Upgrade to Tier %d  ·  %dg" % [tower.tier + 1, cost], func() -> void: upgrade_pressed.emit(null), 60)
			up.disabled = not can_afford_upgrade
	var row := UI.row(_panel_box, 6)
	if not tower.is_support():
		UI.button(row, "Target: " + tower.targeting_name(), targeting_pressed.emit, 56)
	var sell := UI.button(row, "Sell +%dg" % sell_value, sell_pressed.emit, 56)
	UITheme.style_danger(sell)
	_panel.visible = true


func show_wall_panel(sell_value: int) -> void:
	_clear_panel()
	var row := UI.row(_panel_box, 6)
	UI.label(row, "Wall", 24, Palette.GOLD)
	var sell := UI.button(row, "Sell +%dg" % sell_value, sell_pressed.emit, 56)
	UITheme.style_danger(sell)
	var close := UI.button(row, "✕", close_pressed.emit, 56)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(56, 56)
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false
	_clear_panel()


func show_tutorial(text: String) -> void:
	_tutorial_text.text = text
	_tutorial.visible = true


func hide_tutorial() -> void:
	_tutorial.visible = false


func show_pause(paused: bool) -> void:
	if not paused:
		_overlay.visible = false
		return
	_fill_overlay("Paused", "")
	var resume := UI.button(_overlay_box, "Resume", pause_pressed.emit, 72)
	UITheme.style_primary(resume)
	UI.button(_overlay_box, "Restart level", retry_pressed.emit, 64)
	UI.button(_overlay_box, "Quit to map", quit_pressed.emit, 64)
	_overlay.visible = true


func show_result(won: bool, stars: int, detail: String, next_label: String) -> void:
	_fill_overlay("Victory!" if won else "The keep has fallen", UI.stars_text(stars) if won else "")
	if detail:
		UI.label(_overlay_box, detail, 21, Palette.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	if won and next_label:
		var next := UI.button(_overlay_box, next_label, next_pressed.emit, 72)
		UITheme.style_primary(next)
	var retry := UI.button(_overlay_box, "Play again", retry_pressed.emit, 64)
	if not won:
		UITheme.style_primary(retry)
	UI.button(_overlay_box, "Back to map", quit_pressed.emit, 64)
	_overlay.visible = true


func _fill_overlay(title: String, subtitle: String) -> void:
	for child in _overlay_box.get_children():
		child.queue_free()
	UI.title(_overlay_box, title, 44)
	if subtitle:
		var s := UI.label(_overlay_box, subtitle, 44, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		s.add_theme_constant_override("outline_size", 6)


func _clear_panel() -> void:
	for child in _panel_box.get_children():
		_panel_box.remove_child(child)
		child.queue_free()
