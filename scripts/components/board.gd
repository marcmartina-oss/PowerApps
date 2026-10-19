class_name Board
extends Node2D
## Draws the map and turns pointer input into cell taps and wall-paint strokes.
## The ground is painted once into a texture; structures redraw on change; the
## Overlay child redraws every frame for routes, previews and flashes. Children
## (towers, enemies, projectiles) live in board units: one tile is TILE units;
## the level scales the board to fit.

signal cell_tapped(cell: Vector2i)
signal cell_painted(cell: Vector2i)

const TILE := 64.0
const NO_CELL := Vector2i(-1, -1)

var grid: GridManager
var world := 1
var routes: Array = []

var _ground: ImageTexture
var _preview_cell := NO_CELL
var _preview_valid := true
var _preview_routes: Array = []
var _selected := NO_CELL
var _range_px := 0.0
var _highlight := NO_CELL
var _flashes: Dictionary[Vector2i, float] = {}
var _time := 0.0

var _pressed := false
var _painting := false
var _press_cell := NO_CELL
var _last_cell := NO_CELL

@onready var towers: Node2D = $Towers
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var effects: Effects = $Effects
@onready var overlay: Node2D = $Overlay


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func setup(grid_manager: GridManager, world_index: int) -> void:
	grid = grid_manager
	world = world_index
	routes = grid.gate_routes()
	_paint_ground()
	grid.maze_changed.connect(queue_redraw)
	grid.gates_changed.connect(queue_redraw)
	overlay.draw.connect(_draw_overlay)
	queue_redraw()


func pixel_size() -> Vector2:
	return Vector2(grid.size) * TILE


func set_routes(new_routes: Array) -> void:
	routes = new_routes


func show_build_preview(cell: Vector2i, valid: bool, preview_routes: Array) -> void:
	_selected = NO_CELL
	_preview_cell = cell
	_preview_valid = valid
	_preview_routes = preview_routes


func show_selection(cell: Vector2i, range_px: float) -> void:
	_preview_cell = NO_CELL
	_preview_routes = []
	_selected = cell
	_range_px = range_px


func clear_selection() -> void:
	_preview_cell = NO_CELL
	_preview_routes = []
	_selected = NO_CELL


## Tutorial highlight ring on a tile; NO_CELL to clear.
func set_highlight(cell: Vector2i) -> void:
	_highlight = cell


## Briefly tints a tile red, e.g. a skipped tile in a wall-paint stroke.
func flash_invalid(cell: Vector2i) -> void:
	_flashes[cell] = 0.35


func cell_at(viewport_pos: Vector2) -> Vector2i:
	var local := get_global_transform_with_canvas().affine_inverse() * viewport_pos
	return Vector2i((local / TILE).floor())


func _process(delta: float) -> void:
	_time += delta
	for cell in _flashes.keys():
		_flashes[cell] -= delta
		if _flashes[cell] <= 0.0:
			_flashes.erase(cell)
	overlay.queue_redraw()


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


## Ground texture: two-tone tiles with speckles and grass tufts, one pixel per
## board unit so it stays crisp when the board is scaled down on a phone.
func _paint_ground() -> void:
	var pal := Palette.world(world)
	var size := Vector2i(pixel_size())
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = world * 1000 + grid.size.x
	for y in grid.size.y:
		for x in grid.size.x:
			var base: Color = pal[0] if (x + y) % 2 == 0 else pal[1]
			img.fill_rect(Rect2i(x * int(TILE), y * int(TILE), int(TILE), int(TILE)), base)
			for i in 14:
				var px := Vector2i(x * int(TILE) + rng.randi_range(2, int(TILE) - 3), y * int(TILE) + rng.randi_range(2, int(TILE) - 3))
				var detail: Color = pal[2] if rng.randf() < 0.7 else base.darkened(0.12)
				img.set_pixelv(px, detail)
				if rng.randf() < 0.35:
					img.set_pixelv(px + Vector2i(0, -1), detail)
					img.set_pixelv(px + Vector2i(1, -2), detail.lightened(0.1))
	_ground = ImageTexture.create_from_image(img)


func _draw() -> void:
	if grid == null:
		return
	var pal := Palette.world(world)
	draw_texture(_ground, Vector2.ZERO)
	var font := ThemeDB.fallback_font
	for y in grid.size.y:
		for x in grid.size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			match grid.get_tile(cell):
				GridManager.Tile.ROCK:
					_draw_rock(rect, pal[4])
				GridManager.Tile.WATER:
					draw_rect(rect, pal[3])
					draw_rect(rect.grow(-6.0), pal[3].lightened(0.12))
					draw_line(rect.position + Vector2(10, 22), rect.position + Vector2(30, 22), Color(1, 1, 1, 0.3), 2.0)
					draw_line(rect.position + Vector2(28, 44), rect.position + Vector2(52, 44), Color(1, 1, 1, 0.3), 2.0)
				GridManager.Tile.RUIN:
					draw_rect(rect.grow(-4.0), pal[4].darkened(0.15))
					draw_rect(Rect2(rect.position + Vector2(8, 8), Vector2(20, 24)), pal[4].lightened(0.15))
					draw_rect(Rect2(rect.position + Vector2(34, 20), Vector2(22, 32)), pal[4].lightened(0.08))
					draw_rect(Rect2(rect.position + Vector2(12, 40), Vector2(14, 14)), pal[4].darkened(0.35))
				GridManager.Tile.WALL:
					_draw_wall(rect)
				GridManager.Tile.GATE:
					var active := grid.is_active_gate(cell)
					var gate_c := Palette.GATE if active else Palette.GATE.darkened(0.5)
					draw_rect(rect.grow(-1.0), gate_c.darkened(0.4))
					draw_rect(rect.grow(-8.0), gate_c)
					draw_circle(rect.get_center(), TILE * 0.26, Color(0.1, 0.0, 0.15))
					if active:
						draw_arc(rect.get_center(), TILE * 0.26, 0.0, TAU, 20, Palette.GATE.lightened(0.4), 2.0)
				GridManager.Tile.KEEP:
					draw_rect(rect.grow(-1.0), Palette.KEEP.darkened(0.45))
					draw_rect(rect.grow(-6.0), Palette.KEEP)
					for i in 4:
						draw_rect(Rect2(rect.position + Vector2(4 + i * 15, 2), Vector2(9, 10)), Palette.KEEP.darkened(0.45))
					draw_rect(Rect2(rect.get_center() + Vector2(-8, 4), Vector2(16, 24)), Palette.KEEP.darkened(0.6))
					draw_colored_polygon(PackedVector2Array([rect.get_center() + Vector2(0, -22), rect.get_center() + Vector2(0, -8), rect.get_center() + Vector2(14, -15)]), Palette.GOLD)
	if grid.wall_budget >= 0:
		draw_string(font, Vector2(6, pixel_size().y - 6), "Walls %d/%d" % [grid.wall_count, grid.wall_budget], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))


func _draw_rock(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 18), c + Vector2(-20, -10), c + Vector2(-4, -24), c + Vector2(18, -18), c + Vector2(26, 6), c + Vector2(14, 22)]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 12), c + Vector2(-14, -8), c + Vector2(-2, -18), c + Vector2(12, -12), c + Vector2(18, 4), c + Vector2(8, 16)]), color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -4), c + Vector2(-2, -14), c + Vector2(8, -8)]), color.lightened(0.25))


func _draw_wall(rect: Rect2) -> void:
	draw_rect(rect.grow(-2.0), Palette.WALL_DARK)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(TILE - 4, TILE - 10)), Palette.WALL)
	var mortar := Palette.WALL_DARK
	for row in 3:
		var y := rect.position.y + 2 + (row + 1) * (TILE - 10) / 4.0
		draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), mortar, 2.0)
		var offset := (TILE - 4) / 4.0 if row % 2 == 0 else 0.0
		for col in 3:
			var x := rect.position.x + 2 + offset + col * (TILE - 4) / 2.0
			if x < rect.end.x - 3:
				draw_line(Vector2(x, y - (TILE - 10) / 4.0), Vector2(x, y), mortar, 2.0)
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(TILE - 4, 4)), Palette.WALL.lightened(0.2))


func _draw_overlay() -> void:
	if grid == null:
		return
	var o := overlay
	for cell in _flashes:
		o.draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), Palette.INVALID)
	for route: Array[Vector2i] in routes:
		_draw_route(route, Palette.ROUTE, 8.0, false)
	if _preview_cell != NO_CELL:
		for route: Array[Vector2i] in _preview_routes:
			_draw_route(route, Palette.PREVIEW_ROUTE, 5.0, true)
		o.draw_rect(Rect2(Vector2(_preview_cell) * TILE, Vector2(TILE, TILE)), Palette.VALID if _preview_valid else Palette.INVALID)
	if _selected != NO_CELL:
		o.draw_rect(Rect2(Vector2(_selected) * TILE, Vector2(TILE, TILE)).grow(-2.0), Color(1, 1, 0.4), false, 4.0)
		if _range_px > 0.0:
			o.draw_circle(cell_center(_selected), _range_px, Color(1, 1, 1, 0.08))
			o.draw_arc(cell_center(_selected), _range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)
	if _highlight != NO_CELL:
		var pulse := 4.0 + sin(_time * 5.0) * 3.0
		o.draw_rect(Rect2(Vector2(_highlight) * TILE, Vector2(TILE, TILE)).grow(pulse), Palette.GOLD, false, 4.0)


func _draw_route(route: Array[Vector2i], color: Color, width: float, animated: bool) -> void:
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in route:
		points.append(cell_center(cell))
	overlay.draw_polyline(points, color, width, true)
	if animated:
		# Marching dots show direction of travel.
		var total := 0.0
		for i in range(1, points.size()):
			total += points[i - 1].distance_to(points[i])
		var spacing := TILE * 0.5
		var offset := fmod(_time * TILE, spacing)
		var d := offset
		while d < total:
			var p := _point_along(points, d)
			overlay.draw_circle(p, 4.0, Color.WHITE)
			d += spacing


func _point_along(points: PackedVector2Array, distance: float) -> Vector2:
	for i in range(1, points.size()):
		var seg := points[i - 1].distance_to(points[i])
		if distance <= seg:
			return points[i - 1].lerp(points[i], distance / seg)
		distance -= seg
	return points[points.size() - 1]
