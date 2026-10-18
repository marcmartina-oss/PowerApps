class_name Projectile
extends Node2D
## Single-target shots home in on their target. Splash shots fly to where the
## target was when fired and damage everything in the radius on landing.

var _data: TowerData
var _target: Enemy
var _destination := Vector2.ZERO
var _enemies: Node


func setup(tower_data: TowerData, from: Vector2, target: Enemy, enemies: Node) -> void:
	_data = tower_data
	_target = target
	_destination = target.position
	_enemies = enemies
	position = from


func _is_splash() -> bool:
	return _data.splash_radius > 0.0


func _process(delta: float) -> void:
	if not _is_splash() and is_instance_valid(_target) and _target.is_alive():
		_destination = _target.position
	position = position.move_toward(_destination, _data.projectile_speed * Board.TILE * delta)
	if position == _destination:
		_impact()
		queue_free()


func _impact() -> void:
	if not _is_splash():
		if is_instance_valid(_target) and _target.is_alive():
			_target.take_damage(_data.damage, _data.damage_type)
		return
	var radius := _data.splash_radius * Board.TILE
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if enemy.data.flying and not _data.hits_flyers:
			continue
		if enemy.position.distance_to(_destination) <= radius:
			enemy.take_damage(_data.damage, _data.damage_type)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0 if _is_splash() else 5.0, _data.color.lightened(0.3))
