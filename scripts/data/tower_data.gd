class_name TowerData
extends Resource
## Static definition of a tower type. Ranges are in tiles, intervals in seconds.
## Tier 2 and 3 scale the base stats; tier 3 also picks one of two specializations.

enum DamageType { PHYSICAL, MAGIC, TRUE }
enum Effect { NONE, SLOW, BURN, BUFF }
enum Look { ARCHER, STONE, FROST, FLAME, ARCANE, BANNER }

const MAX_TIER := 3

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cost: int = 50
@export var damage: float = 10.0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var attack_range: float = 2.5
@export var fire_interval: float = 1.0
@export var projectile_speed: float = 12.0
## 0 means single target (homing). Above 0, the shot lands where the target was and hits everything in the radius.
@export var splash_radius: float = 0.0
@export var hits_flyers: bool = true
@export var look: Look = Look.ARCHER
@export var color: Color = Color.WHITE

@export_group("Status effect")
@export var effect: Effect = Effect.NONE
## Slow: speed multiplier (0.5 = half speed). Burn: damage per second. Buff: attack-speed fraction.
@export var effect_strength: float = 0.0
@export var effect_duration: float = 2.0

@export_group("Upgrades")
## Gold for tier 2 and tier 3.
@export var upgrade_costs: Array[int] = [60, 110]
## Damage multiplier per tier above 1 (applied cumulatively).
@export var upgrade_damage_mult: float = 1.5
## Extra range in tiles per tier above 1.
@export var upgrade_range_add: float = 0.3
@export var spec_a: TowerSpec
@export var spec_b: TowerSpec


func upgrade_cost(current_tier: int) -> int:
	return upgrade_costs[current_tier - 1] if current_tier < MAX_TIER else 0


## Total gold spent on a tower of this type at `tier`, for refunds.
func total_cost(tier: int) -> int:
	var total := cost
	for t in range(1, tier):
		total += upgrade_costs[t - 1]
	return total


func damage_at(tier: int) -> float:
	return damage * pow(upgrade_damage_mult, tier - 1)


func range_at(tier: int) -> float:
	return attack_range + upgrade_range_add * (tier - 1)
