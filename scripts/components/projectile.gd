class_name Projectile
extends Node2D
## Single-target shots home in on their target. Splash shots fly to where the
## target was when fired and damage everything in the radius on landing.
## Carries the firing tower's stats at launch so later upgrades don't change shots in flight.

signal impacted(at: Vector2, splash_px: float, color: Color)

var tower: Tower
var damage := 0.0
var damage_type := TowerData.DamageType.PHYSICAL
var splash_px := 0.0
var speed_px := 0.0
var color := Color.WHITE
var look := TowerData.Look.ARCHER

var _target: Enemy
var _destination := Vector2.ZERO
var _enemies: Node
var _trail: PackedVector2Array = []


func setup(from_tower: Tower, from: Vector2, target: Enemy, enemies: Node) -> void:
	tower = from_tower
	damage = tower.damage()
	damage_type = tower.damage_type()
	splash_px = tower.splash_radius() * Board.TILE
	speed_px = tower.data.projectile_speed * Board.TILE
	color = tower.data.color
	look = tower.data.look
	_target = target
	_destination = target.position
	_enemies = enemies
	position = from


func _is_splash() -> bool:
	return splash_px > 0.0


func _process(delta: float) -> void:
	if not _is_splash() and is_instance_valid(_target) and _target.is_alive():
		_destination = _target.position
	_trail.append(position)
	if _trail.size() > 6:
		_trail.remove_at(0)
	position = position.move_toward(_destination, speed_px * delta)
	queue_redraw()
	if position == _destination:
		_impact()
		queue_free()


func _impact() -> void:
	impacted.emit(_destination, splash_px, color)
	if not _is_splash():
		if is_instance_valid(_target) and _target.is_alive():
			_hit(_target)
			if tower.has_spec(TowerSpec.Kind.LIGHTNING):
				_chain(_target, int(tower.spec.value))
		return
	for enemy in _enemies_near(_destination, splash_px):
		_hit(enemy)


## Applies damage and the tower's status effect to one enemy.
func _hit(enemy: Enemy) -> void:
	if enemy.data.flying and not tower.data.hits_flyers:
		return
	var amount := damage
	if tower.has_spec(TowerSpec.Kind.SHATTER) and enemy.is_slowed():
		amount *= tower.spec.value
	match tower.data.effect:
		TowerData.Effect.SLOW:
			enemy.apply_slow(tower.data.effect_strength, tower.data.effect_duration)
		TowerData.Effect.BURN:
			enemy.apply_burn(tower.data.effect_strength * pow(tower.data.upgrade_damage_mult, tower.tier - 1),
				tower.data.effect_duration, tower.has_spec(TowerSpec.Kind.WILDFIRE))
	if tower.has_spec(TowerSpec.Kind.QUAKE):
		enemy.apply_stun(tower.spec.value)
	enemy.take_damage(amount, damage_type, tower)


func _chain(from: Enemy, jumps: int) -> void:
	var hit: Array[Enemy] = [from]
	var current := from
	for i in jumps:
		var next: Enemy = null
		var best := INF
		for enemy in _enemies_near(current.position, Board.TILE * 1.5):
			if enemy in hit:
				continue
			var d := enemy.position.distance_to(current.position)
			if d < best:
				best = d
				next = enemy
		if next == null:
			return
		hit.append(next)
		impacted.emit(next.position, 0.0, color)
		_hit(next)
		current = next


func _enemies_near(point: Vector2, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy and enemy.is_alive() and enemy.position.distance_to(point) <= radius:
			found.append(enemy)
	return found


func _draw() -> void:
	var local_trail := PackedVector2Array()
	for p in _trail:
		local_trail.append(p - position)
	local_trail.append(Vector2.ZERO)
	if local_trail.size() >= 2:
		draw_polyline(local_trail, Color(color, 0.35), 4.0 if _is_splash() else 2.0)
	match look:
		TowerData.Look.STONE:
			draw_circle(Vector2.ZERO, 9.0, Color(0.45, 0.42, 0.38))
			draw_circle(Vector2(-2, -2), 5.0, Color(0.6, 0.57, 0.52))
		TowerData.Look.FROST:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(6, 0), Vector2(0, 8), Vector2(-6, 0)]), Color(0.8, 0.95, 1.0))
		TowerData.Look.FLAME:
			draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.55, 0.1))
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.4))
		TowerData.Look.ARCANE:
			draw_circle(Vector2.ZERO, 6.0, Color(0.85, 0.6, 1.0))
			draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
		_:
			var dir := (_destination - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			draw_line(-dir * 8.0, dir * 8.0, Color(0.9, 0.85, 0.7), 2.5)
			draw_line(dir * 8.0, dir * 4.0 + dir.orthogonal() * 3.0, Color(0.9, 0.85, 0.7), 2.0)
