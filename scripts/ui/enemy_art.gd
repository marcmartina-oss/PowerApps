class_name EnemyArt
extends RefCounted
## Procedural enemy drawing: a distinct silhouette per Look, drawn in the enemy's
## local space. Keeps the Enemy script about behaviour.


static func paint(e: Enemy) -> void:
	var r := e.data.radius * Board.TILE
	var c := e.data.color
	if e._hit_flash > 0.0:
		c = c.lightened(0.6)
	var bob := sin(e._wobble) * r * 0.08
	# Shadow
	e.draw_circle(Vector2(0, r * 0.9), r * 0.8, Color(0, 0, 0, 0.25))
	e.draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	match e.data.look:
		EnemyData.Look.GOBLIN:
			_body(e, r, c)
			_ears(e, r, c)
			_eyes(e, r, Color(1, 0.3, 0.2))
		EnemyData.Look.WOLF:
			var f := e._facing
			var side := f.orthogonal()
			e.draw_colored_polygon(PackedVector2Array([f * r * 1.4, side * r * 0.8 - f * r * 0.9, -side * r * 0.8 - f * r * 0.9]), c)
			e.draw_circle(f * r * 0.5, r * 0.7, c.lightened(0.15))
			e.draw_circle(f * r * 0.8 + side * r * 0.3, r * 0.14, Color(1, 0.9, 0.2))
			e.draw_circle(f * r * 0.8 - side * r * 0.3, r * 0.14, Color(1, 0.9, 0.2))
		EnemyData.Look.ORC:
			_body(e, r, c)
			e.draw_rect(Rect2(-r * 0.9, -r * 0.3, r * 1.8, r * 0.5), c.darkened(0.35))
			_tusks(e, r)
			_eyes(e, r, Color(1, 0.9, 0.3))
		EnemyData.Look.KNIGHT:
			e.draw_rect(Rect2(-r * 0.8, -r * 0.8, r * 1.6, r * 1.6), c.darkened(0.2))
			e.draw_rect(Rect2(-r * 0.6, -r * 0.6, r * 1.2, r * 1.2), c)
			e.draw_line(Vector2(-r * 0.45, 0), Vector2(r * 0.45, 0), Color(0.1, 0.1, 0.15), 3.0)
			e.draw_line(Vector2(0, -r * 0.2), Vector2(0, r * 0.3), Color(0.9, 0.2, 0.2), 3.0)
		EnemyData.Look.BAT:
			var flap := sin(e._wobble * 2.0) * r * 0.5
			e.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-r * 1.6, -r * 0.4 + flap), Vector2(-r * 1.2, r * 0.5)]), c.darkened(0.1))
			e.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r * 1.6, -r * 0.4 + flap), Vector2(r * 1.2, r * 0.5)]), c.darkened(0.1))
			e.draw_circle(Vector2.ZERO, r * 0.55, c)
			_eyes(e, r * 0.8, Color(1, 0.2, 0.2))
		EnemyData.Look.SAPPER:
			_body(e, r, c)
			e.draw_rect(Rect2(-r * 0.7, -r * 1.2, r * 1.4, r * 0.5), Color(0.8, 0.6, 0.2))
			e.draw_line(Vector2(r * 0.5, 0), Vector2(r * 1.4, -r * 0.8), Color(0.45, 0.3, 0.2), 4.0)
			e.draw_rect(Rect2(r * 1.1, -r * 1.2, r * 0.6, r * 0.5), Color(0.6, 0.6, 0.65))
			_eyes(e, r, Color(1, 1, 1))
		EnemyData.Look.SLIME:
			var squash := 1.0 + sin(e._wobble) * 0.1
			e.draw_set_transform(Vector2(0, bob), 0.0, Vector2(squash, 1.0 / squash))
			e.draw_circle(Vector2.ZERO, r, Color(c, 0.85))
			e.draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.35))
			_eyes(e, r * 0.8, Color(0.1, 0.1, 0.1))
		EnemyData.Look.SHAMAN:
			_body(e, r, c)
			e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.7, -r * 0.5), Vector2(r * 0.7, -r * 0.5), Vector2(0, -r * 1.8)]), Color(0.9, 0.85, 0.6))
			e.draw_line(Vector2(r * 0.8, r * 0.6), Vector2(r * 1.2, -r * 1.2), Color(0.5, 0.35, 0.2), 3.0)
			e.draw_circle(Vector2(r * 1.2, -r * 1.2), r * 0.3, Color(0.4, 1.0, 0.6))
			_eyes(e, r, Color(0.4, 1.0, 0.6))
		EnemyData.Look.GHOST:
			var a: float = 0.45 if e.walker and e.walker.held else 0.75
			e.draw_circle(Vector2(0, -r * 0.2), r, Color(c, a))
			e.draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.2), Vector2(r, -r * 0.2), Vector2(r * 0.6, r), Vector2(0, r * 0.6), Vector2(-r * 0.6, r)]), Color(c, a))
			_eyes(e, r, Color(0.1, 0.1, 0.2))
		EnemyData.Look.TROLL:
			_body(e, r, c)
			e.draw_circle(Vector2(0, -r * 0.1), r * 0.75, c.lightened(0.1))
			e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, -r * 0.9), Vector2(r * 0.6, -r * 0.9), Vector2(0, -r * 1.5)]), Palette.GOLD)
			e.draw_line(Vector2(r * 0.6, r * 0.4), Vector2(r * 1.5, -r * 0.6), Color(0.4, 0.3, 0.2), 6.0)
			_tusks(e, r)
			_eyes(e, r, Color(1, 0.3, 0.1))
		EnemyData.Look.DRAGON:
			var flap := sin(e._wobble * 1.5) * r * 0.6
			e.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-r * 1.8, -r * 0.6 + flap), Vector2(-r * 1.4, r * 0.4)]), c.darkened(0.2))
			e.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r * 1.8, -r * 0.6 + flap), Vector2(r * 1.4, r * 0.4)]), c.darkened(0.2))
			e.draw_circle(Vector2.ZERO, r * 0.8, c)
			e.draw_circle(Vector2(0, -r * 0.7), r * 0.45, c.lightened(0.1))
			e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.2, -r * 1.0), Vector2(r * 0.2, -r * 1.0), Vector2(0, -r * 1.5)]), Color(1, 0.6, 0.1))
			_eyes(e, r * 0.7, Color(1, 0.9, 0.2))
		EnemyData.Look.LICH:
			e.draw_colored_polygon(PackedVector2Array([Vector2(-r, r), Vector2(r, r), Vector2(r * 0.5, -r), Vector2(-r * 0.5, -r)]), Color(c, 0.85))
			e.draw_circle(Vector2(0, -r * 0.5), r * 0.5, Color(0.9, 0.9, 0.85))
			e.draw_line(Vector2(r * 0.9, r * 0.5), Vector2(r * 1.3, -r * 1.3), Color(0.3, 0.2, 0.3), 3.0)
			e.draw_circle(Vector2(r * 1.3, -r * 1.3), r * 0.35, Color(0.5, 1.0, 0.9))
			_eyes(e, r, Color(0.3, 1.0, 0.8))
	e.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e.is_slowed():
		e.draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 16, Color(0.6, 0.9, 1.0, 0.8), 2.0)
	if e.is_burning():
		var fl := absf(sin(e._wobble * 3.0))
		e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, -r), Vector2(r * 0.5, -r), Vector2(0, -r * (1.6 + fl * 0.5))]), Color(1, 0.5, 0.1, 0.85))
	if e.stun_time > 0.0:
		for i in 3:
			var ang := e._wobble + i * TAU / 3.0
			e.draw_circle(Vector2(cos(ang), sin(ang) * 0.4) * r * 1.1 + Vector2(0, -r * 1.3), 3.0, Palette.GOLD)
	if e.health < e.data.max_health:
		var w := Board.TILE * (0.9 if e.data.is_boss else 0.6)
		var bar := Rect2(-w / 2.0, -r - 12.0, w, 6.0)
		e.draw_rect(bar, Color(0.15, 0.0, 0.0))
		e.draw_rect(Rect2(bar.position, Vector2(w * maxf(e.health, 0.0) / e.data.max_health, 6.0)), Color(0.3, 0.95, 0.3))


static func _body(e: Enemy, r: float, c: Color) -> void:
	e.draw_circle(Vector2.ZERO, r, c)
	e.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, c.darkened(0.5), 2.0)


static func _ears(e: Enemy, r: float, c: Color) -> void:
	e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.6, -r * 0.5), Vector2(-r * 1.4, -r * 1.2), Vector2(-r * 0.2, -r * 0.9)]), c)
	e.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.6, -r * 0.5), Vector2(r * 1.4, -r * 1.2), Vector2(r * 0.2, -r * 0.9)]), c)


static func _tusks(e: Enemy, r: float) -> void:
	e.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.5, r * 0.2), Vector2(-r * 0.2, r * 0.2), Vector2(-r * 0.4, -r * 0.3)]), Color(0.95, 0.9, 0.8))
	e.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.5, r * 0.2), Vector2(r * 0.2, r * 0.2), Vector2(r * 0.4, -r * 0.3)]), Color(0.95, 0.9, 0.8))


static func _eyes(e: Enemy, r: float, c: Color) -> void:
	e.draw_circle(Vector2(-r * 0.35, -r * 0.2), r * 0.16, c)
	e.draw_circle(Vector2(r * 0.35, -r * 0.2), r * 0.16, c)
