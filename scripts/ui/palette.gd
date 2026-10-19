class_name Palette
extends RefCounted
## Colours for the whole game: one ground palette per world plus the shared UI theme.

const GOLD := Color(1.0, 0.82, 0.35)
const PARCHMENT := Color(0.93, 0.87, 0.74)
const INK := Color(0.12, 0.09, 0.07)
const WOOD := Color(0.36, 0.23, 0.14)
const WOOD_LIGHT := Color(0.52, 0.35, 0.2)
const LIVES := Color(1.0, 0.45, 0.45)
const WALL := Color(0.62, 0.47, 0.33)
const WALL_DARK := Color(0.36, 0.26, 0.17)
const KEEP := Color(0.35, 0.5, 0.85)
const GATE := Color(0.55, 0.2, 0.65)
const ROUTE := Color(1, 1, 1, 0.3)
const PREVIEW_ROUTE := Color(1.0, 0.85, 0.2, 0.95)
const VALID := Color(0.3, 1.0, 0.4, 0.4)
const INVALID := Color(1.0, 0.2, 0.2, 0.55)

## Ground colours per world: [base, alt, detail, water, rock]
const WORLDS: Array = [
	[Color(0.38, 0.58, 0.3), Color(0.34, 0.54, 0.27), Color(0.5, 0.7, 0.35), Color(0.3, 0.55, 0.75), Color(0.5, 0.5, 0.5)],
	[Color(0.25, 0.38, 0.3), Color(0.22, 0.34, 0.28), Color(0.4, 0.5, 0.3), Color(0.2, 0.35, 0.38), Color(0.42, 0.44, 0.42)],
	[Color(0.42, 0.38, 0.36), Color(0.38, 0.34, 0.33), Color(0.55, 0.45, 0.4), Color(0.95, 0.4, 0.1), Color(0.3, 0.28, 0.3)],
]

const WORLD_SKY: Array[Color] = [Color(0.1, 0.14, 0.1), Color(0.07, 0.1, 0.11), Color(0.14, 0.09, 0.09)]


static func world(index: int) -> Array:
	return WORLDS[clampi(index - 1, 0, WORLDS.size() - 1)]


static func sky(index: int) -> Color:
	return WORLD_SKY[clampi(index - 1, 0, WORLD_SKY.size() - 1)]
