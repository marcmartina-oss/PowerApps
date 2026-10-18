extends "res://tests/test_case.gd"
## Mid-wave rerouting and the anti-exploit rules for live maze editing.

const C := GridManager.Check

var grid: GridManager


func before_each() -> void:
	grid = GridManager.new()
	grid.setup(Vector2i(7, 9), [Vector2i(3, 0)] as Array[Vector2i], Vector2i(3, 8), [] as Array[Vector2i])


func _walker_at_gate() -> GroundWalker:
	return GroundWalker.new(grid.gates[0], grid.route_from(grid.gates[0]))


## Mirrors what the level does on maze_changed.
func _reroute(walkers: Array[GroundWalker]) -> void:
	for walker in walkers:
		walker.route = grid.next_route(walker)


func test_walker_follows_route_to_keep() -> void:
	var walker := _walker_at_gate()
	walker.advance(100.0)
	assert_true(walker.is_at(grid.keep))
	assert_eq(walker.remaining_distance(), 0.0)


func test_walker_moves_continuously_without_teleporting() -> void:
	var walker := _walker_at_gate()
	var last := walker.tile_position()
	for i in 200:
		walker.advance(0.07)
		var pos := walker.tile_position()
		assert_true(pos.distance_to(last) <= 0.0701, "jumped from %s to %s" % [last, pos])
		last = pos


func test_mid_wave_reroute_finishes_current_step_first() -> void:
	var walker := _walker_at_gate()
	var walkers: Array[GroundWalker] = [walker]
	walker.advance(1.5)  # between (3,1) and (3,2)
	assert_eq(walker.cell_to, Vector2i(3, 2))
	var wall := Vector2i(3, 4)
	assert_eq(grid.check_build(wall, walkers), C.OK)
	grid.build(wall, GridManager.Tile.WALL)
	_reroute(walkers)
	assert_eq(walker.cell_to, Vector2i(3, 2), "target tile unchanged by reroute")
	assert_eq(walker.route[0], Vector2i(3, 2))
	assert_false(wall in walker.route)
	walker.advance(100.0)
	assert_true(walker.is_at(grid.keep))


func test_unaffected_walker_keeps_its_route() -> void:
	var walker := _walker_at_gate()
	var walkers: Array[GroundWalker] = [walker]
	walker.advance(0.5)
	var before := walker.route.duplicate()
	grid.build(Vector2i(0, 7), GridManager.Tile.WALL)
	_reroute(walkers)
	assert_eq(walker.route, before)


func test_selling_opens_shorter_route() -> void:
	grid.build(Vector2i(3, 5), GridManager.Tile.WALL)
	var walker := _walker_at_gate()
	var walkers: Array[GroundWalker] = [walker]
	assert_eq(walker.route.size(), 11)
	walker.advance(0.5)
	assert_eq(grid.check_sell(Vector2i(3, 5), walkers), C.OK)
	grid.clear(Vector2i(3, 5))
	_reroute(walkers)
	assert_eq(walker.route.size(), 8, "straight line from (3,1)")


func test_rejects_edit_forcing_reversal() -> void:
	# Corridor: walls on both sides of column 3 for rows 1-5, so the walker is in a tube.
	for y in range(1, 6):
		grid.build(Vector2i(2, y), GridManager.Tile.WALL)
		grid.build(Vector2i(4, y), GridManager.Tile.WALL)
	var walker := _walker_at_gate()
	var walkers: Array[GroundWalker] = [walker]
	walker.advance(2.5)  # between (3,2) and (3,3)
	# Plugging the tube ahead leaves the only route back up past the tile it just left.
	assert_eq(grid.check_build(Vector2i(3, 5), walkers), C.ENEMY_REVERSAL)


func test_rejects_edit_that_loops_walker_over_used_tiles() -> void:
	var walker := _walker_at_gate()
	walker.visits[Vector2i(2, 3)] = GridManager.MAX_TILE_VISITS
	walker.visits[Vector2i(4, 3)] = GridManager.MAX_TILE_VISITS
	walker.advance(1.5)  # between (3,1) and (3,2)
	var walkers: Array[GroundWalker] = [walker]
	# Any detour around (3,3) must pass (2,3) or (4,3), both used up.
	assert_eq(grid.check_build(Vector2i(3, 3), walkers), C.ENEMY_LOOP)


func test_rapid_build_sell_cycles_cannot_stall_enemies() -> void:
	# Each tick: try to toggle every tile near the walker (build if allowed, else sell
	# if allowed). Tries to farm path length as hard as a script can.
	var walker := _walker_at_gate()
	var walkers: Array[GroundWalker] = [walker]
	var built: Array[Vector2i] = []
	var edits := 0
	var ticks := 0
	var tile_count := grid.size.x * grid.size.y
	while not walker.is_at(grid.keep) and ticks < 10000:
		ticks += 1
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var cell := walker.cell_to + Vector2i(dx, dy)
				if cell in built:
					if grid.check_sell(cell, walkers) == C.OK:
						grid.clear(cell)
						built.erase(cell)
						_reroute(walkers)
						edits += 1
				elif grid.check_build(cell, walkers) == C.OK:
					grid.build(cell, GridManager.Tile.WALL)
					built.append(cell)
					_reroute(walkers)
					edits += 1
		walker.advance(0.25)
	assert_true(edits > 50, "the script really did edit the maze (%d edits)" % edits)
	assert_true(walker.is_at(grid.keep), "walker reached the keep")
	var steps := 0
	for cell in walker.visits:
		assert_true(walker.visits[cell] <= GridManager.MAX_TILE_VISITS, "tile %s visited %d times" % [cell, walker.visits[cell]])
		steps += walker.visits[cell]
	assert_true(steps <= tile_count * GridManager.MAX_TILE_VISITS, "path length bounded (%d steps)" % steps)


func test_every_gate_stays_open_through_random_edits() -> void:
	grid = GridManager.new()
	grid.setup(Vector2i(9, 14), [Vector2i(1, 0), Vector2i(7, 0)] as Array[Vector2i], Vector2i(4, 13), [Vector2i(4, 6)] as Array[Vector2i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var walkers: Array[GroundWalker] = []
	for i in 2000:
		if i % 40 == 0:
			walkers.append(GroundWalker.new(grid.gates[i / 40 % 2], grid.route_from(grid.gates[i / 40 % 2])))
		var cell := Vector2i(rng.randi_range(0, 8), rng.randi_range(0, 13))
		if grid.is_structure(cell):
			if grid.check_sell(cell, walkers) == C.OK:
				grid.clear(cell)
				_reroute(walkers)
		elif grid.check_build(cell, walkers) == C.OK:
			grid.build(cell, GridManager.Tile.WALL)
			_reroute(walkers)
		for walker in walkers:
			walker.advance(0.3)
			assert_true(walker.has_route(), "walker lost its route")
			assert_false(grid.is_structure(walker.cell_from) or grid.is_structure(walker.cell_to), "walker inside a wall")
		for route in grid.gate_routes():
			assert_false(route.is_empty(), "a gate was sealed")
		if not failures.is_empty():
			return
