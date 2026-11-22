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
@onready var car_honk_sfx: AudioStreamPlayer = $CarHonkSfx
@onready var car_engine_sfx: AudioStreamPlayer = $CarEngineSfx
@onready var dog_bark_warn_sfx: AudioStreamPlayer = $DogBarkWarnSfx
@onready var dog_bark_run_sfx: AudioStreamPlayer = $DogBarkRunSfx
@onready var music: AudioStreamPlayer = $Music
@onready var tier_sfx: AudioStreamPlayer = $TierSfx
@onready var fail_sting: AudioStreamPlayer = $FailStingSfx
@onready var fail_music: AudioStreamPlayer = $FailMusicSfx
@onready var countdown: CountdownOverlay = $Hud/HudRoot/Countdown
@onready var hud: HeartsHud = $Hud/HudRoot/Hearts
@onready var score_hud: ScoreHud = $Hud/HudRoot/Score
@onready var progress_hud: ProgressBarHud = $Hud/HudRoot/Progress
@onready var pause_menu: PauseMenu = $Hud/HudRoot/Pause
@onready var results: ResultsScreen = $GameOver/Results
@onready var _debug_label: Label = $Hud/HudRoot/Debug

## Base forward speed. The momentum dip lowers it temporarily after a hit.
var speed: float = GameConfig.RUN_SPEED
## Distance travelled this run, in pixels.
var distance: float = 0.0
## False after the last heart is lost or the tanod catches Elias; frozen until [R].
var is_running: bool = true
## True while the 3-2-1-GO countdown owns the screen. The world is frozen and
## the player is locked, but the overlay clock still ticks.
var is_counting_down: bool = false
## Pure score system: distance points, hazard passes, School Item pickups.
var score_system: ScoreSystem = ScoreSystem.new()
## Seconds of momentum dip hold remaining, then seconds of eased recovery.
var momentum_time_left: float = 0.0
var momentum_recover_time_left: float = 0.0
## True once the chase-ending lunge has started (caught or hazard-hit mid-chase).
var _caught: bool = false
## True once the failure cue has been queued, so a double game-over call (the
## lunge fallback plus the arrest callback) cannot restart the sting or bed.
var _fail_cue_started: bool = false

## Seconds the home zone lasts. Editable in the Inspector so the house run can
## be extended without touching GameConfig; HOME and STREET are timed, SCHOOL
## has no duration.
@export_range(5.0, 300.0, 1.0) var home_zone_seconds: float = GameConfig.ZONE_HOME_DURATION_SECONDS:
	set(value):
		home_zone_seconds = value
		# Re-derive immediately so a live Inspector edit moves the home
		# boundary (and the scaled hazard unlocks) without restarting the run.
		home_zone_length = GameConfig.zone_home_length(home_zone_seconds)
## Distance (px) at which home ends, derived from [member home_zone_seconds].
var home_zone_length: float = GameConfig.zone_home_length()
## Seconds the street zone lasts, editable in the Inspector the same way.
@export_range(5.0, 300.0, 1.0) var street_zone_seconds: float = GameConfig.ZONE_STREET_DURATION_SECONDS
## Distance (px) the street zone lasts, derived from [member street_zone_seconds].
var street_zone_length: float = GameConfig.zone_street_length()
## Zone currently being drawn and scored.
var current_zone: GameConfig.Zone = GameConfig.Zone.HOME
## Which rules this run plays by (GameConfig.RunMode), read from GameState.
var mode: int = GameConfig.RunMode.CAMPAIGN
## Distance (px) at which a campaign run finishes. 0 means endless.
var campaign_finish_distance: float = GameConfig.campaign_finish_distance()
## True once the campaign finish line has been crossed (victory shown once).
var _finished: bool = false
## True while the victory run-off plays: the scene is frozen, Elias runs off the
## right edge, and the results card waits for him to leave the frame.
var run_off_active: bool = false
## Test counters: victory run-offs started and handed off to the results.
var run_off_start_count: int = 0
var run_off_finish_count: int = 0
## Sprint speed Elias carries into the run-off: his last live speed, floored and
## multiplied by GameConfig.FINISH_RUN_OFF_SPEED_FACTOR.
var _run_off_speed: float = 0.0
## Coins collected during this run, shown on the results screen. Currency
## rides the wallet (GameState); this is just the per-run tally.
var coins_collected: int = 0
## Test counter: how many times the car honk actually fired. Guaranteed at
## most once per car by the director's single-pending-warning rule.
var car_honk_play_count: int = 0
## Test counter: how many times the engine pass-by actually fired.
var car_engine_play_count: int = 0
## Test counters: how many times each dog bark take actually fired - the
## double-bark telegraph (warn) and the single-bark chase cues (run).
var dog_bark_warn_play_count: int = 0
var dog_bark_run_play_count: int = 0
## Test counter: how many times the combo tier riser fired. One per rung per
## run at most (ScoreSystem's paid-set rule), so the suite can assert it.
var tier_up_play_count: int = 0
## Test counter: the failure cue is queued exactly once per run.
var fail_cue_play_count: int = 0
## Per-bark jitter source, so three barks in one encounter never sound like
## the same sample three times.
var _bark_rng := RandomNumberGenerator.new()
## The one gain tween the music uses. The duck and the fade-out animate the same
## property, so each new fade kills the previous one instead of fighting for it.
var _music_tween: Tween


func _ready() -> void:
	home_zone_length = GameConfig.zone_home_length(home_zone_seconds)
	street_zone_length = GameConfig.zone_street_length(street_zone_seconds)
	current_zone = GameConfig.zone_for_distance(
		distance, home_zone_length, street_zone_length, GameConfig.RunMode.CAMPAIGN)
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
	set_run_mode(GameState.mode)
	_debug_label.visible = GameState.debug_overlay
	GameState.debug_overlay_changed.connect(_on_debug_overlay_changed)
	results.visible = false
	arrest.visible = false
	arrest.scale = Vector2(GameConfig.ARREST_SCALE, GameConfig.ARREST_SCALE)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.caught.connect(_on_player_caught)
	player.item_collected.connect(_on_item_collected)
	player.damaged.connect(_on_player_damaged)
	# Shield pips live on their own panel; pushed on every charge change.
	player.shield_changed.connect(hud.set_shields)
	pursuer.caught.connect(_on_pursuer_caught)
	pursuer.lunge_finished.connect(_on_lunge_finished)
	arrest.animation_finished.connect(_on_arrest_finished)
	hud.set_hearts(player.health, player.max_health)
	hud.set_shields(player.shield_charges, player.shield_max)
	pause_menu.setup(self)

	score_system.score_changed.connect(score_hud.set_score)
	score_system.combo_changed.connect(score_hud.set_combo)
	score_system.item_count_changed.connect(score_hud.set_items)
	score_system.tier_reached.connect(_on_tier_reached)
	# The HUD shows coins earned THIS RUN, not the persistent wallet - a run
	# always starts from zero. The wallet signal stays reserved for the shop.
	score_hud.set_score(score_system.score)
	score_hud.set_combo(1, 0)
	score_hud.set_items(0)
	score_hud.set_coins(0)
	_update_progress()

	director.hazard_passed.connect(score_system.add_hazard_passed)
	director.item_missed.connect(_on_item_missed)
	director.car_warning_started.connect(_on_car_warning_started)
	director.car_entered.connect(_on_car_entered)
	director.dog_warning_started.connect(_on_dog_warning_started)
	director.dog_barked.connect(_on_dog_barked)
	_bark_rng.randomize()
	director.setup(hazards, randi())

	# The bed comes up on GO (see begin_run), ducks while the tanod chases and
	# falls silent the moment the world freezes (see _freeze_world).
	pause_menu.pause_changed.connect(_on_pause_changed)
	pursuer.chase_started.connect(_on_chase_started)
	pursuer.chase_faded.connect(_on_chase_faded)
	_begin_countdown()


## Lock the run behind the 3-2-1-GO overlay. is_running is false so every
## existing "is the world live?" gate (spawns, distance, score, the results
## screen) answers correctly without a second flag; is_counting_down is what
## keeps _physics_process ticking the overlay clock instead of returning
## outright. Pausing stays available on purpose.
func _begin_countdown() -> void:
	is_running = false
	is_counting_down = true
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	# Physics is off, so the world has to hand the sprite its start-line pose.
	player.waiting_at_start = true
	countdown.finished.connect(begin_run)
	countdown.begin()


## GO frame: unlock the run. Idempotent - the overlay emits finished once, and
## the suite calls this directly to skip the wait - so a second call never
## restarts the bed.
func begin_run() -> void:
	if not is_counting_down:
		return
	is_counting_down = false
	is_running = true
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	# GO cuts the idle straight into the run cycle, under the "GO!" beat.
	player.waiting_at_start = false
	_start_music()
	# A direct unlock (tests) never showed GO, so drop the blocking overlay
	# here. The real path has already handed the screen to the GO beat.
	if not countdown.go_shown:
		countdown.dismiss()


## Fade the run bed in from silence so starting a run never slams to full.
func _start_music() -> void:
	# Loop in code rather than in the import params: a future reimport cannot
	# silently switch the loop off.
	if music.stream is AudioStreamMP3:
		(music.stream as AudioStreamMP3).loop = true
	elif music.stream is AudioStreamOggVorbis:
		(music.stream as AudioStreamOggVorbis).loop = true
	# A pause during the countdown freezes a stopped stream; clearing the flag
	# keeps the first GO from arriving muted.
	music.stream_paused = false
	music.volume_db = GameConfig.MUSIC_SILENT_DB
	music.play()
	_fade_music_to(GameConfig.MUSIC_VOLUME_DB, GameConfig.MUSIC_FADE_IN_TIME)


## Move the bed to `db` over `seconds`, cancelling any fade already running.
func _fade_music_to(db: float, seconds: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", db, seconds)


## The tanod is closing in: drop the bed so the barks carry the warning.
func _on_chase_started() -> void:
	if is_running:
		_fade_music_to(GameConfig.MUSIC_DUCK_DB, GameConfig.MUSIC_DUCK_TIME)


## Chase over: bring the bed back at twice the duck time, so the recovery is
## less twitchy than the duck.
func _on_chase_faded() -> void:
	if is_running:
		_fade_music_to(GameConfig.MUSIC_VOLUME_DB, GameConfig.MUSIC_DUCK_TIME * 2.0)


## Pausing the tree does not stop audio, so the bed and the countdown voice have
## to be frozen by hand.
func _on_pause_changed(paused: bool) -> void:
	music.stream_paused = paused
	countdown.set_audio_paused(paused)


## Fade out and stop. A second call before the fade finishes simply restarts
## it: the kill in _fade_music_to keeps one tween on the property.
func _stop_music() -> void:
	if not music.playing:
		return
	_fade_music_to(GameConfig.MUSIC_SILENT_DB, GameConfig.MUSIC_FADE_OUT_TIME)
	_music_tween.tween_callback(music.stop)


## Failure presentation: the sting and the sad bed start together, so the
## reveal lands on one hit instead of a hand-off. Guarded so the lunge fallback
## and the arrest callback cannot queue it twice.
func _play_fail_cue() -> void:
	if _fail_cue_started:
		return
	_fail_cue_started = true
	fail_cue_play_count += 1
	# Loop in code for the same reason as _start_music: a reimport cannot switch
	# it off silently. MP3 is the committed format, OGG kept for parity.
	if fail_music.stream is AudioStreamMP3:
		(fail_music.stream as AudioStreamMP3).loop = true
	elif fail_music.stream is AudioStreamOggVorbis:
		(fail_music.stream as AudioStreamOggVorbis).loop = true
	fail_music.stream_paused = false
	fail_music.volume_db = GameConfig.MUSIC_SILENT_DB
	fail_sting.play()
	fail_music.play()
	create_tween().tween_property(
		fail_music, "volume_db", GameConfig.FAIL_MUSIC_DB,
		GameConfig.FAIL_MUSIC_FADE_IN)


## Honk when the car's exclamation appears, not when the car spawns: the horn
## blast is exactly CAR_WARNING_DURATION long, so it ends as the car enters the
## world and its tail decays as the car slides into view. Pitch is per variant,
## so the two car types sound like different vehicles.
func _on_car_warning_started(lane: int, variant: int) -> void:
	car_honk_play_count += 1
	car_honk_sfx.pitch_scale = GameConfig.CAR_HONK_PITCH[
		variant % GameConfig.CAR_HONK_PITCH.size()]
	car_honk_sfx.play()


## Engine pass-by, started when the car spawns (not at the warning). The clip
## is a recorded approach-pass-recede trimmed to the car's 2.27 s lifetime: it
## swells as the car crosses the screen edge, peaks just before it reaches the
## player's lane and fades out as it despawns. Non-positional on purpose - the
## lanes are vertical, so the clip's own envelope does the "passing by" work.
func _on_car_entered(lane: int, variant: int) -> void:
	car_engine_play_count += 1
	car_engine_sfx.pitch_scale = GameConfig.CAR_ENGINE_PITCH[
		variant % GameConfig.CAR_ENGINE_PITCH.size()]
	car_engine_sfx.play()


## Dog bark cue 1: the double-bark telegraph, with the exclamation.
func _on_dog_warning_started(lane: int, variant: int) -> void:
	_play_dog_bark(dog_bark_warn_sfx, variant)
	dog_bark_warn_play_count += 1


## Dog bark cues 2-3: the single-bark chase take as the dog crosses its
## screen-position thresholds (the index is reserved for future per-cue takes).
func _on_dog_barked(_index: int, variant: int) -> void:
	_play_dog_bark(dog_bark_run_sfx, variant)
	dog_bark_run_play_count += 1


## Shared bark player: base pitch is per dog variant, plus a small jitter so
## consecutive barks never sound like one sample repeated.
func _play_dog_bark(player: AudioStreamPlayer, variant: int) -> void:
	var base: float = GameConfig.DOG_BARK_PITCH[
		variant % GameConfig.DOG_BARK_PITCH.size()]
	player.pitch_scale = base + _bark_rng.randf_range(
		-GameConfig.DOG_BARK_PITCH_JITTER, GameConfig.DOG_BARK_PITCH_JITTER)
	player.play()


## Hand the run its rules. Called by _ready with GameState.mode and by the
## suite to exercise both modes in one world. Recomputes the campaign finish
## so a mode swap never leaves a stale line behind.
func set_run_mode(new_mode: int) -> void:
	mode = new_mode
	campaign_finish_distance = (
		GameConfig.campaign_finish_distance(home_zone_length, street_zone_length)
		if mode == GameConfig.RunMode.CAMPAIGN
		else 0.0
	)


## Speed the run should settle at outside a momentum dip: campaign ramps
## continuously to CAMPAIGN_RAMP_MAX_MULTIPLIER by the finish line; endless
## ramps with distance so late runs get faster. The Speed shop upgrade
## multiplies both.
func _base_speed() -> float:
	var upgraded := GameConfig.shop_speed_multiplier(
		GameState.shop_level(GameConfig.ShopUpgrade.SPEED))
	if mode == GameConfig.RunMode.ENDLESS:
		return GameConfig.RUN_SPEED * GameConfig.endless_speed_multiplier(distance) * upgraded
	var ramp := GameConfig.campaign_speed_multiplier(
		distance, campaign_finish_distance)
	return GameConfig.RUN_SPEED * ramp * upgraded


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_counting_down:
		countdown.advance(delta)
		# The GO beat unlocks the run inside advance(); returning here keeps the
		# unlock frame from also simulating, so the first live frame is clean.
		return
	if run_off_active:
		# Victory lap: the world is frozen, only Elias moves. Stepped here (not a
		# tween) so a paused tree freezes it and the suite can drive it.
		_advance_run_off(delta)
		return
	if not is_running:
		return
	var base := _base_speed()
	if momentum_time_left > 0.0:
		momentum_time_left = maxf(momentum_time_left - delta, 0.0)
		speed = base * GameConfig.MOMENTUM_DIP_FACTOR
		if momentum_time_left <= 0.0:
			momentum_recover_time_left = GameConfig.MOMENTUM_RECOVER_TIME
	elif momentum_recover_time_left > 0.0:
		momentum_recover_time_left = maxf(momentum_recover_time_left - delta, 0.0)
		var t := 1.0 - clampf(
			momentum_recover_time_left / GameConfig.MOMENTUM_RECOVER_TIME, 0.0, 1.0)
		speed = lerpf(
			base * GameConfig.MOMENTUM_DIP_FACTOR,
			base,
			t,
		)
	else:
		speed = base
	# Keep live hazards/items on the exact current world speed so they ride
	# the road with no slide through the dip and the ease-back.
	for child in hazards.get_children():
		if child is Hazard or child is Collectible:
			child.speed = speed
	distance += speed * delta
	_update_zone()
	_update_progress()
	# Campaign: stop spawning before the line so the last stretch is a clean
	# sprint, then end the run in a victory the moment Elias reaches it.
	if mode == GameConfig.RunMode.CAMPAIGN:
		if distance >= campaign_finish_distance:
			_finish_campaign()
			return
		if distance < campaign_finish_distance - GameConfig.CAMPAIGN_SPAWN_CUTOFF_PX:
			director.tick(delta, speed, distance, current_zone, home_zone_length)
	else:
		director.tick(delta, speed, distance, current_zone, home_zone_length)
	score_system.add_distance(distance)
	pursuer.set_world_speed(speed)
	pursuer.track(player.lane_y)
	player.pursuer_active = pursuer.is_active()
	queue_redraw()
	_update_debug()


## Push the top-center progress bar for the current mode: the campaign course
## track, or the endless gold-milestone bar.
func _update_progress() -> void:
	if progress_hud == null:
		return
	if mode == GameConfig.RunMode.CAMPAIGN:
		progress_hud.set_campaign(
			distance,
			home_zone_length,
			street_zone_length,
			campaign_finish_distance,
			current_zone,
		)
	else:
		progress_hud.set_endless(distance)


## Step the zone clock. HOME and STREET are timed; the mode decides what comes
## after the street - SCHOOL for campaign, street forever for endless.
## The swap is instant - there is no transition art - and leftover hazards are
## cleared in the same frame, so nothing from the old zone lingers on screen.
func _update_zone() -> void:
	var next := GameConfig.zone_for_distance(
		distance, home_zone_length, street_zone_length, mode)
	if next == current_zone:
		return
	current_zone = next
	_purge_zone_leftovers()
	zone_changed.emit(current_zone)
	queue_redraw()


## Free hazards that cannot exist in the freshly entered zone, plus anything
## already on top of Elias, so the swap frame never lands a hit he could not
## see coming. Kinds legal in both zones ride across untouched, and pickups
## are zone-agnostic so they always stay.
func _purge_zone_leftovers() -> void:
	for child in hazards.get_children():
		if child is not Hazard:
			continue
		var hazard := child as Hazard
		if not GameConfig.hazard_allows_zone(hazard.kind, current_zone):
			hazard.queue_free()
			continue
		if hazard.position.x > GameConfig.PLAYER_X \
				and hazard.position.x < GameConfig.PLAYER_X + GameConfig.ZONE_SWAP_CLEAR_PX:
			hazard.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F3:
			GameState.set_debug_overlay(not GameState.debug_overlay)
			get_viewport().set_input_as_handled()
		KEY_R:
			# No restart during the victory lap: let Elias finish his exit.
			if not is_running and not is_counting_down and not run_off_active:
				get_tree().reload_current_scene()
				get_viewport().set_input_as_handled()


## Apply a debug-overlay flip from the settings panel or F3, refreshing the
## readout so a re-enabled overlay shows live values instead of stale text.
func _on_debug_overlay_changed(shown: bool) -> void:
	_debug_label.visible = shown
	if shown:
		_update_debug()


# --- Run lifecycle -----------------------------------------------------------

func _on_health_changed(current: int, maximum: int) -> void:
	hud.set_hearts(current, maximum)


func _on_item_collected(kind: int) -> void:
	# Currency is not score: coins tally per run for the HUD/results card and
	# go to the persistent wallet, touching neither the score, the item count,
	# nor the combo.
	if kind == GameConfig.ItemKind.COIN:
		coins_collected += 1
		score_hud.set_coins(coins_collected)
		GameState.add_coins(GameConfig.COIN_VALUE)
		return
	score_system.add_item_pickup()


## A new multiplier rung was reached. ScoreSystem already guarantees this fires
## at most once per rung per run, so the coin bonus cannot be farmed by letting
## the chain break and rebuilding it.
func _on_tier_reached(tier: int) -> void:
	tier_up_play_count += 1
	tier_sfx.play()
	var bonus := GameConfig.combo_tier_coin_bonus(tier)
	if bonus <= 0:
		return
	# Tier coins are currency, not score: the per-run tally (shown on the HUD
	# and the results card) and the persistent wallet both move by the bonus.
	coins_collected += bonus
	score_hud.set_coins(coins_collected)
	GameState.add_coins(bonus)


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
		_show_game_over(ResultsScreen.Outcome.CAUGHT)


func _on_arrest_finished() -> void:
	_show_game_over(ResultsScreen.Outcome.CAUGHT)


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
	_show_game_over(ResultsScreen.Outcome.OUT_OF_HEARTS)


func _freeze_world() -> void:
	is_running = false
	is_counting_down = false
	# A failure landing on the same frame as the finish line cancels the victory
	# lap, so the results card that follows cannot be overwritten by a win.
	run_off_active = false
	_stop_music()
	countdown.dismiss()
	hazards.process_mode = Node.PROCESS_MODE_DISABLED
	director.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.sprite.modulate.a = 1.0
	_update_debug()


## Cross the campaign finish line: freeze the world, then let Elias run off the
## right edge before the victory card is revealed. Guarded so a single crossing
## can never double-report the score.
func _finish_campaign() -> void:
	if _finished:
		return
	_finished = true
	_freeze_world()
	_begin_run_off()


## Victory run-off: the scene has stopped, so the only thing still moving is
## Elias. He runs forward off the right edge, sprinting faster than his in-run
## speed with the run cycle scaled to match, so the lap is short and his feet
## still match the ground.
func _begin_run_off() -> void:
	run_off_active = true
	run_off_start_count += 1
	_run_off_speed = maxf(speed, GameConfig.FINISH_RUN_OFF_MIN_SPEED) \
		* GameConfig.FINISH_RUN_OFF_SPEED_FACTOR
	# A finish mid-jump or mid-slide should still exit on the ground.
	player.air_height = 0.0
	player.vertical_speed = 0.0
	player.in_air = false
	player.is_sliding = false
	player.invulnerable_time_left = 0.0
	player.position = Vector2(player.position.x, player.lane_y)
	player.sprite.rotation = 0.0
	player.sprite.modulate = Color.WHITE
	player.sprite.flip_h = false
	player.sprite.speed_scale = GameConfig.FINISH_RUN_OFF_SPEED_FACTOR
	player.sprite.play(&"run")
	# The last stretch can still hold a car or two: fade them rather than let
	# Elias ghost through frozen obstacles on his way out.
	if hazards.get_child_count() > 0:
		var tw := create_tween()
		tw.tween_property(
			hazards, "modulate:a", 0.0, GameConfig.FINISH_RUN_OFF_FADE_TIME)
		tw.tween_callback(func() -> void: hazards.visible = false)
	pursuer.visible = false
	pursuer.process_mode = Node.PROCESS_MODE_DISABLED
	_update_debug()


func _advance_run_off(delta: float) -> void:
	player.position.x += _run_off_speed * delta
	if player.position.x < GameConfig.FINISH_RUN_OFF_EXIT_X:
		return
	player.position.x = GameConfig.FINISH_RUN_OFF_EXIT_X
	run_off_active = false
	run_off_finish_count += 1
	_show_game_over(ResultsScreen.Outcome.VICTORY)


func _show_game_over(outcome: int) -> void:
	# Failure gets the sting, then the looping bed. Victory stays silent.
	if outcome != ResultsScreen.Outcome.VICTORY:
		_play_fail_cue()
	# The progress bar must not peek out from under the results overlay.
	if progress_hud != null:
		progress_hud.visible = false
	# Campaign: finish-gated score rule (gold needs a new best). Endless:
	# medal by distance reached. The best is read BEFORE show_results records
	# this run's score with GameState.
	var previous_best := GameState.best_for_mode()
	var medal := GameConfig.medal_for_distance(int(distance / 100.0))
	if mode == GameConfig.RunMode.CAMPAIGN:
		medal = GameConfig.campaign_medal(
			outcome == ResultsScreen.Outcome.VICTORY,
			score_system.score,
			previous_best,
		)
	results.show_results(
		outcome,
		score_system.score,
		int(distance / 100.0),
		["HOME", "STREET", "SCHOOL"][current_zone],
		score_system.item_count,
		medal,
		coins_collected,
	)
	_update_debug()


func _update_debug() -> void:
	if not _debug_label.visible:
		return
	_debug_label.text = "LANE  %d   (%.1f px)\nSPEED %.0f px/s\nDIST  %.1f m\nZONE  %s\nFINISH %s\nAIR   %.0f px   SLIDE %s\nHEARTS %d/%d   IFRAME %.2f s\nSCORE %d   x%d   ITEMS %d\nCHASE %s  GAP %.0f px\nFPS   %d\n[F3] hide" % [
		player.lane,
		player.lane_y,
		speed,
		distance / 100.0,
		["HOME", "STREET", "SCHOOL"][current_zone],
		_finish_debug_text(),
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


## The finish readout for the debug overlay: metres still to run in campaign,
## a dash in endless (no line exists).
func _finish_debug_text() -> String:
	if mode != GameConfig.RunMode.CAMPAIGN:
		return "--"
	return "IN %.1f m" % maxf((campaign_finish_distance - distance) / 100.0, 0.0)


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
