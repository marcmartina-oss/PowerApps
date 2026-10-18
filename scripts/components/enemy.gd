class_name Enemy
extends Node2D
## Base enemy: health, armor and movement. Ground enemies walk the maze through a
## GroundWalker; flyers head straight for the keep. Positions are in board units.

signal died(enemy: Enemy)
signal reached_keep(enemy: Enemy)

var data: EnemyData
var health := 0.0
## Null for flyers.
var walker: GroundWalker

var _keep: Vector2i
## Position in tile coordinates; tile centres are whole numbers.
var _tile_pos := Vector2.ZERO
var _done := false


func setup(enemy_data: EnemyData, grid: GridManager, gate: Vector2i) -> void:
	data = enemy_data
	health = data.max_health
	_keep = grid.keep
	_tile_pos = Vector2(gate)
	if not data.flying:
		walker = GroundWalker.new(gate, grid.route_from(gate))
	_sync_position()


func is_alive() -> bool:
	return not _done


func is_ground() -> bool:
	return walker != null


func remaining_distance() -> float:
	if walker:
		return walker.remaining_distance()
	return _tile_pos.distance_to(Vector2(_keep))


func take_damage(amount: float, damage_type: TowerData.DamageType) -> void:
	if _done:
		return
	if damage_type == TowerData.DamageType.PHYSICAL:
		amount *= 1.0 - data.armor
	health -= amount
	queue_redraw()
	if health <= 0.0:
		_done = true
		died.emit(self)
		queue_free()


func _process(delta: float) -> void:
	if _done:
		return
	var step := data.speed * delta
	if walker and not walker.has_route():
		# Validation should make this impossible; walk straight in rather than freeze.
		push_warning("Enemy %s lost its route at %s" % [data.id, walker.cell_to])
		walker = null
	if walker:
		walker.advance(step)
		_tile_pos = walker.tile_position()
		if walker.is_at(_keep):
			_arrive()
	else:
		_tile_pos = _tile_pos.move_toward(Vector2(_keep), step)
		if _tile_pos == Vector2(_keep):
			_arrive()
	_sync_position()


func _arrive() -> void:
	_done = true
	reached_keep.emit(self)
	queue_free()


func _sync_position() -> void:
	position = (_tile_pos + Vector2(0.5, 0.5)) * Board.TILE


func _draw() -> void:
	var r := data.radius * Board.TILE
	if data.flying:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 1.3, r * 0.6), Vector2(-r * 1.3, r * 0.6)]), data.color)
	else:
		draw_circle(Vector2.ZERO, r, data.color)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 2.0)
	if health < data.max_health:
		var w := Board.TILE * 0.6
		var bar := Rect2(-w / 2.0, -r - 10.0, w, 5.0)
		draw_rect(bar, Color(0.15, 0.0, 0.0))
		draw_rect(Rect2(bar.position, Vector2(w * maxf(health, 0.0) / data.max_health, 5.0)), Color(0.3, 0.95, 0.3))
