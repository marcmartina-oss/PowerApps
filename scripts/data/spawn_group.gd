class_name SpawnGroup
extends Resource
## A run of identical enemies within a wave.

@export var enemy: EnemyData
@export var count: int = 5
@export var interval: float = 1.0
@export var start_delay: float = 0.0
@export var gate_index: int = 0
