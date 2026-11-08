@tool
class_name RunWorld
extends Node2D
## The M5 street course.
##
## Owns forward speed, distance, the hazard director, School Items, scoring,
## and the pursuer. Draws sunset sky + designer houses (parallax) + road
## (scrolls with hazards) with translucent lane paint on top, and hosts the
## player and the hearts HUD. Zones arrive in M5.

const SKY_COLOR := Color("#6fb7e8")
const SUN_COLOR := Color("#fff3b0")
const SUN_GLOW := Color(1.0, 0.95, 0.69, 0.18)
const SKYLINE_FAR := Color("#4a6d8c")
const SKYLINE_NEAR := Color("#3a5570")
const GROUND_BASE := Color("#232a36")
const LANE_COLORS := [Color("#3c4757"), Color("#46536b"), Color("#4f5f7d")]
const LANE_EDGE := Color("#fff6e0")
const GROUND_TICK := Color(1.0, 1.0, 1.0, 0.85)

const SKY_TEXTURE := "res://assets/backgrounds/sky.png"
const STREET_TEXTURE := "res://assets/backgrounds/Designer (1).png"
const SKY_PARALLAX := 0.09
const HOUSES_PARALLAX := 1
const STREET_ROAD_PARALLAX := 1.0
## Y in Designer pixels (1024 tall) where houses end and the road begins.
const STREET_HOUSES_END_Y := 630.0

var _sky_texture: Texture2D
var _street_texture: Texture2D

@onready var player: Player = $Player
@onready var pursuer: Pursuer = $Pursuer
@onready var arrest: AnimatedSprite2D = $Arrest
@onready var hazards: Node2D = $Hazards
@onready var director: SpawnDirector = $SpawnDirector
@onready var hud: HeartsHud = $Hud
@onready var score_hud: ScoreHud = $ScoreHud
@onready var game_over_root: Control = $GameOver/Root
@onready var game_over_label: Label = $GameOver/Root/Label
@onready var caught_label: Label = $GameOver/Root/CaughtLabel
@onready var _debug_label: Label = $DebugOverlay/Label

## Base forward speed. The momentum dip lowers it temporarily after a hit.
var speed: float = GameConfig.RUN_SPEED
## Distance travelled this run, in pixels.
var distance: float = 0.0
## False after the last heart is lost or the tanod catches Elias; frozen until [R].
var is_running: bool = true
## Pure score system: distance points, hazard passes, School Item pickups.
var score_system: ScoreSystem = ScoreSystem.new()
## Seconds of momentum dip hold remaining, then seconds of eased recovery.
var momentum_time_left: float = 0.0
var momentum_recover_time_left: float = 0.0
## True once the chase-ending lunge has started (caught or hazard-hit mid-chase).
var _caught: bool = false


func _ready() -> void:
	# Editor preview: load art + draw once, skip runtime wiring.
	if Engine.is_editor_hint():
		_sky_texture = load(SKY_TEXTURE) as Texture2D
		_street_texture = load(STREET_TEXTURE) as Texture2D
		queue_redraw()
		return
	_debug_label.visible = GameConfig.DEBUG_OVERLAY
	game_over_root.visible = false
	caught_label.visible = false
	arrest.visible = false
	arrest.scale = Vector2(GameConfig.ARREST_SCALE, GameConfig.ARREST_SCALE)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.caught.connect(_on_player_caught)
	player.item_collected.connect(_on_item_collected)
	player.damaged.connect(_on_player_damaged)
	pursuer.caught.connect(_on_pursuer_caught)
	pursuer.lunge_finished.connect(_on_lunge_finished)
	arrest.animation_finished.connect(_on_arrest_finished)
	hud.set_hearts(player.health, GameConfig.MAX_HEARTS)

	score_system.score_changed.connect(score_hud.set_score)
	score_system.combo_changed.connect(score_hud.set_combo)
	score_system.item_count_changed.connect(score_hud.set_items)
	score_hud.set_score(score_system.score)
	score_hud.set_combo(1, 0)
	score_hud.set_items(0)

	director.hazard_passed.connect(score_system.add_hazard_passed)
	director.item_missed.connect(_on_item_missed)
	director.setup(hazards, randi())


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_running:
		return
	if momentum_time_left > 0.0:
		momentum_time_left = maxf(momentum_time_left - delta, 0.0)
		speed = GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR
		if momentum_time_left <= 0.0:
			momentum_recover_time_left = GameConfig.MOMENTUM_RECOVER_TIME
	elif momentum_recover_time_left > 0.0:
		momentum_recover_time_left = maxf(momentum_recover_time_left - delta, 0.0)
		var t := 1.0 - clampf(
			momentum_recover_time_left / GameConfig.MOMENTUM_RECOVER_TIME, 0.0, 1.0)
		speed = lerpf(
			GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR,
			GameConfig.RUN_SPEED,
			t,
		)
	else:
		speed = GameConfig.RUN_SPEED
	# Keep live hazards/items on the exact current world speed so they ride
	# the road with no slide through the dip and the ease-back.
	for child in hazards.get_children():
		if child is Hazard or child is Collectible:
			child.speed = speed
	distance += speed * delta
	director.tick(delta, speed, distance)
	score_system.add_distance(distance)
	pursuer.set_world_speed(speed)
	pursuer.track(player.lane_y)
	player.pursuer_active = pursuer.is_active()
	queue_redraw()
	_update_debug()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
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


func _on_item_collected(_kind: int) -> void:
	score_system.add_item_pickup()


func _on_player_damaged(_remaining: int) -> void:
	score_system.reset_combo()
	momentum_time_left = GameConfig.MOMENTUM_DIP_TIME
	momentum_recover_time_left = 0.0
	pursuer.wake()


func _on_item_missed() -> void:
	score_system.reset_combo()
	pursuer.wake()


func _on_player_caught() -> void:
	if _caught:
		return
	_caught = true
	_freeze_world()
	_play_arrest()


func _on_pursuer_caught() -> void:
	if _caught:
		return
	_caught = true
	_freeze_world()
	_play_arrest()


func _on_lunge_finished() -> void:
	# Fallback if the arrest node is missing: show overlay immediately.
	if not arrest.visible:
		_show_game_over(true)


func _on_arrest_finished() -> void:
	_show_game_over(true)


## Play the combined grab: hide the solo sprites, run the arrest strip.
func _play_arrest() -> void:
	player.sprite.visible = false
	pursuer.visible = false
	arrest.position = Vector2(GameConfig.PLAYER_X, player.lane_y)
	arrest.position.y -= GameConfig.ARREST_SPRITE_HEIGHT * GameConfig.ARREST_SCALE * 0.5
	arrest.visible = true
	arrest.play(&"arrest")


func _on_player_died() -> void:
	if _caught:
		return  # The lunge flow shows the CAUGHT! overlay.
	_freeze_world()
	_show_game_over(false)


func _freeze_world() -> void:
	is_running = false
	hazards.process_mode = Node.PROCESS_MODE_DISABLED
	director.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.sprite.modulate.a = 1.0
	_update_debug()


func _show_game_over(caught: bool) -> void:
	game_over_root.visible = true
	game_over_label.visible = not caught
	caught_label.visible = caught
	_update_debug()


func _update_debug() -> void:
	if not _debug_label.visible:
		return
	_debug_label.text = "LANE  %d   (%.1f px)\nSPEED %.0f px/s\nDIST  %.1f m\nAIR   %.0f px   SLIDE %s\nHEARTS %d/%d   IFRAME %.2f s\nSCORE %d   x%d   ITEMS %d\nCHASE %s  GAP %.0f px\nFPS   %d\n[F3] hide" % [
		player.lane,
		player.lane_y,
		speed,
		distance / 100.0,
		player.air_height,
		"yes" if player.is_sliding else "no",
		player.health,
		GameConfig.MAX_HEARTS,
		player.invulnerable_time_left,
		score_system.score,
		GameConfig.combo_multiplier(score_system.chain),
		score_system.item_count,
		["DORMANT", "CHASE", "FADE", "LUNGE"][pursuer.state],
		pursuer.gap,
		Engine.get_frames_per_second(),
	]


# --- Street + lane rendering -------------------------------------------------

func _draw() -> void:
	var view := GameConfig.DESIGN_SIZE
	var horizon := GameConfig.lane_y(0) - GameConfig.LANE_HALF_HEIGHT

	if _sky_texture == null:
		_sky_texture = load(SKY_TEXTURE) as Texture2D
	if _street_texture == null:
		_street_texture = load(STREET_TEXTURE) as Texture2D

	if _sky_texture != null:
		_draw_loops(_sky_texture, Rect2(Vector2.ZERO, view), SKY_PARALLAX)
	else:
		draw_rect(Rect2(Vector2.ZERO, view), SKY_COLOR)
		_draw_sun()

	if _street_texture != null:
		var src := _street_texture.get_size()
		var houses_src := Rect2(Vector2.ZERO, Vector2(src.x, STREET_HOUSES_END_Y))
		var road_src := Rect2(
			Vector2(0.0, STREET_HOUSES_END_Y),
			Vector2(src.x, src.y - STREET_HOUSES_END_Y),
		)
		_draw_loops(_street_texture, Rect2(Vector2.ZERO, Vector2(view.x, horizon)), HOUSES_PARALLAX, houses_src)
		_draw_loops(_street_texture, Rect2(Vector2(0.0, horizon), Vector2(view.x, view.y - horizon)), STREET_ROAD_PARALLAX, road_src)
	else:
		_draw_skyline(0.10, horizon, 210.0, SKYLINE_FAR, 300.0)
		_draw_skyline(0.22, horizon, 140.0, SKYLINE_NEAR, 190.0)
		draw_rect(Rect2(0.0, horizon, view.x, view.y - horizon), GROUND_BASE)

	for lane in GameConfig.LANE_COUNT:
		var y := GameConfig.lane_y(lane)
		var top := y - GameConfig.LANE_HALF_HEIGHT
		if _street_texture == null:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), LANE_COLORS[lane])
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.9), 3.0)
		else:
			var band := Color(LANE_COLORS[lane], 0.15)
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), band)
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.5), 3.0)
		_draw_ticks(y)


## Tile the texture horizontally across the destination band, looped at
## `parallax` (road runs 1.0 so it never slides against hazards).
func _draw_loops(texture: Texture2D, destination: Rect2, parallax: float, source := Rect2()) -> void:
	if texture == null:
		return
	if source.size.x < 1.0:
		source = Rect2(Vector2.ZERO, texture.get_size())
	var offset := fmod(distance * parallax, destination.size.x)
	var x := -offset
	while x < GameConfig.DESIGN_WIDTH:
		draw_texture_rect_region(
			texture,
			Rect2(Vector2(x, destination.position.y), destination.size),
			source,
			Color(1, 1, 1),
		)
		x += destination.size.x


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


## Scrolling ticks along a lane's centre (road paint, thin).
func _draw_ticks(y: float) -> void:
	var period := GameConfig.GROUND_TICK_LENGTH + GameConfig.GROUND_TICK_GAP
	var x := -fmod(distance, period)
	while x < GameConfig.DESIGN_WIDTH:
		draw_rect(Rect2(x, y - 2.0, GameConfig.GROUND_TICK_LENGTH, 4.0), GROUND_TICK)
		x += period


## Stable pseudo-random value in [0, 1) for a world index.
static func _hash01(index: int) -> float:
	var value := (index * 1103515245 + 12345) & 0x7fffffff
	return float(value % 1000) / 1000.0
