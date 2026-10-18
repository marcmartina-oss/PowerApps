class_name Board
extends Node2D
## Draws the grid, walls and route previews, and turns pointer input into cell
## taps and wall-paint strokes. Children (towers, enemies, projectiles) live in
## board units: one tile is TILE units; the level scales the board to fit.

signal cell_tapped(cell: Vector2i)
signal cell_painted(cell: Vector2i)

const TILE := 64.0
const NO_CELL := Vector2i(-1, -1)

const GRASS_A := Color(0.33, 0.52, 0.29)
const GRASS_B := Color(0.30, 0.48, 0.27)
const ROCK := Color(0.45, 0.45, 0.47)
const WALL := Color(0.55, 0.40, 0.25)
const GATE := Color(0.50, 0.20, 0.55)
const KEEP := Color(0.25, 0.45, 0.80)
const ROUTE := Color(1, 1, 1, 0.35)
const PREVIEW_ROUTE := Color(1.0, 0.85, 0.2, 0.9)
const VALID := Color(0.3, 1.0, 0.4, 0.45)
const INVALID := Color(1.0, 0.2, 0.2, 0.55)

var grid: GridManager
var routes: Array = []

var _preview_cell := NO_CELL
var _preview_valid := true
var _preview_routes: Array = []
var _selected := NO_CELL
var _range_px := 0.0
var _flashes: Dictionary[Vector2i, float] = {}

var _pressed := false
var _painting := false
var _press_cell := NO_CELL
var _last_cell := NO_CELL

@onready var towers: Node2D = $Towers
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func setup(grid_manager: GridManager) -> void:
	grid = grid_manager
	routes = grid.gate_routes()
	queue_redraw()


func pixel_size() -> Vector2:
	return Vector2(grid.size) * TILE


func set_routes(new_routes: Array) -> void:
	routes = new_routes
	queue_redraw()


func show_build_preview(cell: Vector2i, valid: bool, preview_routes: Array) -> void:
	_selected = NO_CELL
	_preview_cell = cell
	_preview_valid = valid
	_preview_routes = preview_routes
	queue_redraw()


func show_selection(cell: Vector2i, range_px: float) -> void:
	_preview_cell = NO_CELL
	_preview_routes = []
	_selected = cell
	_range_px = range_px
	queue_redraw()


func clear_selection() -> void:
	_preview_cell = NO_CELL
	_preview_routes = []
	_selected = NO_CELL
	queue_redraw()


## Briefly tints a tile red, e.g. a skipped tile in a wall-paint stroke.
func flash_invalid(cell: Vector2i) -> void:
	_flashes[cell] = 0.35
	queue_redraw()


func cell_at(viewport_pos: Vector2) -> Vector2i:
	var local := get_global_transform_with_canvas().affine_inverse() * viewport_pos
	return Vector2i((local / TILE).floor())


func _process(delta: float) -> void:
	if _flashes.is_empty():
		return
	for cell in _flashes.keys():
		_flashes[cell] -= delta
		if _flashes[cell] <= 0.0:
			_flashes.erase(cell)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Touches arrive as emulated mouse events, so taps on HUD buttons are consumed
	# by the GUI and never reach the board.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_at(event.position)
		if event.pressed:
			if not grid.is_in_bounds(cell):
				return
			_pressed = true
			_painting = false
			_press_cell = cell
			_last_cell = cell
			get_viewport().set_input_as_handled()
		elif _pressed:
			_pressed = false
			if not _painting:
				cell_tapped.emit(_press_cell)
			_painting = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressed:
		var cell := cell_at(event.position)
		if cell == _last_cell or not grid.is_in_bounds(cell):
			return
		if not _painting:
			_painting = true
			cell_painted.emit(_press_cell)
		# Walk tile by tile so fast swipes don't leave gaps.
		while _last_cell != cell:
			var d := cell - _last_cell
			if absi(d.x) >= absi(d.y):
				_last_cell.x += signi(d.x)
			else:
				_last_cell.y += signi(d.y)
			cell_painted.emit(_last_cell)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if grid == null:
		return
	var font := ThemeDB.fallback_font
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			draw_rect(rect, GRASS_A if (x + y) % 2 == 0 else GRASS_B)
			match grid.get_tile(cell):
				GridManager.Tile.ROCK:
					draw_rect(rect.grow(-4.0), ROCK)
					draw_rect(rect.grow(-14.0), ROCK.darkened(0.2))
				GridManager.Tile.WALL:
					draw_rect(rect.grow(-3.0), WALL)
					draw_rect(rect.grow(-3.0), WALL.darkened(0.4), false, 3.0)
				GridManager.Tile.GATE:
					draw_rect(rect.grow(-2.0), GATE)
					draw_string(font, rect.position + Vector2(0, TILE * 0.62), "GATE", HORIZONTAL_ALIGNMENT_CENTER, TILE, 15)
				GridManager.Tile.KEEP:
					draw_rect(rect.grow(-2.0), KEEP)
					draw_string(font, rect.position + Vector2(0, TILE * 0.62), "KEEP", HORIZONTAL_ALIGNMENT_CENTER, TILE, 15)
	for cell in _flashes:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), INVALID)
	for route: Array[Vector2i] in routes:
		_draw_route(route, ROUTE, 8.0)
	if _preview_cell != NO_CELL:
		for route: Array[Vector2i] in _preview_routes:
			_draw_route(route, PREVIEW_ROUTE, 4.0)
		draw_rect(Rect2(Vector2(_preview_cell) * TILE, Vector2(TILE, TILE)), VALID if _preview_valid else INVALID)
	if _selected != NO_CELL:
		draw_rect(Rect2(Vector2(_selected) * TILE, Vector2(TILE, TILE)), Color(1, 1, 0.4), false, 4.0)
		if _range_px > 0.0:
			draw_circle(cell_center(_selected), _range_px, Color(1, 1, 1, 0.08))
			draw_arc(cell_center(_selected), _range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)


func _draw_route(route: Array[Vector2i], color: Color, width: float) -> void:
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in route:
		points.append(cell_center(cell))
	draw_polyline(points, color, width, true)
