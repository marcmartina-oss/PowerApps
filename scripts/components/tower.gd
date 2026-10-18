class_name Tower
extends Node2D
## Base tower: picks a target by targeting mode and fires projectiles.

enum Targeting { FIRST, STRONGEST, FASTEST, FLYERS }

const TARGETING_NAMES: Array[String] = ["First", "Strongest", "Fastest", "Flyers"]
const PROJECTILE_SCENE := preload("res://scenes/towers/projectile.tscn")

var data: TowerData
var cell: Vector2i
var targeting := Targeting.FIRST

var _cooldown := 0.0
var _enemies: Node
var _projectiles: Node
var _aim := Vector2.UP


func setup(tower_data: TowerData, at_cell: Vector2i, enemies: Node, projectiles: Node) -> void:
	data = tower_data
	cell = at_cell
	_enemies = enemies
	_projectiles = projectiles
	position = Board.cell_center(cell)


func cycle_targeting() -> void:
	targeting = ((targeting + 1) % Targeting.size()) as Targeting


func targeting_name() -> String:
	return TARGETING_NAMES[targeting]


func range_px() -> float:
	return data.attack_range * Board.TILE


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _pick_target()
	if target == null:
		return
	_cooldown = data.fire_interval
	_aim = (target.position - position).normalized()
	var shot: Projectile = PROJECTILE_SCENE.instantiate()
	shot.setup(data, position + _aim * Board.TILE * 0.3, target, _enemies)
	_projectiles.add_child(shot)
	queue_redraw()


func _pick_target() -> Enemy:
	var best: Enemy = null
	var best_score := -INF
	var reach := range_px()
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if enemy.data.flying and not data.hits_flyers:
			continue
		if position.distance_to(enemy.position) > reach:
			continue
		var score := _score(enemy)
		if score > best_score:
			best_score = score
			best = enemy
	return best


func _score(enemy: Enemy) -> float:
	match targeting:
		Targeting.STRONGEST:
			return enemy.health
		Targeting.FASTEST:
			return enemy.data.speed
		Targeting.FLYERS:
			return (1000.0 if enemy.data.flying else 0.0) - enemy.remaining_distance()
		_:
			return -enemy.remaining_distance()


func _draw() -> void:
	var half := Board.TILE * 0.42
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), data.color.darkened(0.45))
	draw_circle(Vector2.ZERO, half * 0.72, data.color)
	draw_line(Vector2.ZERO, _aim * half * 0.95, data.color.lightened(0.6), 6.0)
