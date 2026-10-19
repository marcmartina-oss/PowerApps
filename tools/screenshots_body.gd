extends RefCounted
## See screenshots.gd.

var tree: SceneTree
var root: Window
var out_dir := ""


func run(scene_tree: SceneTree, dir: String) -> void:
	tree = scene_tree
	root = tree.root
	out_dir = dir
	await _run()


func _shot(name: String) -> void:
	await tree.process_frame
	await tree.process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _screen(scene: String, name: String) -> void:
	var node: Node = load(scene).instantiate()
	root.add_child(node)
	await _shot(name)
	node.queue_free()
	await tree.process_frame


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _run() -> void:
	# Some progress so the menus have something to show.
	Save.reset()
	for n in [1, 2, 3, 4, 5, 6, 7]:
		Save.record_result(Game.campaign.level_by_number(n).id, 3 if n < 5 else 2)
	Save.set_purchased(true)
	Save.record_endless(&"endless_1", 17)

	await _screen("res://scenes/ui/title.tscn", "01_title")
	await _screen("res://scenes/ui/world_map.tscn", "02_world_map")
	await _screen("res://scenes/ui/modes.tscn", "03_modes")
	await _screen("res://scenes/ui/skills.tscn", "04_skill_tree")
	await _screen("res://scenes/ui/settings.tscn", "05_settings")
	Save.set_purchased(false)
	await _screen("res://scenes/ui/unlock.tscn", "06_unlock")
	Save.set_purchased(true)

	# Level 1 with the tutorial prompt.
	Save.set_tutorial_done(false)
	var level := await _level(1)
	await _shot("07_level1_tutorial")
	level._skip_tutorial()
	# Build a maze and show the ghost preview.
	level.economy.earn(400)
	for x in [1, 2, 3, 5, 6, 7, 8]:
		level.try_build(Vector2i(x, 3), Level.WALL, false)
	for x in [0, 1, 2, 3, 5, 6, 7]:
		level.try_build(Vector2i(x, 6), Level.WALL, false)
	level.try_build(Vector2i(4, 3), &"archer", false)
	level.try_build(Vector2i(4, 6), &"stone_thrower", false)
	level.try_build(Vector2i(7, 4), &"archer", false)
	level._on_cell_tapped(Vector2i(0, 9))
	await _shot("08_level1_build_preview")
	level._deselect()
	level.start_wave()
	await _frames(300)
	level._on_cell_tapped(Vector2i(4, 3))
	await _shot("09_level1_wave_tower_panel")
	level._deselect()
	level.try_upgrade(Vector2i(4, 3))
	level.economy.earn(300)
	level._on_cell_tapped(Vector2i(4, 3))
	await _shot("10_level1_specialization_choice")
	level._deselect()
	level._toggle_pause()
	await _shot("11_pause")
	level._toggle_pause()
	level.queue_free()
	await tree.process_frame

	# Marsh level mid-wave with all towers.
	level = await _level(16)
	level.economy.earn(2000)
	var cells := [Vector2i(1, 2), Vector2i(7, 2), Vector2i(2, 5), Vector2i(6, 5), Vector2i(1, 8), Vector2i(7, 8), Vector2i(4, 10), Vector2i(3, 11)]
	var kinds: Array[StringName] = [&"archer", &"frost_mage", &"flame_brazier", &"arcane_spire", &"stone_thrower", &"archer", &"frost_mage", &"arcane_spire"]
	for i in cells.size():
		for off in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if level.try_build(cells[i] + off, kinds[i], false):
				var t := level.tower_at(cells[i] + off)
				if i % 2 == 0:
					level.try_upgrade(t.cell)
					level.try_upgrade(t.cell, t.data.spec_a if i % 4 == 0 else t.data.spec_b)
				break
	for x in [0, 1, 2, 3, 5, 6, 7, 8]:
		level.try_build(Vector2i(x, 4), Level.WALL, false)
	for x in [1, 2, 3, 4, 5, 6, 7, 8]:
		level.try_build(Vector2i(x, 7), Level.WALL, false)
	level.waves.current = 3
	level.start_wave()
	await _frames(420)
	await _shot("12_marsh_wave")
	level.queue_free()
	await tree.process_frame

	# Peaks level with banner and shifting gate, then the victory screen.
	level = await _level(24)
	level.economy.earn(2000)
	for cell in [Vector2i(3, 2), Vector2i(5, 2), Vector2i(4, 2)]:
		level.try_build(cell, &"war_banner" if cell.x == 4 else &"arcane_spire", false)
	var b := level.tower_at(Vector2i(4, 2))
	if b:
		level.try_upgrade(b.cell)
		level.try_upgrade(b.cell, b.data.spec_a)
	for x in [1, 2, 3, 5, 6, 7, 8]:
		level.try_build(Vector2i(x, 5), Level.WALL, false)
	level.waves.current = 0
	level.start_wave()
	await _frames(360)
	level._on_cell_tapped(Vector2i(4, 2))
	await _shot("13_peaks_banner")
	level._deselect()
	level._end(Level.Phase.WON)
	await _shot("14_victory")
	level.queue_free()
	await tree.process_frame

	# Endless map, late wave.
	level = await _level_data(Game.campaign.endless_maps[1])
	level.economy.earn(3000)
	for x in [0, 1, 2, 3, 5, 6, 7]:
		level.try_build(Vector2i(x, 4), Level.WALL, false)
	for cell in [Vector2i(1, 6), Vector2i(7, 6), Vector2i(4, 9), Vector2i(2, 11), Vector2i(6, 11)]:
		level.try_build(cell, &"flame_brazier" if cell.y == 9 else &"archer", false)
	level.waves.current = 11
	level.start_wave()
	await _frames(500)
	await _shot("15_endless")
	level._end(Level.Phase.LOST)
	await _shot("16_defeat")


func _level(number: int) -> Level:
	return await _level_data(Game.campaign.level_by_number(number))


func _level_data(data: LevelData) -> Level:
	Game.current_level = data
	var level: Level = load("res://scenes/level/level.tscn").instantiate()
	root.add_child(level)
	await tree.process_frame
	return level
