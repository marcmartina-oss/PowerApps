extends "res://tests/test_case.gd"

var grid: GridManager


func before_each() -> void:
	grid = GridManager.new()
	grid.setup(Vector2i(5, 5), [Vector2i(2, 0)] as Array[Vector2i], Vector2i(2, 4), [] as Array[Vector2i])


func test_straight_route_on_open_grid() -> void:
	var route := grid.route_from(Vector2i(2, 0))
	assert_eq(route, [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)] as Array[Vector2i])


func test_routes_never_move_diagonally() -> void:
	var route := grid.route_from(Vector2i(0, 0))
	for i in range(1, route.size()):
		var step := route[i] - route[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1, "step %s" % step)


func test_route_avoids_structures_and_rocks() -> void:
	grid.build(Vector2i(2, 2), GridManager.Tile.WALL)
	var route := grid.route_from(Vector2i(2, 0))
	assert_false(Vector2i(2, 2) in route)
	assert_eq(route.size(), 7, "detour adds two tiles")


func test_equal_cost_ties_are_stable() -> void:
	grid.build(Vector2i(2, 2), GridManager.Tile.WALL)
	var first := grid.route_from(Vector2i(2, 0))
	for i in 20:
		assert_eq(grid.route_from(Vector2i(2, 0)), first)


func test_preview_matches_route_after_build() -> void:
	var preview: Array = grid.gate_routes_if_built(Vector2i(2, 1))
	grid.build(Vector2i(2, 1), GridManager.Tile.WALL)
	assert_eq(preview, grid.gate_routes())


func test_preview_does_not_change_grid() -> void:
	var before := grid.gate_routes()
	grid.gate_routes_if_built(Vector2i(2, 1))
	assert_eq(grid.gate_routes(), before)
	assert_eq(grid.get_tile(Vector2i(2, 1)), GridManager.Tile.EMPTY)
