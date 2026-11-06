class_name ScoreSystem
extends RefCounted
## Pure run scoring: distance points, hazard passes, and School Items.
##
## The combo multiplier is built only by School Items. It resets when the player
## is hit or lets an item scroll past. No scene tree is touched here, so the
## headless suite can assert the whole scoring model directly.

signal score_changed(score: int)
signal combo_changed(multiplier: int, chain: int)
signal item_count_changed(count: int)

var score: int = 0
var item_count: int = 0
var chain: int = 0

var _distance_points: int = 0


## Award the distance trickle for total [param distance] travelled.
func add_distance(distance: float) -> void:
	var points := int(floor(distance / GameConfig.SCORE_DISTANCE_DIVISOR))
	if points <= _distance_points:
		return
	score += points - _distance_points
	_distance_points = points
	score_changed.emit(score)


## Award the flat bonus for a hazard that scrolled past without hitting.
func add_hazard_passed() -> void:
	score += GameConfig.SCORE_PER_HAZARD
	score_changed.emit(score)


## Count one School Item and score it with the current multiplier.
func add_item_pickup() -> void:
	item_count += 1
	chain += 1
	score += GameConfig.SCORE_PER_ITEM * GameConfig.combo_multiplier(chain)
	item_count_changed.emit(item_count)
	combo_changed.emit(GameConfig.combo_multiplier(chain), chain)
	score_changed.emit(score)


## Break the pickup chain (damage or a missed item). Items are not lost.
func reset_combo() -> void:
	if chain == 0:
		return
	chain = 0
	combo_changed.emit(GameConfig.combo_multiplier(chain), chain)
