extends "res://tests/test_case.gd"


func test_spend_and_earn() -> void:
	var economy := Economy.new()
	economy.setup(100, 20)
	assert_true(economy.spend(60))
	assert_false(economy.spend(60), "can't overspend")
	assert_eq(economy.gold, 40)
	economy.earn(5)
	assert_eq(economy.gold, 45)


func test_refund_is_seventy_percent_rounded_down() -> void:
	assert_eq(Economy.refund_value(5), 3)
	assert_eq(Economy.refund_value(50), 35)
	assert_eq(Economy.refund_value(80), 56)


func test_star_thresholds() -> void:
	var economy := Economy.new()
	economy.setup(0, 20)
	assert_eq(economy.stars(), 3)
	economy.lose_lives(1)
	assert_eq(economy.stars(), 2)
	economy.lose_lives(9)
	assert_eq(economy.stars(), 2, "lost exactly half")
	economy.lose_lives(1)
	assert_eq(economy.stars(), 1)
	economy.lose_lives(50)
	assert_eq(economy.lives, 0)
	assert_true(economy.is_defeated())
	assert_eq(economy.stars(), 0)


func test_wave_spawns_on_schedule() -> void:
	var goblin := EnemyData.new()
	goblin.display_name = "Goblin"
	var wolf := EnemyData.new()
	wolf.display_name = "Wolf"
	var g := SpawnGroup.new()
	g.enemy = goblin
	g.count = 3
	g.interval = 1.0
	var w := SpawnGroup.new()
	w.enemy = wolf
	w.count = 2
	w.interval = 0.5
	w.start_delay = 0.25
	w.gate_index = 1
	var wave := WaveData.new()
	wave.groups = [g, w] as Array[SpawnGroup]
	var manager := WaveManager.new()
	manager.setup([wave] as Array[WaveData])
	var spawned: Array[String] = []
	manager.spawn_requested.connect(func(e: EnemyData, gate: int) -> void: spawned.append("%s@%d" % [e.display_name, gate]))
	assert_true(manager.has_next())
	manager.start_next()
	manager.tick(0.0)
	assert_eq(spawned, ["Goblin@0"] as Array[String])
	manager.tick(0.8)
	assert_eq(spawned, ["Goblin@0", "Wolf@1", "Wolf@1"] as Array[String])
	manager.tick(1.5)
	assert_eq(spawned.size(), 5)
	assert_false(manager.is_spawning())
	assert_false(manager.has_next())
	assert_eq(manager.describe(0), "3 Goblin, 2 Wolf")
