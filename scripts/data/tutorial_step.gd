class_name TutorialStep
extends Resource
## One prompt in a level's interactive tutorial. Shown when `trigger` happens,
## dismissed by the player or automatically once `done_when` happens.

enum Trigger { LEVEL_START, TOWER_BUILT, WALL_BUILT, WAVE_STARTED, WAVE_CLEARED, INVALID_PLACEMENT, STRUCTURE_SOLD, TOWER_UPGRADED }

@export_multiline var text: String
@export var trigger: Trigger = Trigger.LEVEL_START
## Tile to highlight, or (-1, -1) for none.
@export var highlight: Vector2i = Vector2i(-1, -1)
## Which wave (1-based) the trigger applies to for wave triggers; 0 for any.
@export var wave: int = 0
