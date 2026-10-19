class_name CampaignData
extends Resource
## Every level in the game, in order, plus the other modes' maps.

const WORLD_NAMES: Array[String] = ["The Borderlands", "The Haunted Marsh", "The Dragon Peaks"]
const LEVELS_PER_WORLD := 10
## Levels playable without the full-game unlock.
const FREE_LEVELS := 5

@export var levels: Array[LevelData] = []
@export var endless_maps: Array[LevelData] = []
@export var challenges: Array[LevelData] = []
## Total stars needed to unlock each challenge, in order.
@export var challenge_star_costs: Array[int] = []


func level_by_number(number: int) -> LevelData:
	for level in levels:
		if level.number == number:
			return level
	return null


func world_levels(world: int) -> Array[LevelData]:
	var result: Array[LevelData] = []
	for level in levels:
		if level.world == world:
			result.append(level)
	return result
