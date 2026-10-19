extends Control
## Title screen: a painted keep-and-maze backdrop with the main menu.


func _ready() -> void:
	var col := UI.page(self, 1)
	var backdrop := TitleBackdrop.new()
	add_child(backdrop)
	move_child(backdrop, 1)  # above the page colour, below the menu
	UI.spacer(col, 60)
	UI.title(col, "MAZE KEEP", 72)
	var tag := UI.label(col, "Build the labyrinth. Hold the keep.", 24, Palette.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	tag.add_theme_constant_override("outline_size", 5)
	# The menu starts just below the painted band (see TitleBackdrop).
	var h := get_viewport_rect().size.y
	UI.spacer(col, maxf(h * 0.30 + get_viewport_rect().size.x / 9.0 * 6.0 + 50.0 - 270.0, 120.0))
	var box := UI.column(col, 12)
	var play := UI.button(box, "Play", func() -> void: Game.go("worlds"), 84)
	UITheme.style_primary(play)
	UI.button(box, "Endless & Challenges", func() -> void: Game.go("modes"), 68)
	UI.button(box, "Skill Tree  ·  %d ★" % Save.total_stars(), func() -> void: Game.go("skills"), 68)
	UI.button(box, "Settings", func() -> void: Game.go("settings"), 68)
	if not IAP.is_unlocked():
		UI.spacer(col, 8)
		var unlock := UI.button(col, "Unlock the full game · %s · no ads" % IAP.price, func() -> void:
			Game.return_to = "title"
			Game.go("unlock"), 60)
		unlock.add_theme_font_size_override("font_size", 20)
	UI.spacer(col, 20)
	Audio.play_music(0)
	Audio.prewarm(1)
