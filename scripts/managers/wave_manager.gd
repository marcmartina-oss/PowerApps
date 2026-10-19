class_name WaveManager
extends RefCounted
## Reads wave definitions and requests spawns on schedule. Driven by tick() so
## the level controls ordering and tests can step it deterministically.
## In Endless mode, waves past the authored list are generated from a pool and
## scale up without limit.

signal spawn_requested(enemy: EnemyData, gate_index: int)

var waves: Array[WaveData] = []
## Index of the wave in progress, or of the last one started. -1 before any.
var current := -1
var endless_pool: Array[EnemyData] = []

var _pending: Array[Dictionary] = []
var _clock := 0.0
## Health multiplier applied to spawns of the current wave (Endless scaling).
var health_scale := 1.0


func setup(level_waves: Array[WaveData], pool: Array[EnemyData] = []) -> void:
	waves = level_waves.duplicate()
	endless_pool = pool
	current = -1
	health_scale = 1.0
	_pending.clear()


func is_endless() -> bool:
	return not endless_pool.is_empty()


func has_next() -> bool:
	return is_endless() or current + 1 < waves.size()


func total() -> int:
	return waves.size()


func start_next() -> void:
	assert(has_next())
	current += 1
	while waves.size() <= current:
		waves.append(generate_wave(waves.size()))
	health_scale = 1.0 + 0.12 * maxi(current - 9, 0) if is_endless() else 1.0
	_clock = 0.0
	_pending.clear()
	for group in waves[current].groups:
		for i in group.count:
			_pending.append({
				"time": group.start_delay + i * group.interval,
				"order": _pending.size(),
				"enemy": group.enemy,
				"gate": group.gate_index,
			})
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.time < b.time or (a.time == b.time and a.order < b.order))


func tick(delta: float) -> void:
	_clock += delta
	while not _pending.is_empty() and _pending[0].time <= _clock:
		var entry: Dictionary = _pending.pop_front()
		spawn_requested.emit(entry.enemy, entry.gate)


func is_spawning() -> bool:
	return not _pending.is_empty()


func clear_bonus() -> int:
	return waves[current].clear_bonus if current >= 0 else 0


## "8 Goblin, 3 Wolf Rider" for the wave at `index`, used by the next-wave preview.
func describe(index: int) -> String:
	if index < 0:
		return ""
	if index >= waves.size():
		if not is_endless():
			return ""
		return describe_wave(generate_wave(index))
	return describe_wave(waves[index])


static func describe_wave(wave: WaveData) -> String:
	var counts: Dictionary[String, int] = {}
	for group in wave.groups:
		counts[group.enemy.display_name] = counts.get(group.enemy.display_name, 0) + group.count
	var parts: PackedStringArray = []
	for enemy_name in counts:
		parts.append("%d %s" % [counts[enemy_name], enemy_name])
	return ", ".join(parts)


## Deterministic endless wave: a few groups drawn from the pool, growing with the index.
func generate_wave(index: int) -> WaveData:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("endless") + index * 7919
	var wave := WaveData.new()
	var budget := 8 + index * 3
	var groups := mini(1 + index / 3, 4)
	var delay := 0.0
	for g in groups:
		var max_pick := mini(endless_pool.size() - 1, index / 2)
		var enemy := endless_pool[rng.randi_range(0, max_pick)]
		var group := SpawnGroup.new()
		group.enemy = enemy
		group.count = clampi(budget / groups / maxi(int(enemy.max_health / 30.0), 1), 2, 30)
		group.interval = maxf(1.2 - index * 0.02, 0.35)
		group.start_delay = delay
		group.gate_index = g % 2
		wave.groups.append(group)
		delay += group.count * group.interval * 0.6
	if index > 0 and index % 10 == 9 and endless_pool.size() > 0:
		var boss := SpawnGroup.new()
		boss.enemy = endless_pool[endless_pool.size() - 1]
		boss.count = 1 + index / 20
		boss.interval = 4.0
		boss.start_delay = delay
		wave.groups.append(boss)
	wave.clear_bonus = 30 + index * 4
	return wave
