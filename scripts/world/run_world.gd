@tool
class_name RunWorld
extends Node2D
## The M5 course.
##
## Owns forward speed, distance, the zone clock (home -> street), the hazard
## director, School Items, scoring, and the pursuer. Each zone draws its own
## background stack: home is a two-layer interior (wall + floor) over a slow
## sunset neighbourhood seen through the window glass, street is the sunset
## sky plus the designer houses and road. Lanes are painted on top; the
## road/floor always scrolls at world speed so hazards never slide.

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

## The corridor the school zone runs through. This is the art with its frosted
## window panes cut out by tools/mask_hallway_glass.gd, so the campus panorama
## behind the corridor shows through the glass.
const SCHOOL_TEXTURE := "res://assets/backgrounds/newschoolhallway_glass.png"
## Drawn behind the corridor: the sunny campus seen through the cut-out windows,
## drifting slower than the corridor for a real parallax read. The parallax is
## livelier than the sky's because the window glass makes it easy to see.
const SCHOOL_CAMPUS_TEXTURE := "res://assets/backgrounds/Sunny Anime School Campus Panorama.png"
const SCHOOL_CAMPUS_PARALLAX := 0.28
## Drawn behind the corridor first (like HOME_BASE for house.png) so the glass
## reveals daylight instead of the viewport clear colour if the art is missing.
const SCHOOL_BASE := Color("#8fc0e4")
## Corridor and floor both ride the world speed, exactly like the home room.
const SCHOOL_WALL_PARALLAX := 1.0
const SCHOOL_FLOOR_PARALLAX := 1.0
## The corridor floor is bright and glossy, so its imaginary three lanes are
## painted darker than the street's tint to stay readable. They use the exact
## same lane bands as every other zone (GameConfig.LANE_Y).
## The closing dash ends a few px below the wall/floor split of the endgame art,
## so Elias' feet rest on the door threshold instead of on its bottom line.
const SCHOOL_DOOR_FOOT_INSET := 6.0
const SCHOOL_LANE_FILL := Color(0.05, 0.07, 0.11, 0.22)
const SCHOOL_LANE_EDGE := Color(1.0, 0.97, 0.89, 0.8)
const SCHOOL_LANE_EDGE_WIDTH := 4.0

var _sky_texture: Texture2D
var _street_texture: Texture2D
var _home_texture: Texture2D
var _home_sky_texture: Texture2D
var _school_texture: Texture2D
var _school_campus_texture: Texture2D
var _school_end_texture: Texture2D

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
@onready var escape_label: Label = $GameOver/Root/EscapeLabel
@onready var retry_button: TextureButton = $GameOver/Root/RetryButton
@onready var retry_icon: TextureRect = $GameOver/Root/RetryButton/RetryIcon
@onready var quit_button: TextureButton = $GameOver/Root/QuitButton
@onready var quit_icon: TextureRect = $GameOver/Root/QuitButton/QuitIcon
@onready var _debug_label: Label = $DebugOverlay/Label
@onready var _zone_fade: ColorRect = $ZoneFade/Rect

## Current world speed. The momentum dip lowers it temporarily after a hit.
var speed: float = GameConfig.RUN_SPEED
## Zone base speed for this frame, before the momentum dip is applied.
var base_speed: float = GameConfig.RUN_SPEED
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
## True once the corridor has ended: the scroll stops on the endgame hallway and
## Elias dashes the last stretch to the exit door on his own.
var finale_started: bool = false

## Seconds the home zone lasts. Editable in the Inspector so the house run can
## be extended without touching GameConfig; the school zone is terminal.
@export_range(5.0, 300.0, 1.0) var home_zone_seconds: float = GameConfig.ZONE_HOME_DURATION_SECONDS
## Distance (px) at which home ends, derived from [member home_zone_seconds].
var home_zone_length: float = GameConfig.zone_home_length()
## Seconds the street zone lasts before the school corridor. Also editable in the
## Inspector; the street boundary derives from it.
@export_range(5.0, 300.0, 1.0) var street_zone_seconds: float = GameConfig.ZONE_STREET_DURATION_SECONDS
## Distance (px) at which the street ends, derived from [member street_zone_seconds].
var street_zone_length: float = GameConfig.zone_street_length()
## Seconds the school corridor lasts before the endgame hallway. Also editable
## in the Inspector, so the final stretch can be tuned without GameConfig.
@export_range(5.0, 300.0, 1.0) var school_zone_seconds: float = GameConfig.ZONE_SCHOOL_DURATION_SECONDS
## Distance (px) at which the corridor ends and the endgame hallway begins.
var school_zone_length: float = GameConfig.zone_school_length()
## Zone currently being drawn and scored.
var current_zone: GameConfig.Zone = GameConfig.Zone.HOME
## Seconds of zone cross-fade remaining.
var _zone_fade_time_left: float = 0.0


func _ready() -> void:
	_apply_zone_durations()
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
		_school_campus_texture = load(SCHOOL_CAMPUS_TEXTURE) as Texture2D
		_school_end_texture = load(GameConfig.SCHOOL_END_TEXTURE) as Texture2D
		queue_redraw()
		return
	_debug_label.visible = GameConfig.DEBUG_OVERLAY
	game_over_root.visible = false
	caught_label.visible = false
	# Green button face from the atlas, with the green retry arrow on top.
	retry_button.texture_normal = _ui_button_texture(GameConfig.UI_BUTTON_FACE_TILE)
	retry_button.texture_hover = retry_button.texture_normal
	retry_button.texture_pressed = retry_button.texture_normal
	retry_icon.texture = _ui_button_texture(GameConfig.UI_RETRY_TILE)
	retry_button.pressed.connect(_on_retry_pressed)
	# Quit sits beside retry on both end screens, on the same green face.
	quit_button.texture_normal = retry_button.texture_normal
	quit_button.texture_hover = quit_button.texture_normal
	quit_button.texture_pressed = quit_button.texture_normal
	quit_icon.texture = _ui_button_texture(GameConfig.UI_QUIT_TILE)
	quit_button.pressed.connect(_on_quit_pressed)
	arrest.visible = false
	arrest.scale = Vector2(GameConfig.ARREST_SCALE, GameConfig.ARREST_SCALE)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.caught.connect(_on_player_caught)
	player.item_collected.connect(_on_item_collected)
	player.damaged.connect(_on_player_damaged)
	player.jumped.connect(_on_player_jumped)
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
	score_hud.set_distance(distance, home_zone_length)
	score_hud.set_distance_progress(_zone_progress())
	hud.set_speed(speed)
	hud.set_speed_ratio(speed / GameConfig.max_run_speed())

	director.hazard_passed.connect(score_system.add_hazard_passed)
	director.item_missed.connect(_on_item_missed)
	director.setup(hazards, randi())


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_running:
		return
	if finale_started:
		_update_finale(delta)
		return
	# Each zone runs at its own pace, so every zone change speeds the run up.
	base_speed = GameConfig.zone_run_speed(current_zone)
	if momentum_time_left > 0.0:
		momentum_time_left = maxf(momentum_time_left - delta, 0.0)
		speed = base_speed * GameConfig.MOMENTUM_DIP_FACTOR
		if momentum_time_left <= 0.0:
			momentum_recover_time_left = GameConfig.MOMENTUM_RECOVER_TIME
	elif momentum_recover_time_left > 0.0:
		momentum_recover_time_left = maxf(momentum_recover_time_left - delta, 0.0)
		var t := 1.0 - clampf(
			momentum_recover_time_left / GameConfig.MOMENTUM_RECOVER_TIME, 0.0, 1.0)
		speed = lerpf(
			base_speed * GameConfig.MOMENTUM_DIP_FACTOR,
			base_speed,
			t,
		)
	else:
		speed = base_speed
	# Keep live hazards/items on the exact current world speed so they ride
	# the road with no slide through the dip and the ease-back.
	for child in hazards.get_children():
		if child is Hazard or child is Collectible:
			child.speed = speed
	distance += speed * delta
	# The end of the corridor stops the scroll on the endgame hallway; from there
	# Elias covers the last stretch to the exit door on his own.
	if distance >= _finale_distance():
		distance = _finale_distance()
		_start_finale()
		return
	_update_zone()
	director.tick(delta, speed, distance)
	score_system.add_distance(distance)
	score_hud.set_distance(distance, _zone_goal_distance())
	score_hud.set_distance_progress(_zone_progress())
	hud.set_speed(speed)
	hud.set_speed_ratio(speed / GameConfig.max_run_speed())
	pursuer.set_world_speed(speed)
	pursuer.set_base_speed(base_speed)
	pursuer.track(player.lane_y)
	player.pursuer_active = pursuer.is_active()
	queue_redraw()
	_update_debug()


## Slice one tile out of the UI button atlas.
func _ui_button_texture(tile: Vector2i) -> AtlasTexture:
	return GameConfig.ui_tile(tile)


## Retry button: same restart as pressing [R] on the game over screen.
func _on_retry_pressed() -> void:
	GameAudio.play(&"ui_click")
	get_tree().paused = false
	get_tree().reload_current_scene()


## Quit button on the end screens: leaves the game from wherever it ended.
func _on_quit_pressed() -> void:
	GameAudio.play(&"ui_click")
	get_tree().paused = false
	get_tree().quit()


## Recompute both zone boundaries from the Inspector overrides.
func _apply_zone_durations() -> void:
	home_zone_length = GameConfig.zone_home_length(home_zone_seconds)
	street_zone_length = GameConfig.zone_street_length(street_zone_seconds)
	school_zone_length = GameConfig.zone_school_length(school_zone_seconds)


## How far the run is through the zone it is in (0..1). The last corridor
## counts down to the endgame hallway, so the meter fills as the door nears.
func _zone_progress() -> float:
	match current_zone:
		GameConfig.Zone.HOME:
			return clampf(distance / maxf(home_zone_length, 1.0), 0.0, 1.0)
		GameConfig.Zone.STREET:
			return clampf(
				(distance - home_zone_length) / maxf(street_zone_length, 1.0), 0.0, 1.0)
		_:
			return clampf(
				(distance - home_zone_length - street_zone_length)
					/ maxf(school_zone_length, 1.0),
				0.0,
				1.0,
			)


## Distance (px) at which the scroll stops on the endgame hallway.
func _finale_distance() -> float:
	return home_zone_length + street_zone_length + school_zone_length


## Distance the HUD counts up to while [member current_zone] is running.
func _zone_goal_distance() -> float:
	match current_zone:
		GameConfig.Zone.HOME:
			return home_zone_length
		GameConfig.Zone.STREET:
			return home_zone_length + street_zone_length
		_:
			return _finale_distance()


## Step the zone clock. Home and street have durations; school is terminal.
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
	GameAudio.play(&"pickup")
	score_system.add_item_pickup()


func _on_player_jumped() -> void:
	GameAudio.play(&"jump")


func _on_player_damaged(_remaining: int) -> void:
	GameAudio.play(&"hit")
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
	GameAudio.play(&"hit")
	player.sprite.visible = false
	pursuer.visible = false
	arrest.position = Vector2(GameConfig.PLAYER_X, player.lane_y)
	arrest.position.y -= GameConfig.ARREST_SPRITE_HEIGHT * GameConfig.ARREST_SCALE * 0.5
	arrest.visible = true
	arrest.play(&"arrest")


func _on_player_died() -> void:
	if _caught:
		return  # The lunge flow shows the CAUGHT! overlay.
	GameAudio.play(&"hit")
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
	escape_label.visible = false
	_update_debug()


## The run was finished at the exit door instead of lost.
func _show_escape() -> void:
	game_over_root.visible = true
	game_over_label.visible = false
	caught_label.visible = false
	escape_label.visible = true
	_update_debug()


# --- Finale ------------------------------------------------------------------

## The corridor has ended: stop the scroll on the endgame hallway (the drawn
## offset freezes with [member distance]) and hand the rest of the screen to
## Elias, who covers it himself with [member Player.forward_offset].
func _start_finale() -> void:
	finale_started = true
	_clear_stage()
	pursuer.visible = false
	pursuer.process_mode = Node.PROCESS_MODE_DISABLED
	player.forward_offset = 0.0
	player.forward_offset_y = 0.0
	player.depth_scale = 1.0
	# The last stretch is scripted, so ignore lane and jump input until the door.
	player.set_process_unhandled_input(false)
	speed = GameConfig.FINALE_RUN_SPEED
	base_speed = speed
	score_hud.set_distance(distance, _zone_goal_distance())
	score_hud.set_distance_progress(1.0)
	hud.set_speed(speed)
	hud.set_speed_ratio(speed / GameConfig.max_run_speed())
	_update_debug()
	queue_redraw()


## Closing dash: the background is frozen, so the run carries on through the
## player alone until he is standing in the doorway. The dash is diagonal - the
## door sits on the far wall, above the lane Elias was running in.
func _update_finale(delta: float) -> void:
	speed = GameConfig.FINALE_RUN_SPEED
	base_speed = speed
	var target_x := _door_offset()
	var target_y := _door_threshold_y() - player.lane_y
	player.forward_offset = move_toward(player.forward_offset, target_x, speed * delta)
	player.forward_offset_y = move_toward(
		player.forward_offset_y, target_y, speed * delta)
	# Recede as he climbs the corridor: the door is on the far wall, so the last
	# stretch has to read as distance, not as sliding along the floor.
	var travelled := 1.0
	if absf(target_y) > 0.001:
		travelled = clampf(player.forward_offset_y / target_y, 0.0, 1.0)
	player.depth_scale = lerpf(1.0, GameConfig.FINALE_DEPTH_SCALE, travelled)
	hud.set_speed(speed)
	hud.set_speed_ratio(speed / GameConfig.max_run_speed())
	_update_debug()
	if absf(player.forward_offset - target_x) < 0.01 \
			and absf(player.forward_offset_y - target_y) < 0.01:
		_finish_run()


## Screen distance between the starting mark and the endgame exit door.
func _door_offset() -> float:
	return maxf(GameConfig.school_exit_x() - GameConfig.PLAYER_X, 0.0)


## Screen y of the exit door's threshold: the wall/floor split of the endgame
## art scaled into the viewport, so the dash can finish with Elias standing in
## the doorway instead of on his lane below it.
func _door_threshold_y() -> float:
	if _school_end_texture == null:
		_school_end_texture = load(GameConfig.SCHOOL_END_TEXTURE) as Texture2D
	if _school_end_texture == null:
		return GameConfig.lane_y(GameConfig.PLAYER_START_LANE)
	var src := _school_end_texture.get_size()
	var art_scale := GameConfig.DESIGN_WIDTH / src.x
	return GameConfig.SCHOOL_END_FLOOR_SPLIT_RATIO * src.y * art_scale \
		+ SCHOOL_DOOR_FOOT_INSET


## Clear the stage so the dash to the door is a clean finish.
func _clear_stage() -> void:
	director.process_mode = Node.PROCESS_MODE_DISABLED
	hazards.process_mode = Node.PROCESS_MODE_DISABLED
	for child in hazards.get_children():
		child.queue_free()


## Elias is through the door: freeze the finished run and show the outcome.
func _finish_run() -> void:
	GameAudio.play(&"finish")
	# Freezing stops the player's own physics, so land the last of the dash here
	# or the sprite would stop a frame short of the doorway.
	player.forward_offset = _door_offset()
	player.forward_offset_y = _door_threshold_y() - player.lane_y
	player.depth_scale = GameConfig.FINALE_DEPTH_SCALE
	player._apply_pose()
	_freeze_world()
	player.sprite.play(&"idle")
	_show_escape()


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
	match current_zone:
		GameConfig.Zone.HOME:
			_draw_home(view)
		GameConfig.Zone.STREET:
			_draw_street(view)
		_:
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


## School: the campus panorama sits behind the corridor and drifts at the
## street sky's parallax, so the transparent panes of the hallway art read as a
## mirror reflecting a moving schoolyard.
##
## The corridor is drawn at one uniform scale - screen width / source width,
## the same scale the street uses - instead of stretching each slice into its
## band. That keeps the lockers, floor tiles and therefore the hazards and
## School Items in proportion with the other zones; the near floor is cropped
## by the viewport rather than squashed. Because both slices share the scale and
## the parallax, they join without a visible seam and the floor line can be
## retuned freely through SCHOOL_FLOOR_SPLIT_Y.
func _draw_school(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), SCHOOL_BASE)

	if _school_texture == null:
		_school_texture = load(SCHOOL_TEXTURE) as Texture2D
	if _school_texture == null:
		draw_rect(Rect2(0.0, view.y * 0.5, view.x, view.y * 0.5), GROUND_BASE)
		return

	var src := _school_texture.get_size()
	var art_scale := view.x / src.x
	# The wall slice starts at SCHOOL_WALL_START_Y so the art's own ceiling frames
	# the corridor; the window glass in this cut-out copy is transparent, which is
	# what lets the campus parallax show through it.
	var wall_start := clampf(GameConfig.SCHOOL_WALL_START_RATIO * src.y, 0.0, src.y - 2.0)
	var split := clampf(
		GameConfig.SCHOOL_FLOOR_SPLIT_RATIO * src.y, wall_start + 1.0, src.y - 1.0)
	var wall_height := minf((split - wall_start) * art_scale, view.y)
	var floor_height := maxf(view.y - wall_height, 0.0)
	var floor_src_height := minf(floor_height / art_scale, src.y - split)

	if _school_campus_texture == null:
		_school_campus_texture = load(SCHOOL_CAMPUS_TEXTURE) as Texture2D
	if _school_campus_texture != null:
		_draw_loops(
			_school_campus_texture,
			Rect2(Vector2.ZERO, Vector2(view.x, wall_height)),
			SCHOOL_CAMPUS_PARALLAX,
			Rect2(),
			true,
		)

	_draw_loops(
		_school_texture,
		Rect2(Vector2.ZERO, Vector2(view.x, wall_height)),
		SCHOOL_WALL_PARALLAX,
		Rect2(Vector2(0.0, wall_start), Vector2(src.x, split - wall_start)),
		true,
	)
	if floor_height > 0.0:
		_draw_loops(
			_school_texture,
			Rect2(Vector2(0.0, wall_height), Vector2(view.x, floor_height)),
			SCHOOL_FLOOR_PARALLAX,
			Rect2(Vector2(0.0, split), Vector2(src.x, floor_src_height)),
			true,
		)
	_draw_school_end(view)


## The endgame hallway is the last screen of the run: it slides in from the
## right as the corridor runs out and is exactly one viewport wide at the moment
## the scroll stops, so the exit door ends up at
## [method GameConfig.school_exit_x].
##
## It is a single scene rather than a tiling strip, so it uses the same uniform
## scale and wall/floor split as the corridor art but no looping and no
## distance offset of its own.
func _draw_school_end(view: Vector2) -> void:
	var art_x := _finale_distance() - distance
	if art_x >= view.x:
		return
	if _school_end_texture == null:
		_school_end_texture = load(GameConfig.SCHOOL_END_TEXTURE) as Texture2D
	if _school_end_texture == null:
		return

	var src := _school_end_texture.get_size()
	var art_scale := view.x / src.x
	var split := clampf(GameConfig.SCHOOL_END_FLOOR_SPLIT_RATIO * src.y, 1.0, src.y - 1.0)
	var wall_height := minf(split * art_scale, view.y)
	var floor_height := maxf(view.y - wall_height, 0.0)
	var floor_src_height := minf(floor_height / art_scale, src.y - split)

	draw_texture_rect_region(
		_school_end_texture,
		Rect2(Vector2(art_x, 0.0), Vector2(view.x, wall_height)),
		Rect2(0.0, 0.0, src.x, split),
	)
	if floor_height > 0.0:
		draw_texture_rect_region(
			_school_end_texture,
			Rect2(Vector2(art_x, wall_height), Vector2(view.x, floor_height)),
			Rect2(0.0, split, src.x, floor_src_height),
		)


## Lane edges plus white ticks, shared by every zone. The corridor paints the
## same three lane bands darker so the imaginary path reads on its glossy floor.
func _draw_lane_paint(view: Vector2) -> void:
	var textured := _zone_has_texture()
	var corridor := current_zone == GameConfig.Zone.SCHOOL
	for lane in GameConfig.LANE_COUNT:
		var y := GameConfig.lane_y(lane)
		var top := y - GameConfig.LANE_HALF_HEIGHT
		if corridor:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), SCHOOL_LANE_FILL)
			draw_line(Vector2(0.0, top), Vector2(view.x, top), SCHOOL_LANE_EDGE, SCHOOL_LANE_EDGE_WIDTH)
		elif textured:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), Color(LANE_COLORS[lane], 0.15))
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.5), 3.0)
		else:
			draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), LANE_COLORS[lane])
			draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.9), 3.0)
		_draw_ticks(y)


## Whether the current zone has real background art (tints the lane paint).
func _zone_has_texture() -> bool:
	match current_zone:
		GameConfig.Zone.HOME:
			return _home_texture != null
		GameConfig.Zone.STREET:
			return _street_texture != null
		_:
			return _school_texture != null


## Tile the texture horizontally across the destination band, looped at
## `parallax` (road runs 1.0 so it never slides against hazards).
##
## Pass [param mirrored] for art that was not authored to tile. Alternate tiles
## are then drawn flipped, and because a flipped tile's edge is the same source
## column as its neighbour's, every junction is continuous instead of a hard
## cut. The loop period doubles, so the same tile only repeats after two widths.
func _draw_loops(texture: Texture2D, destination: Rect2, parallax: float,
		source := Rect2(), mirrored := false) -> void:
	if texture == null:
		return
	if source.size.x < 1.0:
		source = Rect2(Vector2.ZERO, texture.get_size())
	var tile_width := destination.size.x
	var period := tile_width * 2.0 if mirrored else tile_width
	var offset := fmod(distance * parallax, period)
	var x := -offset
	var index := 0
	while x < GameConfig.DESIGN_WIDTH:
		if mirrored and index % 2 == 1:
			# Flip around the tile's right edge so its seam aligns with the
			# normal tile that follows.
			draw_set_transform(
				Vector2(x + tile_width, destination.position.y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect_region(
				texture,
				Rect2(Vector2.ZERO, destination.size),
				source,
				Color(1, 1, 1),
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(
				texture,
				Rect2(Vector2(x, destination.position.y), destination.size),
				source,
				Color(1, 1, 1),
			)
		x += tile_width
		index += 1


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
