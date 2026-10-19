class_name Effects
extends Node2D
## Cheap one-shot visuals drawn from a single node: hit sparks, death puffs,
## splash rings, floating gold text and wall-smash dust. Everything is a small
## dictionary updated in _process and drawn in one _draw call, so 150 enemies
## dying in a row cost no extra nodes.

var _items: Array[Dictionary] = []


func spark(at: Vector2, color: Color) -> void:
	_items.append({"kind": "spark", "pos": at, "color": color, "t": 0.0, "life": 0.18})


func ring(at: Vector2, radius: float, color: Color) -> void:
	_items.append({"kind": "ring", "pos": at, "color": color, "t": 0.0, "life": 0.3, "radius": radius})


func puff(at: Vector2, color: Color, big := false) -> void:
	var rng := RandomNumberGenerator.new()
	var bits: Array[Vector2] = []
	for i in (10 if big else 6):
		bits.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 60.0 if big else 36.0))
	_items.append({"kind": "puff", "pos": at, "color": color, "t": 0.0, "life": 0.45 if big else 0.35, "bits": bits, "size": 7.0 if big else 4.0})


func text(at: Vector2, label: String, color: Color) -> void:
	_items.append({"kind": "text", "pos": at, "color": color, "t": 0.0, "life": 0.9, "label": label})


func _process(delta: float) -> void:
	if _items.is_empty():
		return
	var i := _items.size() - 1
	while i >= 0:
		_items[i].t += delta
		if _items[i].t >= _items[i].life:
			_items.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for item in _items:
		var k: float = item.t / item.life
		var color: Color = item.color
		match item.kind:
			"spark":
				color.a = 1.0 - k
				for j in 4:
					var dir := Vector2.from_angle(j * TAU / 4.0 + 0.6)
					draw_line(item.pos + dir * 4.0, item.pos + dir * (6.0 + k * 14.0), color, 2.0)
			"ring":
				color.a = 0.6 * (1.0 - k)
				draw_arc(item.pos, item.radius * (0.4 + 0.6 * k), 0.0, TAU, 32, color, 3.0)
				draw_circle(item.pos, item.radius * (0.4 + 0.6 * k), Color(color, color.a * 0.3))
			"puff":
				color.a = 1.0 - k
				for bit: Vector2 in item.bits:
					draw_circle(item.pos + bit * k, item.size * (1.0 - k * 0.6), color)
			"text":
				color.a = 1.0 - k * k
				draw_string(font, item.pos + Vector2(-20, -10 - k * 30.0), item.label, HORIZONTAL_ALIGNMENT_CENTER, 40, 18, color)
