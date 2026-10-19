class_name TowerSpec
extends Resource
## One of the two tier-3 specializations a tower can take.

enum Kind {
	LONGBOW,   ## + range
	VOLLEY,    ## fires at several targets at once
	BOULDER,   ## bigger splash
	QUAKE,     ## splash also stuns
	BLIZZARD,  ## slow becomes an area around the tower
	SHATTER,   ## bonus damage to slowed enemies
	INFERNO,   ## wider burn range
	WILDFIRE,  ## burn spreads to nearby enemies
	LIGHTNING, ## chains to nearby enemies
	VOID,      ## true damage, ignores armor fully
	RALLY,     ## adjacent towers fire faster
	BOUNTY,    ## adjacent towers' kills pay extra gold
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.LONGBOW
## Meaning depends on kind: extra range in tiles, number of targets, chain count,
## damage multiplier, buff fraction...
@export var value: float = 1.0
