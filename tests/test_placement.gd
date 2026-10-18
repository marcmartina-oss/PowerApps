extends "res://tests/test_case.gd"

const C := GridManager.Check

var grid: GridManager
var no_walkers: Array[GroundWalker] = []


func before_each() -> void:
	grid = GridManager.new()
	# 5x5, gate top-middle, keep bottom-middle, rock at (0,2).
	grid.setup(Vector2i(5, 5), [Vector2i(2, 0)] as Array[Vector2i], Vector2i(2, 4), [Vector2i(0, 2)] as Array[Vector2i])


func test_empty_tile_is_buildable() -> void:
	assert_eq(grid.check_build(Vector2i(1, 1), no_walkers), C.OK)


func test_rejects_out_of_bounds() -> void:
	assert_eq(grid.check_build(Vector2i(-1, 0), no_walkers), C.OUT_OF_BOUNDS)
	assert_eq(grid.check_build(Vector2i(5, 2), no_walkers), C.OUT_OF_BOUNDS)


func test_rejects_unbuildable_terrain() -> void:
	assert_eq(grid.check_build(Vector2i(0, 2), no_walkers), C.NOT_BUILDABLE, "rock")
	assert_eq(grid.check_build(Vector2i(2, 0), no_walkers), C.NOT_BUILDABLE, "gate")
	assert_eq(grid.check_build(Vector2i(2, 4), no_walkers), C.NOT_BUILDABLE, "keep")


func test_rejects_existing_structure() -> void:
	grid.build(Vector2i(1, 1), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(1, 1), no_walkers), C.OCCUPIED_BY_STRUCTURE)


func test_rejects_full_blockage() -> void:
	# Wall off row 2 except one gap; the last gap must be refused.
	for x in [1, 2, 3]:
		grid.build(Vector2i(x, 2), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(4, 2), no_walkers), C.BLOCKS_PATH)
	assert_eq(grid.get_tile(Vector2i(4, 2)), GridManager.Tile.EMPTY, "rejected check leaves grid untouched")
	assert_false(grid.route_from(Vector2i(2, 0)).is_empty())


func test_rejects_tiles_occupied_by_enemy() -> void:
	var walker := GroundWalker.new(Vector2i(2, 0), grid.route_from(Vector2i(2, 0)))
	walker.advance(0.5)  # between (2,0) and (2,1)
	var walkers: Array[GroundWalker] = [walker]
	assert_eq(grid.check_build(Vector2i(2, 1), walkers), C.OCCUPIED_BY_ENEMY, "tile it is entering")
	walker.advance(0.6)  # now between (2,1) and (2,2)
	assert_eq(grid.check_build(Vector2i(2, 1), walkers), C.OCCUPIED_BY_ENEMY, "tile it is leaving")
	assert_eq(grid.check_build(Vector2i(2, 2), walkers), C.OCCUPIED_BY_ENEMY)


func test_multiple_gates_each_need_a_route() -> void:
	grid = GridManager.new()
	# Two gates on the top row, keep bottom-right. Wall in gate A completely.
	grid.setup(Vector2i(5, 5), [Vector2i(0, 0), Vector2i(4, 0)] as Array[Vector2i], Vector2i(4, 4), [] as Array[Vector2i])
	grid.build(Vector2i(1, 0), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(0, 1), no_walkers), C.BLOCKS_PATH, "would seal gate A even though gate B is open")
	assert_eq(grid.check_build(Vector2i(3, 0), no_walkers), C.OK, "gate B can still go down")
	grid.build(Vector2i(3, 0), GridManager.Tile.WALL)
	assert_eq(grid.check_build(Vector2i(4, 1), no_walkers), C.BLOCKS_PATH, "would seal gate B")


func test_sell_requires_structure() -> void:
	assert_eq(grid.check_sell(Vector2i(1, 1), no_walkers), C.NO_STRUCTURE)
	assert_eq(grid.check_sell(Vector2i(0, 2), no_walkers), C.NO_STRUCTURE, "rocks can't be sold")
	grid.build(Vector2i(1, 1), GridManager.Tile.TOWER)
	assert_eq(grid.check_sell(Vector2i(1, 1), no_walkers), C.OK)
	grid.clear(Vector2i(1, 1))
	assert_eq(grid.get_tile(Vector2i(1, 1)), GridManager.Tile.EMPTY)


func test_maze_changed_signal_fires() -> void:
	var count := [0]
	grid.maze_changed.connect(func() -> void: count[0] += 1)
	grid.build(Vector2i(1, 1), GridManager.Tile.WALL)
	grid.clear(Vector2i(1, 1))
	assert_eq(count[0], 2)
