extends Node
## Autoload "Save": stars, unlocks, skill tree, settings and purchase state,
## stored in user://save.cfg. Everything is keyed by level id so the campaign
## can be reordered without losing progress.

signal changed

const PATH := "user://save.cfg"

## Skill tree: each track has 3 ranks, unlocked by total stars.
const SKILLS: Array[Dictionary] = [
	{"id": "gold", "name": "Deep Coffers", "desc": "+%d starting gold", "per_rank": 25, "costs": [3, 12, 30]},
	{"id": "walls", "name": "Master Masons", "desc": "Walls cost %d less", "per_rank": 1, "costs": [6, 18, 40]},
	{"id": "range", "name": "Keen Eyes", "desc": "+%.1f tile tower range", "per_rank": 0.2, "costs": [9, 24, 50]},
]

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)


func save() -> void:
	_cfg.save(PATH)
	changed.emit()


# --- Progress ---

func stars_for(level_id: StringName) -> int:
	return _cfg.get_value("stars", String(level_id), 0)


func record_result(level_id: StringName, stars: int) -> void:
	if stars > stars_for(level_id):
		_cfg.set_value("stars", String(level_id), stars)
		save()


func total_stars() -> int:
	var total := 0
	if _cfg.has_section("stars"):
		for key in _cfg.get_section_keys("stars"):
			total += int(_cfg.get_value("stars", key, 0))
	return total


func endless_best(map_id: StringName) -> int:
	return _cfg.get_value("endless", String(map_id), 0)


func record_endless(map_id: StringName, waves: int) -> void:
	if waves > endless_best(map_id):
		_cfg.set_value("endless", String(map_id), waves)
		save()


# --- Skill tree ---

func skill_rank(skill_id: String) -> int:
	for skill in SKILLS:
		if skill.id == skill_id:
			var rank := 0
			for cost: int in skill.costs:
				if total_stars() >= cost:
					rank += 1
			return rank
	return 0


func bonus_gold() -> int:
	return skill_rank("gold") * 25


func wall_discount() -> int:
	return skill_rank("walls")


func bonus_range() -> float:
	return skill_rank("range") * 0.2


# --- Settings ---

func get_setting(key: String, default: Variant) -> Variant:
	return _cfg.get_value("settings", key, default)


func set_setting(key: String, value: Variant) -> void:
	_cfg.set_value("settings", key, value)
	save()


func music_on() -> bool:
	return get_setting("music", true)


func sfx_on() -> bool:
	return get_setting("sfx", true)


func tutorial_done() -> bool:
	return get_setting("tutorial_done", false)


func set_tutorial_done(done: bool) -> void:
	set_setting("tutorial_done", done)


# --- Purchase ---

func is_purchased() -> bool:
	return _cfg.get_value("purchase", "full_game", false)


func set_purchased(purchased: bool) -> void:
	_cfg.set_value("purchase", "full_game", purchased)
	save()


func unlock_prompt_shown() -> bool:
	return _cfg.get_value("purchase", "prompt_shown", false)


func set_unlock_prompt_shown() -> void:
	_cfg.set_value("purchase", "prompt_shown", true)
	save()


## Wipes everything (Settings → Reset progress).
func reset() -> void:
	_cfg = ConfigFile.new()
	save()
