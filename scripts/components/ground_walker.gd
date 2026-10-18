class_name GroundWalker
extends RefCounted
## Tile-by-tile movement state for a ground enemy. A walker always finishes the
## step to its current target tile before turning onto a new route, so it never
## teleports. Invariant: route[0] == cell_to whenever route is not empty.

var cell_from: Vector2i
var cell_to: Vector2i
## 0 at cell_from, 1 at cell_to.
var progress := 0.0
var route: Array[Vector2i] = []
## How many times this walker has arrived on each tile.
var visits: Dictionary[Vector2i, int] = {}


func _init(start: Vector2i, start_route: Array[Vector2i]) -> void:
	cell_from = start
	cell_to = start
	visits[start] = 1
	route = start_route


func is_moving() -> bool:
	return cell_from != cell_to


func has_route() -> bool:
	return not route.is_empty()


func is_at(cell: Vector2i) -> bool:
	return not is_moving() and cell_from == cell


func occupies(cell: Vector2i) -> bool:
	return cell == cell_from or cell == cell_to


## Moves `tiles` tiles along the route, carrying leftover distance across tiles.
func advance(tiles: float) -> void:
	while tiles > 0.0:
		if not is_moving() and not _take_next_step():
			return
		var remaining := 1.0 - progress
		if tiles < remaining:
			progress += tiles
			return
		tiles -= remaining
		progress = 0.0
		cell_from = cell_to
		visits[cell_from] = visits.get(cell_from, 0) + 1


## Tiles left to walk before reaching the end of the route.
func remaining_distance() -> float:
	if route.is_empty():
		return INF
	var rest := float(route.size() - 1)
	return rest + (1.0 - progress if is_moving() else 0.0)


## Current position in tile coordinates (tile centres are whole numbers).
func tile_position() -> Vector2:
	return Vector2(cell_from).lerp(Vector2(cell_to), progress)


func _take_next_step() -> bool:
	if route.size() < 2 or route[0] != cell_from:
		return false
	route.remove_at(0)
	cell_to = route[0]
	return true
