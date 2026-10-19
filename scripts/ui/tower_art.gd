class_name TowerArt
extends RefCounted
## Procedural tower drawing: a distinct silhouette per Look, with tier pips and
## a specialization banner. Drawn in the tower's local space.


static func paint(t: Tower, aim: Vector2, recoil: float, spin: float) -> void:
	var half := Board.TILE * 0.42
	var c := t.data.color
	# Base plinth
	t.draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), Color(0.3, 0.27, 0.25))
	t.draw_rect(Rect2(-half + 3, -half + 3, half * 2.0 - 6, half * 2.0 - 6), Color(0.45, 0.42, 0.4))
	t.draw_rect(Rect2(-half + 3, -half + 3, half * 2.0 - 6, half * 2.0 - 6), Color(0.2, 0.18, 0.17), false, 2.0)
	var kick := aim * -recoil * 4.0
	match t.data.look:
		TowerData.Look.ARCHER:
			t.draw_circle(Vector2.ZERO, half * 0.62, Color(0.55, 0.4, 0.25))
			t.draw_circle(Vector2.ZERO, half * 0.62, Color(0.3, 0.2, 0.12), false, 2.0)
			for i in 6:
				var a := i * TAU / 6.0
				t.draw_rect(Rect2(Vector2(cos(a), sin(a)) * half * 0.62 - Vector2(3, 3), Vector2(6, 6)), Color(0.35, 0.25, 0.15))
			var bow_c := Vector2.ZERO + aim * half * 0.3 + kick
			t.draw_arc(bow_c, half * 0.35, aim.angle() - 1.2, aim.angle() + 1.2, 10, Color(0.8, 0.65, 0.4), 3.0)
			t.draw_line(bow_c + Vector2.from_angle(aim.angle() - 1.2) * half * 0.35, bow_c + Vector2.from_angle(aim.angle() + 1.2) * half * 0.35, Color(0.9, 0.9, 0.9), 1.5)
		TowerData.Look.STONE:
			t.draw_rect(Rect2(-half * 0.7, -half * 0.3, half * 1.4, half * 0.8), Color(0.5, 0.35, 0.2))
			t.draw_circle(Vector2(-half * 0.5, half * 0.4), half * 0.22, Color(0.3, 0.25, 0.2))
			t.draw_circle(Vector2(half * 0.5, half * 0.4), half * 0.22, Color(0.3, 0.25, 0.2))
			var arm_end := aim * half * (0.9 - recoil * 0.5) + kick
			t.draw_line(-aim * half * 0.4, arm_end, Color(0.6, 0.45, 0.25), 5.0)
			t.draw_circle(arm_end, half * 0.22, Color(0.45, 0.42, 0.38))
		TowerData.Look.FROST:
			t.draw_colored_polygon(PackedVector2Array([Vector2(0, -half * 0.95), Vector2(half * 0.45, 0), Vector2(0, half * 0.6), Vector2(-half * 0.45, 0)]), Color(0.75, 0.92, 1.0))
			t.draw_colored_polygon(PackedVector2Array([Vector2(0, -half * 0.7), Vector2(half * 0.22, 0), Vector2(0, half * 0.35), Vector2(-half * 0.22, 0)]), Color(1, 1, 1, 0.8))
			for i in 3:
				var a := spin * 1.5 + i * TAU / 3.0
				t.draw_circle(Vector2.from_angle(a) * half * 0.75, 3.0, Color(0.8, 0.95, 1.0))
			if t.has_spec(TowerSpec.Kind.BLIZZARD):
				t.draw_arc(Vector2.ZERO, half * 0.9, spin, spin + 4.0, 12, Color(0.8, 0.95, 1.0, 0.7), 2.0)
		TowerData.Look.FLAME:
			t.draw_rect(Rect2(-half * 0.55, -half * 0.1, half * 1.1, half * 0.7), Color(0.25, 0.22, 0.2))
			t.draw_rect(Rect2(-half * 0.65, -half * 0.2, half * 1.3, half * 0.2), Color(0.35, 0.3, 0.28))
			var fl := absf(sin(spin * 7.0)) * 0.4 + 0.8
			t.draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.45, -half * 0.2), Vector2(half * 0.45, -half * 0.2), Vector2(half * 0.15, -half * 0.6 * fl), Vector2(0, -half * 1.0 * fl), Vector2(-half * 0.2, -half * 0.55 * fl)]), Color(1.0, 0.5, 0.1))
			t.draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.2, -half * 0.2), Vector2(half * 0.2, -half * 0.2), Vector2(0, -half * 0.65 * fl)]), Color(1.0, 0.9, 0.4))
		TowerData.Look.ARCANE:
			t.draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.45, half * 0.7), Vector2(half * 0.45, half * 0.7), Vector2(half * 0.15, -half * 0.6), Vector2(-half * 0.15, -half * 0.6)]), Color(0.4, 0.3, 0.55))
			var orb := Vector2(0, -half * 0.7) + Vector2(sin(spin * 3.0), cos(spin * 2.0)) * 2.0
			t.draw_circle(orb, half * 0.3, Color(0.85, 0.6, 1.0))
			t.draw_circle(orb, half * 0.15, Color.WHITE)
			if t.has_spec(TowerSpec.Kind.VOID):
				t.draw_circle(orb, half * 0.12, Color(0.1, 0.0, 0.2))
		TowerData.Look.BANNER:
			t.draw_line(Vector2(0, half * 0.8), Vector2(0, -half * 0.95), Color(0.5, 0.35, 0.2), 4.0)
			var wave := sin(spin * 4.0) * 3.0
			var flag_c := Color(0.85, 0.2, 0.2) if not t.has_spec(TowerSpec.Kind.BOUNTY) else Palette.GOLD
			t.draw_colored_polygon(PackedVector2Array([Vector2(2, -half * 0.95), Vector2(half * 0.9, -half * 0.75 + wave), Vector2(half * 0.6, -half * 0.45 + wave), Vector2(half * 0.9, -half * 0.15 + wave), Vector2(2, -half * 0.3)]), flag_c)
			t.draw_circle(Vector2(0, -half * 0.95), 4.0, Palette.GOLD)
	for i in t.tier:
		t.draw_circle(Vector2(-half + 8 + i * 9, half - 8), 3.0, Palette.GOLD)
	if t.spec:
		t.draw_rect(Rect2(half - 14, -half + 4, 10, 10), Color.WHITE)
		t.draw_rect(Rect2(half - 12, -half + 6, 6, 6), c)
	if t.buff_speed > 1.0 or t.buff_bounty > 0.0:
		t.draw_arc(Vector2.ZERO, half * 1.05, 0.0, TAU, 20, Color(1.0, 0.85, 0.3, 0.6), 2.0)
