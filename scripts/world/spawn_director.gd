class_name SpawnDirector
extends Node
## Spawns hazard rows ahead of the player and School Items on their own clock.
##
## Timing is expressed in travelled distance rather than wall-clock seconds so
## the course density stays identical when RUN_SPEED changes in M5. Patterns are
## pure static functions so the headless fuzz suite can hammer them without a
## scene tree.

signal hazard_passed
signal item_missed
## Fired once when a car warning starts, so the world can honk while the
## exclamation is still on screen (the warning node frees itself at the end
## of the hold, which would cut a honk owned by it).
signal car_warning_started(lane: int, variant: int)
## Fired once when the car actually spawns (warning finished), so the world
## can start the engine pass-by exactly as the car enters the world.
signal car_entered(lane: int, variant: int)
## Fired when a dog warning starts: cue 1, the double-bark telegraph.
signal dog_warning_started(lane: int, variant: int)
## Fired as the dog crosses a DOG_BARK_X screen position: cues 2-3.
signal dog_barked(index: int, variant: int)

const HAZARD_SCENE := preload("res://scenes/hazard.tscn")
const COLLECTIBLE_SCENE := preload("res://scenes/collectible.tscn")
const WARNING_SCENE := preload("res://scenes/hazard_warning.tscn")
const DOG_WARNING_TEXTURE := preload(
	"res://assets/signs/exclamation/Exclamation Mark 1st Outline 64px.png")
const CAR_WARNING_TEXTURE := preload(
	"res://assets/signs/exclamation/Exclamation Mark 2nd Outline 64px.png")

var hazards: Node2D = null
var _rng := RandomNumberGenerator.new()
var _distance_since_row: float = GameConfig.ROW_GAP_START
var _distance_since_pickup: float = 0.0
var _pickup_gap: float = 0.0
## Luck upgrade: pickup and coin-run gaps shrink by this factor (<= 1.0).
var _luck_gap_factor: float = 1.0
## Speed upgrade: hazard rows spread out by the same factor the world speeds
## up, so faster runs get the same hazard RATE instead of a hidden difficulty
## spike (see GameConfig.shop_row_gap_scale).
var _speed_gap_scale: float = 1.0
## Coin-run clock: one trail of 3-5 coins in a single reserved lane.
var _distance_since_coin_run: float = 0.0
var _next_coin_run_gap: float = GameConfig.COIN_RUN_GAP_MIN
var _coin_run_lane: int = -1
var _coin_run_coins: Array = []
var _next_dog_distance: float = GameConfig.DOG_FIRST_DISTANCE
var _dog_reserved_lane: int = -1
var _dog_warning: HazardWarning = null
var _active_dog: Hazard = null
## Variant of the dog currently running (fixed at its spawn), used for the
## chase-bark pitch.
var _active_dog_variant: int = 0
## How many chase barks (DOG_BARK_X cues) have fired for the active dog.
var _dog_barks_fired: int = 0
var _next_dog_variant: int = 0
var _dog_speed: float = GameConfig.RUN_SPEED
## Cars warn first: one pending entry per warned lane
## {lane: int, speed: float, variant: int, warning: HazardWarning}.
var _car_warnings: Array[Dictionary] = []
## Cooldown clock for car warnings: the travelled distance at which another
## car may be considered. Reset to CAR_FIRST_DISTANCE by setup().
var _next_car_distance: float = GameConfig.CAR_FIRST_DISTANCE

## Tuning knobs, editable in the Inspector of the SpawnDirector node in
## run_world.tscn. Defaults come from GameConfig so tests and code use the
## same numbers.
@export_range(0.0, 30000.0, 100.0) var car_first_distance_px: float = GameConfig.CAR_FIRST_DISTANCE
@export_range(0.0, 30000.0, 100.0) var car_gap_min_px: float = GameConfig.CAR_GAP_MIN
@export_range(0.0, 30000.0, 100.0) var car_gap_max_px: float = GameConfig.CAR_GAP_MAX
## Dog encounter timing, mirrored from GameConfig so it can be tuned in the
## SpawnDirector Inspector just like the car (both clocks are distance-based).
@export_range(0.0, 30000.0, 100.0) var dog_first_distance_px: float = GameConfig.DOG_FIRST_DISTANCE
@export_range(0.0, 30000.0, 100.0) var dog_gap_min_px: float = GameConfig.DOG_GAP_MIN
@export_range(0.0, 30000.0, 100.0) var dog_gap_max_px: float = GameConfig.DOG_GAP_MAX


## Attach to the container that receives hazard instances.
func setup(parent: Node2D, seed_value: int = 0) -> void:
	hazards = parent
	_rng.seed = seed_value
	# Luck upgrade makes both item clocks denser.
	_luck_gap_factor = GameConfig.shop_luck_gap_factor(
		GameState.shop_level(GameConfig.ShopUpgrade.LUCK))
	# Speed upgrade widens the rows by the same factor it raises speed.
	_speed_gap_scale = GameConfig.shop_row_gap_scale(
		GameState.shop_level(GameConfig.ShopUpgrade.SPEED))
	_pickup_gap = _rng.randf_range(GameConfig.PICKUP_GAP_MIN, GameConfig.PICKUP_GAP_MAX) \
		* _luck_gap_factor
	_next_coin_run_gap = _rng.randf_range(
		GameConfig.COIN_RUN_GAP_MIN, GameConfig.COIN_RUN_GAP_MAX) * _luck_gap_factor
	_distance_since_coin_run = 0.0
	_coin_run_lane = -1
	_coin_run_coins = []
	_next_dog_distance = dog_first_distance_px
	_dog_reserved_lane = -1
	_dog_warning = null
	_active_dog = null
	_next_dog_variant = 0
	_dog_speed = GameConfig.RUN_SPEED
	_car_warnings = []
	_next_car_distance = car_first_distance_px


## Cancel specials that cannot legally cross a zone boundary, while leaving
## zone-agnostic row/pickup/coin clocks intact. Warning nodes are freed so their
## async finished callbacks cannot spawn a dog or car after the art has swapped.
func reset_for_zone_swap(distance: float) -> void:
	var had_dog_warning := is_instance_valid(_dog_warning) \
		and not _dog_warning.is_queued_for_deletion()
	var had_active_dog := is_instance_valid(_active_dog) \
		and not _active_dog.is_queued_for_deletion()
	if had_dog_warning:
		_dog_warning.queue_free()
	if had_active_dog:
		_active_dog.queue_free()

	_dog_warning = null
	_active_dog = null
	_active_dog_variant = 0
	_dog_barks_fired = 0
	_dog_reserved_lane = -1
	if had_dog_warning or had_active_dog:
		_next_dog_distance = distance + _rng.randf_range(
			dog_gap_min_px,
			dog_gap_max_px,
		)

	for i in range(_car_warnings.size() - 1, -1, -1):
		var entry: Dictionary = _car_warnings[i]
		var warning = entry.get("warning")
		if is_instance_valid(warning):
			var warning_node := warning as Node
			if is_instance_valid(warning_node) and not warning_node.is_queued_for_deletion():
				warning_node.queue_free()
	_car_warnings = []
	_next_car_distance = distance + _rng.randf_range(
		minf(car_gap_min_px, car_gap_max_px),
		maxf(car_gap_min_px, car_gap_max_px),
	)
	_refresh_coin_reservation()


## Advance the spawn clock. Call once per physics frame with the world speed.
## [param zone] gates zone-restricted kinds (HOME furniture, street-only
## dog/car). [param home_length] is the run's home length in px, scaling the
## home kinds' fractional unlock distances; -1 falls back to the default.
## [param mode] lets endless play keep tightening the rows past the campaign
## ramp instead of plateauing.
func tick(
	delta: float,
	speed: float,
	distance: float,
	zone: int = -1,
	home_length: float = -1.0,
	mode: int = GameConfig.RunMode.CAMPAIGN,
) -> void:
	if hazards == null:
		return
	_refresh_dog_reservation()
	_update_dog_barks()
	_refresh_coin_reservation()
	if distance >= _next_dog_distance and _dog_reserved_lane < 0:
		_try_start_dog_encounter(distance, speed, zone)

	_distance_since_row += speed * delta
	var gap := GameConfig.row_gap(distance, mode) * _speed_gap_scale
	while _distance_since_row >= gap:
		_distance_since_row -= gap
		spawn_row(distance, speed, zone, home_length)
		gap = GameConfig.row_gap(distance, mode) * _speed_gap_scale

	_distance_since_pickup += speed * delta
	while _distance_since_pickup >= _pickup_gap:
		_distance_since_pickup -= _pickup_gap
		spawn_pickup(distance, speed)
		_pickup_gap = _rng.randf_range(GameConfig.PICKUP_GAP_MIN, GameConfig.PICKUP_GAP_MAX) \
			* _luck_gap_factor

	_distance_since_coin_run += speed * delta
	if _distance_since_coin_run >= _next_coin_run_gap and _coin_run_lane < 0:
		_distance_since_coin_run = 0.0
		spawn_coin_run(distance, speed)
		_next_coin_run_gap = _rng.randf_range(
			GameConfig.COIN_RUN_GAP_MIN, GameConfig.COIN_RUN_GAP_MAX) * _luck_gap_factor


## Spawn one row, leaving the active dog's lane, any live coin-run lane, and
## any pending car-warning lane out of the hazard pattern, so special hazards
## never share their lane with a row hazard.
## [param zone] gates zone-restricted kinds (HOME furniture, street-only
## dog/car).
## Returns the blocked lanes.
func spawn_row(
	distance: float,
	speed: float = GameConfig.RUN_SPEED,
	zone: int = -1,
	home_length: float = -1.0,
) -> Array[int]:
	var lanes := generate_pattern(
		distance, _rng, _dog_reserved_lane, _coin_run_lane, _car_reserved_lanes())
	# At most one car per row, and only when the cooldown allows one.
	var allow_car := _car_allowed(distance, zone)
	for lane in lanes:
		var kind := pick_kind(distance, _rng, zone, allow_car, home_length)
		if kind == GameConfig.HazardKind.CAR:
			_start_car_warning(lane, speed)
			allow_car = false
			_next_car_distance = distance + _rng.randf_range(
				minf(car_gap_min_px, car_gap_max_px),
				maxf(car_gap_min_px, car_gap_max_px),
			)
			continue
		var hazard := HAZARD_SCENE.instantiate() as Hazard
		hazards.add_child(hazard)
		hazard.setup(kind, lane, speed)
		hazard.position.x = GameConfig.SPAWN_X
		hazard.passed_player.connect(_on_hazard_passed)
	return lanes


## Spawn one School Item on a lane clear of nearby hazards.
## Returns the lane used, or -1 when the pickup was skipped.
func spawn_pickup(distance: float, speed: float = GameConfig.RUN_SPEED) -> int:
	var occupied := _occupied_pickup_lanes()
	for lane in _car_reserved_lanes():
		if not occupied.has(lane):
			occupied.append(lane)

	var lane := choose_pickup_lane(occupied, _rng)
	if lane < 0:
		return -1

	var kinds: Array[GameConfig.ItemKind] = [
		GameConfig.ItemKind.PENCIL,
		GameConfig.ItemKind.ERASER,
		GameConfig.ItemKind.BOOK,
		GameConfig.ItemKind.BAG,
		GameConfig.ItemKind.SHARPENER,
		GameConfig.ItemKind.RULER,
		GameConfig.ItemKind.CALCULATOR,
	]
	var item := COLLECTIBLE_SCENE.instantiate() as Collectible
	hazards.add_child(item)
	item.setup(kinds[_rng.randi() % kinds.size()], lane, speed)
	item.position.x = GameConfig.SPAWN_X
	item.missed.connect(_on_item_missed)
	return lane


## Spawn one coin run: COIN_RUN_MIN..COIN_RUN_MAX coins in a single clear lane,
## all at once, spaced COIN_SPACING px apart so they scroll past as a trail.
## The lane is reserved - hazard rows avoid it until every coin is gone.
## Returns the lane used, or -1 when the run was skipped.
func spawn_coin_run(distance: float, speed: float = GameConfig.RUN_SPEED) -> int:
	if _coin_run_lane >= 0:
		return -1
	var occupied := _occupied_pickup_lanes()
	if _dog_reserved_lane >= 0 and not occupied.has(_dog_reserved_lane):
		occupied.append(_dog_reserved_lane)
	for lane in _car_reserved_lanes():
		if not occupied.has(lane):
			occupied.append(lane)
	var lane := choose_pickup_lane(occupied, _rng)
	if lane < 0:
		return -1

	var count := _rng.randi_range(GameConfig.COIN_RUN_MIN, GameConfig.COIN_RUN_MAX)
	for i in count:
		var coin := COLLECTIBLE_SCENE.instantiate() as Collectible
		hazards.add_child(coin)
		coin.setup(GameConfig.ItemKind.COIN, lane, speed)
		coin.position.x = GameConfig.SPAWN_X + float(i) * GameConfig.COIN_SPACING
		_coin_run_coins.append(coin)
	_coin_run_lane = lane
	return lane


# --- Street cars (warn, then enter fast) -------------------------------------

## True when another car warning may start at [param distance]: only in the
## street zone, never while one warning is pending, and only after the
## cooldown gap since the previous warning.
func _car_allowed(distance: float, zone: int) -> bool:
	if zone != GameConfig.Zone.STREET:
		return false
	if not _car_warnings.is_empty():
		return false
	return distance >= _next_car_distance


## Lanes with a car warning still showing. Rows, pickups, and coin runs keep
## out of them so nothing shares the car's lane before it arrives.
func _car_reserved_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for entry in _car_warnings:
		if not lanes.has(int(entry["lane"])):
			lanes.append(int(entry["lane"]))
	return lanes


## Show the exclamation in [param lane], then spawn the car when it finishes.
func _start_car_warning(lane: int, speed: float) -> void:
	var variant := _rng.randi() % GameConfig.CAR_VARIANTS.size()
	var warning := WARNING_SCENE.instantiate() as HazardWarning
	warning.setup(CAR_WARNING_TEXTURE, GameConfig.CAR_WARNING_DURATION)
	warning.position = Vector2(
		GameConfig.CAR_WARNING_X,
		GameConfig.lane_y(lane) - GameConfig.CAR_WARNING_Y_OFFSET,
	)
	hazards.add_child(warning)
	warning.play()
	warning.finished.connect(_on_car_warning_finished.bind(lane))
	# One honk per car: _car_allowed refuses to start a second warning while
	# this one is pending, so honks can never overlap.
	car_warning_started.emit(lane, variant)
	_car_warnings.append({
		"lane": lane, "speed": speed, "variant": variant, "warning": warning,
	})


func _on_car_warning_finished(lane: int) -> void:
	# Take the pending entry for this lane, then spawn the car it announced.
	# (The warning node frees itself after emitting finished.)
	var entry: Dictionary = {}
	for i in range(_car_warnings.size() - 1, -1, -1):
		if int(_car_warnings[i]["lane"]) == lane:
			entry = _car_warnings[i]
			_car_warnings.remove_at(i)
			break
	if hazards == null:
		return
	var car := HAZARD_SCENE.instantiate() as Hazard
	hazards.add_child(car)
	car.setup(
		GameConfig.HazardKind.CAR,
		lane,
		float(entry.get("speed", GameConfig.RUN_SPEED)),
		int(entry.get("variant", 0)),
	)
	car.position.x = GameConfig.SPAWN_X
	car.passed_player.connect(_on_hazard_passed)
	car_entered.emit(lane, int(entry.get("variant", 0)))


func _try_start_dog_encounter(distance: float, speed: float, zone: int = -1) -> bool:
	# The dog encounter clock bypasses pick_kind, so the house gate lives here:
	# the dog waits while Elias is indoors and starts on the first outdoor
	# frame. Only HOME is excluded - the house is furniture-only.
	if zone == GameConfig.Zone.HOME:
		return false
	var occupied := _occupied_dog_entry_lanes()
	var dog_lane := choose_dog_lane(occupied, _rng)
	if dog_lane < 0:
		return false

	_dog_reserved_lane = dog_lane
	_dog_speed = speed
	_next_dog_distance = distance + _rng.randf_range(
		dog_gap_min_px,
		dog_gap_max_px,
	)

	var warning := WARNING_SCENE.instantiate() as HazardWarning
	warning.setup(DOG_WARNING_TEXTURE, GameConfig.DOG_WARNING_DURATION)
	warning.position = Vector2(
		GameConfig.DOG_WARNING_X,
		GameConfig.lane_y(_dog_reserved_lane) - GameConfig.DOG_WARNING_Y_OFFSET,
	)
	hazards.add_child(warning)
	_dog_warning = warning
	warning.finished.connect(_on_dog_warning_finished, CONNECT_ONE_SHOT)
	warning.play()
	# Cue 1: the double-bark telegraph, right as the exclamation appears.
	dog_warning_started.emit(_dog_reserved_lane, _next_dog_variant)
	return true


func _occupied_dog_entry_lanes() -> Array[int]:
	var occupied: Array[int] = []
	# A pending car warning owns its lane; never send the dog there.
	for lane in _car_reserved_lanes():
		if not occupied.has(lane):
			occupied.append(lane)
	var min_x := GameConfig.SPAWN_X - GameConfig.DOG_LANE_ENTRY_CLEARANCE
	for child in hazards.get_children():
		if not (child is Hazard or child is Collectible):
			continue
		if child.position.x < min_x:
			continue
		if child is Hazard:
			var hazard := child as Hazard
			if not occupied.has(hazard.lane):
				occupied.append(hazard.lane)
		else:
			var item := child as Collectible
			if not occupied.has(item.lane):
				occupied.append(item.lane)
	return occupied


func _on_dog_warning_finished() -> void:
	_dog_warning = null
	if hazards == null or _dog_reserved_lane < 0:
		return

	var dog := HAZARD_SCENE.instantiate() as Hazard
	hazards.add_child(dog)
	dog.setup(GameConfig.HazardKind.DOG, _dog_reserved_lane, _dog_speed, _next_dog_variant)
	dog.position.x = GameConfig.SPAWN_X
	dog.passed_player.connect(_on_hazard_passed)
	_active_dog = dog
	_active_dog_variant = _next_dog_variant
	_dog_barks_fired = 0
	_next_dog_variant = (_next_dog_variant + 1) % GameConfig.DOG_TEXTURES.size()


## Fire the chase barks (cues 2-3) as the dog crosses its DOG_BARK_X screen
## positions, each once per encounter. Tied to screen position, not time, so
## the final bark lands the frame the dog reaches the player's lane and stays
## in sync if RUN_SPEED or upgrades change.
func _update_dog_barks() -> void:
	while _dog_barks_fired < GameConfig.DOG_BARK_X.size():
		if not is_instance_valid(_active_dog) or _active_dog.is_queued_for_deletion():
			return
		if _active_dog.position.x > float(GameConfig.DOG_BARK_X[_dog_barks_fired]):
			return
		dog_barked.emit(_dog_barks_fired, _active_dog_variant)
		_dog_barks_fired += 1


func _refresh_dog_reservation() -> void:
	# A freed dog compares equal to null in Godot 4, so both a null reference
	# and a despawned dog fall through to the release below. While the warning
	# is still playing the dog does not exist yet, so the reservation holds.
	if is_instance_valid(_dog_warning) and not _dog_warning.is_queued_for_deletion():
		return
	if is_instance_valid(_active_dog) and not _active_dog.is_queued_for_deletion():
		return
	_active_dog = null
	_dog_reserved_lane = -1


## Release the coin-run lane once every coin of the trail is collected or
## despawned (freed coins compare equal to null in Godot 4).
func _refresh_coin_reservation() -> void:
	for i in range(_coin_run_coins.size() - 1, -1, -1):
		var coin = _coin_run_coins[i]
		if not is_instance_valid(coin) or coin.is_queued_for_deletion():
			_coin_run_coins.remove_at(i)
	if _coin_run_coins.is_empty():
		_coin_run_lane = -1


## Lane indices with a hazard within PICKUP_LANE_CLEARANCE of the spawn point.
func _occupied_pickup_lanes() -> Array[int]:
	var occupied: Array[int] = []
	for child in hazards.get_children():
		if child is Hazard:
			var hazard_node := child as Hazard
			if absf(hazard_node.position.x - GameConfig.SPAWN_X) < GameConfig.PICKUP_LANE_CLEARANCE:
				if not occupied.has(hazard_node.lane):
					occupied.append(hazard_node.lane)
	return occupied


## Pick a clear lane for the dog, or -1 if all lanes have an entry obstacle.
static func choose_dog_lane(
	occupied: Array[int],
	rng: RandomNumberGenerator,
) -> int:
	var open_lanes: Array[int] = []
	for lane in GameConfig.LANE_COUNT:
		if not occupied.has(lane):
			open_lanes.append(lane)
	if open_lanes.is_empty():
		return -1
	return open_lanes[rng.randi() % open_lanes.size()]


## Pure lane choice for the pickup clock. Returns -1 when no lane is open.
static func choose_pickup_lane(occupied: Array[int], rng: RandomNumberGenerator) -> int:
	var open_lanes: Array[int] = []
	for lane in GameConfig.LANE_COUNT:
		if not occupied.has(lane):
			open_lanes.append(lane)
	if open_lanes.is_empty():
		return -1
	return open_lanes[rng.randi() % open_lanes.size()]


## Lane indices blocked by one row, sorted ascending.
##
## Uses Fisher-Yates with the supplied RNG (not Array.shuffle(), which ignores
## the seed) so a seeded run is reproducible.
static func generate_pattern(
	distance: float,
	rng: RandomNumberGenerator,
	reserved_lane: int = -1,
	also_reserved: int = -1,
	more_reserved: Array[int] = [],
) -> Array[int]:
	var lanes: Array[int] = []
	for lane in GameConfig.LANE_COUNT:
		if lane == reserved_lane or lane == also_reserved:
			continue
		if lane in more_reserved:
			continue
		lanes.append(lane)
	if lanes.is_empty():
		return []
	for i in range(lanes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := lanes[i]
		lanes[i] = lanes[j]
		lanes[j] = swap

	var progress := clampf(distance / GameConfig.ROW_GAP_RAMP_DISTANCE, 0.0, 1.0)
	var two_lane_chance := lerpf(
		GameConfig.TWO_LANE_CHANCE_START,
		GameConfig.TWO_LANE_CHANCE_MAX,
		progress,
	)
	var blocked := 2 if rng.randf() < two_lane_chance else 1
	blocked = mini(blocked, lanes.size())

	var pattern: Array[int] = []
	for i in blocked:
		pattern.append(lanes[i])
	pattern.sort()
	return pattern


## Weighted kind choice among the kinds unlocked at [param distance].
## [param zone] gates zone-restricted kinds: a kind's "zones" list decides
## where it may appear (HOME furniture, street-only dog/car); -1 matches the
## pre-zones behavior: ungated kinds only.
## [param allow_car] is the director's cooldown gate: when false the car is
## skipped even in the street zone.
## [param home_length] is the run's home length in px, scaling the home kinds'
## fractional unlock distances; -1 falls back to the configured default.
static func pick_kind(
	distance: float,
	rng: RandomNumberGenerator,
	zone: int = -1,
	allow_car: bool = true,
	home_length: float = -1.0,
) -> GameConfig.HazardKind:
	var total := 0.0
	for kind: int in GameConfig.HAZARD_DATA:
		if distance < GameConfig.hazard_unlock(kind, home_length):
			continue
		if kind == GameConfig.HazardKind.CAR and not allow_car:
			continue
		if not GameConfig.hazard_allows_zone(kind, zone):
			continue
		total += float(GameConfig.HAZARD_WEIGHT[kind])

	if total <= 0.0:
		return GameConfig.first_zone_kind(zone)

	var roll := rng.randf() * total
	for kind: int in GameConfig.HAZARD_DATA:
		if distance < GameConfig.hazard_unlock(kind, home_length):
			continue
		if kind == GameConfig.HazardKind.CAR and not allow_car:
			continue
		if not GameConfig.hazard_allows_zone(kind, zone):
			continue
		roll -= float(GameConfig.HAZARD_WEIGHT[kind])
		if roll <= 0.0:
			return kind
	return GameConfig.first_zone_kind(zone)


func _on_hazard_passed() -> void:
	hazard_passed.emit()


func _on_item_missed() -> void:
	item_missed.emit()
