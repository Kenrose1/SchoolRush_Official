@tool
class_name RunWorld
extends Node2D
## The M5 course.
##
## Owns forward speed, distance, the zone clock (home -> street -> school), the
## hazard director, School Items, scoring, and the pursuer. Each zone draws its
## own background stack: home is a two-layer interior (wall + floor) over a slow
## sunset neighbourhood seen through the window glass, street is the sunset sky
## plus the designer houses and road, school is the hallway (wall + wood floor)
## over the campus exterior seen through the hallway windows. Lanes are painted
## on top; the road/floor always scrolls at world speed so hazards never slide.

signal zone_changed(zone: GameConfig.Zone)

const SKY_COLOR := Color("#6fb7e8")
const SUN_COLOR := Color("#fff3b0")
const SUN_GLOW := Color(1.0, 0.95, 0.69, 0.18)
const SKYLINE_FAR := Color("#4a6d8c")
const SKYLINE_NEAR := Color("#3a5570")
const GROUND_BASE := Color("#232a36")
const LANE_COLORS: Array[Color] = [Color("#3c4757"), Color("#46536b"), Color("#4f5f7d")]
const LANE_EDGE := Color("#fff6e0")
const GROUND_TICK := Color(1.0, 1.0, 1.0, 0.85)

const SKY_TEXTURE := "res://assets/backgrounds/sky.png"
const STREET_TEXTURE := "res://assets/backgrounds/Designer (1).png"
const SKY_PARALLAX := 0.09
const HOUSES_PARALLAX := 1.0
const STREET_ROAD_PARALLAX := 1.0
## Y in Designer pixels (1024 tall) where houses end and the road begins.
const STREET_HOUSES_END_Y := 630.0

const HOME_TEXTURE := "res://assets/backgrounds/house.png"
## Seen through the window glass and door panes of house.png. Drawn behind the
## wall and drifts slowly, exactly like the street sky.
const HOME_SKY_TEXTURE := "res://assets/backgrounds/house_skybabackground.jpg"
const HOME_SKY_PARALLAX := SKY_PARALLAX
## Drawn behind the interior first. house.png has a slightly transparent alpha
## channel (~94%) and see-through window glass, so the panes reveal the sky
## while the base keeps the viewport clear colour out of the art.
const HOME_BASE := Color("#3a2216")
## Wall and floor both ride the world speed so the room scrolls in lockstep
## with the lanes and the hazards.
const HOME_WALL_PARALLAX := 1.0
const HOME_FLOOR_PARALLAX := 1.0

## The hallway interior. Its window band is the only see-through part, so the
## campus exterior shows through the glass exactly like the home window sky.
const SCHOOL_TEXTURE := "res://assets/backgrounds/Schoolhallway.png"
const SCHOOL_BACKGROUND_TEXTURE := "res://assets/backgrounds/SchoolBackground.png"
const SCHOOL_BACKGROUND_PARALLAX := SKY_PARALLAX
## Drawn behind the hall first. The hallway art is opaque below the windows, so
## this only backs the viewport clear colour out of the glass.
const SCHOOL_BASE := Color("#251a29")
## Wall and floor both ride the world speed so the hall scrolls in lockstep
## with the lanes and the hazards.
const SCHOOL_WALL_PARALLAX := 1.0
const SCHOOL_FLOOR_PARALLAX := 1.0
## Y in Schoolhallway pixels (1024 tall) where the wall ends and the wood floor
## begins. Sits just under the horizon, so the wall band maps almost 1:1.
const SCHOOL_FLOOR_SPLIT_Y := 576.0

var _sky_texture: Texture2D
var _street_texture: Texture2D
var _home_texture: Texture2D
var _home_sky_texture: Texture2D
var _school_texture: Texture2D
var _school_background_texture: Texture2D

@onready var player: Player = $Player
@onready var pursuer: Pursuer = $Pursuer
@onready var arrest: AnimatedSprite2D = $Arrest
@onready var hazards: Node2D = $Hazards
@onready var director: SpawnDirector = $SpawnDirector
@onready var hud: HeartsHud = $Hud/HudRoot/Hearts
@onready var score_hud: ScoreHud = $Hud/HudRoot/Score
@onready var pause_menu: PauseMenu = $Hud/HudRoot/Pause
@onready var game_over_root: Control = $GameOver/Root
@onready var game_over_label: Label = $GameOver/Root/Label
@onready var caught_label: Label = $GameOver/Root/CaughtLabel
@onready var _debug_label: Label = $Hud/HudRoot/Debug
@onready var _zone_fade: ColorRect = $ZoneFade/Rect

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

## Seconds the home zone lasts. Editable in the Inspector so the house run can
## be extended without touching GameConfig; HOME and STREET are timed, SCHOOL
## has no duration.
@export_range(5.0, 300.0, 1.0) var home_zone_seconds: float = GameConfig.ZONE_HOME_DURATION_SECONDS
## Distance (px) at which home ends, derived from [member home_zone_seconds].
var home_zone_length: float = GameConfig.zone_home_length()
## Seconds the street zone lasts, editable in the Inspector the same way.
@export_range(5.0, 300.0, 1.0) var street_zone_seconds: float = GameConfig.ZONE_STREET_DURATION_SECONDS
## Distance (px) the street zone lasts, derived from [member street_zone_seconds].
var street_zone_length: float = GameConfig.zone_street_length()
## Zone currently being drawn and scored.
var current_zone: GameConfig.Zone = GameConfig.Zone.HOME
## Seconds of zone cross-fade remaining.
var _zone_fade_time_left: float = 0.0


func _ready() -> void:
	home_zone_length = GameConfig.zone_home_length(home_zone_seconds)
	street_zone_length = GameConfig.zone_street_length(street_zone_seconds)
	current_zone = GameConfig.zone_for_distance(distance, home_zone_length, street_zone_length)
	if _zone_fade != null:
		_zone_fade.color.a = 0.0
	# Editor preview: load art + draw once, skip runtime wiring.
	if Engine.is_editor_hint():
		_sky_texture = load(SKY_TEXTURE) as Texture2D
		_street_texture = load(STREET_TEXTURE) as Texture2D
		_home_texture = load(HOME_TEXTURE) as Texture2D
		_home_sky_texture = load(HOME_SKY_TEXTURE) as Texture2D
		_school_texture = load(SCHOOL_TEXTURE) as Texture2D
		_school_background_texture = load(SCHOOL_BACKGROUND_TEXTURE) as Texture2D
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
	pause_menu.setup(self)

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
	_update_zone()
	director.tick(delta, speed, distance)
	score_system.add_distance(distance)
	pursuer.set_world_speed(speed)
	pursuer.track(player.lane_y)
	player.pursuer_active = pursuer.is_active()
	queue_redraw()
	_update_debug()


## Step the zone clock. HOME and STREET are timed; SCHOOL is terminal.
func _update_zone() -> void:
	var next := GameConfig.zone_for_distance(distance, home_zone_length, street_zone_length)
	if next == current_zone:
		return
	current_zone = next
	_zone_fade_time_left = GameConfig.ZONE_FADE_TIME
	_zone_fade.color.a = 1.0
	zone_changed.emit(current_zone)
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _zone_fade_time_left <= 0.0:
		return
	_zone_fade_time_left = maxf(_zone_fade_time_left - delta, 0.0)
	_zone_fade.color.a = clampf(_zone_fade_time_left / GameConfig.ZONE_FADE_TIME, 0.0, 1.0)


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
	_debug_label.text = "LANE  %d   (%.1f px)\nSPEED %.0f px/s\nDIST  %.1f m\nZONE  %s\nAIR   %.0f px   SLIDE %s\nHEARTS %d/%d   IFRAME %.2f s\nSCORE %d   x%d   ITEMS %d\nCHASE %s  GAP %.0f px\nFPS   %d\n[F3] hide" % [
		player.lane,
		player.lane_y,
		speed,
		distance / 100.0,
		["HOME", "STREET", "SCHOOL"][current_zone],
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


# --- Zone rendering ----------------------------------------------------------

func _draw() -> void:
	var view := GameConfig.DESIGN_SIZE
	if current_zone == GameConfig.Zone.HOME:
		_draw_home(view)
	elif current_zone == GameConfig.Zone.STREET:
		_draw_street(view)
	else:
		_draw_school(view)
	_draw_lane_paint(view)


## Home: the interior split at the floor line. Both slices ride the world
## speed. A sunset neighbourhood sits behind the wall and drifts at the street
## sky's parallax, so the window glass (the only see-through part of house.png)
## reveals a moving street scene. The floor band stays backed by HOME_BASE, so
## the wood and the lane paint keep their exact colours.
func _draw_home(view: Vector2) -> void:
	var horizon := GameConfig.lane_y(0) - GameConfig.LANE_HALF_HEIGHT
	draw_rect(Rect2(Vector2.ZERO, view), HOME_BASE)

	if _home_texture == null:
		_home_texture = load(HOME_TEXTURE) as Texture2D
	if _home_texture == null:
		draw_rect(Rect2(0.0, horizon, view.x, view.y - horizon), GROUND_BASE)
		return

	if _home_sky_texture == null:
		_home_sky_texture = load(HOME_SKY_TEXTURE) as Texture2D
	if _home_sky_texture != null:
		_draw_loops(
			_home_sky_texture,
			Rect2(Vector2.ZERO, Vector2(view.x, horizon)),
			HOME_SKY_PARALLAX,
		)

	var src := _home_texture.get_size()
	var split := clampf(GameConfig.HOUSE_FLOOR_SPLIT_RATIO * src.y, 0.0, src.y)
	var wall_src := Rect2(Vector2.ZERO, Vector2(src.x, split))
	var floor_src := Rect2(Vector2(0.0, split), Vector2(src.x, src.y - split))
	_draw_loops(_home_texture, Rect2(Vector2.ZERO, Vector2(view.x, horizon)), HOME_WALL_PARALLAX, wall_src)
	_draw_loops(_home_texture, Rect2(Vector2(0.0, horizon), Vector2(view.x, view.y - horizon)), HOME_FLOOR_PARALLAX, floor_src)


## Street: sunset sky, then the designer houses and road split at the curb.
func _draw_street(view: Vector2) -> void:
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


## School: the hallway split at the wood-floor line. The wall band maps almost
## 1:1, so the window glass lands on the upper wall. The campus exterior sits
## behind it and drifts at the street sky's parallax, so the panes reveal a
## moving yard. The floor band rides world speed with the lanes.
func _draw_school(view: Vector2) -> void:
	var horizon := GameConfig.lane_y(0) - GameConfig.LANE_HALF_HEIGHT
	draw_rect(Rect2(Vector2.ZERO, view), SCHOOL_BASE)

	if _school_background_texture == null:
		_school_background_texture = load(SCHOOL_BACKGROUND_TEXTURE) as Texture2D
	if _school_background_texture != null:
		_draw_loops(
			_school_background_texture,
			Rect2(Vector2.ZERO, Vector2(view.x, horizon)),
			SCHOOL_BACKGROUND_PARALLAX,
		)
	else:
		draw_rect(Rect2(Vector2.ZERO, Vector2(view.x, horizon)), SKY_COLOR)

	if _school_texture == null:
		_school_texture = load(SCHOOL_TEXTURE) as Texture2D
	if _school_texture == null:
		draw_rect(Rect2(0.0, horizon, view.x, view.y - horizon), GROUND_BASE)
		return

	var src := _school_texture.get_size()
	var split := clampf(SCHOOL_FLOOR_SPLIT_Y, 0.0, src.y)
	var wall_src := Rect2(Vector2.ZERO, Vector2(src.x, split))
	var floor_src := Rect2(Vector2(0.0, split), Vector2(src.x, src.y - split))
	_draw_loops(_school_texture, Rect2(Vector2.ZERO, Vector2(view.x, horizon)), SCHOOL_WALL_PARALLAX, wall_src)
	_draw_loops(_school_texture, Rect2(Vector2(0.0, horizon), Vector2(view.x, view.y - horizon)), SCHOOL_FLOOR_PARALLAX, floor_src)


## Cream lane edges plus white ticks, shared by every zone.
func _draw_lane_paint(view: Vector2) -> void:
	var textured := false
	if current_zone == GameConfig.Zone.HOME:
		textured = _home_texture != null
	elif current_zone == GameConfig.Zone.STREET:
		textured = _street_texture != null
	else:
		textured = _school_texture != null
	for lane in GameConfig.LANE_COUNT:
		var y := GameConfig.lane_y(lane)
		var top := y - GameConfig.LANE_HALF_HEIGHT
		if textured:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), Color(LANE_COLORS[lane], 0.15))
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.5), 3.0)
		else:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), LANE_COLORS[lane])
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.9), 3.0)
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
