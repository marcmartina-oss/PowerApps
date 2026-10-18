class_name Pathfinding
extends RefCounted
## Shortest 4-way routes on the square grid using AStarGrid2D.
## The solver is deterministic: identical grid state and endpoints always give
## the identical route, so a ghost preview from a gate matches exactly the route
## a freshly spawned enemy at that gate will walk.

var _astar := AStarGrid2D.new()


func setup(size: Vector2i) -> void:
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.jumping_enabled = false
	_astar.update()


func set_blocked(cell: Vector2i, blocked: bool) -> void:
	_astar.set_point_solid(cell, blocked)


func is_blocked(cell: Vector2i) -> bool:
	return _astar.is_point_solid(cell)


## Route from `from` to `to`, both ends included. Empty if there is none.
func find_route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if is_blocked(from) or is_blocked(to):
		return []
	return _astar.get_id_path(from, to)
