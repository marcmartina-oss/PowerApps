class_name EnemyData
extends Resource
## Static definition of an enemy type. Speed is in tiles per second.

@export var id: StringName
@export var display_name: String
@export var max_health: float = 30.0
@export var speed: float = 1.5
## Fraction of physical damage ignored (0 to 1). Magic damage ignores armor.
@export_range(0.0, 1.0) var armor: float = 0.0
@export var lives_cost: int = 1
@export var gold_reward: int = 3
@export var flying: bool = false
## Body radius as a fraction of a tile.
@export var radius: float = 0.25
@export var color: Color = Color.WHITE
