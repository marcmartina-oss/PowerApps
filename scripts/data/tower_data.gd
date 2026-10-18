class_name TowerData
extends Resource
## Static definition of a tower type. Ranges and speeds are in tiles.

enum DamageType { PHYSICAL, MAGIC }

@export var id: StringName
@export var display_name: String
@export var cost: int = 50
@export var damage: float = 10.0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var attack_range: float = 2.5
@export var fire_interval: float = 1.0
@export var projectile_speed: float = 12.0
## 0 means single target (homing). Above 0, the shot lands where the target was and hits everything in the radius.
@export var splash_radius: float = 0.0
@export var hits_flyers: bool = true
@export var color: Color = Color.WHITE
