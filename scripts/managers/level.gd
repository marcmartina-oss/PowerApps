class_name Level
extends Node2D
## Runs one level: build and wave phases, placement and selling, economy, and
## win/lose. Systems talk through signals; this node wires them together.

enum Phase { BUILD, WAVE, WON, LOST }

## Minimum game time between maze edits while a wave is running.
const EDIT_COOLDOWN := 1.0
const WALL: StringName = &"wall"
const SPEEDS: Array[int] = [1, 2, 3]
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const TOWER_SCENE := preload("res://scenes/towers/tower.tscn")

@export var level_data: LevelData

var grid := GridManager.new()
var economy := Economy.new()
var waves := WaveManager.new()
var phase := Phase.BUILD

## cell -> {kind: StringName, cost: int, tower: Tower or null}
var _structures: Dictionary[Vector2i, Dictionary] = {}
var _towers_by_id: Dictionary[StringName, TowerData] = {}
var _selected := Board.NO_CELL
var _game_time := 0.0
var _last_edit_time := -INF
var _preview_refresh := 0.0
var _speed_index := 0

@onready var board: Board = $Board
@onready var hud: Hud = $Hud


func _ready() -> void:
	for tower in level_data.available_towers:
		_towers_by_id[tower.id] = tower
	grid.setup_from_level(level_data)
	board.setup(grid)
	waves.setup(level_data.waves)

	economy.gold_changed.connect(_on_gold_changed)
	economy.lives_changed.connect(hud.set_lives)
	economy.setup(level_data.starting_gold, level_data.starting_lives)
	grid.maze_changed.connect(_on_maze_changed)
	waves.spawn_requested.connect(_spawn_enemy)
	board.cell_tapped.connect(_on_cell_tapped)
	board.cell_painted.connect(_on_cell_painted)
	hud.start_wave_pressed.connect(start_wave)
	hud.build_pressed.connect(func(kind: StringName) -> void: _build_selected(kind))
	hud.sell_pressed.connect(_sell_selected)
	hud.targeting_pressed.connect(_cycle_targeting)
	hud.close_pressed.connect(_deselect)
	hud.speed_pressed.connect(_cycle_speed)
	hud.pause_pressed.connect(_toggle_pause)
	hud.retry_pressed.connect(_retry)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_wave_hud()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_game_time += delta
	if phase != Phase.WAVE:
		return
	waves.tick(delta)
	if not waves.is_spawning() and _alive_enemies().is_empty():
		_finish_wave()
		return
	# Enemies move, so a pending build's validity can change under the player's finger.
	_preview_refresh -= delta
	if _preview_refresh <= 0.0 and _selected != Board.NO_CELL and not grid.is_structure(_selected):
		_preview_refresh = 0.2
		_show_build_menu(_selected)


# --- Public actions (also used by tests and bots) ---

func start_wave() -> void:
	if phase != Phase.BUILD or not waves.has_next():
		return
	phase = Phase.WAVE
	_last_edit_time = -INF
	waves.start_next()
	_refresh_wave_hud()


## Builds `kind` (WALL or a tower id) at `cell`. Returns true on success.
func try_build(cell: Vector2i, kind: StringName, report := true) -> bool:
	if phase != Phase.BUILD and phase != Phase.WAVE:
		return false
	var cost := _cost_of(kind)
	if not _cooldown_ready():
		if report:
			hud.toast("Wait a moment between changes during a wave")
		return false
	if not economy.can_afford(cost):
		if report:
			hud.toast("Not enough gold")
		return false
	var check := grid.check_build(cell, _walkers())
	if check != GridManager.Check.OK:
		if report:
			hud.toast(GridManager.CHECK_MESSAGES[check])
		return false
	economy.spend(cost)
	var tower: Tower = null
	if kind != WALL:
		tower = TOWER_SCENE.instantiate()
		tower.setup(_towers_by_id[kind], cell, board.enemies, board.projectiles)
		board.towers.add_child(tower)
	_structures[cell] = {"kind": kind, "cost": cost, "tower": tower}
	_last_edit_time = _game_time
	grid.build(cell, GridManager.Tile.WALL if kind == WALL else GridManager.Tile.TOWER)
	return true


func try_sell(cell: Vector2i) -> bool:
	if not _structures.has(cell):
		return false
	if not _cooldown_ready():
		hud.toast("Wait a moment between changes during a wave")
		return false
	var check := grid.check_sell(cell, _walkers())
	if check != GridManager.Check.OK:
		hud.toast(GridManager.CHECK_MESSAGES[check])
		return false
	var record: Dictionary = _structures[cell]
	_structures.erase(cell)
	if record.tower:
		record.tower.queue_free()
	economy.earn(Economy.refund_value(record.cost))
	_last_edit_time = _game_time
	grid.clear(cell)
	return true


func tower_at(cell: Vector2i) -> Tower:
	return _structures[cell].tower if _structures.has(cell) else null


# --- Input ---

func _on_cell_tapped(cell: Vector2i) -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	if cell == _selected:
		_deselect()
		return
	if grid.is_structure(cell):
		_selected = cell
		_show_structure_panel(cell)
	elif grid.get_tile(cell) == GridManager.Tile.EMPTY:
		_selected = cell
		_show_build_menu(cell)
	else:
		_deselect()


func _on_cell_painted(cell: Vector2i) -> void:
	if _selected != Board.NO_CELL:
		_deselect()
	if grid.get_tile(cell) != GridManager.Tile.EMPTY:
		return
	# Each tile validates on its own; invalid ones are skipped without charge.
	if not try_build(cell, WALL, false):
		board.flash_invalid(cell)
		if not economy.can_afford(level_data.wall_cost):
			hud.toast("Not enough gold")


func _build_selected(kind: StringName) -> void:
	if try_build(_selected, kind):
		_deselect()


func _sell_selected() -> void:
	if try_sell(_selected):
		_deselect()


func _cycle_targeting() -> void:
	var tower := tower_at(_selected)
	if tower:
		tower.cycle_targeting()
		_show_structure_panel(_selected)


func _deselect() -> void:
	_selected = Board.NO_CELL
	board.clear_selection()
	hud.hide_panel()


func _show_build_menu(cell: Vector2i) -> void:
	var check := grid.check_build(cell, _walkers())
	var valid := check == GridManager.Check.OK
	board.show_build_preview(cell, valid, grid.gate_routes_if_built(cell) if valid else [])
	var options: Array[Dictionary] = [_option(WALL, "Wall", level_data.wall_cost, valid)]
	for tower in level_data.available_towers:
		options.append(_option(tower.id, tower.display_name, tower.cost, valid))
	hud.show_build_menu(options, GridManager.CHECK_MESSAGES[check])


func _option(kind: StringName, label: String, cost: int, valid: bool) -> Dictionary:
	return {"kind": kind, "label": label, "cost": cost, "enabled": valid and economy.can_afford(cost)}


func _show_structure_panel(cell: Vector2i) -> void:
	var record: Dictionary = _structures[cell]
	var tower: Tower = record.tower
	var sell_label := "Sell +%dg" % Economy.refund_value(record.cost)
	if tower:
		board.show_selection(cell, tower.range_px())
		hud.show_structure_panel(tower.data.display_name, sell_label, tower.targeting_name())
	else:
		board.show_selection(cell, 0.0)
		hud.show_structure_panel("Wall", sell_label, "")


# --- Game flow ---

func _spawn_enemy(data: EnemyData, gate_index: int) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, grid, grid.gates[gate_index % grid.gates.size()])
	enemy.died.connect(_on_enemy_died)
	enemy.reached_keep.connect(_on_enemy_reached_keep)
	board.enemies.add_child(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	economy.earn(enemy.data.gold_reward)


func _on_enemy_reached_keep(enemy: Enemy) -> void:
	economy.lose_lives(enemy.data.lives_cost)
	if economy.is_defeated() and phase == Phase.WAVE:
		_end(Phase.LOST)


func _finish_wave() -> void:
	economy.earn(waves.clear_bonus())
	if waves.has_next():
		phase = Phase.BUILD
		hud.toast("Wave cleared! +%d gold" % waves.clear_bonus())
		_refresh_wave_hud()
	else:
		_end(Phase.WON)


func _end(result: Phase) -> void:
	phase = result
	_deselect()
	hud.set_start_wave(false)
	hud.show_result(result == Phase.WON, economy.stars())


func _on_maze_changed() -> void:
	for walker in _walkers():
		walker.route = grid.next_route(walker)
	board.set_routes(grid.gate_routes())


func _on_gold_changed(gold: int) -> void:
	hud.set_gold(gold)
	if _selected != Board.NO_CELL and not grid.is_structure(_selected):
		_show_build_menu(_selected)


func _refresh_wave_hud() -> void:
	var shown := waves.current + 1 if phase == Phase.WAVE else waves.current + 2
	hud.set_wave(mini(shown, waves.waves.size()), waves.waves.size())
	var upcoming := waves.current + 1
	hud.set_next_wave(waves.describe(upcoming))
	hud.set_start_wave(phase == Phase.BUILD, "Start Wave %d" % (upcoming + 1))


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	Engine.time_scale = SPEEDS[_speed_index]
	hud.set_speed(SPEEDS[_speed_index])


func _toggle_pause() -> void:
	if phase == Phase.WON or phase == Phase.LOST:
		return
	get_tree().paused = not get_tree().paused
	hud.show_pause(get_tree().paused)


func _retry() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


# --- Helpers ---

func _cost_of(kind: StringName) -> int:
	return level_data.wall_cost if kind == WALL else _towers_by_id[kind].cost


func _cooldown_ready() -> bool:
	return phase != Phase.WAVE or _game_time - _last_edit_time >= EDIT_COOLDOWN


func _alive_enemies() -> Array[Enemy]:
	var alive: Array[Enemy] = []
	for node in board.enemies.get_children():
		var enemy := node as Enemy
		if enemy and enemy.is_alive():
			alive.append(enemy)
	return alive


func _walkers() -> Array[GroundWalker]:
	var walkers: Array[GroundWalker] = []
	for enemy in _alive_enemies():
		if enemy.is_ground():
			walkers.append(enemy.walker)
	return walkers


## Fits the board between the HUD's top bar and bottom area, inside the safe area.
func _layout() -> void:
	var view := get_viewport_rect().size
	var safe := Rect2(Vector2.ZERO, view)
	if OS.has_feature("mobile"):
		var window := Vector2(DisplayServer.window_get_size())
		var screen_safe := Rect2(DisplayServer.get_display_safe_area())
		if window.x > 0.0 and screen_safe.size.x > 0.0:
			var k := view / window
			safe = Rect2(screen_safe.position * k, screen_safe.size * k)
	hud.layout(safe)
	var area := Rect2(safe.position.x + 12.0, safe.position.y + Hud.TOP_HEIGHT,
		safe.size.x - 24.0, safe.size.y - Hud.TOP_HEIGHT - Hud.BOTTOM_HEIGHT)
	var board_size := board.pixel_size()
	var s := minf(area.size.x / board_size.x, area.size.y / board_size.y)
	board.scale = Vector2(s, s)
	board.position = area.position + (area.size - board_size * s) / 2.0
