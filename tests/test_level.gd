extends "res://tests/test_case.gd"
## Runs the real level scene. Needs --fixed-fps 60 so frames simulate faster than real time.

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const MAX_FRAMES := 60000

var level: Level


func before_each() -> void:
	Game.current_level = null
	Save.reset()
	await _load(Game.campaign.level_by_number(1))


func after_each() -> void:
	level.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0
	Game.current_level = null


func _load(data: LevelData) -> void:
	if level:
		level.queue_free()
		await tree.process_frame
	Game.current_level = data
	level = LEVEL_SCENE.instantiate()
	tree.root.add_child(level)
	await tree.process_frame


func test_every_level_loads_with_open_routes() -> void:
	var all: Array[LevelData] = []
	all.append_array(Game.campaign.levels)
	all.append_array(Game.campaign.endless_maps)
	all.append_array(Game.campaign.challenges)
	assert_eq(Game.campaign.levels.size(), 30)
	for data in all:
		var grid := GridManager.new()
		grid.setup_from_level(data)
		for route in grid.gate_routes():
			assert_false(route.is_empty(), "%s: gate sealed by terrain" % data.id)
		if data.shifting_gates:
			grid.set_gates(data.alt_gates)
			for route in grid.gate_routes():
				assert_false(route.is_empty(), "%s: alt gate sealed" % data.id)
		assert_true(data.waves.size() >= 3 or data.is_endless(), "%s has waves" % data.id)
		for wave in data.waves:
			for group in wave.groups:
				assert_true(group.enemy != null, "%s: group without enemy" % data.id)
		assert_false(data.available_towers.is_empty(), "%s has towers" % data.id)


func test_build_upgrade_and_sell() -> void:
	level.economy.earn(500)
	var gold := level.economy.gold
	assert_true(level.try_build(Vector2i(2, 2), &"archer"))
	assert_eq(level.economy.gold, gold - 50)
	var tower := level.tower_at(Vector2i(2, 2))
	assert_true(tower != null)
	assert_true(level.try_upgrade(Vector2i(2, 2)))
	assert_eq(tower.tier, 2)
	assert_eq(level.economy.gold, gold - 110)
	assert_false(level.try_upgrade(Vector2i(2, 2)), "tier 3 needs a specialization")
	assert_true(level.try_upgrade(Vector2i(2, 2), tower.data.spec_a))
	assert_eq(tower.tier, 3)
	assert_true(tower.has_spec(TowerSpec.Kind.LONGBOW))
	assert_true(tower.attack_range() > tower.data.attack_range + 1.0)
	assert_true(level.try_sell(Vector2i(2, 2)))
	assert_eq(level.economy.gold, gold - 220 + 154, "70% of everything spent comes back")
	assert_eq(level.grid.get_tile(Vector2i(2, 2)), GridManager.Tile.EMPTY)


func test_banner_buffs_adjacent_towers() -> void:
	level.economy.earn(1000)
	level.try_build(Vector2i(2, 2), &"archer")
	var archer := level.tower_at(Vector2i(2, 2))
	assert_eq(archer.buff_speed, 1.0)
	await _load(Game.campaign.level_by_number(23))
	level.economy.earn(2000)
	var cells := _open_pair()
	level.try_build(cells[0], &"archer")
	level.try_build(cells[1], &"war_banner")
	archer = level.tower_at(cells[0])
	assert_true(archer.buff_speed > 1.0, "rallied by the banner")
	var banner := level.tower_at(cells[1])
	level.try_upgrade(cells[1])
	level.try_upgrade(cells[1], banner.data.spec_b)
	assert_true(archer.buff_bounty > 0.0, "bounty banner")
	level.try_sell(cells[1])
	assert_eq(archer.buff_speed, 1.0, "buff removed with the banner")


func _open_pair() -> Array[Vector2i]:
	for y in range(2, 11):
		for x in range(1, 7):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if level.grid.check_build(a, [] as Array[GroundWalker], GridManager.Tile.TOWER) == GridManager.Check.OK \
					and level.grid.check_build(b, [] as Array[GroundWalker], GridManager.Tile.TOWER) == GridManager.Check.OK:
				return [a, b]
	return [Vector2i(1, 2), Vector2i(2, 2)]


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


func test_sapper_smashes_walls_and_slime_splits() -> void:
	var sapper := load("res://data/enemies/sapper.tres") as EnemyData
	var slime := load("res://data/enemies/slime.tres") as EnemyData
	# Wall straight across the gate's column so the sapper must smash through.
	level.economy.earn(1000)
	for x in level.grid.size.x:
		level.try_build(Vector2i(x, 2), Level.WALL, false)
	level.try_sell(Vector2i(0, 2))  # one gap far away, so smashing is the sapper's shorter choice
	var before := level.grid.wall_count
	level.phase = Level.Phase.WAVE
	level._spawn_enemy(sapper, 0)
	level._spawn_enemy(slime, 0)
	var enemies := level._alive_enemies()
	assert_eq(enemies.size(), 2)
	for frame in 900:
		await tree.process_frame
		if level.grid.wall_count < before:
			break
	assert_true(level.grid.wall_count < before, "a wall was smashed")
	var slime_enemy: Enemy = enemies[1]
	slime_enemy.take_damage(10000.0, TowerData.DamageType.TRUE)
	await tree.process_frame
	var names: Array[String] = []
	for enemy in level._alive_enemies():
		names.append(enemy.data.display_name)
	assert_eq(names.count("Slimeling"), 2, "slime split into two: %s" % [names])


func test_ghost_waits_then_phases_through_walls() -> void:
	var ghost := load("res://data/enemies/ghost.tres") as EnemyData
	level.economy.earn(1000)
	for x in level.grid.size.x:
		level.try_build(Vector2i(x, 2), Level.WALL, false)
	level.try_sell(Vector2i(0, 2))
	var before := level.grid.wall_count
	level.phase = Level.Phase.WAVE
	level._spawn_enemy(ghost, 0)
	var enemy := level._alive_enemies()[0]
	var held_frames := 0
	var passed := false
	for frame in 900:
		await tree.process_frame
		if enemy == null or not is_instance_valid(enemy):
			break
		if enemy.walker.held:
			held_frames += 1
		if enemy.walker.cell_from.y > 2:
			passed = true
			break
	assert_true(passed, "ghost got past the wall row")
	assert_true(held_frames > 0, "it waited for its phase cooldown first")
	assert_eq(level.grid.wall_count, before, "without smashing anything")


func test_frost_and_flame_thermal_shock() -> void:
	var goblin := load("res://data/enemies/orc_brute.tres") as EnemyData
	level.phase = Level.Phase.WAVE
	var a := level._make_enemy(goblin, Vector2i(4, 0))
	var b := level._make_enemy(goblin, Vector2i(4, 0))
	a.apply_burn(10.0, 2.0)
	b.apply_burn(10.0, 2.0)
	b.apply_slow(0.5, 2.0)
	await _run_frames(30)
	assert_true(a.health < goblin.max_health, "burn ticks")
	assert_true(b.health < a.health, "slowed and burning takes extra damage")
	assert_true(b.data.speed * 0.5 == b.data.speed * b.slow_factor)


func test_undefended_keep_falls() -> void:
	Engine.time_scale = 3.0
	await _play(func() -> void: pass)
	assert_eq(level.phase, Level.Phase.LOST)


func test_bot_wins_level_one_with_a_simple_maze() -> void:
	var result := await _bot_play(1)
	assert_eq(result.phase, Level.Phase.WON, "lives left: %d" % result.lives)
	assert_true(Save.stars_for(&"level_01") >= 1, "result saved")


func test_bot_wins_a_marsh_level() -> void:
	var result := await _bot_play(13)
	assert_eq(result.phase, Level.Phase.WON, "lives left: %d" % result.lives)


func test_bot_wins_a_peaks_level() -> void:
	var result := await _bot_play(24)
	assert_eq(result.phase, Level.Phase.WON, "lives left: %d" % result.lives)


## A bot playing like a sensible beginner: a serpentine of walls on rows 3/6/9,
## towers at the corners the monsters must walk around, then more towers and
## upgrades as gold allows. Everything is bought in priority order, so a step
## it can't afford yet is retried at the next build phase. A balance smoke
## test, not a proof of fun.
func _bot_play(number: int) -> Dictionary:
	await _load(Game.campaign.level_by_number(number))
	var ids: Array[StringName] = []
	for t in level.level_data.available_towers:
		if t.id != &"war_banner":
			ids.append(t.id)
	var w := level.grid.size.x
	var plan: Array = []  # [cell, kind]
	var gaps: Dictionary[int, int] = {}
	for row in [3, 6, 9]:
		# Open end alternates sides, but never on the same side as a gate feeding
		# the corridor above this row (World 3's edge gates), and never in a
		# column with terrain in it.
		var left_first: bool = (row / 3) % 2 == 1
		for gate in level.grid.all_gates:
			if gate.y > row - 3 and gate.y < row:
				left_first = gate.x > w / 2
		var order := range(w) if left_first else range(w - 1, -1, -1)
		for x in order:
			if level.grid.get_tile(Vector2i(x, row - 1)) == GridManager.Tile.EMPTY \
					and level.grid.get_tile(Vector2i(x, row)) == GridManager.Tile.EMPTY \
					and level.grid.get_tile(Vector2i(x, row + 1)) == GridManager.Tile.EMPTY:
				gaps[row] = x
				break
	# Archers just inside each turn see two corridors at once. The first one is
	# bought before the walls so wave 1 is never undefended.
	var corners: Array[Vector2i] = []
	for row in [3, 6, 9]:
		var gap: int = gaps.get(row, 0)
		corners.append(Vector2i(1 if gap < w / 2 else w - 2, row + 1))
	plan.append([corners[0], &"archer"])
	for row in [3, 6, 9]:
		for x in w:
			if x != gaps.get(row, -1):
				plan.append([Vector2i(x, row), Level.WALL])
	plan.append([corners[1], &"archer"])
	plan.append([corners[2], &"archer"])
	var extras := [Vector2i(w - 2, 4), Vector2i(1, 7), Vector2i(w - 2, 10), Vector2i(w / 2, 2), Vector2i(w / 2, 11)]
	for i in extras.size():
		plan.append([extras[i], ids[(i + 1) % ids.size()]])
	var built_towers: Array[Vector2i] = []
	var buy := func() -> void:
		for step: Array in plan:
			var cell: Vector2i = step[0]
			var kind: StringName = step[1]
			if kind != Level.WALL:
				# A rock where the plan wanted a tower: use the nearest open neighbour instead.
				cell = _buildable_near(cell)
				if cell == Board.NO_CELL or step.size() > 2:
					continue
			if level.grid.is_structure(cell):
				continue
			if level.try_build(cell, kind, false):
				if kind != Level.WALL:
					built_towers.append(cell)
					step.append(true)  # done
			elif kind != Level.WALL and not level.economy.can_afford(_cost(kind)):
				return  # save up for this one rather than skipping ahead
		for cell in built_towers:
			var tower := level.tower_at(cell)
			if tower and tower.can_upgrade() and level.economy.gold > tower.upgrade_cost() + 20:
				level.try_upgrade(cell, tower.data.spec_a if tower.tier == 2 else null)
	Engine.time_scale = 3.0
	await _play(buy)
	if OS.get_environment("BOT_DEBUG"):
		print("          level %d: phase %d, %d lives, %d stars, %d gold, wave %d/%d" % [number, level.phase, level.economy.lives, level.economy.stars(), level.economy.gold, level.waves.current + 1, level.waves.total()])
	return {"phase": level.phase, "lives": level.economy.lives}


func _buildable_near(cell: Vector2i) -> Vector2i:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c := cell + offset
		if level.grid.is_in_bounds(c) and (level.grid.get_tile(c) == GridManager.Tile.EMPTY or level.tower_at(c) != null):
			return c
	return Board.NO_CELL


func _cost(kind: StringName) -> int:
	for t in level.level_data.available_towers:
		if t.id == kind:
			return t.cost
	return level.wall_cost


## Plays waves until the level ends, calling `build` at every build phase.
func _play(build: Callable) -> void:
	for frame in MAX_FRAMES:
		if level.phase == Level.Phase.WON or level.phase == Level.Phase.LOST:
			return
		if level.phase == Level.Phase.BUILD:
			build.call()
			if OS.get_environment("BOT_DEBUG") and level.waves.current >= 0:
				print("            after wave %d: %d lives, %d gold, %d structures" % [level.waves.current + 1, level.economy.lives, level.economy.gold, level.structure_count()])
			level.start_wave()
		await tree.process_frame
	fail("level did not finish in %d frames" % MAX_FRAMES)


func _run_frames(count: int) -> void:
	for i in count:
		await tree.process_frame
