class_name LevelData
extends Resource
## One playable map: layout, starting resources, towers on offer, rules and waves.

enum Mode { CAMPAIGN, ENDLESS, CHALLENGE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var mode: Mode = Mode.CAMPAIGN
## 1-based world index; sets the palette and music.
@export var world: int = 1
## 1-based position within the campaign; 0 for other modes.
@export var number: int = 0
@export var grid_size: Vector2i = Vector2i(9, 14)
@export var gates: Array[Vector2i] = []
## Gates used on odd waves when shifting_gates is on (World 3).
@export var alt_gates: Array[Vector2i] = []
@export var shifting_gates: bool = false
@export var keep: Vector2i
## Unbuildable, impassable terrain. `rocks` draw as stone, `water` as water, `ruins` as broken stone.
@export var rocks: Array[Vector2i] = []
@export var water: Array[Vector2i] = []
@export var ruins: Array[Vector2i] = []
@export var starting_gold: int = 150
@export var starting_lives: int = 20
@export var wall_cost: int = 5
## Maximum walls that may stand at once; -1 for unlimited.
@export var wall_budget: int = -1
@export var walls_allowed: bool = true
## Game speed multiplier applied on top of the player's choice (Challenge: double speed).
@export var speed_multiplier: float = 1.0
@export var available_towers: Array[TowerData] = []
@export var waves: Array[WaveData] = []
## Endless mode: waves beyond the list are generated from this pool, scaling up forever.
@export var endless_pool: Array[EnemyData] = []
@export var tutorial: Array[TutorialStep] = []
## Towers first made available by beating this level (for the win screen).
@export var unlocks_towers: Array[TowerData] = []


func blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.append_array(rocks)
	cells.append_array(water)
	cells.append_array(ruins)
	return cells


func is_endless() -> bool:
	return mode == Mode.ENDLESS
