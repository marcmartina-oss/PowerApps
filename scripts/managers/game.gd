extends Node
## Autoload "Game": campaign data, screen navigation and what the player is
## allowed to play. Scenes ask Game to move between screens so the flow is in
## one place.

const CAMPAIGN := preload("res://data/campaign.tres")
const SCENES := {
	"title": "res://scenes/ui/title.tscn",
	"worlds": "res://scenes/ui/world_map.tscn",
	"level": "res://scenes/level/level.tscn",
	"settings": "res://scenes/ui/settings.tscn",
	"skills": "res://scenes/ui/skill_tree.tscn",
	"unlock": "res://scenes/ui/unlock.tscn",
	"modes": "res://scenes/ui/modes.tscn",
}

var campaign: CampaignData = CAMPAIGN
## The level the Level scene loads when it starts.
var current_level: LevelData
## Where to return after the current screen (e.g. the unlock screen).
var return_to := "worlds"


func go(screen: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(SCENES[screen])


func play(level: LevelData) -> void:
	current_level = level
	go("level")


func is_level_unlocked(level: LevelData) -> bool:
	if level.mode != LevelData.Mode.CAMPAIGN:
		return true
	if level.number == 1:
		return true
	var previous := campaign.level_by_number(level.number - 1)
	return previous != null and Save.stars_for(previous.id) > 0


func is_level_free(level: LevelData) -> bool:
	return level.mode != LevelData.Mode.CAMPAIGN or level.number <= CampaignData.FREE_LEVELS


func can_play(level: LevelData) -> bool:
	return is_level_unlocked(level) and (is_level_free(level) or IAP.is_unlocked())


func next_level(level: LevelData) -> LevelData:
	return campaign.level_by_number(level.number + 1) if level.mode == LevelData.Mode.CAMPAIGN else null


func is_challenge_unlocked(index: int) -> bool:
	if index >= campaign.challenge_star_costs.size():
		return true
	return Save.total_stars() >= campaign.challenge_star_costs[index]


## True when the one-time unlock prompt should appear after this level.
func should_prompt_unlock(level: LevelData) -> bool:
	return level.mode == LevelData.Mode.CAMPAIGN and level.number == CampaignData.FREE_LEVELS \
		and not IAP.is_unlocked() and not Save.unlock_prompt_shown()
