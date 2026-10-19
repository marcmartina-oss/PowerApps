extends Control
## Skill tree: three tracks of permanent bonuses, each rank unlocked by total stars.


func _ready() -> void:
	var col := UI.page(self, 3)
	var header := UI.row(col, 8)
	var back := UI.button(header, "‹", func() -> void: Game.go("title"), 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(64, 60)
	UI.label(header, "Skill Tree", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var total := Save.total_stars()
	UI.label(col, "Earn stars in the campaign to unlock permanent bonuses. You have ★ %d." % total, 20)
	for skill in Save.SKILLS:
		UI.spacer(col, 6)
		var panel := PanelContainer.new()
		col.add_child(panel)
		var box := UI.column(panel, 6)
		var rank: int = Save.skill_rank(skill.id)
		UI.label(box, "%s   (rank %d / 3)" % [skill.name, rank], 26, Palette.GOLD)
		var row := UI.row(box, 6)
		for r in 3:
			var cost: int = skill.costs[r]
			var value: Variant = skill.per_rank * (r + 1)
			var desc: String = skill.desc % value
			var b := UI.button(row, "%s\n★ %d" % [desc, cost], func() -> void: pass, 84, false)
			b.add_theme_font_size_override("font_size", 17)
			if r < rank:
				UITheme.style_primary(b)
				b.add_theme_font_size_override("font_size", 17)
			else:
				b.disabled = true
	Audio.play_music(0)
