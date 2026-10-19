extends SceneTree
## Draws the app icon (1024x1024): a keep flag over a serpentine maze.
##   godot --headless -s res://tools/make_icon.gd


func _initialize() -> void:
	var s := 1024
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	# Sky to grass gradient.
	for y in s:
		var k := y / float(s)
		var c := Color(0.16, 0.22, 0.14).lerp(Color(0.36, 0.56, 0.28), k)
		img.fill_rect(Rect2i(0, y, s, 1), c)
	# Checker tiles.
	var tile := 128
	for ty in range(2, 8):
		for tx in 8:
			if (tx + ty) % 2 == 0:
				img.fill_rect(Rect2i(tx * tile, ty * tile, tile, tile), Color(0.33, 0.52, 0.26))
	# Maze walls.
	var wall := Color(0.62, 0.47, 0.33)
	var dark := Color(0.36, 0.26, 0.17)
	for seg in [[0, 3, 6], [2, 5, 6], [0, 7, 6]]:
		for tx in range(seg[0], seg[0] + seg[2]):
			var r := Rect2i(tx * tile + 8, seg[1] * tile + 8, tile - 16, tile - 16)
			img.fill_rect(r, dark)
			img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, r.size.y - 20)), wall)
	# Gate and keep.
	img.fill_rect(Rect2i(3 * tile + 12, 1 * tile + 40, tile - 24, tile - 40), Color(0.55, 0.2, 0.65))
	img.fill_rect(Rect2i(3 * tile + 44, 1 * tile + 70, 40, 60), Color(0.1, 0.0, 0.15))
	var keep := Rect2i(3 * tile - 20, 6 * tile - 40, tile + 40, tile + 60)
	img.fill_rect(keep, Color(0.2, 0.3, 0.55))
	img.fill_rect(keep.grow(-16), Color(0.35, 0.5, 0.85))
	for i in 4:
		img.fill_rect(Rect2i(keep.position.x + 8 + i * 44, keep.position.y - 30, 30, 36), Color(0.2, 0.3, 0.55))
	img.fill_rect(Rect2i(keep.position.x + keep.size.x / 2 - 24, keep.position.y + 60, 48, keep.size.y - 60), Color(0.12, 0.18, 0.35))
	# Flag.
	var fx := keep.position.x + keep.size.x / 2
	img.fill_rect(Rect2i(fx - 6, keep.position.y - 170, 12, 150), Color(0.52, 0.35, 0.2))
	for y in 90:
		var w := int(120.0 * (1.0 - y / 90.0 * 0.4))
		img.fill_rect(Rect2i(fx + 6, keep.position.y - 170 + y, w, 1), Color(1.0, 0.82, 0.35))
	# Rounded corners (iOS masks anyway, but keeps previews tidy).
	var radius := 180
	for y in s:
		for x in s:
			var dx := maxi(radius - x, x - (s - 1 - radius))
			var dy := maxi(radius - y, y - (s - 1 - radius))
			if dx > 0 and dy > 0 and Vector2(dx, dy).length() > radius:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.save_png("res://assets/icons/icon.png")
	print("icon written")
	quit()
