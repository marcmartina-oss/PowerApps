class_name Pathfinding
extends RefCounted
## Shortest 4-way routes on the square grid using AStarGrid2D.
## The solver is deterministic: identical grid state and endpoints always give
## the identical route, so a ghost preview from a gate matches exactly the route
## a freshly spawned enemy at that gate will walk.
##
## Two grids are kept in step: the normal one, where walls are solid, and a
## wall-permissive one for wall-breakers and ghosts, where walls are passable
## but expensive, so they still prefer open corridors.

## Cost multiplier of crossing a wall tile on the permissive grid.
const WALL_WEIGHT := 4.0

var _astar := AStarGrid2D.new()
var _permissive := AStarGrid2D.new()


func setup(size: Vector2i) -> void:
	for grid in [_astar, _permissive]:
		grid.region = Rect2i(Vector2i.ZERO, size)
		grid.cell_size = Vector2.ONE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.jumping_enabled = false
		grid.update()


## Terrain blocks everyone; walls block normal walkers only.
func set_terrain(cell: Vector2i, blocked: bool) -> void:
	_astar.set_point_solid(cell, blocked)
	_permissive.set_point_solid(cell, blocked)


func set_wall(cell: Vector2i, present: bool) -> void:
	# Terrain stays solid when a wall is removed from the same tile.
	_astar.set_point_solid(cell, present or _permissive.is_point_solid(cell))
	_permissive.set_point_weight_scale(cell, WALL_WEIGHT if present else 1.0)


func is_blocked(cell: Vector2i) -> bool:
	return _astar.is_point_solid(cell)


## Route from `from` to `to`, both ends included. Empty if there is none.
func find_route(from: Vector2i, to: Vector2i, through_walls := false) -> Array[Vector2i]:
	var grid := _permissive if through_walls else _astar
	if grid.is_point_solid(from) or grid.is_point_solid(to):
		return []
	return grid.get_id_path(from, to)
