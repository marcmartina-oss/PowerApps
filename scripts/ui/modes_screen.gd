extends Control
## Endless maps with best wave, and Challenge levels unlocked by stars.


func _ready() -> void:
	var col := UI.page(self, 2)
	var header := UI.row(col, 8)
	var back := UI.button(header, "‹", func() -> void: Game.go("title"), 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(64, 60)
	UI.label(header, "Endless & Challenges", 32, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UI.spacer(col, 6)
	UI.label(col, "Endless", 28, Palette.GOLD)
	UI.label(col, "Waves scale forever. How long can your maze hold?", 20)
	for map in Game.campaign.endless_maps:
		var best := Save.endless_best(map.id)
		var b := UI.button(col, "%s\nBest: %d waves" % [map.display_name, best] if best > 0 else "%s\nNot yet attempted" % map.display_name, func() -> void: Game.play(map), 90)
		b.add_theme_font_size_override("font_size", 22)
	UI.spacer(col, 12)
	UI.label(col, "Challenges", 28, Palette.GOLD)
	UI.label(col, "Fixed rules. Unlocked with campaign stars (you have ★ %d)." % Save.total_stars(), 20)
	var challenges := Game.campaign.challenges
	for i in challenges.size():
		var level := challenges[i]
		var unlocked := Game.is_challenge_unlocked(i)
		var cost: int = Game.campaign.challenge_star_costs[i] if i < Game.campaign.challenge_star_costs.size() else 0
		var text := "%s\n%s   %s" % [level.display_name, level.description, UI.stars_text(Save.stars_for(level.id))]
		if not unlocked:
			text = "%s\n🔒 Needs ★ %d" % [level.display_name, cost]
		var b := UI.button(col, text, func() -> void: Game.play(level), 96)
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = not unlocked
	Audio.play_music(0)
