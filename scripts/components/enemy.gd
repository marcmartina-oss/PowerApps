class_name Enemy
extends Node2D
## Base enemy: health, armor, status effects and movement. Ground enemies walk
## the maze through a GroundWalker; flyers head straight for the keep.
## Special behaviours (wall smashing, phasing, healing, splitting) are driven by
## EnemyData flags so new monsters need no new code.

signal died(enemy: Enemy, killer: Tower)
signal reached_keep(enemy: Enemy)
signal wall_smashed(cell: Vector2i)
signal damaged(enemy: Enemy, amount: float)

## Burn damage multiplier while also slowed (Frost + Flame synergy).
const THERMAL_SHOCK := 2.0
## Seconds between burn spreading to neighbours (Wildfire).
const SPREAD_INTERVAL := 1.0

var data: EnemyData
var health := 0.0
## Null for flyers.
var walker: GroundWalker
var grid: GridManager

var slow_factor := 1.0
var slow_time := 0.0
var burn_dps := 0.0
var burn_time := 0.0
var burn_spreads := false
var stun_time := 0.0

var _keep: Vector2i
## Position in tile coordinates; tile centres are whole numbers.
var _tile_pos := Vector2.ZERO
var _done := false
var _smash_progress := 0.0
var _phase_cooldown := 0.0
var _heal_cooldown := 0.0
var _spread_cooldown := 0.0
var _enemies: Node
var _hit_flash := 0.0
var _facing := Vector2.DOWN
var _wobble := 0.0


func setup(enemy_data: EnemyData, grid_manager: GridManager, start_cell: Vector2i, enemies: Node) -> void:
	data = enemy_data
	health = data.max_health
	grid = grid_manager
	_keep = grid.keep
	_enemies = enemies
	_tile_pos = Vector2(start_cell)
	_heal_cooldown = data.heal_interval
	_phase_cooldown = data.phase_interval
	if data.is_ground():
		walker = GroundWalker.new(start_cell, grid.route_from(start_cell, data.ignores_walls()), data.ignores_walls())
		if data.ignores_walls():
			walker.blocker = grid.is_wall
	_sync_position()


func is_alive() -> bool:
	return not _done


func is_ground() -> bool:
	return walker != null


func is_slowed() -> bool:
	return slow_time > 0.0


func is_burning() -> bool:
	return burn_time > 0.0


func remaining_distance() -> float:
	if walker:
		return walker.remaining_distance()
	return _tile_pos.distance_to(Vector2(_keep))


## Tile position of the enemy's current (or nearest) cell.
func current_cell() -> Vector2i:
	return walker.cell_to if walker else Vector2i(_tile_pos.round())


func take_damage(amount: float, damage_type: TowerData.DamageType, killer: Tower = null) -> void:
	if _done:
		return
	match damage_type:
		TowerData.DamageType.PHYSICAL:
			amount *= 1.0 - data.armor
		TowerData.DamageType.MAGIC:
			amount *= 1.0 - data.armor * 0.5
	health -= amount
	_hit_flash = 0.12
	damaged.emit(self, amount)
	queue_redraw()
	if health <= 0.0:
		_done = true
		died.emit(self, killer)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor) if is_slowed() else factor
	slow_time = maxf(slow_time, duration)
	queue_redraw()


func apply_burn(dps: float, duration: float, spreads := false) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, duration)
	burn_spreads = burn_spreads or spreads
	queue_redraw()


func apply_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)


func heal(amount: float) -> void:
	if _done or health >= data.max_health:
		return
	health = minf(health + amount, data.max_health)
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	_tick_status(delta)
	if _done:
		return
	_tick_heal(delta)
	if stun_time > 0.0:
		return
	var step := data.speed * slow_factor * delta
	_wobble += delta * 8.0
	if walker:
		_tick_ground(step, delta)
	else:
		var before := _tile_pos
		_tile_pos = _tile_pos.move_toward(Vector2(_keep), step)
		if _tile_pos != before:
			_facing = (_tile_pos - before).normalized()
		if _tile_pos == Vector2(_keep):
			_arrive()
	_sync_position()


func _tick_ground(step: float, delta: float) -> void:
	if not walker.has_route():
		# Validation should make this impossible; walk straight in rather than freeze.
		push_warning("Enemy %s lost its route at %s" % [data.id, walker.cell_to])
		walker = null
		return
	_phase_cooldown = maxf(_phase_cooldown - delta, 0.0)
	var next := walker.next_cell()
	var wall_ahead := not walker.is_moving() and grid.is_wall(next)
	if wall_ahead and data.breaks_walls:
		walker.held = true
		_smash_progress += delta
		if _smash_progress >= data.smash_time:
			_smash_progress = 0.0
			wall_smashed.emit(next)
		return
	var phasing := false
	if wall_ahead and data.phases_walls:
		if _phase_cooldown > 0.0:
			walker.held = true
			return
		_phase_cooldown = data.phase_interval
		phasing = true
	walker.held = false
	_smash_progress = 0.0
	var before := _tile_pos
	walker.advance(step, phasing)
	_tile_pos = walker.tile_position()
	if _tile_pos != before:
		_facing = (_tile_pos - before).normalized()
	if walker.is_at(_keep):
		_arrive()


func _tick_status(delta: float) -> void:
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
			queue_redraw()
	if stun_time > 0.0:
		stun_time -= delta
	if burn_time > 0.0:
		burn_time -= delta
		var dps := burn_dps * (THERMAL_SHOCK if is_slowed() else 1.0)
		# Burn is true damage; armor does not help against fire.
		take_damage(dps * delta, TowerData.DamageType.TRUE)
		if burn_spreads and _enemies:
			_spread_cooldown -= delta
			if _spread_cooldown <= 0.0:
				_spread_cooldown = SPREAD_INTERVAL
				for other in _neighbours(1.0):
					other.apply_burn(burn_dps * 0.5, 2.0, false)
		if burn_time <= 0.0:
			burn_dps = 0.0
			burn_spreads = false
			queue_redraw()


func _tick_heal(delta: float) -> void:
	if data.heal_amount <= 0.0 or _enemies == null:
		return
	_heal_cooldown -= delta
	if _heal_cooldown > 0.0:
		return
	_heal_cooldown = data.heal_interval
	for other in _neighbours(data.heal_radius):
		other.heal(data.heal_amount)


func _neighbours(radius_tiles: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var reach := radius_tiles * Board.TILE
	for node in _enemies.get_children():
		var other := node as Enemy
		if other and other != self and other.is_alive() and other.position.distance_to(position) <= reach:
			found.append(other)
	return found


func _arrive() -> void:
	_done = true
	reached_keep.emit(self)
	queue_free()


func _sync_position() -> void:
	position = (_tile_pos + Vector2(0.5, 0.5)) * Board.TILE


func _draw() -> void:
	EnemyArt.paint(self)
