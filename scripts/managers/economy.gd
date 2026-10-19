class_name Economy
extends RefCounted
## Gold, keep lives, refunds and star rating.

signal gold_changed(gold: int)
signal lives_changed(lives: int)

const REFUND_RATE := 0.7

var gold := 0
var lives := 0
var starting_lives := 0
var total_earned := 0


func setup(start_gold: int, start_lives: int) -> void:
	gold = start_gold
	lives = start_lives
	starting_lives = start_lives
	total_earned = 0
	gold_changed.emit(gold)
	lives_changed.emit(lives)


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true


func earn(amount: int) -> void:
	gold += amount
	total_earned += amount
	gold_changed.emit(gold)


static func refund_value(cost: int) -> int:
	return floori(cost * REFUND_RATE)


func lose_lives(amount: int) -> void:
	lives = maxi(lives - amount, 0)
	lives_changed.emit(lives)


func is_defeated() -> bool:
	return lives <= 0


## 3 stars: no lives lost. 2 stars: lost up to half. 1 star: survived.
func stars() -> int:
	if lives <= 0:
		return 0
	var lost := starting_lives - lives
	if lost == 0:
		return 3
	if lost * 2 <= starting_lives:
		return 2
	return 1
