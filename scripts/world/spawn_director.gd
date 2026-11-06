class_name SpawnDirector
extends Node
## Spawns hazard rows ahead of the player.
##
## Timing is expressed in travelled distance rather than wall-clock seconds so
## the course density stays identical when RUN_SPEED changes in M5. Patterns are
## pure static functions so the headless fuzz suite can hammer them without a
## scene tree.

const HAZARD_SCENE := preload("res://scenes/hazard.tscn")

var hazards: Node2D = null
var _rng := RandomNumberGenerator.new()
var _distance_since_row: float = GameConfig.ROW_GAP_START


## Attach to the container that receives hazard instances.
func setup(parent: Node2D, seed_value: int = 0) -> void:
	hazards = parent
	_rng.seed = seed_value


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


## Spawn one row. At most two lanes are blocked, so one is always open.
func spawn_row(distance: float, speed: float = GameConfig.RUN_SPEED) -> Array[int]:
	var lanes := generate_pattern(distance, _rng)
	for lane in lanes:
		var hazard := HAZARD_SCENE.instantiate() as Hazard
		hazards.add_child(hazard)
		hazard.setup(pick_kind(distance, _rng), lane, speed)
		hazard.position.x = GameConfig.SPAWN_X
	return lanes


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
