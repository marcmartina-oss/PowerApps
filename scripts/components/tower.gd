class_name Tower
extends Node2D
## Base tower: tiers, specialization, targeting and firing. War Banner buffs are
## pushed in by the Level (see set_buffs) whenever the maze changes.

signal fired(tower: Tower)
signal upgraded(tower: Tower)

enum Targeting { FIRST, STRONGEST, FASTEST, FLYERS }

const TARGETING_NAMES: Array[String] = ["First", "Strongest", "Fastest", "Flyers"]
const PROJECTILE_SCENE := preload("res://scenes/towers/projectile.tscn")
## Blizzard re-applies its area slow this often.
const AURA_INTERVAL := 0.5

var data: TowerData
var cell: Vector2i
var tier := 1
var spec: TowerSpec
var targeting := Targeting.FIRST
## Attack-speed multiplier from adjacent War Banners (1 = none).
var buff_speed := 1.0
## Extra gold fraction on kills from adjacent Bounty banners.
var buff_bounty := 0.0
## Extra range in tiles from the skill tree.
var bonus_range := 0.0
## Called with (position, splash_px, color) when one of this tower's shots lands.
var impact_handler: Callable

var _cooldown := 0.0
var _enemies: Node
var _projectiles: Node
var _aim := Vector2.UP
var _recoil := 0.0
var _spin := 0.0


func setup(tower_data: TowerData, at_cell: Vector2i, enemies: Node, projectiles: Node) -> void:
	data = tower_data
	cell = at_cell
	_enemies = enemies
	_projectiles = projectiles
	position = Board.cell_center(cell)


func can_upgrade() -> bool:
	return tier < TowerData.MAX_TIER


func upgrade_cost() -> int:
	return data.upgrade_cost(tier)


func total_cost() -> int:
	return data.total_cost(tier)


## Raises the tier. Tier 3 requires choosing a specialization.
func upgrade(chosen_spec: TowerSpec = null) -> void:
	assert(can_upgrade())
	tier += 1
	if tier == TowerData.MAX_TIER:
		spec = chosen_spec
	upgraded.emit(self)
	queue_redraw()


func has_spec(kind: TowerSpec.Kind) -> bool:
	return spec != null and spec.kind == kind


func cycle_targeting() -> void:
	targeting = ((targeting + 1) % Targeting.size()) as Targeting


func targeting_name() -> String:
	return TARGETING_NAMES[targeting]


func set_buffs(speed_mult: float, bounty: float) -> void:
	buff_speed = speed_mult
	buff_bounty = bounty
	queue_redraw()


func is_support() -> bool:
	return data.effect == TowerData.Effect.BUFF


func damage() -> float:
	var value := data.damage_at(tier)
	if has_spec(TowerSpec.Kind.VOID) or has_spec(TowerSpec.Kind.BOULDER):
		value *= spec.value
	return value


func attack_range() -> float:
	var tiles := data.range_at(tier) + bonus_range
	if has_spec(TowerSpec.Kind.LONGBOW) or has_spec(TowerSpec.Kind.INFERNO):
		tiles += spec.value
	return tiles


func range_px() -> float:
	return attack_range() * Board.TILE


func fire_interval() -> float:
	return data.fire_interval / buff_speed


func splash_radius() -> float:
	var radius := data.splash_radius
	if has_spec(TowerSpec.Kind.BOULDER):
		radius *= 1.6
	if has_spec(TowerSpec.Kind.INFERNO):
		radius = maxf(radius, 0.8)
	return radius


func damage_type() -> TowerData.DamageType:
	return TowerData.DamageType.TRUE if has_spec(TowerSpec.Kind.VOID) else data.damage_type


func shots_per_volley() -> int:
	return int(spec.value) if has_spec(TowerSpec.Kind.VOLLEY) else 1


func _process(delta: float) -> void:
	_recoil = maxf(_recoil - delta * 4.0, 0.0)
	_spin += delta
	if is_support():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if has_spec(TowerSpec.Kind.BLIZZARD):
		_cooldown = AURA_INTERVAL
		var any := false
		for enemy in _enemies_in_range():
			enemy.apply_slow(data.effect_strength, data.effect_duration)
			any = true
		if any:
			queue_redraw()
		return
	var targets := _pick_targets(shots_per_volley())
	if targets.is_empty():
		return
	_cooldown = fire_interval()
	_aim = (targets[0].position - position).normalized()
	_recoil = 1.0
	for target in targets:
		var shot: Projectile = PROJECTILE_SCENE.instantiate()
		shot.setup(self, position + _aim * Board.TILE * 0.3, target, _enemies)
		if impact_handler.is_valid():
			shot.impacted.connect(impact_handler)
		_projectiles.add_child(shot)
	fired.emit(self)
	queue_redraw()


func _enemies_in_range() -> Array[Enemy]:
	var found: Array[Enemy] = []
	var reach := range_px()
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if enemy.data.flying and not data.hits_flyers:
			continue
		if position.distance_to(enemy.position) <= reach:
			found.append(enemy)
	return found


func _pick_targets(count: int) -> Array[Enemy]:
	var candidates := _enemies_in_range()
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _score(a) > _score(b))
	return candidates.slice(0, count)


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
	TowerArt.paint(self, _aim, _recoil, _spin)
