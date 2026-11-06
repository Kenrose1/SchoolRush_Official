class_name RunWorld
extends Node2D
## The M2 gray-box course.
##
## Owns forward speed, distance, the hazard director, and the run lifecycle.
## Draws the three lane tiers plus a placeholder skyline and hosts the player
## and the temporary heart HUD. Scoring, zones, and the pursuer arrive in later
## milestones.

const SKY_COLOR := Color("#6fb7e8")
const SUN_COLOR := Color("#fff3b0")
const SUN_GLOW := Color(1.0, 0.95, 0.69, 0.18)
const SKYLINE_FAR := Color("#4a6d8c")
const SKYLINE_NEAR := Color("#3a5570")
const GROUND_BASE := Color("#232a36")
const LANE_COLORS := [Color("#3c4757"), Color("#46536b"), Color("#4f5f7d")]
const LANE_EDGE := Color(0.83, 0.88, 0.96, 0.55)
const GROUND_TICK := Color(0.85, 0.9, 0.98, 0.35)

@onready var player: Player = $Player
@onready var hazards: Node2D = $Hazards
@onready var director: SpawnDirector = $SpawnDirector
@onready var hud: HeartsHud = $Hud
@onready var game_over_root: Control = $GameOver/Root
@onready var _debug_label: Label = $DebugOverlay/Label

## Forward speed in px/s. Stays at the base value until ramping lands in M5.
var speed: float = GameConfig.RUN_SPEED
## Distance travelled this run, in pixels.
var distance: float = 0.0
## False after the last heart is lost; the world freezes until [R].
var is_running: bool = true


func _ready() -> void:
	_debug_label.visible = GameConfig.DEBUG_OVERLAY
	game_over_root.visible = false

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	hud.set_hearts(player.health, GameConfig.MAX_HEARTS)

	director.setup(hazards, randi())


func _physics_process(delta: float) -> void:
	if not is_running:
		return
	distance += speed * delta
	director.tick(delta, speed, distance)
	queue_redraw()
	_update_debug()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F3:
			_debug_label.visible = not _debug_label.visible
			get_viewport().set_input_as_handled()
		KEY_R:
			if not is_running:
				get_tree().reload_current_scene()
				get_viewport().set_input_as_handled()


# --- Run lifecycle -----------------------------------------------------------

func _on_health_changed(current: int, maximum: int) -> void:
	hud.set_hearts(current, maximum)


func _on_player_died() -> void:
	is_running = false
	game_over_root.visible = true
	hazards.process_mode = Node.PROCESS_MODE_DISABLED
	director.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.sprite.modulate.a = 1.0
	_update_debug()


func _update_debug() -> void:
	if not _debug_label.visible:
		return
	_debug_label.text = "LANE  %d   (%.1f px)\nSPEED %.0f px/s\nDIST  %.1f m\nAIR   %.0f px   SLIDE %s\nHEARTS %d/%d   IFRAME %.2f s\nFPS   %d\n[F3] hide" % [
		player.lane,
		player.lane_y,
		speed,
		distance / 100.0,
		player.air_height,
		"yes" if player.is_sliding else "no",
		player.health,
		GameConfig.MAX_HEARTS,
		player.invulnerable_time_left,
		Engine.get_frames_per_second(),
	]


# --- Placeholder course rendering -------------------------------------------

func _draw() -> void:
	var view := GameConfig.DESIGN_SIZE
	var horizon := GameConfig.lane_y(0) - GameConfig.LANE_HALF_HEIGHT

	draw_rect(Rect2(Vector2.ZERO, view), SKY_COLOR)
	_draw_sun()
	_draw_skyline(0.10, horizon, 210.0, SKYLINE_FAR, 300.0)
	_draw_skyline(0.22, horizon, 140.0, SKYLINE_NEAR, 190.0)
	draw_rect(Rect2(0.0, horizon, view.x, view.y - horizon), GROUND_BASE)

	for lane in GameConfig.LANE_COUNT:
		var y := GameConfig.lane_y(lane)
		var top := y - GameConfig.LANE_HALF_HEIGHT
		draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), LANE_COLORS[lane])
		draw_line(Vector2(0.0, top), Vector2(view.x, top), LANE_EDGE, 3.0)
		_draw_ticks(y)


func _draw_sun() -> void:
	var center := Vector2(1560.0, 210.0)
	draw_circle(center, 150.0, SUN_GLOW)
	draw_circle(center, 96.0, SUN_COLOR)


## Deterministic parallax skyline: rectangles keyed by world index so the
## silhouette never flickers, no textures required.
func _draw_skyline(parallax: float, base_y: float, max_height: float,
		color: Color, spacing: float) -> void:
	var offset := distance * parallax
	var first := int(floor(offset / spacing)) - 1
	var last := first + int(ceil(GameConfig.DESIGN_WIDTH / spacing)) + 2
	for index in range(first, last):
		var x := index * spacing - offset
		var height := max_height * (0.4 + 0.6 * _hash01(index))
		draw_rect(Rect2(x, base_y - height, spacing - 16.0, height + 2.0), color)


## Scrolling ticks along a lane's centre, the main speed cue in the gray box.
func _draw_ticks(y: float) -> void:
	var period := GameConfig.GROUND_TICK_LENGTH + GameConfig.GROUND_TICK_GAP
	var x := -fmod(distance, period)
	while x < GameConfig.DESIGN_WIDTH:
		draw_rect(Rect2(x, y - 3.0, GameConfig.GROUND_TICK_LENGTH, 6.0), GROUND_TICK)
		x += period


## Stable pseudo-random value in [0, 1) for a world index.
static func _hash01(index: int) -> float:
	var value := (index * 1103515245 + 12345) & 0x7fffffff
	return float(value % 1000) / 1000.0
