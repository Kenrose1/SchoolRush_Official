class_name Game
extends Node2D
## One run of School Rush. Campaign, Endless and Training share the course and
## rules; only pacing and end conditions differ (GDD section 05).
## The scene tree lives in scenes/game.tscn; every number below is editable.

signal finished(result: Dictionary)

@export_group("Run length")
@export var campaign_m := 1400.0
@export var bell_time := 135.0
@export var training_m := 320.0

@export_group("Rules")
@export var max_hearts := 3
@export var max_combo := 5
@export var pickup_score := 20.0
@export var hit_penalty := 25.0
@export var speed_ratio_on_hit := 0.55
@export var recovery_rate := 0.30

@export_group("Pace")
@export var px_per_m := 55.0
@export var speed_start := 620.0
@export var speed_campaign_end := 1050.0
@export var speed_endless_max := 1250.0
@export var endless_ramp := 6.6
@export var training_speed := 430.0

@export_group("Spawning")
@export var spawn_x := 2140.0
@export var despawn_x := -420.0
@export var gap_start := 30.0
@export var gap_end := 19.0
@export var training_gap := 42.0
@export var pickup_chance := 0.62

const OBSTACLE_SCENES := {
	"sign": preload("res://scenes/obstacle_sign.tscn"),
	"manhole": preload("res://scenes/obstacle_manhole.tscn"),
	"debris": preload("res://scenes/obstacle_debris.tscn"),
	"slide": preload("res://scenes/obstacle_slide.tscn"),
}
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

var mode := "campaign"
var running := true
var distance_m := 0.0
var speed := 620.0
var score := 0.0
var items := 0
var combo := 1
var hearts := 3
var bell_left := 135.0
var pursuer_threat := false

@onready var world: Node2D = $World
@onready var background: Background = $World/Background
@onready var course: Course = $World/Course
@onready var pursuer: Pursuer = $World/Pursuer
@onready var player: Player = $World/Player
@onready var hud: Hud = $HudLayer/Hud

var _obstacles: Array[Obstacle] = []
var _pickups: Array[Pickup] = []
var _speed_ratio := 1.0
var _base_speed := 620.0
var _next_spawn_m := 30.0
var _elapsed := 0.0
var _shake := 0.0
var _theme: Dictionary = {}
var _zone := -1
var _ending := false
var _end_timer := 0.0
var _pending: Dictionary = {}
var _hits := 0
var _prompt_lock := 0.0


func _ready() -> void:
	hearts = max_hearts
	bell_left = bell_time
	hud.game = self
	# The Player node owns the lane heights; the painted tracks follow them.
	course.lane_heights = player.lane_y
	course.sync_lanes()
	if mode == "training":
		_base_speed = training_speed

	_zone = _zone_for(0.0)
	_theme = Pal.zone_colors(_zone)
	background.set_zone(_zone)
	course.apply_theme(_theme)
	course.set_active_lane(player.lane)
	hud.show_banner(_zone_title())
	if mode == "training":
		hud.show_prompt("TRAINING // W/S LANES   SPACE JUMP   CTRL SLIDE", 4.0)
	_next_spawn_m = 26.0
	Sfx.set_intensity(0.15)
	Sfx.start_music()
	Sfx.play("bell", -8.0)


func _process(delta: float) -> void:
	if _ending:
		_end_timer -= delta
		if _end_timer <= 0.0:
			_ending = false
			finished.emit(_pending)
		return
	if not running:
		return

	_elapsed += delta
	_prompt_lock = maxf(0.0, _prompt_lock - delta)

	match mode:
		"campaign":
			_base_speed = lerpf(speed_start, speed_campaign_end, clampf(progress(), 0.0, 1.0))
		"endless":
			_base_speed = minf(speed_endless_max, speed_start + _elapsed * endless_ramp)
		_:
			_base_speed = training_speed
	speed = _base_speed * lerpf(0.72, 1.0, _speed_ratio)
	_speed_ratio = minf(1.0, _speed_ratio + delta * recovery_rate)

	var step := speed * delta
	distance_m += step / px_per_m
	score += step / px_per_m
	background.advance(step)
	course.advance(step)
	course.set_active_lane(player.lane)

	for obstacle in _obstacles:
		obstacle.advance(step)
	for pickup in _pickups:
		pickup.advance(step)
	_cull()

	if distance_m >= _next_spawn_m:
		_spawn_wave()

	_collide()
	_update_zone(delta)

	player.speed = speed
	pursuer.player_x = player.position.x
	pursuer.sync_ratio(_speed_ratio, player.position.y)
	pursuer_threat = pursuer.is_threat()

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 55.0)
		world.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.6)
	else:
		world.position = Vector2.ZERO

	_show_context_prompt()
	Sfx.set_intensity(clampf(speed / 1150.0, 0.1, 1.0))

	if mode == "campaign":
		bell_left -= delta
		if bell_left <= 0.0:
			bell_left = 0.0
			_finish("bell", 0.6)
			return
		if distance_m >= campaign_m:
			_finish("win", 1.0)
			return
	elif mode == "training":
		if distance_m >= training_m:
			_finish("training_done", 1.0)
			return


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_W, KEY_UP, KEY_1:
			player.move_lane(-1)
		KEY_S, KEY_DOWN, KEY_3:
			player.move_lane(1)
		KEY_SPACE:
			player.jump()
		KEY_CTRL, KEY_SHIFT:
			player.slide()


# --- spawning --------------------------------------------------------------

func _difficulty() -> float:
	if mode == "campaign":
		return clampf(progress(), 0.0, 1.0)
	if mode == "endless":
		return clampf(_elapsed / 110.0, 0.0, 1.0)
	return 0.2


func _spawn_wave() -> void:
	var difficulty := _difficulty()
	var safe := randi_range(0, 2)
	var kinds: Array[String] = []

	if mode == "training":
		kinds = ["single"]
	elif difficulty < 0.18:
		kinds = ["single", "single", "double_jump"]
	elif difficulty < 0.45:
		kinds = ["single", "double_jump", "mix", "double_slide"]
	else:
		kinds = ["double_jump", "double_slide", "mix", "wall_jump", "wall_slide", "single"]

	var pattern: String = kinds[randi_range(0, kinds.size() - 1)]
	var lanes: Array[int] = [0, 1, 2]
	match pattern:
		"single":
			lanes = [_other_lane(safe)]
		"double_jump", "double_slide", "mix":
			lanes = _two_lanes(safe)
		"wall_jump", "wall_slide":
			lanes = [0, 1, 2]

	var slide_pattern := pattern in ["double_slide", "wall_slide"]
	for index in lanes.size():
		var lane: int = lanes[index]
		var is_slide := slide_pattern if pattern != "mix" else index == 1
		if is_slide:
			_spawn_obstacle("slide", lane, spawn_x, "", 1.0)
		else:
			var props := ["sign", "manhole", "debris"]
			var prop: String = props[randi_range(0, props.size() - 1)]
			_spawn_obstacle("jump", lane, spawn_x, prop, randf_range(0.92, 1.12))

	if randf() < pickup_chance and pattern != "wall_slide" and pattern != "wall_jump":
		var kinds_item := ["book", "pencil", "eraser", "bag"]
		var item_kind: String = kinds_item[randi_range(0, kinds_item.size() - 1)]
		_spawn_pickup_item(item_kind, safe, spawn_x + randf_range(120.0, 380.0))

	var gap_m := lerpf(gap_start, gap_end, difficulty)
	if mode == "training":
		gap_m = training_gap
	# Anchor to the current distance so one long frame cannot dump a burst of waves.
	_next_spawn_m = maxf(_next_spawn_m + gap_m, distance_m + gap_m)


func _two_lanes(safe: int) -> Array[int]:
	var out: Array[int] = []
	for lane in 3:
		if lane != safe:
			out.append(lane)
	return out


func _other_lane(safe: int) -> int:
	var options: Array[int] = []
	for lane in 3:
		if lane != safe:
			options.append(lane)
	return options[randi_range(0, options.size() - 1)]


func _spawn_obstacle(kind: String, lane: int, x: float, prop: String, scale_factor: float) -> void:
	var scene: PackedScene = OBSTACLE_SCENES["slide"] if kind == "slide" else OBSTACLE_SCENES.get(prop, OBSTACLE_SCENES["sign"])
	var obstacle: Obstacle = scene.instantiate()
	world.add_child(obstacle)
	obstacle.setup(kind, lane, x, prop, scale_factor, player.lane_y[lane])
	obstacle.z_index = 2
	_obstacles.append(obstacle)


func _spawn_pickup_item(kind: String, lane: int, x: float) -> Pickup:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	world.add_child(pickup)
	pickup.setup(kind, lane, x, player.lane_y[lane])
	pickup.z_index = 1
	_pickups.append(pickup)
	return pickup


func _cull() -> void:
	for i in range(_obstacles.size() - 1, -1, -1):
		var obstacle := _obstacles[i]
		if obstacle.x < despawn_x:
			obstacle.queue_free()
			_obstacles.remove_at(i)
	for i in range(_pickups.size() - 1, -1, -1):
		var pickup := _pickups[i]
		if pickup.x < despawn_x:
			pickup.queue_free()
			_pickups.remove_at(i)


# --- collisions ------------------------------------------------------------

func _collide() -> void:
	var body := player.hit_rect()
	for obstacle in _obstacles:
		if obstacle.rect().intersects(body):
			_hit()
			return
	var reach := player.hit_rect().grow(26.0)
	for pickup in _pickups:
		if pickup.collected:
			continue
		if pickup.rect().intersects(reach):
			_collect(pickup)


func _collect(pickup: Pickup) -> void:
	pickup.collected = true
	items += 1
	combo = mini(max_combo, combo + 1)
	score += pickup_score * combo
	pickup.queue_free()
	_pickups.erase(pickup)
	Sfx.play("combo" if combo >= 4 else "pickup", -2.0)


func _hit() -> void:
	if player.is_invulnerable() or not running:
		return
	if mode == "training":
		return
	_hits += 1
	hearts -= 1
	combo = 1
	score = maxf(0.0, score - hit_penalty)
	player.hurt()
	hud.flash_impact()
	_shake = 14.0
	Sfx.play("hit", 2.0)
	_speed_ratio = speed_ratio_on_hit
	if hearts <= 0:
		_finish("hearts", 0.5)
		return
	# Any hit summons the Pursuer; a second hit before recovering lets him lunge.
	if pursuer.appear():
		_finish("pursuer", 0.85)


# --- zones & prompts -------------------------------------------------------

func _zone_for(_meters: float) -> int:
	match mode:
		"campaign":
			return clampi(int(progress() * 3.0), 0, 2)
		"endless":
			return int(distance_m / 260.0) % 2
		_:
			return 1


func _zone_title() -> String:
	return String(Pal.zone_colors(_zone)["title"])


func _update_zone(delta: float) -> void:
	var target_index := _zone_for(distance_m)
	if target_index != _zone:
		_zone = target_index
		background.set_zone(_zone)
		hud.show_banner(_zone_title())
		Sfx.play("bell", -14.0)
	var target := Pal.zone_colors(_zone)
	var rate := minf(1.0, delta * 2.2)
	for key: String in target:
		var value: Variant = target[key]
		if value is Color:
			_theme[key] = (_theme[key] as Color).lerp(value as Color, rate)
	course.apply_theme(_theme)


func _show_context_prompt() -> void:
	if _prompt_lock > 0.0:
		return
	var nearest: Obstacle = null
	var best := 999999.0
	for obstacle in _obstacles:
		if obstacle.lane != player.lane:
			continue
		var dx := obstacle.x - player.position.x
		if dx > 24.0 and dx < best and dx < 620.0:
			best = dx
			nearest = obstacle
	if nearest == null:
		return
	if nearest.kind == "jump" and not player.airborne:
		hud.show_prompt("SPACE // JUMP", 0.5)
		_prompt_lock = 0.9
	elif nearest.kind == "slide" and not player.sliding:
		hud.show_prompt("CTRL // SLIDE", 0.5)
		_prompt_lock = 0.9


# --- state -----------------------------------------------------------------

func progress() -> float:
	return clampf(distance_m / campaign_m, 0.0, 1.0)


func speed_ratio() -> float:
	return clampf(_speed_ratio, 0.0, 1.0)


func mode_label() -> String:
	match mode:
		"endless":
			return "ENDLESS SURVIVAL"
		"training":
			return "TRAINING RUN"
		_:
			return "CAMPAIGN"


func _finish(outcome: String, delay: float) -> void:
	if not running:
		return
	running = false
	pursuer_threat = outcome == "pursuer"
	match outcome:
		"win", "training_done":
			Sfx.play("win")
		"bell":
			Sfx.play("bell", 3.0)
		_:
			Sfx.play("over")
	Sfx.stop_music()
	_pending = {
		"mode": mode,
		"outcome": outcome,
		"score": int(score),
		"items": items,
		"distance": int(distance_m),
		"combo": combo,
		"hits": _hits,
		"zone": _zone_title(),
	}
	_ending = true
	_end_timer = delay
