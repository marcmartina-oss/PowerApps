extends "res://tests/test_case.gd"
## Wall-permissive routing, wall budgets, shifting gates and endless waves.

const C := GridManager.Check

var grid: GridManager


func before_each() -> void:
	grid = GridManager.new()
	grid.setup(Vector2i(7, 9), [Vector2i(3, 0)] as Array[Vector2i], Vector2i(3, 8), [] as Array[Vector2i])


func _wall_row(y: int, gap: int) -> void:
	for x in grid.size.x:
		if x != gap:
			grid.build(Vector2i(x, y), GridManager.Tile.WALL)


func test_wall_breaker_routes_through_walls_but_not_towers() -> void:
	_wall_row(4, 0)  # long detour for walkers via x = 0
	var normal := grid.route_from(Vector2i(3, 0))
	var through := grid.route_from(Vector2i(3, 0), true)
	assert_true(through.size() < normal.size(), "straight through is shorter")
	assert_true(grid.is_wall(through[4]), "the permissive route crosses the wall at (3,4)")
	grid.clear(Vector2i(3, 4))
	grid.build(Vector2i(3, 4), GridManager.Tile.TOWER)
	through = grid.route_from(Vector2i(3, 0), true)
	assert_false(Vector2i(3, 4) in through, "towers block wall-breakers too")


func test_wall_breakers_prefer_open_corridors() -> void:
	# A single wall ahead with a two-tile detour: the detour is cheaper than smashing.
	grid.build(Vector2i(3, 4), GridManager.Tile.WALL)
	var through := grid.route_from(Vector2i(3, 0), true)
	assert_false(Vector2i(3, 4) in through)


func test_building_a_tower_cannot_trap_a_sapper() -> void:
	# Sapper tunnel between two rows of towers (walls would just get smashed).
	for y in range(1, 8):
		grid.build(Vector2i(2, y), GridManager.Tile.TOWER)
		grid.build(Vector2i(4, y), GridManager.Tile.TOWER)
	var sapper := GroundWalker.new(Vector2i(3, 0), grid.route_from(Vector2i(3, 0), true), true)
	sapper.advance(1.5)
	var walkers: Array[GroundWalker] = [sapper]
	assert_eq(grid.check_build(Vector2i(3, 5), walkers, GridManager.Tile.WALL), C.OK, "a wall is fine, it can be smashed")
	assert_eq(grid.check_build(Vector2i(3, 5), walkers, GridManager.Tile.TOWER), C.ENEMY_REVERSAL, "a tower would force it back")
	grid.build(Vector2i(3, 5), GridManager.Tile.WALL)
	sapper.route = grid.next_route(sapper)
	assert_true(Vector2i(3, 5) in sapper.route, "it plans to smash through")


func test_walker_stops_at_a_wall_it_must_smash() -> void:
	grid.build(Vector2i(3, 3), GridManager.Tile.WALL)
	for x in grid.size.x:
		if x != 3:
			grid.build(Vector2i(x, 3), GridManager.Tile.TOWER)
	var sapper := GroundWalker.new(Vector2i(3, 0), grid.route_from(Vector2i(3, 0), true), true)
	sapper.blocker = grid.is_wall
	sapper.advance(10.0)
	assert_true(sapper.is_at(Vector2i(3, 2)), "waits in front of the wall, at %s" % sapper.cell_from)
	sapper.advance(0.5, true)
	assert_eq(sapper.cell_to, Vector2i(3, 3), "forced step phases onto the wall tile")
	grid.clear(Vector2i(3, 3))
	sapper.advance(10.0)
	assert_true(sapper.is_at(grid.keep))


func test_wall_budget_and_forbidden_walls() -> void:
	grid.wall_budget = 2
	grid.build(Vector2i(0, 2), GridManager.Tile.WALL)
	grid.build(Vector2i(1, 2), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(2, 2), [] as Array[GroundWalker], GridManager.Tile.WALL), C.WALL_BUDGET)
	assert_eq(grid.check_build(Vector2i(2, 2), [] as Array[GroundWalker], GridManager.Tile.TOWER), C.OK, "towers don't count")
	grid.clear(Vector2i(0, 2))
	assert_eq(grid.check_build(Vector2i(2, 2), [] as Array[GroundWalker], GridManager.Tile.WALL), C.OK, "selling frees budget")
	grid.walls_allowed = false
	assert_eq(grid.check_build(Vector2i(2, 2), [] as Array[GroundWalker], GridManager.Tile.WALL), C.WALLS_FORBIDDEN)


func test_shifting_gates_keep_every_gate_tile_unbuildable() -> void:
	var level := LevelData.new()
	level.grid_size = Vector2i(7, 9)
	level.gates = [Vector2i(3, 0)] as Array[Vector2i]
	level.alt_gates = [Vector2i(0, 4)] as Array[Vector2i]
	level.shifting_gates = true
	level.keep = Vector2i(3, 8)
	grid.setup_from_level(level)
	assert_eq(grid.check_build(Vector2i(0, 4), [] as Array[GroundWalker]), C.NOT_BUILDABLE, "inactive gate")
	assert_eq(grid.gates, [Vector2i(3, 0)] as Array[Vector2i])
	grid.set_gates(level.alt_gates)
	assert_eq(grid.gates, [Vector2i(0, 4)] as Array[Vector2i])
	assert_true(grid.is_active_gate(Vector2i(0, 4)))
	assert_false(grid.is_active_gate(Vector2i(3, 0)))
	assert_eq(grid.check_build(Vector2i(3, 0), [] as Array[GroundWalker]), C.NOT_BUILDABLE, "old gate stays a gate")
	# Walling off an INACTIVE gate is refused too: it must stay reachable for later waves.
	grid.set_gates(level.gates)
	grid.build(Vector2i(1, 4), GridManager.Tile.WALL)
	grid.build(Vector2i(0, 3), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(0, 5), [] as Array[GroundWalker]), C.BLOCKS_PATH)


func test_endless_waves_generate_and_scale() -> void:
	var goblin := EnemyData.new()
	goblin.display_name = "Goblin"
	goblin.max_health = 26
	var orc := EnemyData.new()
	orc.display_name = "Orc"
	orc.max_health = 150
	var manager := WaveManager.new()
	manager.setup([] as Array[WaveData], [goblin, orc] as Array[EnemyData])
	assert_true(manager.has_next())
	var sizes: Array[int] = []
	for i in 25:
		manager.start_next()
		var n := 0
		for g in manager.waves[i].groups:
			n += g.count
		sizes.append(n)
		assert_true(manager.is_spawning())
		manager.tick(1000.0)
	assert_true(sizes[24] > sizes[0], "later waves are bigger (%s)" % [sizes])
	assert_true(manager.health_scale > 1.0, "health scales after wave 10")
	assert_true(manager.has_next(), "never ends")
	assert_eq(manager.generate_wave(5).groups.size(), manager.generate_wave(5).groups.size(), "deterministic")
	assert_ne(manager.describe(30), "")


func test_tower_tiers_and_refund_value() -> void:
	var data := TowerData.new()
	data.cost = 50
	data.upgrade_costs = [60, 110] as Array[int]
	data.damage = 10
	data.attack_range = 2.0
	assert_eq(data.upgrade_cost(1), 60)
	assert_eq(data.upgrade_cost(2), 110)
	assert_eq(data.upgrade_cost(3), 0)
	assert_eq(data.total_cost(3), 220)
	assert_eq(data.damage_at(3), 22.5)
	assert_eq(data.range_at(2), 2.3)
