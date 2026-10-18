class_name WaveManager
extends RefCounted
## Reads wave definitions and requests spawns on schedule. Driven by tick() so
## the level controls ordering and tests can step it deterministically.

signal spawn_requested(enemy: EnemyData, gate_index: int)

var waves: Array[WaveData] = []
## Index of the wave in progress, or of the last one started. -1 before any.
var current := -1

var _pending: Array[Dictionary] = []
var _clock := 0.0


func setup(level_waves: Array[WaveData]) -> void:
	waves = level_waves
	current = -1
	_pending.clear()


func has_next() -> bool:
	return current + 1 < waves.size()


func start_next() -> void:
	assert(has_next())
	current += 1
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
	if index < 0 or index >= waves.size():
		return ""
	var counts: Dictionary[String, int] = {}
	for group in waves[index].groups:
		counts[group.enemy.display_name] = counts.get(group.enemy.display_name, 0) + group.count
	var parts: PackedStringArray = []
	for enemy_name in counts:
		parts.append("%d %s" % [counts[enemy_name], enemy_name])
	return ", ".join(parts)
