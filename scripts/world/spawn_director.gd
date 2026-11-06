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

const HAZARD_SCENE := preload("res://scenes/hazard.tscn")
const COLLECTIBLE_SCENE := preload("res://scenes/collectible.tscn")

var hazards: Node2D = null
var _rng := RandomNumberGenerator.new()
var _distance_since_row: float = GameConfig.ROW_GAP_START
var _distance_since_pickup: float = 0.0
var _pickup_gap: float = 0.0


## Attach to the container that receives hazard instances.
func setup(parent: Node2D, seed_value: int = 0) -> void:
	hazards = parent
	_rng.seed = seed_value
	_pickup_gap = _rng.randf_range(GameConfig.PICKUP_GAP_MIN, GameConfig.PICKUP_GAP_MAX)


## Advance the spawn clock. Call once per physics frame with the world speed.
func tick(delta: float, speed: float, distance: float) -> void:
	if hazards == null:
		return
	_distance_since_row += speed * delta
	var gap := GameConfig.row_gap(distance)
	while _distance_since_row >= gap:
		_distance_since_row -= gap
		spawn_row(distance, speed)
		gap = GameConfig.row_gap(distance)

	_distance_since_pickup += speed * delta
	while _distance_since_pickup >= _pickup_gap:
		_distance_since_pickup -= _pickup_gap
		spawn_pickup(distance, speed)
		_pickup_gap = _rng.randf_range(GameConfig.PICKUP_GAP_MIN, GameConfig.PICKUP_GAP_MAX)


## Spawn one row. At most two lanes are blocked, so one is always open.
func spawn_row(distance: float, speed: float = GameConfig.RUN_SPEED) -> Array[int]:
	var lanes := generate_pattern(distance, _rng)
	for lane in lanes:
		var hazard := HAZARD_SCENE.instantiate() as Hazard
		hazards.add_child(hazard)
		hazard.setup(pick_kind(distance, _rng), lane, speed)
		hazard.position.x = GameConfig.SPAWN_X
		hazard.passed_player.connect(_on_hazard_passed)
	return lanes


## Spawn one School Item on a lane clear of nearby hazards.
## Returns the lane used, or -1 when the pickup was skipped.
func spawn_pickup(distance: float, speed: float = GameConfig.RUN_SPEED) -> int:
	var occupied: Array[int] = []
	for child in hazards.get_children():
		if child is Hazard:
			var hazard_node := child as Hazard
			if absf(hazard_node.position.x - GameConfig.SPAWN_X) < GameConfig.PICKUP_LANE_CLEARANCE:
				if not occupied.has(hazard_node.lane):
					occupied.append(hazard_node.lane)

	var lane := choose_pickup_lane(occupied, _rng)
	if lane < 0:
		return -1

	var kinds: Array[GameConfig.ItemKind] = [
		GameConfig.ItemKind.PENCIL,
		GameConfig.ItemKind.ERASER,
		GameConfig.ItemKind.BOOK,
		GameConfig.ItemKind.BAG,
	]
	var item := COLLECTIBLE_SCENE.instantiate() as Collectible
	hazards.add_child(item)
	item.setup(kinds[_rng.randi() % kinds.size()], lane, speed)
	item.position.x = GameConfig.SPAWN_X
	item.missed.connect(_on_item_missed)
	return lane


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
static func generate_pattern(distance: float, rng: RandomNumberGenerator) -> Array[int]:
	var lanes: Array[int] = []
	for lane in GameConfig.LANE_COUNT:
		lanes.append(lane)
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
	var blocked := GameConfig.LANE_COUNT - 1 if rng.randf() < two_lane_chance else 1

	var pattern: Array[int] = []
	for i in blocked:
		pattern.append(lanes[i])
	pattern.sort()
	return pattern


## Weighted kind choice among the kinds unlocked at [param distance].
static func pick_kind(distance: float, rng: RandomNumberGenerator) -> GameConfig.HazardKind:
	var total := 0.0
	for kind: int in GameConfig.HAZARD_DATA:
		if distance >= float(GameConfig.HAZARD_UNLOCK[kind]):
			total += float(GameConfig.HAZARD_WEIGHT[kind])

	if total <= 0.0:
		return GameConfig.HazardKind.MANHOLE

	var roll := rng.randf() * total
	for kind: int in GameConfig.HAZARD_DATA:
		if distance < float(GameConfig.HAZARD_UNLOCK[kind]):
			continue
		roll -= float(GameConfig.HAZARD_WEIGHT[kind])
		if roll <= 0.0:
			return kind
	return GameConfig.HazardKind.MANHOLE


func _on_hazard_passed() -> void:
	hazard_passed.emit()


func _on_item_missed() -> void:
	item_missed.emit()
