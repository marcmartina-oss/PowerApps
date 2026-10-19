class_name TitleBackdrop
extends Control
## Painted backdrop for the title screen: sky, hills, a maze with the keep and
## a goblin patrol marching past. Sits behind the menu.

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Drawn in viewport space: the control's own rect may still be empty on the first frames.
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.14, 0.1))
	for i in 12:
		var k := i / 12.0
		draw_rect(Rect2(0, h * k * 0.6, w, h * 0.06), Color(0.1, 0.14, 0.1).lerp(Color(0.25, 0.3, 0.2), k))
	draw_circle(Vector2(w * 0.16, h * 0.07), 40.0, Color(0.95, 0.9, 0.7, 0.9))
	for i in 3:
		var y := h * (0.27 + i * 0.03)
		var hill := PackedVector2Array([Vector2(0, h)])
		for x in range(0, int(w) + 40, 40):
			hill.append(Vector2(x, y - sin(x * 0.01 + i) * 30.0 - i * 20.0))
		hill.append(Vector2(w, h))
		draw_colored_polygon(hill, Color(0.18, 0.28, 0.16).darkened(i * 0.15))
	var pal := Palette.world(1)
	var tile := w / 9.0
	var ground := Rect2(0, h * 0.30, w, tile * 6.0)
	draw_rect(ground, pal[0])
	for row in 6:
		for c in 9:
			if (row + c) % 2 == 0:
				draw_rect(Rect2(c * tile, ground.position.y + row * tile, tile, tile), pal[1])
	var walls := [[0, 1], [1, 1], [2, 1], [3, 1], [5, 1], [6, 1], [7, 1], [8, 1], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [0, 5], [1, 5], [2, 5], [6, 5], [7, 5], [8, 5]]
	for wc in walls:
		var r := Rect2(wc[0] * tile + 3, ground.position.y + wc[1] * tile + 3, tile - 6, tile - 6)
		draw_rect(r, Palette.WALL_DARK)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y - 8)), Palette.WALL)
	var keep := Rect2(4 * tile, ground.position.y + 5 * tile - tile * 0.5, tile, tile * 1.5)
	draw_rect(keep, Palette.KEEP.darkened(0.3))
	draw_rect(keep.grow(-8), Palette.KEEP)
	for i in 3:
		draw_rect(Rect2(keep.position + Vector2(6 + i * 26, -12), Vector2(14, 14)), Palette.KEEP.darkened(0.3))
	var flag := keep.position + Vector2(keep.size.x / 2.0, -14)
	draw_line(flag, flag + Vector2(0, -50), Palette.WOOD_LIGHT, 4.0)
	draw_colored_polygon(PackedVector2Array([flag + Vector2(0, -50), flag + Vector2(36 + sin(_time * 3.0) * 4.0, -40), flag + Vector2(0, -28)]), Palette.GOLD)
	for i in 4:
		var x := fmod(_time * 60.0 + i * 90.0, w + 60.0) - 30.0
		var y := ground.position.y + 2 * tile + tile * 0.5 + sin(_time * 8.0 + i) * 3.0
		draw_circle(Vector2(x, y + 10), 14.0, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(x, y), 14.0, Color(0.55, 0.85, 0.3))
		draw_circle(Vector2(x - 5, y - 3), 2.5, Color(1, 0.3, 0.2))
		draw_circle(Vector2(x + 5, y - 3), 2.5, Color(1, 0.3, 0.2))
	# Below the painting: a plain dark band for the menu, fading in from the grass.
	var band_top := ground.end.y
	for i in 10:
		var k := i / 10.0
		draw_rect(Rect2(0, band_top + k * 40.0, w, 4.0), Color(0.08, 0.1, 0.08, k))
	draw_rect(Rect2(0, band_top + 40.0, w, h - band_top), Color(0.08, 0.1, 0.08))
