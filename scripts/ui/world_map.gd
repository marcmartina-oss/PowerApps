extends Control
## World map and level select: three world tabs, ten levels each with stars.

var _world := 1
var _levels_box: VBoxContainer
var _tabs: Array[Button] = []
var _bg: ColorRect


func _ready() -> void:
	# Open on the furthest world the player has reached.
	for level in Game.campaign.levels:
		if Game.is_level_unlocked(level):
			_world = level.world
	var col := UI.page(self, _world)
	_bg = get_child(0)
	var header := UI.row(col, 8)
	var back := UI.button(header, "‹", func() -> void: Game.go("title"), 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(64, 60)
	UI.label(header, "Campaign", 34, Palette.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UI.label(header, "★ %d / %d" % [Save.total_stars(), Game.campaign.levels.size() * 3], 24, Palette.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var tabs := UI.row(col, 6)
	for w in range(1, 4):
		var tab := UI.button(tabs, "%d" % w, func() -> void: _select_world(w), 56)
		tab.add_theme_font_size_override("font_size", 22)
		_tabs.append(tab)
	_levels_box = UI.column(col, 10)
	_select_world(_world)
	Audio.play_music(0)


func _select_world(world: int) -> void:
	_world = world
	_bg.color = Palette.sky(world)
	for i in _tabs.size():
		_tabs[i].text = ("▸ %d. %s" if i + 1 == world else "%d") % ([i + 1, CampaignData.WORLD_NAMES[i]] if i + 1 == world else [i + 1])
		_tabs[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL if i + 1 == world else Control.SIZE_SHRINK_CENTER
		_tabs[i].custom_minimum_size = Vector2(0 if i + 1 == world else 64, 56)
	for child in _levels_box.get_children():
		child.queue_free()
	var world_levels := Game.campaign.world_levels(world)
	var stars_here := 0
	for level in world_levels:
		stars_here += Save.stars_for(level.id)
	UI.label(_levels_box, "%s   ★ %d / %d" % [CampaignData.WORLD_NAMES[world - 1], stars_here, world_levels.size() * 3], 20, Palette.PARCHMENT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_levels_box.add_child(grid)
	for level in world_levels:
		var unlocked := Game.is_level_unlocked(level)
		var paid := not Game.is_level_free(level) and not IAP.is_unlocked()
		var stars := Save.stars_for(level.id)
		var text := "%d. %s\n%s" % [level.number, level.display_name, UI.stars_text(stars)]
		if not unlocked:
			text = "%d. ???\n🔒" % level.number
		elif paid:
			text = "%d. %s\n🔒 Full game" % [level.number, level.display_name]
		var b := UI.button(grid, text, func() -> void: _open(level), 96)
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = not unlocked
		if unlocked and stars == 0 and not paid:
			UITheme.style_primary(b)
			b.add_theme_font_size_override("font_size", 20)


func _open(level: LevelData) -> void:
	if Game.can_play(level):
		Game.play(level)
	else:
		Game.return_to = "worlds"
		Game.go("unlock")
