extends Control
## Settings: music, sound, tutorial replay, restore purchases, reset progress.

var _status: Label
var _confirm_reset := false


func _ready() -> void:
	var col := UI.page(self, 1)
	var header := UI.row(col, 8)
	var back := UI.button(header, "‹", func() -> void: Game.go("title"), 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(64, 60)
	UI.label(header, "Settings", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UI.spacer(col, 10)
	_toggle(col, "Music", Save.music_on(), func(on: bool) -> void:
		Save.set_setting("music", on)
		Audio.apply_settings())
	_toggle(col, "Sound effects", Save.sfx_on(), func(on: bool) -> void:
		Save.set_setting("sfx", on))
	UI.spacer(col, 10)
	UI.button(col, "Replay tutorial (levels 1–3)", func() -> void:
		Save.set_tutorial_done(false)
		_status.text = "Tutorial prompts will show again.", 64)
	UI.button(col, "Restore purchases", func() -> void:
		_status.text = "Restoring…"
		IAP.restore(), 64)
	UI.spacer(col, 10)
	var reset := UI.button(col, "Reset all progress", _reset, 64)
	UITheme.style_danger(reset)
	_status = UI.label(col, "", 20, Palette.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.spacer(col, 20)
	UI.label(col, "Maze Keep %s\nNo ads. No tracking. One purchase unlocks everything." % ProjectSettings.get_setting("application/config/version", "0.2"), 17, Color(0.7, 0.68, 0.62), HORIZONTAL_ALIGNMENT_CENTER)
	IAP.purchase_finished.connect(func(_ok: bool, message: String) -> void: _status.text = message)
	Audio.play_music(0)


func _toggle(parent: Node, label: String, on: bool, changed: Callable) -> void:
	var b := CheckButton.new()
	b.text = label
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(func(pressed: bool) -> void:
		Audio.play(&"click")
		changed.call(pressed))
	parent.add_child(b)


func _reset() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_status.text = "Tap again to erase all stars, unlocks and settings."
		return
	var purchased := Save.is_purchased()
	Save.reset()
	Save.set_purchased(purchased)
	_status.text = "Progress reset."
	_confirm_reset = false
