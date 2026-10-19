class_name GridManager
extends RefCounted
## Tile grid, buildable tiles, placement validation and the live-maze routing
## rules from the design doc. Validation is done by applying a change to the
## pathfinder, checking every gate and every active ground enemy, then reverting.

signal maze_changed
signal gates_changed

enum Tile { EMPTY, ROCK, WATER, RUIN, WALL, TOWER, GATE, KEEP }

enum Check {
	OK,
	OUT_OF_BOUNDS,
	NOT_BUILDABLE,
	OCCUPIED_BY_STRUCTURE,
	NO_STRUCTURE,
	OCCUPIED_BY_ENEMY,
	BLOCKS_PATH,
	ENEMY_REVERSAL,
	ENEMY_LOOP,
	WALL_BUDGET,
	WALLS_FORBIDDEN,
}

## A ground enemy may arrive on any one tile at most this many times. Edits that
## would route an enemy back onto a tile it has used up are rejected, which caps
## total path length however the player builds and sells mid-wave.
const MAX_TILE_VISITS := 2

const CHECK_MESSAGES: Dictionary[Check, String] = {
	Check.OK: "",
	Check.OUT_OF_BOUNDS: "Outside the map",
	Check.NOT_BUILDABLE: "Can't build here",
	Check.OCCUPIED_BY_STRUCTURE: "Already built here",
	Check.NO_STRUCTURE: "Nothing to sell",
	Check.OCCUPIED_BY_ENEMY: "A monster is in the way",
	Check.BLOCKS_PATH: "Monsters must always have a path to the keep",
	Check.ENEMY_REVERSAL: "That would make monsters double back",
	Check.ENEMY_LOOP: "Monsters can't be looped through the same tiles again",
	Check.WALL_BUDGET: "No walls left on this level",
	Check.WALLS_FORBIDDEN: "No walls allowed on this level",
}

var size: Vector2i
## Gates monsters currently spawn from.
var gates: Array[Vector2i] = []
## Every gate tile, active or not. All of them must always reach the keep.
var all_gates: Array[Vector2i] = []
var keep: Vector2i
var wall_budget := -1
var walls_allowed := true
var wall_count := 0

var _tiles := PackedByteArray()
var _pathfinding := Pathfinding.new()


func setup(grid_size: Vector2i, gate_cells: Array[Vector2i], keep_cell: Vector2i, rock_cells: Array[Vector2i]) -> void:
	size = grid_size
	keep = keep_cell
	wall_budget = -1
	walls_allowed = true
	wall_count = 0
	_tiles = PackedByteArray()
	_tiles.resize(size.x * size.y)
	_pathfinding.setup(size)
	for rock in rock_cells:
		_set_tile(rock, Tile.ROCK)
	_set_tile(keep, Tile.KEEP)
	all_gates = gate_cells.duplicate()
	set_gates(gate_cells)


func setup_from_level(level: LevelData) -> void:
	setup(level.grid_size, level.gates, level.keep, level.rocks)
	for cell in level.water:
		_set_tile(cell, Tile.WATER)
	for cell in level.ruins:
		_set_tile(cell, Tile.RUIN)
	wall_budget = level.wall_budget
	walls_allowed = level.walls_allowed
	# Alternate gates stay unbuildable all level, so shifting never lands on a structure.
	for gate in level.alt_gates:
		_set_tile(gate, Tile.GATE)
		if not gate in all_gates:
			all_gates.append(gate)


## Changes which gates spawn monsters (World 3's shifting gates). Every gate
## tile, active or not, stays a gate tile.
func set_gates(gate_cells: Array[Vector2i]) -> void:
	gates = gate_cells.duplicate()
	for gate in gates:
		_set_tile(gate, Tile.GATE)
	gates_changed.emit()


func is_active_gate(cell: Vector2i) -> bool:
	return cell in gates


func is_in_bounds(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, size).has_point(cell)


func get_tile(cell: Vector2i) -> Tile:
	return _tiles[cell.y * size.x + cell.x] as Tile


func is_structure(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var tile := get_tile(cell)
	return tile == Tile.WALL or tile == Tile.TOWER


func is_wall(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and get_tile(cell) == Tile.WALL


func is_terrain(cell: Vector2i) -> bool:
	var tile := get_tile(cell)
	return tile == Tile.ROCK or tile == Tile.WATER or tile == Tile.RUIN


func route_from(cell: Vector2i, through_walls := false) -> Array[Vector2i]:
	return _pathfinding.find_route(cell, keep, through_walls)


## One route per gate, in gate order. A blocked gate gives an empty route.
func gate_routes() -> Array:
	var routes := []
	for gate in gates:
		routes.append(route_from(gate))
	return routes


## Gate routes as they would be if `cell` were built on. Used for the ghost preview.
func gate_routes_if_built(cell: Vector2i, tile: Tile = Tile.WALL) -> Array:
	var before := get_tile(cell)
	_set_tile(cell, tile)
	var routes := gate_routes()
	_set_tile(cell, before)
	return routes


## The route a walker adopts under the current grid: it keeps its existing route
## while that is still open and no shorter one exists, otherwise takes the fresh
## shortest route from the tile it is stepping onto.
func next_route(walker: GroundWalker) -> Array[Vector2i]:
	var fresh := route_from(walker.cell_to, walker.through_walls)
	if walker.has_route() and _is_open(walker.route, walker.through_walls) and walker.route.size() <= fresh.size():
		return walker.route
	return fresh


func check_build(cell: Vector2i, walkers: Array[GroundWalker], tile: Tile = Tile.WALL) -> Check:
	if not is_in_bounds(cell):
		return Check.OUT_OF_BOUNDS
	match get_tile(cell):
		Tile.EMPTY:
			pass
		Tile.WALL, Tile.TOWER:
			return Check.OCCUPIED_BY_STRUCTURE
		_:
			return Check.NOT_BUILDABLE
	if tile == Tile.WALL:
		if not walls_allowed:
			return Check.WALLS_FORBIDDEN
		if wall_budget >= 0 and wall_count >= wall_budget:
			return Check.WALL_BUDGET
	for walker in walkers:
		if walker.occupies(cell):
			return Check.OCCUPIED_BY_ENEMY
	_set_tile(cell, tile)
	var result := _check_routes(walkers)
	_set_tile(cell, Tile.EMPTY)
	return result


func check_sell(cell: Vector2i, walkers: Array[GroundWalker]) -> Check:
	if not is_structure(cell):
		return Check.NO_STRUCTURE
	var before := get_tile(cell)
	_set_tile(cell, Tile.EMPTY)
	var result := _check_routes(walkers)
	_set_tile(cell, before)
	return result


## Applies a validated build. Callers must check_build first.
func build(cell: Vector2i, tile: Tile) -> void:
	assert(tile == Tile.WALL or tile == Tile.TOWER)
	_set_tile(cell, tile)
	if tile == Tile.WALL:
		wall_count += 1
	maze_changed.emit()


## Applies a validated sale, or a wall smashed by an enemy. Callers must check_sell first.
func clear(cell: Vector2i) -> void:
	assert(is_structure(cell))
	if get_tile(cell) == Tile.WALL:
		wall_count -= 1
	_set_tile(cell, Tile.EMPTY)
	maze_changed.emit()


func _check_routes(walkers: Array[GroundWalker]) -> Check:
	for gate in all_gates:
		if route_from(gate).is_empty():
			return Check.BLOCKS_PATH
	for walker in walkers:
		var route := next_route(walker)
		if route.is_empty():
			return Check.BLOCKS_PATH
		if route == walker.route:
			continue
		if walker.is_moving() and route.size() > 1 and route[1] == walker.cell_from:
			return Check.ENEMY_REVERSAL
		for i in range(1, route.size()):
			if walker.visits.get(route[i], 0) >= MAX_TILE_VISITS:
				return Check.ENEMY_LOOP
	return Check.OK


func _is_open(route: Array[Vector2i], through_walls: bool) -> bool:
	for cell in route:
		if through_walls:
			if is_terrain(cell) or get_tile(cell) == Tile.TOWER:
				return false
		elif _pathfinding.is_blocked(cell):
			return false
	return true


func _set_tile(cell: Vector2i, tile: Tile) -> void:
	_tiles[cell.y * size.x + cell.x] = tile
	# Towers and terrain block everyone; only walls can be smashed or phased through.
	_pathfinding.set_terrain(cell, tile == Tile.ROCK or tile == Tile.WATER or tile == Tile.RUIN or tile == Tile.TOWER)
	_pathfinding.set_wall(cell, tile == Tile.WALL)
