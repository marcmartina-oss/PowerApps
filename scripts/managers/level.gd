class_name Level
extends Node2D
## Runs one level: build and wave phases, placement, selling and upgrades,
## economy, special enemy behaviours, tutorial prompts and win/lose.
## Systems talk through signals; this node wires them together.

enum Phase { BUILD, WAVE, WON, LOST }

## Minimum game time between maze edits while a wave is running.
const EDIT_COOLDOWN := 1.0
const WALL: StringName = &"wall"
const SPEEDS: Array[int] = [1, 2, 3]
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const TOWER_SCENE := preload("res://scenes/towers/tower.tscn")

## Used when the scene is run directly (editor Play or tests); Game.current_level wins otherwise.
@export var level_data: LevelData

var grid := GridManager.new()
var economy := Economy.new()
var waves := WaveManager.new()
var phase := Phase.BUILD
var wall_cost := 5

## cell -> {kind: StringName, tower: Tower or null}
var _structures: Dictionary[Vector2i, Dictionary] = {}
var _towers_by_id: Dictionary[StringName, TowerData] = {}
var _selected := Board.NO_CELL
var _game_time := 0.0
var _last_edit_time := -INF
var _preview_refresh := 0.0
var _speed_index := 0
var _tutorial_queue: Array[TutorialStep] = []
var _tutorial_shown: Array[TutorialStep] = []
var _tutorial_active := false
var _tutorial_skipped := false
var _bonus_range := 0.0

@onready var board: Board = $Board
@onready var hud: Hud = $Hud


func _ready() -> void:
	if Game.current_level:
		level_data = Game.current_level
	for tower in level_data.available_towers:
		_towers_by_id[tower.id] = tower
	wall_cost = maxi(level_data.wall_cost - Save.wall_discount(), 1)
	_bonus_range = Save.bonus_range()
	_tutorial_skipped = Save.tutorial_done()

	grid.setup_from_level(level_data)
	board.setup(grid, level_data.world)
	waves.setup(level_data.waves, level_data.endless_pool)

	economy.gold_changed.connect(_on_gold_changed)
	economy.lives_changed.connect(hud.set_lives)
	economy.setup(level_data.starting_gold + Save.bonus_gold(), level_data.starting_lives)
	grid.maze_changed.connect(_on_maze_changed)
	grid.gates_changed.connect(_on_maze_changed)
	waves.spawn_requested.connect(_spawn_enemy)
	board.cell_tapped.connect(_on_cell_tapped)
	board.cell_painted.connect(_on_cell_painted)
	hud.start_wave_pressed.connect(start_wave)
	hud.build_pressed.connect(func(kind: StringName) -> void: _build_selected(kind))
	hud.upgrade_pressed.connect(_upgrade_selected)
	hud.sell_pressed.connect(_sell_selected)
	hud.targeting_pressed.connect(_cycle_targeting)
	hud.close_pressed.connect(_deselect)
	hud.speed_pressed.connect(_cycle_speed)
	hud.pause_pressed.connect(_toggle_pause)
	hud.retry_pressed.connect(_retry)
	hud.quit_pressed.connect(_quit)
	hud.next_pressed.connect(_next)
	hud.tutorial_dismissed.connect(_dismiss_tutorial)
	hud.tutorial_skipped.connect(_skip_tutorial)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_wave_hud()
	Audio.play_music(level_data.world)
	_apply_speed()
	_trigger_tutorial(TutorialStep.Trigger.LEVEL_START)


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
	var index := waves.current + 1
	if level_data.shifting_gates and not level_data.alt_gates.is_empty():
		grid.set_gates(level_data.alt_gates if index % 2 == 1 else level_data.gates)
	waves.start_next()
	Audio.play(&"wave")
	_refresh_wave_hud()
	_trigger_tutorial(TutorialStep.Trigger.WAVE_STARTED, index + 1)


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
	var tile := GridManager.Tile.WALL if kind == WALL else GridManager.Tile.TOWER
	var check := grid.check_build(cell, _walkers(), tile)
	if check != GridManager.Check.OK:
		if report:
			hud.toast(GridManager.CHECK_MESSAGES[check])
			Audio.play(&"invalid")
			if check == GridManager.Check.BLOCKS_PATH:
				_trigger_tutorial(TutorialStep.Trigger.INVALID_PLACEMENT)
		return false
	economy.spend(cost)
	var tower: Tower = null
	if kind != WALL:
		tower = TOWER_SCENE.instantiate()
		tower.setup(_towers_by_id[kind], cell, board.enemies, board.projectiles)
		tower.bonus_range = _bonus_range
		tower.impact_handler = _on_projectile_impact
		tower.fired.connect(_on_tower_fired)
		board.towers.add_child(tower)
	_structures[cell] = {"kind": kind, "tower": tower}
	_last_edit_time = _game_time
	grid.build(cell, tile)
	_refresh_buffs()
	Audio.play(&"build" if tower else &"wall", 0.0 if tower else -6.0)
	board.effects.puff(Board.cell_center(cell), Color(1, 1, 1, 0.6))
	_trigger_tutorial(TutorialStep.Trigger.TOWER_BUILT if tower else TutorialStep.Trigger.WALL_BUILT)
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
		Audio.play(&"invalid")
		return false
	var refund := Economy.refund_value(_structure_value(cell))
	_remove_structure(cell)
	economy.earn(refund)
	_last_edit_time = _game_time
	Audio.play(&"sell")
	board.effects.text(Board.cell_center(cell), "+%d" % refund, Palette.GOLD)
	_trigger_tutorial(TutorialStep.Trigger.STRUCTURE_SOLD)
	return true


func try_upgrade(cell: Vector2i, spec: TowerSpec = null) -> bool:
	var tower := tower_at(cell)
	if tower == null or not tower.can_upgrade():
		return false
	if tower.tier == TowerData.MAX_TIER - 1 and spec == null:
		return false
	var cost := tower.upgrade_cost()
	if not economy.can_afford(cost):
		hud.toast("Not enough gold")
		return false
	economy.spend(cost)
	tower.upgrade(spec)
	_refresh_buffs()
	Audio.play(&"upgrade")
	board.effects.ring(tower.position, Board.TILE * 0.8, Palette.GOLD)
	_trigger_tutorial(TutorialStep.Trigger.TOWER_UPGRADED)
	return true


func tower_at(cell: Vector2i) -> Tower:
	return _structures[cell].tower if _structures.has(cell) else null


func structure_count() -> int:
	return _structures.size()


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
	if not level_data.walls_allowed:
		return
	if _selected != Board.NO_CELL:
		_deselect()
	if grid.get_tile(cell) != GridManager.Tile.EMPTY:
		return
	# Each tile validates on its own; invalid ones are skipped without charge.
	if not try_build(cell, WALL, false):
		board.flash_invalid(cell)
		if not economy.can_afford(wall_cost):
			hud.toast("Not enough gold")


func _build_selected(kind: StringName) -> void:
	if try_build(_selected, kind):
		_deselect()


func _upgrade_selected(spec: TowerSpec) -> void:
	if try_upgrade(_selected, spec):
		_show_structure_panel(_selected)


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
	var walkers := _walkers()
	var check := grid.check_build(cell, walkers, GridManager.Tile.TOWER)
	var valid := check == GridManager.Check.OK
	board.show_build_preview(cell, valid, grid.gate_routes_if_built(cell) if valid else [])
	var options: Array[Dictionary] = []
	if level_data.walls_allowed:
		var wall_check := grid.check_build(cell, walkers, GridManager.Tile.WALL)
		options.append(_option(WALL, "Wall", wall_cost, wall_check == GridManager.Check.OK, Palette.WALL))
		if valid and wall_check != GridManager.Check.OK:
			check = wall_check
	for tower in level_data.available_towers:
		options.append(_option(tower.id, tower.display_name, tower.cost, valid, tower.color))
	hud.show_build_menu(options, GridManager.CHECK_MESSAGES[check] if not valid or check != GridManager.Check.OK else "")


func _option(kind: StringName, label: String, cost: int, valid: bool, color: Color) -> Dictionary:
	return {"kind": kind, "label": label, "cost": cost, "enabled": valid and economy.can_afford(cost), "color": color}


func _show_structure_panel(cell: Vector2i) -> void:
	var tower := tower_at(cell)
	var sell_value := Economy.refund_value(_structure_value(cell))
	if tower:
		board.show_selection(cell, tower.range_px() if not tower.is_support() else Board.TILE * 1.5)
		hud.show_tower_panel(tower, sell_value, economy.can_afford(tower.upgrade_cost()))
	else:
		board.show_selection(cell, 0.0)
		hud.show_wall_panel(sell_value)


# --- Game flow ---

func _spawn_enemy(data: EnemyData, gate_index: int) -> void:
	var gate := grid.gates[gate_index % grid.gates.size()]
	var enemy := _make_enemy(data, gate)
	if waves.health_scale > 1.0:
		enemy.health *= waves.health_scale
		enemy.data = enemy.data.duplicate()
		enemy.data.max_health *= waves.health_scale


func _make_enemy(data: EnemyData, cell: Vector2i) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.setup(data, grid, cell, board.enemies)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_keep.connect(_on_enemy_reached_keep)
	enemy.wall_smashed.connect(_on_wall_smashed)
	enemy.damaged.connect(_on_enemy_damaged)
	board.enemies.add_child(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy, killer: Tower) -> void:
	var reward := enemy.data.gold_reward
	if killer and killer.buff_bounty > 0.0:
		reward = ceili(reward * (1.0 + killer.buff_bounty))
		board.effects.text(enemy.position, "+%d" % reward, Palette.GOLD)
	economy.earn(reward)
	board.effects.puff(enemy.position, enemy.data.color, enemy.data.is_boss)
	Audio.play(&"death_boss" if enemy.data.is_boss else &"death", 0.0 if enemy.data.is_boss else -8.0)
	if enemy.data.split_into:
		var cell := enemy.current_cell()
		for i in enemy.data.split_count:
			var child := _make_enemy(enemy.data.split_into, cell)
			child.position += Vector2(i * 10 - 5, 0)


func _on_enemy_damaged(enemy: Enemy, _amount: float) -> void:
	if randf() < 0.3:
		board.effects.spark(enemy.position, Color(1, 1, 0.8))


func _on_enemy_reached_keep(enemy: Enemy) -> void:
	economy.lose_lives(enemy.data.lives_cost)
	Audio.play(&"leak")
	board.effects.ring(Board.cell_center(grid.keep), Board.TILE, Palette.LIVES)
	if economy.is_defeated() and phase == Phase.WAVE:
		_end(Phase.LOST)


func _on_wall_smashed(cell: Vector2i) -> void:
	if not grid.is_wall(cell):
		return
	_remove_structure(cell)
	Audio.play(&"smash")
	board.effects.puff(Board.cell_center(cell), Palette.WALL, true)


func _on_tower_fired(tower: Tower) -> void:
	var sound: StringName = &"shoot_archer"
	match tower.data.look:
		TowerData.Look.STONE: sound = &"shoot_stone"
		TowerData.Look.FROST: sound = &"shoot_frost"
		TowerData.Look.FLAME: sound = &"shoot_flame"
		TowerData.Look.ARCANE: sound = &"shoot_arcane"
	Audio.play(sound, -10.0)


func _on_projectile_impact(at: Vector2, splash_px: float, color: Color) -> void:
	if splash_px > 0.0:
		board.effects.ring(at, splash_px, color)
		Audio.play(&"splash", -8.0)
	else:
		board.effects.spark(at, color)


func _finish_wave() -> void:
	economy.earn(waves.clear_bonus())
	if level_data.is_endless():
		Save.record_endless(level_data.id, waves.current + 1)
	if waves.has_next():
		phase = Phase.BUILD
		hud.toast("Wave cleared! +%d gold" % waves.clear_bonus())
		Audio.play(&"gold")
		_refresh_wave_hud()
		_trigger_tutorial(TutorialStep.Trigger.WAVE_CLEARED, waves.current + 1)
	else:
		_end(Phase.WON)


func _end(result: Phase) -> void:
	phase = result
	_deselect()
	hud.hide_tutorial()
	hud.set_start_wave(false)
	Engine.time_scale = 1.0
	var won := result == Phase.WON
	Audio.play(&"win" if won else &"lose")
	var stars := economy.stars() if won else 0
	var detail := ""
	var next_label := ""
	if level_data.is_endless():
		detail = "Survived %d waves · Best %d" % [waves.current, Save.endless_best(level_data.id)]
	elif won:
		Save.record_result(level_data.id, stars)
		if level_data.mode == LevelData.Mode.CAMPAIGN and level_data.number >= 3 and not level_data.tutorial.is_empty():
			Save.set_tutorial_done(true)
		for tower in level_data.unlocks_towers:
			detail += "New tower unlocked: %s\n" % tower.display_name
		if Game.should_prompt_unlock(level_data):
			next_label = "Continue"
		elif Game.next_level(level_data):
			next_label = "Next level"
	hud.show_result(won, stars, detail.strip_edges(), next_label)


func _on_maze_changed() -> void:
	for walker in _walkers():
		walker.route = grid.next_route(walker)
	board.set_routes(grid.gate_routes())


func _on_gold_changed(gold: int) -> void:
	hud.set_gold(gold)
	if _selected != Board.NO_CELL:
		if grid.is_structure(_selected):
			_show_structure_panel(_selected)
		else:
			_show_build_menu(_selected)


func _refresh_wave_hud() -> void:
	var total := 0 if level_data.is_endless() else waves.total()
	var shown := waves.current + 1 if phase == Phase.WAVE else waves.current + 2
	hud.set_wave(mini(shown, total) if total > 0 else shown, total)
	var upcoming := waves.current + 1
	hud.set_next_wave(waves.describe(upcoming))
	hud.set_start_wave(phase == Phase.BUILD, "Start Wave %d" % (upcoming + 1))


## Adjacent War Banners speed up (Rally) or enrich (Bounty) their neighbours.
func _refresh_buffs() -> void:
	for cell in _structures:
		var tower: Tower = _structures[cell].tower
		if tower == null or tower.is_support():
			continue
		var speed := 1.0
		var bounty := 0.0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var banner := tower_at(cell + Vector2i(dx, dy))
				if banner == null or not banner.is_support():
					continue
				if banner.has_spec(TowerSpec.Kind.BOUNTY):
					bounty += banner.spec.value
					speed += banner.data.effect_strength * 2
				elif banner.has_spec(TowerSpec.Kind.RALLY):
					speed += banner.spec.value
				else:
					speed += banner.data.effect_strength * banner.tier
		tower.set_buffs(speed, bounty)


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_apply_speed()


func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index] * level_data.speed_multiplier
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


func _quit() -> void:
	Game.go("modes" if level_data.mode != LevelData.Mode.CAMPAIGN else "worlds")


func _next() -> void:
	if Game.should_prompt_unlock(level_data):
		Game.return_to = "worlds"
		Game.go("unlock")
		return
	var next := Game.next_level(level_data)
	if next and Game.can_play(next):
		Game.play(next)
	else:
		Game.go("worlds")


# --- Tutorial ---

func _trigger_tutorial(trigger: TutorialStep.Trigger, wave := 0) -> void:
	if _tutorial_skipped:
		return
	for step in level_data.tutorial:
		if step.trigger == trigger and (step.wave == 0 or step.wave == wave) and not step in _tutorial_shown:
			_tutorial_shown.append(step)
			_tutorial_queue.append(step)
	_show_next_tutorial()


func _show_next_tutorial() -> void:
	if _tutorial_active or _tutorial_queue.is_empty():
		return
	var step: TutorialStep = _tutorial_queue.pop_front()
	_tutorial_active = true
	hud.show_tutorial(step.text)
	board.set_highlight(step.highlight)


func _dismiss_tutorial() -> void:
	_tutorial_active = false
	hud.hide_tutorial()
	board.set_highlight(Board.NO_CELL)
	_show_next_tutorial()


func _skip_tutorial() -> void:
	_tutorial_skipped = true
	_tutorial_queue.clear()
	Save.set_tutorial_done(true)
	_dismiss_tutorial()


# --- Helpers ---

func _cost_of(kind: StringName) -> int:
	return wall_cost if kind == WALL else _towers_by_id[kind].cost


func _structure_value(cell: Vector2i) -> int:
	var tower := tower_at(cell)
	return tower.total_cost() if tower else wall_cost


func _remove_structure(cell: Vector2i) -> void:
	var record: Dictionary = _structures[cell]
	_structures.erase(cell)
	if record.tower:
		record.tower.queue_free()
	grid.clear(cell)
	_refresh_buffs()


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
	var safe := UI.safe_area(self)
	hud.layout(safe)
	var area := Rect2(safe.position.x + 10.0, safe.position.y + Hud.TOP_HEIGHT,
		safe.size.x - 20.0, safe.size.y - Hud.TOP_HEIGHT - Hud.BOTTOM_HEIGHT)
	var board_size := board.pixel_size()
	var s := minf(area.size.x / board_size.x, area.size.y / board_size.y)
	board.scale = Vector2(s, s)
	board.position = area.position + (area.size - board_size * s) / 2.0
