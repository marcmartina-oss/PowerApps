class_name EnemyData
extends Resource
## Static definition of an enemy type. Speed is in tiles per second.
## Behaviour flags combine: a Lich is a healer that phases through walls.

enum Look { GOBLIN, WOLF, ORC, KNIGHT, BAT, SAPPER, SLIME, SHAMAN, GHOST, TROLL, DRAGON, LICH }

@export var id: StringName
@export var display_name: String
@export var max_health: float = 30.0
@export var speed: float = 1.5
## Fraction of physical damage ignored (0 to 1). Magic halves armor; true damage ignores it.
@export_range(0.0, 1.0) var armor: float = 0.0
@export var lives_cost: int = 1
@export var gold_reward: int = 3
## Body radius as a fraction of a tile.
@export var radius: float = 0.25
@export var look: Look = Look.GOBLIN
@export var color: Color = Color.WHITE
@export var is_boss: bool = false

@export_group("Behaviour")
## Flies straight to the keep, ignoring the maze.
@export var flying: bool = false
## Walks through walls, stopping to smash each one (Sapper, Troll King).
@export var breaks_walls: bool = false
## Seconds spent smashing one wall.
@export var smash_time: float = 2.0
## Passes through walls without destroying them, one wall per phase_interval (Ghost, Lich).
@export var phases_walls: bool = false
@export var phase_interval: float = 4.0
## Heals nearby enemies (Shaman, Lich).
@export var heal_amount: float = 0.0
@export var heal_radius: float = 1.5
@export var heal_interval: float = 2.0
## Spawns this many copies of split_into where it dies (Slime).
@export var split_into: EnemyData
@export var split_count: int = 2


func is_ground() -> bool:
	return not flying


func ignores_walls() -> bool:
	return breaks_walls or phases_walls
