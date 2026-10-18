extends "res://tests/test_case.gd"
## Runs the real level scene. Needs --fixed-fps 60 so frames simulate faster than real time.

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const MAX_FRAMES := 30000

var level: Level


func before_each() -> void:
	level = LEVEL_SCENE.instantiate()
	tree.root.add_child(level)
	await tree.process_frame


func after_each() -> void:
	level.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0


func test_level_data_loads() -> void:
	var data := level.level_data
	assert_eq(data.waves.size(), 5)
	assert_eq(data.available_towers.size(), 2)
	assert_eq(data.waves[2].groups.size(), 2)
	assert_eq(data.waves[2].groups[1].enemy.display_name, "Wolf Rider")
	for wave in data.waves:
		for group in wave.groups:
			assert_true(group.enemy != null, "group missing enemy")
	assert_false(level.grid.route_from(data.gates[0]).is_empty(), "map starts with an open route")


func test_build_and_sell_updates_gold_and_grid() -> void:
	var gold := level.economy.gold
	assert_true(level.try_build(Vector2i(2, 2), &"archer"))
	assert_eq(level.economy.gold, gold - 50)
	assert_eq(level.grid.get_tile(Vector2i(2, 2)), GridManager.Tile.TOWER)
	assert_true(level.tower_at(Vector2i(2, 2)) != null)
	assert_true(level.try_sell(Vector2i(2, 2)))
	assert_eq(level.economy.gold, gold - 50 + 35)
	assert_eq(level.grid.get_tile(Vector2i(2, 2)), GridManager.Tile.EMPTY)


func test_edit_cooldown_applies_only_during_waves() -> void:
	assert_true(level.try_build(Vector2i(0, 1), Level.WALL, false))
	assert_true(level.try_build(Vector2i(1, 1), Level.WALL, false), "no cooldown while building")
	level.start_wave()
	assert_true(level.try_build(Vector2i(0, 2), Level.WALL, false))
	assert_false(level.try_build(Vector2i(1, 2), Level.WALL, false), "second edit within 1s is refused")
	await _run_frames(70)
	assert_true(level.try_build(Vector2i(1, 2), Level.WALL, false), "allowed again after the cooldown")


func test_live_enemies_reroute_without_entering_walls() -> void:
	level.economy.earn(1000)
	level.start_wave()
	var edits := 0
	for frame in 1200:
		await tree.process_frame
		# Every second, wall off a tile on the first enemy's route a few steps ahead.
		if frame % 61 == 0:
			for enemy in level._alive_enemies():
				var route := enemy.walker.route
				if route.size() > 4 and level.try_build(route[3], Level.WALL, false):
					edits += 1
					break
		for enemy in level._alive_enemies():
			var walker := enemy.walker
			assert_false(level.grid.is_structure(walker.cell_from) or level.grid.is_structure(walker.cell_to),
				"enemy inside a wall at %s -> %s" % [walker.cell_from, walker.cell_to])
		if not failures.is_empty():
			return
	assert_true(edits >= 3, "made %d mid-wave edits" % edits)


func test_undefended_keep_falls() -> void:
	Engine.time_scale = 3.0
	await _play(func() -> void: pass)
	assert_eq(level.phase, Level.Phase.LOST)


func test_bot_with_a_simple_maze_wins() -> void:
	# A serpentine maze with towers set into its walls, bought in priority order
	# whenever gold allows. A balance smoke test, not a proof of fun.
	var plan: Array = [
		[Vector2i(4, 3), &"archer"], [Vector2i(3, 6), &"archer"],
	]
	for x in [0, 1, 2, 3, 5, 6, 7]:
		plan.append([Vector2i(x, 3), Level.WALL])
	for x in [1, 2, 5, 6, 7, 8]:
		plan.append([Vector2i(x, 6), Level.WALL])
	plan.append([Vector2i(5, 9), &"stone_thrower"])
	for x in [0, 1, 2, 3, 4, 6, 7]:
		plan.append([Vector2i(x, 9), Level.WALL])
	plan.append_array([
		[Vector2i(6, 3), &"stone_thrower"], [Vector2i(2, 6), &"archer"], [Vector2i(3, 9), &"archer"],
		[Vector2i(7, 6), &"archer"], [Vector2i(1, 3), &"archer"], [Vector2i(6, 9), &"archer"],
	])
	var buy := func() -> void:
		for step: Array in plan:
			if not level.grid.is_structure(step[0]):
				level.try_build(step[0], step[1], false)
	Engine.time_scale = 3.0
	await _play(buy)
	assert_eq(level.phase, Level.Phase.WON, "lives left: %d" % level.economy.lives)
	print("          bot result: %d lives, %d stars, %d gold" % [level.economy.lives, level.economy.stars(), level.economy.gold])


## Plays waves until the level ends, calling `build` at every build phase.
func _play(build: Callable) -> void:
	for frame in MAX_FRAMES:
		if level.phase == Level.Phase.WON or level.phase == Level.Phase.LOST:
			return
		if level.phase == Level.Phase.BUILD:
			if OS.get_environment("BOT_DEBUG"): print("          wave %d done: lives %d gold %d structures %d" % [level.waves.current + 1, level.economy.lives, level.economy.gold, level._structures.size()])
			build.call()
			level.start_wave()
		await tree.process_frame
	fail("level did not finish in %d frames" % MAX_FRAMES)


func _run_frames(count: int) -> void:
	for i in count:
		await tree.process_frame
