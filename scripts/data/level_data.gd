class_name LevelData
extends Resource
## One playable map: layout, starting resources, towers on offer and waves.

@export var id: StringName
@export var display_name: String
@export var grid_size: Vector2i = Vector2i(9, 14)
@export var gates: Array[Vector2i] = []
@export var keep: Vector2i
## Unbuildable, impassable terrain (rock, water, ruins).
@export var rocks: Array[Vector2i] = []
@export var starting_gold: int = 150
@export var starting_lives: int = 20
@export var wall_cost: int = 5
@export var available_towers: Array[TowerData] = []
@export var waves: Array[WaveData] = []
