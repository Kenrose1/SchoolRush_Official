extends Node
## Headless test suite for School Rush.
##
## Run with:
##   godot --headless --path . res://tests/test_runner.tscn
##
## Exit code 0 means every check passed. Tell-tale failure output is a line
## starting with "FAIL:".

var _checks := 0
var _failures := 0

# The whole suite runs against this scratch save so the player's real
# progress (wallet + bought upgrades) can never skew gameplay tests.
const SUITE_SAVE_PATH := "user://test_suite_scratch.cfg"
var _real_save_path: String
var _real_coins: int
var _real_levels: Dictionary


func _ready() -> void:
	await get_tree().process_frame

	# Isolate from the real save: defaults for wallet and shop levels.
	_real_save_path = GameState.save_path
	_real_coins = GameState.coins
	_real_levels = GameState.shop_levels.duplicate()
	GameState.save_path = SUITE_SAVE_PATH
	GameState.coins = 0
	GameState.shop_levels = {}
	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := SUITE_SAVE_PATH + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	_section("GameConfig")
	_test_config()

	_section("Zones")
	_test_zones()

	_section("Zone purge")
	await _test_zone_purge()

	_section("Input map")
	_test_input()

	_section("Player")
	await _test_player()

	_section("Health")
	_test_health()

	_section("Hazards")
	await _test_hazard()

	_section("Spawn director")
	await _test_spawn_director()

	_section("Home hazards")
	await _test_home_hazards()

	_section("Score system")
	_test_score_system()

	_section("Medals")
	_test_medals()

	_section("Modes")
	_test_modes()

	_section("Progress bar")
	_test_progress()

	_section("Game state")
	_test_game_state()

	_section("School Items")
	await _test_collectible()

	_section("Pickup director")
	_test_pickup_director()

	_section("Coins")
	_test_coins()

	_section("Shop")
	_test_shop()

	_section("Debug tools")
	_test_debug_tools()

	_section("Pursuer")
	await _test_pursuer()

	_section("Main menu")
	_test_menu()

	_section("Menu music")
	_test_menu_music()

	_section("Run music")
	await _test_run_music()

	_section("Run audio")
	await _test_run_audio()

	_section("Run countdown")
	await _test_countdown()

	_section("Results audio")
	await _test_results_audio()

	_section("Settings")
	_test_settings()

	_section("UI click")
	_test_ui_sfx()

	_section("UI fonts")
	_test_ui_fonts()

	_section("Scenes")
	_test_scenes()

	# Hand the player's real save back before exiting.
	GameState.save_path = _real_save_path
	GameState.coins = _real_coins
	GameState.shop_levels = _real_levels
	GameState.coins_changed.emit(GameState.coins)

	_report()


# --- Suites ------------------------------------------------------------------

func _test_config() -> void:
	_check_eq(GameConfig.LANE_COUNT, 3, "three lane tiers")
	_check_eq(GameConfig.LANE_TOP, 0, "top lane index")
	_check_eq(GameConfig.LANE_BOTTOM, 2, "bottom lane index")

	_check(
		GameConfig.LANE_Y[0] < GameConfig.LANE_Y[1] and GameConfig.LANE_Y[1] < GameConfig.LANE_Y[2],
		"lane Y values increase top to bottom",
	)
	for lane in GameConfig.LANE_COUNT - 1:
		_check_near(
			float(GameConfig.LANE_Y[lane + 1]) - float(GameConfig.LANE_Y[lane]),
			GameConfig.LANE_SPACING,
			0.01,
			"lane %d spacing matches LANE_SPACING" % lane,
		)

	_check_eq(GameConfig.clamp_lane(-5), GameConfig.LANE_TOP, "clamp_lane clamps above")
	_check_eq(GameConfig.clamp_lane(99), GameConfig.LANE_BOTTOM, "clamp_lane clamps below")
	_check_eq(GameConfig.step_lane(GameConfig.LANE_TOP, -1), GameConfig.LANE_TOP, "cannot step above top")
	_check_eq(GameConfig.step_lane(GameConfig.LANE_BOTTOM, 1), GameConfig.LANE_BOTTOM, "cannot step below bottom")
	_check_eq(GameConfig.step_lane(GameConfig.LANE_MIDDLE, -1), GameConfig.LANE_TOP, "step up from middle")
	_check_eq(GameConfig.step_lane(GameConfig.LANE_MIDDLE, 1), GameConfig.LANE_BOTTOM, "step down from middle")

	_check_near(
		GameConfig.LANE_SWITCH_SPEED,
		GameConfig.LANE_SPACING / GameConfig.LANE_SWITCH_TIME,
		0.01,
		"lane switch speed derives from spacing and time",
	)

	_check(
		GameConfig.JUMP_APEX > 90.0 and GameConfig.JUMP_APEX < 150.0,
		"jump apex is roughly one lane (%.1f px)" % GameConfig.JUMP_APEX,
	)
	_check(
		GameConfig.JUMP_AIRTIME > 0.45 and GameConfig.JUMP_AIRTIME < 0.65,
		"jump airtime is snappy (%.2f s)" % GameConfig.JUMP_AIRTIME,
	)
	_check(GameConfig.SLIDE_DURATION > 0.3 and GameConfig.SLIDE_DURATION < 1.0, "slide duration is playable")
	_check(GameConfig.RUN_SPEED > 0.0, "run speed is positive")
	_check(GameConfig.PLAYER_START_LANE == GameConfig.LANE_MIDDLE, "player starts in the middle lane")


func _test_zones() -> void:
	_check_eq(GameConfig.ZONE_ORDER.size(), 3, "three zones in a run")
	_check_eq(GameConfig.ZONE_ORDER[0], GameConfig.Zone.HOME, "home runs first")
	_check_eq(GameConfig.ZONE_ORDER[1], GameConfig.Zone.STREET, "street runs second")
	_check_eq(GameConfig.ZONE_ORDER[2], GameConfig.Zone.SCHOOL, "school runs last")
	_check(
		GameConfig.ZONE_HOME_DURATION_SECONDS > 0.0,
		"home has a duration",
	)
	_check(
		GameConfig.ZONE_HOME_DURATION_SECONDS >= GameConfig.ZONE_HOME_MIN_SECONDS,
		"default home duration clears the minimum",
	)
	_check(
		GameConfig.ZONE_STREET_DURATION_SECONDS > 0.0,
		"street has a duration",
	)
	_check(
		GameConfig.ZONE_STREET_DURATION_SECONDS >= GameConfig.ZONE_STREET_MIN_SECONDS,
		"default street duration clears the minimum",
	)
	_check(
		GameConfig.ZONE_SWAP_CLEAR_PX > 0.0
		and GameConfig.ZONE_SWAP_CLEAR_PX < GameConfig.PLAYER_X,
		"the zone swap clears a tight margin ahead of the player",
	)
	_check_near(
		GameConfig.zone_home_length(),
		GameConfig.ZONE_HOME_DURATION_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"home length derives from duration and speed",
	)
	_check_near(
		GameConfig.zone_street_length(),
		GameConfig.ZONE_STREET_DURATION_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"street length derives from duration and speed",
	)

	var length := GameConfig.zone_home_length()
	var street_len := GameConfig.zone_street_length()
	_check_eq(GameConfig.zone_for_distance(0.0), GameConfig.Zone.HOME, "the run opens at home")
	_check_eq(
		GameConfig.zone_for_distance(length - 1.0),
		GameConfig.Zone.HOME,
		"home holds right up to the boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance(length),
		GameConfig.Zone.STREET,
		"street starts exactly at the home boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance(length + street_len - 1.0),
		GameConfig.Zone.STREET,
		"street holds right up to the school boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance(length + street_len),
		GameConfig.Zone.SCHOOL,
		"school starts exactly at the street boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance((length + street_len) * 10.0),
		GameConfig.Zone.SCHOOL,
		"school never ends",
	)

	var custom := GameConfig.zone_home_length(20.0)
	_check_near(custom, 20.0 * GameConfig.RUN_SPEED, 0.01, "a custom duration scales the boundary")
	_check_near(
		GameConfig.zone_home_length(0.5),
		GameConfig.ZONE_HOME_MIN_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"home duration clamps at the minimum",
	)
	_check_eq(
		GameConfig.zone_for_distance(custom, custom),
		GameConfig.Zone.STREET,
		"a per-run override moves the boundary",
	)
	_check_near(
		GameConfig.zone_street_length(0.5),
		GameConfig.ZONE_STREET_MIN_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"street duration clamps at the minimum",
	)
	_check_eq(
		GameConfig.zone_for_distance(custom + street_len, custom, street_len),
		GameConfig.Zone.SCHOOL,
		"a per-run street override moves the school boundary",
	)
	_check_near(
		GameConfig.HOUSE_FLOOR_SPLIT_RATIO,
		GameConfig.HOUSE_FLOOR_SPLIT_Y / GameConfig.HOUSE_SOURCE_HEIGHT,
		0.0001,
		"the floor split ratio survives a texture downscale",
	)
	var split_px := GameConfig.HOUSE_FLOOR_SPLIT_RATIO * 1920.0
	_check(
		split_px > 0.0 and split_px < 1920.0,
		"the floor split lands inside the downscaled texture",
	)

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main scene loads for the zone check")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	add_child(main)
	var world := main.get_node_or_null("RunWorld") as RunWorld
	_check(world != null, "run world exists for the zone check")
	if world != null:
		world.set_physics_process(false)
		world.set_process(false)
		_check_eq(world.current_zone, GameConfig.Zone.HOME, "the run world opens at home")
		_check_eq(
			world.home_zone_seconds,
			GameConfig.ZONE_HOME_DURATION_SECONDS,
			"the world uses the default home duration",
		)
		_check_near(
			world.home_zone_length,
			GameConfig.zone_home_length(),
			0.01,
			"the world derives its home boundary",
		)
		# A live edit of the house duration re-derives the boundary at once.
		var saved_seconds: float = world.home_zone_seconds
		world.home_zone_seconds = 40.0
		_check_near(
			world.home_zone_length,
			GameConfig.zone_home_length(40.0),
			0.01,
			"editing home_zone_seconds live re-derives the home boundary",
		)
		world.home_zone_seconds = saved_seconds
		_check_eq(
			world.street_zone_seconds,
			GameConfig.ZONE_STREET_DURATION_SECONDS,
			"the world uses the default street duration",
		)
		_check_near(
			world.street_zone_length,
			GameConfig.zone_street_length(),
			0.01,
			"the world derives its street boundary",
		)
		_check_near(world.SCHOOL_BASE.a, 1.0, 0.001, "the school base is fully opaque (no clear-colour bleed)")
		_check(
			ResourceLoader.exists(world.SCHOOL_TEXTURE),
			"the school hallway is on disk",
		)
		_check(
			ResourceLoader.exists(world.SCHOOL_BACKGROUND_TEXTURE),
			"the school background is on disk",
		)
		_check_eq(
			world.SCHOOL_BACKGROUND_PARALLAX,
			world.SKY_PARALLAX,
			"the school exterior drifts like the street sky",
		)
		_check(
			world.SCHOOL_BACKGROUND_PARALLAX < world.SCHOOL_WALL_PARALLAX,
			"the school exterior drifts slower than the hall",
		)
		_check_eq(
			world.SCHOOL_WALL_PARALLAX,
			world.SCHOOL_FLOOR_PARALLAX,
			"school wall and floor scroll in lockstep",
		)
		_check(
			world.SCHOOL_FLOOR_SPLIT_Y > 0.0 and world.SCHOOL_FLOOR_SPLIT_Y < 1024.0,
			"the school floor split lands inside the hallway art",
		)
		_check_near(world.HOME_BASE.a, 1.0, 0.001, "the home base is fully opaque (no sky leak)")
		_check(
			ResourceLoader.exists(world.HOME_SKY_TEXTURE),
			"the home window sky is on disk",
		)
		_check_eq(
			world.HOME_SKY_PARALLAX,
			world.SKY_PARALLAX,
			"the home sky drifts like the street sky",
		)
		_check(
			world.HOME_SKY_PARALLAX < world.HOME_WALL_PARALLAX,
			"the home sky drifts slower than the room",
		)
		_check_eq(
			world.HOME_WALL_PARALLAX,
			world.HOME_FLOOR_PARALLAX,
			"home wall and floor scroll in lockstep",
		)

		# Car honk: the world owns the player (not the warning node, which frees
		# itself and would cut the horn's tail) and honks once per car warning.
		var honk_player := world.car_honk_sfx as AudioStreamPlayer
		_check(honk_player != null, "the world owns a car honk player")
		if honk_player != null:
			_check_eq(honk_player.bus, "SFX", "the car honk routes to the SFX bus")
			var honk_stream := honk_player.stream as AudioStream
			_check(
				honk_stream != null and honk_stream.get_length() > 1.0,
				"the car honk clip is the long blast on disk",
			)
		_check_eq(world.car_honk_play_count, 0, "the car honk is silent before any car")
		world._on_car_warning_started(0, 0)
		_check_eq(world.car_honk_play_count, 1, "a started car warning honks once")
		_check_near(
			world.car_honk_sfx.pitch_scale,
			GameConfig.CAR_HONK_PITCH[0],
			0.0001,
			"variant 0 honks at its configured pitch",
		)
		world._on_car_warning_started(2, 1)
		_check_near(
			world.car_honk_sfx.pitch_scale,
			GameConfig.CAR_HONK_PITCH[1],
			0.0001,
			"variant 1 honks a step lower",
		)
		_check_eq(world.car_honk_play_count, 2, "each car warning honks separately")
		world.car_honk_play_count = 0

		# Engine pass-by: starts at spawn, trimmed to end with the car's
		# despawn so no engine hum outlives its car.
		var engine_player := world.car_engine_sfx as AudioStreamPlayer
		_check(engine_player != null, "the world owns a car engine player")
		if engine_player != null:
			_check_eq(engine_player.bus, "SFX", "the car engine routes to the SFX bus")
			var engine_stream := engine_player.stream as AudioStream
			_check(
				engine_stream != null
				and engine_stream.get_length() > 2.0
				and engine_stream.get_length() < 2.5,
				"the engine clip is the trimmed pass-by, not the long original",
			)
			var car_lifetime: float = (GameConfig.SPAWN_X - GameConfig.DESPAWN_X) / (
				GameConfig.RUN_SPEED + float(
					GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["extra_speed"])
			)
			_check(
				engine_player.stream.get_length() <= car_lifetime + 0.02,
				"the engine clip is no longer than the car's lifetime",
			)
		_check_eq(world.car_engine_play_count, 0, "the engine is silent before any car")
		world._on_car_entered(1, 0)
		_check_eq(world.car_engine_play_count, 1, "a spawned car starts the engine")
		_check_near(
			world.car_engine_sfx.pitch_scale,
			GameConfig.CAR_ENGINE_PITCH[0],
			0.0001,
			"variant 0 idles at its configured pitch",
		)
		world._on_car_entered(2, 1)
		_check_near(
			world.car_engine_sfx.pitch_scale,
			GameConfig.CAR_ENGINE_PITCH[1],
			0.0001,
			"variant 1 idles a step lower",
		)
		_check_eq(world.car_engine_play_count, 2, "each spawned car runs its own pass-by")
		world.car_engine_play_count = 0

		# Dog barks: the warn take is the double-bark telegraph, the run take is
		# the single-bark chase cue. Both route to SFX and keep their trim.
		var warn_bark := world.dog_bark_warn_sfx as AudioStreamPlayer
		var run_bark := world.dog_bark_run_sfx as AudioStreamPlayer
		_check(
			warn_bark != null and run_bark != null,
			"the world owns both dog bark players",
		)
		if warn_bark != null and run_bark != null:
			_check_eq(warn_bark.bus, "SFX", "the warn bark routes to the SFX bus")
			_check_eq(run_bark.bus, "SFX", "the run bark routes to the SFX bus")
			var warn_stream := warn_bark.stream as AudioStream
			var run_stream := run_bark.stream as AudioStream
			_check(
				warn_stream != null and warn_stream.get_length() > 0.6
				and warn_stream.get_length() < 0.8,
				"the warn bark is the double-bark take",
			)
			_check(
				run_stream != null and run_stream.get_length() > 0.3
				and run_stream.get_length() < 0.45,
				"the run bark is the single-bark take",
			)
		_check(
			world.dog_bark_warn_play_count == 0 and world.dog_bark_run_play_count == 0,
			"the dog barks are silent before any dog",
		)
		world._bark_rng.seed = 5
		world._on_dog_warning_started(1, 0)
		_check_eq(
			world.dog_bark_warn_play_count, 1,
			"the warning fires the double-bark telegraph",
		)
		_check(
			world.dog_bark_warn_sfx.pitch_scale >= 1.0 - GameConfig.DOG_BARK_PITCH_JITTER
			and world.dog_bark_warn_sfx.pitch_scale <= 1.0 + GameConfig.DOG_BARK_PITCH_JITTER,
			"dog1's telegraph bark sits in its jitter band",
		)
		world._on_dog_barked(0, 1)
		var bark_pitch_a: float = world.dog_bark_run_sfx.pitch_scale
		world._on_dog_barked(1, 1)
		var bark_pitch_b: float = world.dog_bark_run_sfx.pitch_scale
		_check_eq(world.dog_bark_run_play_count, 2, "both chase cues fire the run take")
		_check(
			bark_pitch_a >= GameConfig.DOG_BARK_PITCH[1] - GameConfig.DOG_BARK_PITCH_JITTER
			and bark_pitch_a <= GameConfig.DOG_BARK_PITCH[1] + GameConfig.DOG_BARK_PITCH_JITTER,
			"dog2's chase bark sits in its jitter band",
		)
		_check(
			bark_pitch_a != bark_pitch_b,
			"the bark jitter varies between consecutive barks",
		)
		world.dog_bark_warn_play_count = 0
		world.dog_bark_run_play_count = 0

		# Zone swaps are instant: no transition node ships, and the swap lands
		# on the crossing frame.
		_check(
			world.get_node_or_null("ZoneFade") == null,
			"the run world ships no zone transition layer",
		)

		# Force the boundary; no frames pass here.
		var seen: Array = []
		world.zone_changed.connect(func(zone: GameConfig.Zone) -> void: seen.append(zone))
		world.distance = world.home_zone_length + 1.0
		world.distance = world.home_zone_length + 1.0
		world.begin_run()
		world._update_zone()
		if world.zone_swap_active:
			_check(not world.pursuer.visible,
				"the tanod is hidden during a zone exit")
			_check_eq(world.pursuer.process_mode, Node.PROCESS_MODE_DISABLED,
				"the tanod cannot advance while Elias exits")
			_check(not world.player.hitbox.monitoring,
				"zone exit disables Elias's hazard hitbox")
			_check(not world.player.can_take_damage(),
				"zone exit grants Elias invulnerability")
			while world.zone_swap_active:
				world._physics_process(1.0 / 60.0)
			_check(world.player.hitbox.monitoring,
				"the next zone restores Elias's hazard hitbox")
			_check_near(world.player.invulnerable_time_left,
				GameConfig.I_FRAME_TIME, 0.01,
				"the next zone starts Elias on a fresh i-frame window")
		world._update_zone()
		_check_eq(world.current_zone, GameConfig.Zone.STREET,
			"crossing the boundary swaps the zone on the same frame")
		_check_eq(seen.size(), 1, "the zone change emits exactly once")
		if seen.size() == 1:
			_check_eq(seen[0], GameConfig.Zone.STREET, "the signal reports the street")
		world._update_zone()
		_check_eq(seen.size(), 1, "a second boundary check emits nothing")

		# Second boundary: street hands over to school the same way.
		world.distance = world.home_zone_length + world.street_zone_length + 1.0
		world._update_zone()
		_check_eq(world.current_zone, GameConfig.Zone.SCHOOL,
			"crossing the street boundary switches to school")
		_check_eq(seen.size(), 2, "the second zone change emits exactly once more")
		if seen.size() == 2:
			_check_eq(seen[1], GameConfig.Zone.SCHOOL, "the signal reports the school")

		world.distance += 100000.0
		world._update_zone()
		_check_eq(seen.size(), 2, "no signal fires after the terminal zone")
	main.queue_free()


func _test_zone_purge() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main scene loads for the purge check")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	add_child(main)
	var world := main.get_node_or_null("RunWorld") as RunWorld
	_check(world != null, "run world exists for the purge check")
	if world == null:
		main.queue_free()
		return
	world.set_physics_process(false)
	world.set_process(false)
	var hazard_scene := load("res://scenes/hazard.tscn") as PackedScene
	var collectible_scene := load("res://scenes/collectible.tscn") as PackedScene

	# Seed one hazard per purge rule, then cross home -> street on a single
	# frame: the furniture and anything on top of Elias go, a hazard just past
	# the clear margin and the distant street hazard stay, so does the pickup.
	world.distance = world.home_zone_length + 1.0
	var nightstand := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(nightstand)
	nightstand.setup(GameConfig.HazardKind.NIGHTSTAND, GameConfig.LANE_TOP, GameConfig.RUN_SPEED)
	nightstand.position.x = 1600.0
	var manhole_far := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(manhole_far)
	manhole_far.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
	manhole_far.position.x = 3000.0
	var manhole_near := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(manhole_near)
	manhole_near.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_BOTTOM, GameConfig.RUN_SPEED)
	manhole_near.position.x = GameConfig.PLAYER_X + GameConfig.ZONE_SWAP_CLEAR_PX * 0.5
	var manhole_just_clear := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(manhole_just_clear)
	manhole_just_clear.setup(
		GameConfig.HazardKind.MANHOLE, GameConfig.LANE_TOP, GameConfig.RUN_SPEED)
	manhole_just_clear.position.x = GameConfig.PLAYER_X + GameConfig.ZONE_SWAP_CLEAR_PX + 40.0
	var coin := collectible_scene.instantiate() as Collectible
	world.hazards.add_child(coin)
	coin.setup(GameConfig.ItemKind.COIN, GameConfig.LANE_BOTTOM, GameConfig.RUN_SPEED)
	coin.position.x = 2500.0

	world._update_zone()
	_check_eq(world.current_zone, GameConfig.Zone.STREET,
		"the swap flips home to street on one frame")
	_check(nightstand.is_queued_for_deletion(),
		"the furniture never survives the swap into the street")
	_check(manhole_near.is_queued_for_deletion(),
		"a hazard on top of Elias is cleared at the swap")
	_check(not manhole_just_clear.is_queued_for_deletion(),
		"a hazard just past the clear margin rides through")
	_check(not manhole_far.is_queued_for_deletion(),
		"a far street hazard rides through the swap")
	_check(not coin.is_queued_for_deletion(), "the coin survives the swap")
	await get_tree().process_frame

	# --- Street -> school: the dog and the car never follow Elias indoors -------
	world.distance = world.home_zone_length + world.street_zone_length + 1.0
	var dog := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(dog)
	dog.setup(GameConfig.HazardKind.DOG, GameConfig.LANE_TOP, GameConfig.RUN_SPEED)
	dog.position.x = 2000.0
	var car := hazard_scene.instantiate() as Hazard
	world.hazards.add_child(car)
	car.setup(GameConfig.HazardKind.CAR, GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
	car.position.x = 2200.0
	world._update_zone()
	_check_eq(world.current_zone, GameConfig.Zone.SCHOOL,
		"the second swap flips street to school")
	_check(dog.is_queued_for_deletion(), "the dog never chases into the school")
	_check(car.is_queued_for_deletion(), "the car never follows into the school")
	_check(not manhole_far.is_queued_for_deletion(),
		"a distant manhole is legal in the school and survives")
	await get_tree().process_frame

	world.director.queue_free()
	main.queue_free()
	await get_tree().process_frame


func _test_input() -> void:
	for action: String in ["lane_up", "lane_down", "jump", "slide", "pause"]:
		_check(InputMap.has_action(action), "action '%s' exists" % action)
	_check(not InputMap.has_action("dash"), "dash action is not registered (dropped in v1.4)")

	_check_eq(InputMap.action_get_events("lane_up").size(), 2, "lane_up has W and Up")
	_check_eq(InputMap.action_get_events("lane_down").size(), 2, "lane_down has S and Down")

	var jump := _first_key("jump")
	_check_eq(jump.physical_keycode, KEY_SPACE, "jump is bound to Space")
	var slide := _first_key("slide")
	_check_eq(slide.physical_keycode, KEY_CTRL, "slide is bound to Ctrl")
	var pause := _first_key("pause")
	_check_eq(pause.physical_keycode, KEY_ESCAPE, "pause is bound to Esc")


func _test_player() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	_check(scene != null, "player scene loads")
	if scene == null:
		return

	var player := scene.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)

	_check_eq(player.lane, GameConfig.LANE_MIDDLE, "player spawns in the middle lane")
	_check_near(player.position.x, GameConfig.PLAYER_X, 0.01, "player is anchored at PLAYER_X")
	_check_near(player.lane_y, GameConfig.lane_y(GameConfig.LANE_MIDDLE), 0.01, "player starts on the middle baseline")

	# Lane bounds and stepping.
	_check(player.move_lane(-1), "lane_up moves the player")
	_check_eq(player.lane, GameConfig.LANE_TOP, "player reached the top lane")
	_check(not player.move_lane(-1), "lane_up is blocked at the top lane")
	_check_eq(player.lane, GameConfig.LANE_TOP, "player stays in the top lane")
	_check(player.move_lane(1), "lane_down moves the player")
	_check(player.move_lane(1), "lane_down moves the player again")
	_check_eq(player.lane, GameConfig.LANE_BOTTOM, "player reached the bottom lane")
	_check(not player.move_lane(1), "lane_down is blocked at the bottom lane")

	# Jump arc: rises, lands, and peaks near the expected height.
	player.lane = GameConfig.LANE_MIDDLE
	_check(player.jump(), "jump starts")
	_check(player.in_air, "player is airborne after jumping")
	_check(not player.jump(), "jump is ignored while already airborne")

	var apex := 0.0
	var steps := 0
	while player.in_air and steps < 240:
		player._physics_process(1.0 / 60.0)
		apex = maxf(apex, player.air_height)
		steps += 1
	_check(not player.in_air, "player lands again")
	_check(steps < 60, "airtime is under one second")
	_check(apex > 90.0 and apex < 150.0, "measured jump apex is about one lane (%.1f px)" % apex)
	_check_near(player.air_height, 0.0, 0.001, "air height resets on landing")

	# Slide: starts, animates, and ends on its own.
	_check(player.slide(), "slide starts on the ground")
	_check(player.is_sliding, "player is sliding")
	_check(not player.slide(), "slide is ignored while already sliding")
	player._physics_process(1.0 / 60.0)
	_check_eq(player.sprite.animation, &"slide", "slide animation plays while sliding")

	var slide_steps := 0
	while player.is_sliding and slide_steps < 120:
		player._physics_process(1.0 / 60.0)
		slide_steps += 1
	_check(not player.is_sliding, "slide ends on its own after SLIDE_DURATION")
	_check(slide_steps < 60, "slide is shorter than a second")
	player._physics_process(1.0 / 60.0)
	_check_eq(player.sprite.animation, &"run", "run animation returns after sliding")

	# Jump cancels a slide.
	_check(player.slide(), "slide restarts for the cancel test")
	_check(player.jump(), "jump is allowed out of a slide")
	_check(player.in_air, "player is airborne after the slide-cancel jump")
	_check(not player.is_sliding, "jumping ends the slide")
	_check(not player.slide(), "slide is ignored while airborne")
	for i in 90:
		player._physics_process(1.0 / 60.0)
	_check(not player.in_air, "player lands after the slide-cancel jump")

	# Presentation: frames are authored scene data, not built at runtime.
	var frames := player.sprite.sprite_frames
	_check(frames != null, "player scene provides sprite frames")
	if frames != null:
		_check(
			frames.resource_path.ends_with("elias_frames.tres"),
			"sprite frames come from the committed resource (%s)" % frames.resource_path,
		)
		_check_eq(frames.get_animation_names().size(), 6, "six Elias animations exist")
		_check_eq(frames.get_frame_count("run"), 7, "run animation has 7 frames")
		_check_eq(frames.get_frame_count("jump"), 3, "jump animation has 3 frames")
		_check_eq(frames.get_frame_count("slide"), 4, "slide animation has 4 frames")
		_check_eq(frames.get_frame_count("death"), 8, "death animation has 8 frames")
		var first_run := frames.get_frame_texture("run", 0)
		_check(first_run != null, "run frame 0 has a texture")
		if first_run != null:
			_check(first_run.resource_path.ends_with("run_0.png"), "run frame 0 is run_0.png")
		_check(frames.get_animation_loop("run"), "run animation loops")
		_check(not frames.get_animation_loop("jump"), "jump animation does not loop")
		_check(not frames.get_animation_loop("death"), "death animation does not loop")
	player._physics_process(1.0 / 60.0)
	_check_eq(player.sprite.animation, &"run", "running animation tracks the ground state")

	player.queue_free()


func _test_health() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	var player := scene.instantiate() as Player

	var health_events: Array = []
	player.health_changed.connect(func(current: int, maximum: int) -> void:
		health_events.append([current, maximum])
	)
	var damaged_events: Array = []
	player.damaged.connect(func(remaining: int) -> void: damaged_events.append(remaining))
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)

	add_child(player)
	player.set_physics_process(false)

	_check_eq(player.health, GameConfig.MAX_HEARTS, "player starts with MAX_HEARTS")
	_check(player.can_take_damage(), "a fresh player can take damage")
	_check_eq(health_events.size(), 1, "initial health is broadcast")

	# Hurt sound: node, bus, and landed-hit-only behavior.
	_check(player.hurt_sfx != null, "the player carries a hurt sound player")
	_check_eq((player.hurt_sfx as AudioStreamPlayer).bus, "SFX", "the hurt sound routes to the SFX bus")
	_check(player.hurt_play_count == 0, "the hurt sound is silent before any hit")

	# VFX wiring: dust and impact flash are committed assets, attached and
	# configured to fire once per burst (not per frame).
	_check(player.land_dust is CPUParticles2D, "the player carries a dust emitter")
	_check(player.land_dust.one_shot, "the dust emitter fires one shot per burst")
	_check(not player.land_dust.local_coords, "dust stays behind in world space")
	_check(
		player.land_dust.texture != null
		and player.land_dust.texture.resource_path.ends_with("dust_soft.png"),
		"the dust emitter uses the committed soft-puff texture",
	)
	_check(player.hit_burst != null, "the player carries an impact flash")
	_check(
		player.hit_burst.texture != null
		and player.hit_burst.texture.resource_path.ends_with("impact_flash.png"),
		"the impact flash uses the committed spritesheet",
	)
	_check_eq(player.hit_burst.hframes, 6, "the impact sheet is 6 columns wide")
	_check_eq(player.hit_burst.vframes, 4, "the impact sheet is 4 rows tall")
	_check_eq(player.hit_burst.frame_count, 24, "the impact sheet plays all 24 frames")
	_check(not player.hit_burst.visible, "the impact flash starts hidden")
	_check_eq(player.dust_burst_count, 0, "no dust before any movement")
	_check_eq(player.hit_burst_count, 0, "no impact flash before any hit")

	# Jump sound: one per launch, on the SFX bus, with re-rolled pitch.
	_check(player.jump_sfx != null, "the player carries a jump sound player")
	_check_eq((player.jump_sfx as AudioStreamPlayer).bus, "SFX", "the jump sound routes to the SFX bus")
	_check(player.jump_play_count == 0, "the jump sound is silent before any jump")
	player.in_air = false
	_check(player.jump(), "the first jump launches")
	_check_eq(player.jump_play_count, 1, "a launch plays the jump sound")
	_check(
		player.jump_sfx.pitch_scale >= 1.0 - player.JUMP_PITCH_VARIATION
		and player.jump_sfx.pitch_scale <= 1.0 + player.JUMP_PITCH_VARIATION,
		"the jump pitch stays within the +-5% variation",
	)
	_check(not player.jump(), "a jump while airborne does not launch again")
	_check_eq(player.jump_play_count, 1, "a blocked mid-air jump stays silent")
	player.in_air = false
	player.air_height = 0.0
	_check(player.jump(), "the second jump launches after landing")
	_check_eq(player.jump_play_count, 2, "a second launch plays again")
	_check(
		player.jump_sfx.pitch_scale >= 1.0 - player.JUMP_PITCH_VARIATION
		and player.jump_sfx.pitch_scale <= 1.0 + player.JUMP_PITCH_VARIATION,
		"the re-rolled pitch stays within the +-5% variation",
	)
	player.in_air = false
	player.air_height = 0.0

	# Dust: one puff per launch, and the landing owns its own puff - the pair
	# must not share a counter or double-fire from the same frame.
	_check_eq(player.dust_burst_count, 2, "each launch puffs dust exactly once")
	player.in_air = true
	player.air_height = 1.0
	player.vertical_speed = -100.0
	player._update_jump(1.0 / 60.0)
	_check(not player.in_air, "the descent lands the player")
	_check_eq(player.dust_burst_count, 3, "landing puffs dust once")

	# Pickup audio: coins and items are different reward channels, so they play
	# different clips on the SFX bus - coins with re-rolled pitch, items stable.
	_check(player.coin_sfx != null, "the player carries a coin sound player")
	_check(player.item_sfx != null, "the player carries an item sound player")
	_check_eq((player.coin_sfx as AudioStreamPlayer).bus, "SFX", "the coin sound routes to the SFX bus")
	_check_eq((player.item_sfx as AudioStreamPlayer).bus, "SFX", "the item sound routes to the SFX bus")
	_check(player.coin_sfx.stream != null, "the coin sound has a stream")
	_check(player.item_sfx.stream != null, "the item sound has a stream")
	_check(player.coin_sfx.stream != player.item_sfx.stream, "coins and items play different clips")
	var coin_clip := player.coin_sfx.stream as AudioStream
	_check(
		coin_clip != null and coin_clip.get_length() < 0.6,
		"the coin clip is the trimmed short take, not the long original",
	)
	_check(
		player.coin_play_count == 0 and player.item_play_count == 0,
		"the pickup sounds are silent before any pickup",
	)
	player._play_pickup_sound(GameConfig.ItemKind.COIN)
	_check_eq(player.coin_play_count, 1, "a coin plays the coin sound")
	_check_eq(player.item_play_count, 0, "a coin does not play the item sound")
	var coin_pitch_first: float = player.coin_sfx.pitch_scale
	player._play_pickup_sound(GameConfig.ItemKind.PENCIL)
	_check_eq(player.item_play_count, 1, "a school item plays the item sound")
	_check_eq(player.coin_play_count, 1, "a school item does not play the coin sound")
	_check_near(player.item_sfx.pitch_scale, 1.0, 0.0001, "the item sound keeps one stable pitch")

	# Two hundred seeded coin rolls: every pitch inside the +-6% band, and the
	# band actually used (variation exists, it is not a constant).
	var pickup_rng := RandomNumberGenerator.new()
	pickup_rng.seed = 11
	player._sfx_rng = pickup_rng
	var coin_pitch_lo := 2.0
	var coin_pitch_hi := 0.0
	var coin_pitch_set := {}
	for i in 200:
		player._play_pickup_sound(GameConfig.ItemKind.COIN)
		var rolled: float = player.coin_sfx.pitch_scale
		coin_pitch_lo = minf(coin_pitch_lo, rolled)
		coin_pitch_hi = maxf(coin_pitch_hi, rolled)
		coin_pitch_set[rolled] = true
	_check(
		coin_pitch_lo >= 1.0 - player.PICKUP_PITCH_VARIATION
		and coin_pitch_hi <= 1.0 + player.PICKUP_PITCH_VARIATION,
		"the coin pitch stays within the +-6% variation",
	)
	_check(coin_pitch_set.size() > 1, "the coin pitch actually varies between pickups")
	player._sfx_rng.randomize()

	_check(player.take_damage(), "the first hit lands")
	_check_eq(player.hurt_play_count, 1, "a landed hit plays the hurt sound")
	_check_eq(player.hit_burst_count, 1, "a landed hit plays one impact flash")
	_check(player.hit_burst.visible, "the impact flash becomes visible on a hit")
	_check_eq(player.hit_burst.frame, 0, "the impact flash starts from frame 0")
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "the first hit removes one heart")
	_check_eq(damaged_events.size(), 1, "damaged fires once")
	_check_eq(health_events.size(), 2, "health_changed fires on damage")
	_check_near(player.invulnerable_time_left, GameConfig.I_FRAME_TIME, 0.001, "a hit starts the i-frame window")
	_check(not player.can_take_damage(), "the player is invulnerable right after a hit")
	_check(not player.take_damage(), "a hit inside the i-frame window is ignored")
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "the ignored hit costs no heart")
	_check_eq(player.hurt_play_count, 1, "an i-frame-blocked hit stays silent")
	_check_eq(player.hit_burst_count, 1, "an i-frame-blocked hit does not flash")

	var steps := int(ceil(GameConfig.I_FRAME_TIME * 60.0)) + 2
	for i in steps:
		player._physics_process(1.0 / 60.0)
	_check(player.invulnerable_time_left <= 0.0, "i-frames expire after I_FRAME_TIME")
	_check(player.can_take_damage(), "the player can be hit again after i-frames")

	_check(player.take_damage(), "the second hit lands after i-frames")
	_check_eq(player.health, 1, "the second hit leaves one heart")
	player.invulnerable_time_left = 0.0
	_check(player.take_damage(), "the last hit lands")
	_check_eq(player.health, 0, "health reaches zero")
	_check_eq(deaths[0], 1, "died fires exactly once")
	_check(not player.take_damage(), "a player at zero hearts cannot be hit again")
	_check_eq(deaths[0], 1, "died does not fire twice")
	_check_eq(player.death_play_count, 0,
		"ordinary fatal hits do not play the car-death animation")

	# A fatal car hit swaps to the dedicated knockdown sheet.
	player.reset_health()
	player.health = 1
	_check(player.take_damage(1, GameConfig.HazardKind.CAR),
		"the fatal car hit lands")
	_check_eq(player.death_play_count, 1,
		"a fatal car hit plays the car-death animation")
	_check_eq(String(player.sprite.animation), "death",
		"the sprite switches to the death animation")
	_check_eq(deaths[0], 2, "the car death also fires died once")

	player.reset_health()
	_check(not player._death_played, "reset clears the death-animation guard")

	# Other assertions in this section share `deaths`; put it back to the value
	# they expect now that the car-death case has been counted.
	deaths[0] = 1
	player.reset_health()
	_check_eq(player.health, GameConfig.MAX_HEARTS, "reset_health restores every heart")
	_check_eq(deaths[0], 1, "reset does not re-fire died")

	# Shield absorb: spends a charge, costs no heart, and must not flash.
	player.shield_charges = 1
	var flash_before: int = player.hit_burst_count
	_check(not player.take_damage(), "a shield charge absorbs the hit")
	_check_eq(player.shield_charges, 0, "the absorbing shield is spent")
	_check_eq(player.hit_burst_count, flash_before, "a shield absorb does not flash")
	player.reset_health()

	# The flash hides itself when the sheet runs out - no lingering sprite.
	player.hit_burst._process(1.0)
	_check(not player.hit_burst.visible, "the impact flash hides when the sheet ends")

	# Hitbox: 10% smaller than the sprite, anchored at the feet.
	var box := player.hitbox_shape.shape as RectangleShape2D
	_check(box != null, "player hitbox has a rectangle shape")
	_check_eq(player.hitbox.collision_layer, GameConfig.LAYER_PLAYER, "player hitbox sits on the player layer")
	_check_eq(player.hitbox.collision_mask, GameConfig.PLAYER_MASK, "player hitbox scans hazards and fx")
	_check(player.hitbox.monitoring, "player hitbox actively scans for hazards")
	if box != null:
		_check_near(box.size.x, GameConfig.HITBOX_SIZE.x, 0.01, "hitbox width is 10% smaller than the sprite")
		_check_near(box.size.y, GameConfig.HITBOX_SIZE.y, 0.01, "hitbox height is 10% smaller than the sprite")
		_check_near(
			player.hitbox_shape.position.y,
			-box.size.y * 0.5,
			0.01,
			"standing hitbox is anchored at the feet",
		)

	_check(player.slide(), "player can slide for the hitbox test")
	player._physics_process(1.0 / 60.0)
	_check_near(
		box.size.y,
		GameConfig.HITBOX_SIZE.y * GameConfig.SLIDE_HITBOX_HEIGHT_FACTOR,
		0.01,
		"sliding halves the hitbox height",
	)
	_check_near(
		player.hitbox_shape.position.y,
		-box.size.y * 0.5,
		0.01,
		"sliding hitbox stays anchored at the feet",
	)

	# Shapes must be per-instance, otherwise one player's slide resizes them all.
	var other := scene.instantiate() as Player
	add_child(other)
	other.set_physics_process(false)
	_check(player.hitbox_shape.shape != other.hitbox_shape.shape, "each player owns a duplicate hitbox shape")
	other.queue_free()

	player.queue_free()


func _test_hazard() -> void:
	var scene := load("res://scenes/hazard.tscn") as PackedScene
	_check(scene != null, "hazard scene loads")
	if scene == null:
		return

	var hazard := scene.instantiate() as Hazard
	add_child(hazard)
	hazard.set_physics_process(false)
	hazard.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_BOTTOM, 0.0)
	_check_eq(hazard.collision_layer, GameConfig.LAYER_HAZARD, "hazard sits on the hazard layer")
	_check_eq(hazard.collision_mask, 0, "hazard does not scan for areas itself")
	_check(not hazard.monitoring, "hazard is passive; the player's hitbox detects it")
	_check_near(
		hazard.position.y,
		GameConfig.lane_y(GameConfig.LANE_BOTTOM),
		0.01,
		"hazard sits on its lane baseline",
	)
	_check(not hazard.requires_slide, "manholes are jumped, not slid under")
	_check(hazard.lane_locked, "moving hazards stay lane-locked for now")
	hazard.queue_free()

	for kind: int in GameConfig.HAZARD_DATA:
		var item := scene.instantiate() as Hazard
		add_child(item)
		item.set_physics_process(false)
		item.setup(kind, GameConfig.LANE_MIDDLE, 0.0)
		var data: Dictionary = GameConfig.HAZARD_DATA[kind]
		var box := item.shape.shape as RectangleShape2D
		_check(item.sprite.texture != null, "kind %d has a texture" % kind)
		if item.sprite.texture != null:
			_check_eq(item.sprite.texture.resource_path, String(data["texture"]), "kind %d uses its configured art" % kind)
		_check_near(box.size.x, float(data["hitbox_w"]), 0.01, "kind %d hitbox width matches data" % kind)
		_check_near(box.size.y, float(data["hitbox_h"]), 0.01, "kind %d hitbox height matches data" % kind)
		_check_near(
			item.box_y_range().y,
			-float(data["clearance"]),
			0.01,
			"kind %d bottom edge sits at its clearance" % kind,
		)
		if bool(data["overhead"]):
			_check(item.requires_slide, "kind %d requires a slide" % kind)
		else:
			_check(
				float(data["hitbox_h"]) < GameConfig.JUMP_APEX,
				"kind %d is shorter than the jump apex (clearable)" % kind,
			)
		item.queue_free()

	# The gantry must overlap a standing hitbox and clear a sliding one.
	var gantry := scene.instantiate() as Hazard
	add_child(gantry)
	gantry.set_physics_process(false)
	gantry.setup(GameConfig.HazardKind.GANTRY, GameConfig.LANE_MIDDLE, 0.0)
	var span := gantry.box_y_range()
	var standing_top := -GameConfig.HITBOX_SIZE.y
	var sliding_top := standing_top * GameConfig.SLIDE_HITBOX_HEIGHT_FACTOR
	_check(span.y > standing_top, "gantry overlaps a standing player")
	_check(span.y < sliding_top, "gantry clears a sliding player")
	_check(span.x < span.y, "gantry hitbox has positive height")
	gantry.queue_free()

	# Movement: moving kinds close in faster than the world scrolls.
	var mover := scene.instantiate() as Hazard
	add_child(mover)
	mover.set_physics_process(false)
	mover.setup(GameConfig.HazardKind.DOG, GameConfig.LANE_TOP, 100.0)
	mover.position.x = GameConfig.SPAWN_X
	mover._physics_process(1.0)
	var dog_speed := 100.0 + float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.DOG]["extra_speed"])
	_check_near(mover.position.x, GameConfig.SPAWN_X - dog_speed, 0.01, "dog closes in faster than world speed")
	_check(mover.sprite.flip_h, "dog sprite faces left towards player while running right-to-left")
	mover.position.x = GameConfig.DESPAWN_X - 1.0
	mover._physics_process(0.016)
	_check(mover.is_queued_for_deletion(), "hazards despawn behind the player")

	var alternate_dog := scene.instantiate() as Hazard
	add_child(alternate_dog)
	alternate_dog.set_physics_process(false)
	alternate_dog.setup(GameConfig.HazardKind.DOG, GameConfig.LANE_MIDDLE, 0.0, 1)
	_check_eq(
		alternate_dog.sprite.texture.resource_path,
		GameConfig.DOG_TEXTURES[1],
		"dog2 is available as the alternate dog sprite",
	)
	_check_eq(alternate_dog.sprite.hframes, 6, "dog2 uses the six-frame walk cycle")
	alternate_dog.sprite.frame = 0
	alternate_dog._frame_timer = 0.0
	alternate_dog._process(0.11)
	_check_eq(alternate_dog.sprite.frame, 1, "dog walk frames animate")
	alternate_dog.queue_free()

	# --- Street car: two variants, one hitbox, faster than the world -----------
	var car := scene.instantiate() as Hazard
	add_child(car)
	car.set_physics_process(false)
	car.setup(GameConfig.HazardKind.CAR, GameConfig.LANE_TOP, 100.0)
	car.position.x = GameConfig.SPAWN_X
	_check_eq(car.sprite.texture.resource_path, GameConfig.CAR_TEXTURES[0],
		"car variant 0 uses the red jeep sheet")
	_check(car.sprite.flip_h, "the car faces left (drives toward the player)")
	_check_eq(car.sprite.hframes, 8, "the car animates eight sheet frames")
	_check_near(car.shape.shape.size.x,
		float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_w"]),
		0.01, "the car uses the shared car hitbox width")
	_check_near(car.shape.shape.size.y,
		float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_h"]),
		0.01, "the car uses the shared car hitbox height")
	car._physics_process(1.0)
	var car_speed := 100.0 + float(
		GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["extra_speed"])
	_check_near(car.position.x, GameConfig.SPAWN_X - car_speed, 0.01,
		"the car closes in faster than the world scrolls")
	car.queue_free()

	var convertible := scene.instantiate() as Hazard
	add_child(convertible)
	convertible.set_physics_process(false)
	convertible.setup(GameConfig.HazardKind.CAR, GameConfig.LANE_MIDDLE, 0.0, 1)
	_check_eq(convertible.sprite.texture.resource_path, GameConfig.CAR_TEXTURES[1],
		"car variant 1 uses the convertible sheet")
	_check_near(convertible.sprite.scale.x,
		float(GameConfig.CAR_VARIANTS[1]["scale"]) * GameConfig.CAR_SCALE_MULT,
		0.01, "car variant 1 uses its own scale times CAR_SCALE_MULT")
	_check_near(convertible.shape.shape.size.x,
		float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_w"]),
		0.01, "both car variants share the hitbox")
	convertible.setup(GameConfig.HazardKind.CAR, GameConfig.LANE_MIDDLE, 0.0, 9)
	_check_eq(convertible.sprite.texture.resource_path, GameConfig.CAR_TEXTURES[1],
		"an out-of-range car variant wraps safely")
	convertible.queue_free()

	# Both car variants render the same on-screen height: the two sheet scales
	# exist to keep Ride1 and Ride2 matched, CAR_SCALE_MULT moves them together.
	# 76 and 66 are the measured alpha-content heights of the Ride1 and Ride2
	# cells (256 px and 192 px tall respectively, art at the cell bottom).
	var jeep_height: float = (
		76.0 * float(GameConfig.CAR_VARIANTS[0]["scale"]) * GameConfig.CAR_SCALE_MULT)
	var convertible_height: float = (
		66.0 * float(GameConfig.CAR_VARIANTS[1]["scale"]) * GameConfig.CAR_SCALE_MULT)
	_check_near(jeep_height, convertible_height, 1.0,
		"both car variants render the same on-screen height")

	# Jump clearance math: at extra_speed 720 the car sweeps past in about
	# 0.30 s, so only SPRING SHOES 3+ keeps the hitbox above 100 px that long.
	var car_pass_time: float = (
		(float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_w"])
			+ GameConfig.HITBOX_SIZE.x)
		/ (GameConfig.RUN_SPEED
			+ float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["extra_speed"])))
	_check(GameConfig.jump_clear_window(
			float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_h"]), 2)
		< car_pass_time,
		"spring shoes 2 cannot clear the car")
	_check(GameConfig.jump_clear_window(
			float(GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]["hitbox_h"]), 3)
		> car_pass_time,
		"spring shoes 3 unlocks jumping the car")

	# End-to-end: the physics server must agree with the geometry above.
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.set_physics_process(false)

	var live_gantry := scene.instantiate() as Hazard
	add_child(live_gantry)
	live_gantry.set_physics_process(false)
	live_gantry.setup(GameConfig.HazardKind.GANTRY, GameConfig.LANE_MIDDLE, 0.0)
	live_gantry.position.x = GameConfig.PLAYER_X
	await _physics_frames(3)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS - 1,
		"the gantry damages a standing player (live physics)",
	)

	player.reset_health()
	player.is_sliding = true
	player._update_hitbox()
	await _physics_frames(3)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS,
		"a sliding player passes under the gantry (live physics)",
	)

	player.is_sliding = false
	player._update_hitbox()
	live_gantry.queue_free()
	await _physics_frames(2)

	var live_manhole := scene.instantiate() as Hazard
	add_child(live_manhole)
	live_manhole.set_physics_process(false)
	live_manhole.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_MIDDLE, 0.0)
	live_manhole.position.x = GameConfig.PLAYER_X
	await _physics_frames(3)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS - 1,
		"the manhole damages a grounded player (live physics)",
	)

	player.reset_health()
	player.air_height = GameConfig.JUMP_APEX
	player._apply_pose()
	await _physics_frames(3)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS,
		"a jumping player clears the manhole (live physics)",
	)

	# Lane rule: a neighbouring lane's hazard is ignored even at jump apex,
	# where the hitbox physically reaches into that lane's band.
	live_manhole.queue_free()
	await _physics_frames(2)
	var off_lane := scene.instantiate() as Hazard
	add_child(off_lane)
	off_lane.set_physics_process(false)
	off_lane.setup(GameConfig.HazardKind.GANTRY, GameConfig.LANE_TOP, 0.0)
	off_lane.position.x = GameConfig.PLAYER_X
	player.reset_health()
	player.air_height = GameConfig.JUMP_APEX
	player._apply_pose()
	await _physics_frames(3)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS,
		"a jump cannot be hit by a neighbouring lane's hazard (live physics)",
	)

	player.invulnerable_time_left = 0.0
	player.move_lane(-1)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS - 1,
		"entering that hazard's lane registers the hit",
	)

	# Direct guard, independent of jump geometry.
	player.reset_health()
	player.lane = GameConfig.LANE_MIDDLE
	player._on_hitbox_area_entered(off_lane)
	_check_eq(player.health, GameConfig.MAX_HEARTS, "an off-lane hazard cannot damage the player")
	player.lane = GameConfig.LANE_TOP
	player._on_hitbox_area_entered(off_lane)
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "a same-lane hazard still damages the player")

	player.reset_health()
	var dog_hit := scene.instantiate() as Hazard
	add_child(dog_hit)
	dog_hit.set_physics_process(false)
	dog_hit.setup(GameConfig.HazardKind.DOG, GameConfig.LANE_TOP, 0.0)
	player._on_hitbox_area_entered(dog_hit)
	_check_eq(
		player.health,
		GameConfig.MAX_HEARTS - 1,
		"a dog hit uses the normal one-heart hazard penalty",
	)
	dog_hit.queue_free()

	# Dog hit with pursuer active triggers caught and died instead of normal damage.
	player.reset_health()
	player.pursuer_active = true
	var dog_chase_hit := scene.instantiate() as Hazard
	add_child(dog_chase_hit)
	dog_chase_hit.set_physics_process(false)
	dog_chase_hit.setup(GameConfig.HazardKind.DOG, GameConfig.LANE_TOP, 0.0)
	var dog_caught := [0]
	var dog_died := [0]
	player.caught.connect(func(): dog_caught[0] += 1)
	player.died.connect(func(): dog_died[0] += 1)
	player._on_hitbox_area_entered(dog_chase_hit)
	_check_eq(dog_caught[0], 1, "dog hit while pursuer is active triggers caught")
	_check_eq(dog_died[0], 1, "dog hit while pursuer is active triggers died")
	_check_eq(player.health, GameConfig.MAX_HEARTS, "dog hit while pursuer is active does not deduct hearts")
	player.pursuer_active = false
	dog_chase_hit.queue_free()

	# --- Car jump dodge: a timed jump clears the car from SPRING SHOES 3 on -----
	var pre_jump_levels: Dictionary = GameState.shop_levels.duplicate()
	var car_data: Dictionary = GameConfig.HAZARD_DATA[GameConfig.HazardKind.CAR]
	var car_w := float(car_data["hitbox_w"])
	var car_h := float(car_data["hitbox_h"])
	var car_closure := GameConfig.RUN_SPEED + float(car_data["extra_speed"])
	var car_contact_gap := car_w * 0.5 + GameConfig.HITBOX_SIZE.x * 0.5
	var car_sweep_time := (car_w + GameConfig.HITBOX_SIZE.x) / car_closure
	for jump_level: int in [0, 3]:
		GameState.shop_levels = { GameConfig.ShopUpgrade.JUMP: jump_level }
		var jump_v := GameConfig.shop_jump_speed(jump_level)
		var jump_disc := jump_v * jump_v - 2.0 * GameConfig.GRAVITY * car_h
		var rise_time := 0.0
		if jump_disc > 0.0:
			rise_time = (jump_v - sqrt(jump_disc)) / GameConfig.GRAVITY
		var clear_window := GameConfig.jump_clear_window(car_h, jump_level)
		# Center the horizontal pass inside the above-car-height window when it
		# fits, so the timing is as fair as the upgrade level allows.
		var lead := rise_time + maxf((clear_window - car_sweep_time) * 0.5, 0.0)
		var jump_car_start := GameConfig.PLAYER_X + car_contact_gap + car_closure * lead

		player.set_physics_process(true)
		player.reset_health()
		player.invulnerable_time_left = 0.0
		player.air_height = 0.0
		player.vertical_speed = 0.0
		player.lane = GameConfig.LANE_MIDDLE
		player.is_sliding = false
		player._update_hitbox()
		player._apply_pose()

		var jump_car := scene.instantiate() as Hazard
		add_child(jump_car)
		jump_car.setup(
			GameConfig.HazardKind.CAR, GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
		jump_car.position.x = jump_car_start

		player.jump()
		await _physics_frames(40)
		if jump_level >= 3:
			_check_eq(
				player.health,
				GameConfig.MAX_HEARTS,
				"spring shoes 3 clears the car with a timed jump (live physics)",
			)
		else:
			_check_eq(
				player.health,
				GameConfig.MAX_HEARTS - 1,
				"spring shoes 0 cannot jump the car (live physics)",
			)
		jump_car.queue_free()
		await _physics_frames(2)
	GameState.shop_levels = pre_jump_levels

	off_lane.queue_free()
	player.queue_free()


func _test_spawn_director() -> void:
	_check_near(GameConfig.row_gap(0.0), GameConfig.ROW_GAP_START, 0.01, "row gap starts wide")
	_check_near(
		GameConfig.row_gap(GameConfig.ROW_GAP_RAMP_DISTANCE * 2.0),
		GameConfig.ROW_GAP_MIN,
		0.01,
		"row gap clamps at ROW_GAP_MIN",
	)
	_check_near(
		GameConfig.row_gap(GameConfig.ROW_GAP_RAMP_DISTANCE * 0.5),
		(GameConfig.ROW_GAP_START + GameConfig.ROW_GAP_MIN) * 0.5,
		0.01,
		"row gap eases linearly with distance",
	)

	var previous := GameConfig.row_gap(0.0) + 1.0
	var monotonic := true
	for step in 100:
		var distance := GameConfig.ROW_GAP_RAMP_DISTANCE * float(step) / 99.0
		var gap := GameConfig.row_gap(distance)
		if gap > previous + 0.001:
			monotonic = false
		previous = gap
	_check(monotonic, "row gap shrinks monotonically as the run advances")
	_check(
		GameConfig.ROW_GAP_MIN >= GameConfig.LANE_SWITCH_TIME * GameConfig.RUN_SPEED * 2.0,
		"the tightest row gap still allows two lane changes",
	)

	# Fuzz: 10,000 rows, every one must leave at least one lane open.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261106
	var violations := 0
	var two_lane_rows := 0
	for i in 10000:
		var distance := rng.randf() * 120000.0
		var lanes := SpawnDirector.generate_pattern(distance, rng)
		if lanes.is_empty() or lanes.size() > GameConfig.LANE_COUNT - 1:
			violations += 1
			continue
		var seen := {}
		for lane in lanes:
			if lane < GameConfig.LANE_TOP or lane > GameConfig.LANE_BOTTOM or seen.has(lane):
				violations += 1
			seen[lane] = true
		if seen.size() >= GameConfig.LANE_COUNT:
			violations += 1
		if lanes.size() == 2:
			two_lane_rows += 1
	_check_eq(violations, 0, "10000 fuzzed rows always leave a lane open")
	_check(two_lane_rows > 0, "some rows block two lanes (%d of 10000)" % two_lane_rows)

	# The same seed must produce the same course.
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	var reproducible := true
	for i in 50:
		if SpawnDirector.generate_pattern(5000.0, rng_a) != SpawnDirector.generate_pattern(5000.0, rng_b):
			reproducible = false
	_check(reproducible, "seeded pattern generation is reproducible")

	# A dog reservation filters only its own lane from hazard rows.
	var reserved_rng := RandomNumberGenerator.new()
	reserved_rng.seed = 12000
	var reserved_lane := GameConfig.LANE_MIDDLE
	var reserved_row_count := 0
	for i in 100:
		var reserved_row := SpawnDirector.generate_pattern(12000.0, reserved_rng, reserved_lane)
		if reserved_row.has(reserved_lane) or reserved_row.is_empty():
			reserved_row_count += 1
	_check_eq(reserved_row_count, 0, "rows never spawn hazards in the dog lane")
	_check(
		SpawnDirector.generate_pattern(12000.0, reserved_rng, reserved_lane).size() > 0,
		"hazards continue spawning in other lanes while the dog lane is reserved",
	)

	var dog_lane_rng := RandomNumberGenerator.new()
	dog_lane_rng.seed = 77
	_check_eq(
		SpawnDirector.choose_dog_lane([0, 1, 2], dog_lane_rng),
		-1,
		"dog waits when every lane has an entry obstacle",
	)
	for i in 50:
		var blocked_lane := dog_lane_rng.randi_range(0, GameConfig.LANE_COUNT - 1)
		var chosen_lane := SpawnDirector.choose_dog_lane([blocked_lane], dog_lane_rng)
		_check(
			chosen_lane >= 0 and chosen_lane < GameConfig.LANE_COUNT and chosen_lane != blocked_lane,
			"dog selects an unoccupied entry lane",
		)

	# Kinds respect their unlock distance.
	var rng_early := RandomNumberGenerator.new()
	rng_early.seed = 7
	var early_locked := true
	for i in 500:
		var kind := SpawnDirector.pick_kind(0.0, rng_early)
		if kind != GameConfig.HazardKind.MANHOLE and kind != GameConfig.HazardKind.DEBRIS:
			early_locked = false
	_check(early_locked, "only unlocked kinds spawn at distance 0")

	var rng_late := RandomNumberGenerator.new()
	rng_late.seed = 7
	var late_kinds := {}
	for i in 2000:
		late_kinds[SpawnDirector.pick_kind(60000.0, rng_late)] = true
	# Ungated pattern rolls (zone -1) see every kind that is not zone-restricted:
	# the dog and car are street-locked, the furniture is home-locked, and the
	# rest spawn freely once unlocked.
	var ungated_kinds := 0
	for kind: int in GameConfig.HAZARD_DATA:
		if GameConfig.hazard_allows_zone(kind, -1):
			ungated_kinds += 1
	_check_eq(late_kinds.size(), ungated_kinds,
		"every ungated kind spawns once unlocked in pattern rolls")

	# The car only rolls in the street zone.
	var rng_car := RandomNumberGenerator.new()
	rng_car.seed = 11
	var car_seen := false
	var car_off_street := true
	for i in 2000:
		if SpawnDirector.pick_kind(60000.0, rng_car, GameConfig.Zone.STREET) \
				== GameConfig.HazardKind.CAR:
			car_seen = true
		if SpawnDirector.pick_kind(60000.0, rng_car, GameConfig.Zone.HOME) \
				== GameConfig.HazardKind.CAR:
			car_off_street = false
		if SpawnDirector.pick_kind(60000.0, rng_car, GameConfig.Zone.SCHOOL) \
				== GameConfig.HazardKind.CAR:
			car_off_street = false
		if SpawnDirector.pick_kind(60000.0, rng_car) == GameConfig.HazardKind.CAR:
			car_off_street = false
	_check(car_seen, "the street zone rolls cars")
	_check(car_off_street, "the car never rolls outside the street zone")

	# The distance clock warns first, then spawns dog1 in a clear lane.
	var event_container := Node2D.new()
	add_child(event_container)
	var event_director := SpawnDirector.new()
	add_child(event_director)
	event_director.setup(event_container, 2026)
	# The dog shares HazardWarning with the car; its warnings must never honk
	# and never fire the engine pass-by.
	var dog_honk_events: Array = []
	var dog_engine_events: Array = []
	event_director.car_warning_started.connect(
		func(honk_lane: int, honk_variant: int) -> void:
			dog_honk_events.append([honk_lane, honk_variant])
	)
	event_director.car_entered.connect(
		func(entry_lane: int, entry_variant: int) -> void:
			dog_engine_events.append([entry_lane, entry_variant])
	)
	event_director._distance_since_row = 0.0
	event_director._distance_since_pickup = 0.0
	event_director.tick(0.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE - 1.0)
	_check_eq(event_director._dog_reserved_lane, -1, "dog stays locked before its first distance")
	event_director.tick(0.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE)
	var first_lane := event_director._dog_reserved_lane
	_check(first_lane >= 0 and first_lane < GameConfig.LANE_COUNT, "dog encounter reserves a lane")
	_check(event_director._active_dog == null, "warning appears before the dog")
	_check(
		event_director._next_dog_distance >= GameConfig.DOG_FIRST_DISTANCE + GameConfig.DOG_GAP_MIN
		and event_director._next_dog_distance <= GameConfig.DOG_FIRST_DISTANCE + GameConfig.DOG_GAP_MAX,
		"next dog encounter uses the configured random distance gap",
	)

	# Regression: real ticks during the warning window must not release the
	# reservation, or the dog never spawns when the warning finishes.
	for dog_tick_i in 5:
		event_director.tick(
			1.0 / 60.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE + 1.0)
	_check_eq(
		event_director._dog_reserved_lane,
		first_lane,
		"ticking during the warning keeps the dog lane reserved",
	)
	_check(event_director._active_dog == null, "no dog until the warning finishes")

	if event_director._dog_warning != null:
		_check_eq(
			event_director._dog_warning.sprite.texture.resource_path,
			"res://assets/signs/exclamation/Exclamation Mark 1st Outline 64px.png",
			"dog warning uses the outlined exclamation asset",
		)
		_check_near(
			event_director._dog_warning.position.x,
			GameConfig.DOG_WARNING_X,
			0.01,
			"dog warning appears near the right edge",
		)

	var reserved_lanes := event_director.spawn_row(GameConfig.DOG_FIRST_DISTANCE, 0.0)
	_check(not reserved_lanes.has(first_lane), "row spawning skips only the dog's lane")
	_check(not reserved_lanes.is_empty(), "other lanes still receive hazards during a dog encounter")

	await _physics_frames(int(GameConfig.DOG_WARNING_DURATION * 60.0) + 10)
	var first_dog := event_director._active_dog
	_check(first_dog != null, "dog spawns after the warning finishes")
	if first_dog != null:
		_check_eq(first_dog.kind, GameConfig.HazardKind.DOG, "encounter creates a dog hazard")
		_check_eq(
			first_dog.sprite.texture.resource_path,
			GameConfig.DOG_TEXTURES[0],
			"first encounter uses dog1",
		)
		_check_eq(first_dog.lane, first_lane, "dog stays in its warned lane")
		_check(first_dog.position.x < GameConfig.SPAWN_X, "dog runs from right to left")
		_check(first_dog.sprite.flip_h, "first encounter dog faces left")
		_check_eq(event_director._dog_reserved_lane, first_lane, "dog lane stays reserved while active")
		first_dog.queue_free()

	for child in event_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	event_director._refresh_dog_reservation()
	_check_eq(event_director._dog_reserved_lane, -1, "dog lane is released after the dog despawns")

	var lane_resumed := false
	for i in 100:
		var resumed_row := event_director.spawn_row(GameConfig.DOG_FIRST_DISTANCE, 0.0)
		if resumed_row.has(first_lane):
			lane_resumed = true
			break
	_check(lane_resumed, "normal hazard spawning resumes in the dog lane after despawn")
	_check(dog_honk_events.is_empty(), "a dog encounter never triggers a car honk")
	_check(dog_engine_events.is_empty(), "a dog encounter never triggers the engine pass-by")

	# --- Street cars warn like the dog, then enter from the right edge ---------
	var car_container := Node2D.new()
	add_child(car_container)
	var car_director := SpawnDirector.new()
	add_child(car_director)
	car_director.setup(car_container, 404)
	var honk_events: Array = []
	car_director.car_warning_started.connect(
		func(honk_lane: int, honk_variant: int) -> void:
			honk_events.append([honk_lane, honk_variant])
	)
	var engine_events: Array = []
	car_director.car_entered.connect(
		func(entry_lane: int, entry_variant: int) -> void:
			engine_events.append([entry_lane, entry_variant])
	)
	car_director._start_car_warning(GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
	_check_eq(car_director._car_warnings.size(), 1, "a warned car waits for its warning")
	var car_warning := car_container.get_children().back() as HazardWarning
	_check(car_warning != null, "the car warning appears in the tree")
	if car_warning != null:
		_check_eq(car_warning.sprite.texture.resource_path, GameConfig.CAR_WARNING_TEXTURE,
			"the car warning uses the second exclamation art")
	var car_lane := int(car_director._car_warnings[0]["lane"])
	var car_variant := int(car_director._car_warnings[0]["variant"])
	_check_eq(car_lane, GameConfig.LANE_MIDDLE, "the car warning records its lane")
	_check_eq(honk_events.size(), 1, "starting a car warning honks exactly once")
	if honk_events.size() == 1:
		_check_eq(int(honk_events[0][0]), car_lane, "the honk fires for the warned lane")
		_check_eq(
			int(honk_events[0][1]),
			int(car_director._car_warnings[0]["variant"]),
			"the honk fires with the car's variant",
		)
	_check(engine_events.is_empty(), "the engine pass-by waits for the car to spawn")

	# Pickups, coin runs, and rows keep out of the warned lane.
	var warned_pickup := car_director.spawn_pickup(0.0, 0.0)
	_check(warned_pickup < 0 or warned_pickup != car_lane,
		"pickups skip the warned car lane")
	var warned_coin_run := car_director.spawn_coin_run(0.0, 0.0)
	_check(warned_coin_run < 0 or warned_coin_run != car_lane,
		"coin runs skip the warned car lane")
	for i in 20:
		var warned_row := car_director.spawn_row(60000.0, 0.0)
		_check(not warned_row.has(car_lane), "rows skip the warned car lane")
	_check_eq(car_director._car_warnings.size(), 1,
		"row spawning does not consume the car warning")

	# The car enters only after the warning finishes.
	await _physics_frames(int(GameConfig.CAR_WARNING_DURATION * 60.0) + 12)
	var warned_car: Hazard = null
	for child in car_container.get_children():
		if child is Hazard and (child as Hazard).kind == GameConfig.HazardKind.CAR:
			warned_car = child as Hazard
	_check(warned_car != null, "the car spawns once its warning finishes")
	if warned_car != null:
		_check_eq(warned_car.lane, car_lane, "the car takes its warned lane")
		_check(warned_car.position.x < GameConfig.SPAWN_X,
			"the car enters from the right edge")
	_check_eq(car_director._car_warnings.size(), 0,
		"the pending car is consumed after spawn")
	_check_eq(honk_events.size(), 1, "the honk does not repeat when the car spawns")
	_check_eq(engine_events.size(), 1, "the engine pass-by fires exactly once at spawn")
	if engine_events.size() == 1:
		_check_eq(int(engine_events[0][0]), car_lane, "the engine fires for the warned lane")
		_check_eq(int(engine_events[0][1]), car_variant, "the engine fires with the car's variant")

	for child in car_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	car_director.queue_free()
	car_container.queue_free()
	await get_tree().process_frame

	# --- Car cooldown: one warning, then a tuned distance gap -------------------
	var cool_container := Node2D.new()
	add_child(cool_container)
	var cool_director := SpawnDirector.new()
	add_child(cool_director)
	cool_director.setup(cool_container, 405)

	# The gate itself: street only, clear pending, and past the clock.
	_check(not cool_director._car_allowed(
			GameConfig.CAR_FIRST_DISTANCE - 1.0, GameConfig.Zone.STREET),
		"no car before the first-car distance")
	_check(cool_director._car_allowed(
			GameConfig.CAR_FIRST_DISTANCE, GameConfig.Zone.STREET),
		"cars are allowed at the first-car distance")
	_check(not cool_director._car_allowed(60000.0, GameConfig.Zone.HOME),
		"cars are never allowed outside the street")
	cool_director._car_warnings.append({
		"lane": 0, "speed": 0.0, "variant": 0, "warning": null,
	})
	_check(not cool_director._car_allowed(60000.0, GameConfig.Zone.STREET),
		"no second car while one warning is pending")
	cool_director._car_warnings.clear()

	# Before the first-car distance no car ever starts.
	cool_director._next_car_distance = GameConfig.CAR_FIRST_DISTANCE
	var early_car := false
	for i in 40:
		cool_director.spawn_row(
			GameConfig.CAR_FIRST_DISTANCE - 1.0, 0.0, GameConfig.Zone.STREET)
		if not cool_director._car_warnings.is_empty():
			early_car = true
			break
	_check(not early_car, "no car starts before the first-car distance")

	# Once the clock allows, a street row eventually warns, and the clock
	# arms a full tuned gap before the next car may be considered.
	cool_director._car_warnings.clear()
	cool_director._next_car_distance = 0.0
	var warned := false
	for i in 80:
		cool_director.spawn_row(60000.0, 0.0, GameConfig.Zone.STREET)
		if not cool_director._car_warnings.is_empty():
			warned = true
			break
	_check(warned, "a street row warns once the cooldown elapsed")
	_check(
		cool_director._next_car_distance >= 60000.0 + GameConfig.CAR_GAP_MIN
		and cool_director._next_car_distance <= 60000.0 + GameConfig.CAR_GAP_MAX,
		"the next car waits a full tuned gap",
	)

	# Rows during the gap never start another car.
	cool_director._car_warnings.clear()
	var second_car := false
	for i in 20:
		cool_director.spawn_row(60000.0, 0.0, GameConfig.Zone.STREET)
		if not cool_director._car_warnings.is_empty():
			second_car = true
			break
	_check(not second_car, "no car starts during the cooldown gap")

	# The explicit gate: allow_car = false skips the car even in the street.
	var rng_no_car := RandomNumberGenerator.new()
	rng_no_car.seed = 13
	var closed_gate_car := false
	for i in 2000:
		if SpawnDirector.pick_kind(60000.0, rng_no_car, GameConfig.Zone.STREET, false) \
				== GameConfig.HazardKind.CAR:
			closed_gate_car = true
	_check(not closed_gate_car, "pick_kind never rolls a car when the gate is closed")

	for child in cool_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	cool_director.queue_free()
	cool_container.queue_free()
	await get_tree().process_frame

	# --- Dog barks: telegraph + position-locked chase cues ----------------------
	var bark_container := Node2D.new()
	add_child(bark_container)
	var bark_director := SpawnDirector.new()
	add_child(bark_director)
	bark_director.setup(bark_container, 406)
	var bark_warn_events: Array = []
	var bark_chase_events: Array = []
	bark_director.dog_warning_started.connect(
		func(bark_lane: int, bark_variant: int) -> void:
			bark_warn_events.append([bark_lane, bark_variant])
	)
	bark_director.dog_barked.connect(
		func(bark_index: int, bark_variant: int) -> void:
			bark_chase_events.append([bark_index, bark_variant])
	)
	_check(
		bark_director._try_start_dog_encounter(
			GameConfig.DOG_FIRST_DISTANCE, GameConfig.RUN_SPEED),
		"a dog encounter can start in an empty lane",
	)
	var warn_variant := int(bark_director._next_dog_variant)
	_check_eq(
		bark_warn_events.size(), 1,
		"the dog warning fires its double-bark telegraph once",
	)
	if bark_warn_events.size() == 1:
		_check_eq(
			int(bark_warn_events[0][0]),
			bark_director._dog_reserved_lane,
			"the telegraph bark fires for the warned lane",
		)
		_check_eq(
			int(bark_warn_events[0][1]),
			warn_variant,
			"the telegraph bark fires with the dog's variant",
		)
	_check_eq(bark_director._dog_barks_fired, 0, "no chase bark before the dog exists")

	# Let the warning finish so the real dog spawns.
	await _physics_frames(int(GameConfig.DOG_WARNING_DURATION * 60.0) + 10)
	var bark_dog := bark_director._active_dog as Hazard
	_check(bark_dog != null, "the dog exists for its chase barks")
	if bark_dog != null:
		_check_eq(
			bark_chase_events.size(), 0,
			"the chase stays silent while the dog is still far right",
		)
		bark_dog.position.x = GameConfig.DOG_BARK_X[0] - 1.0
		bark_director.tick(
			0.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE + 100.0)
		_check_eq(bark_chase_events.size(), 1, "the dog barks once crossing mid-screen")
		if bark_chase_events.size() == 1:
			_check_eq(int(bark_chase_events[0][0]), 0, "the first chase cue is index 0")
		_check_eq(bark_director._dog_barks_fired, 1, "the first chase bark is consumed")

		bark_dog.position.x = GameConfig.DOG_BARK_X[1] + 1.0
		bark_director.tick(
			0.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE + 200.0)
		_check_eq(
			bark_chase_events.size(), 1,
			"the move-now bark waits for the player's lane",
		)

		bark_dog.position.x = GameConfig.DOG_BARK_X[1] - 1.0
		bark_director.tick(
			0.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE + 300.0)
		_check_eq(
			bark_chase_events.size(), 2,
			"the move-now bark fires at the player's lane",
		)
		if bark_chase_events.size() == 2:
			_check_eq(int(bark_chase_events[1][0]), 1, "the second chase cue is index 1")
		_check_eq(bark_director._dog_barks_fired, 2, "both chase barks are consumed")

		for extra_bark_i in 300:
			bark_director.tick(
				1.0 / 60.0, GameConfig.RUN_SPEED, GameConfig.DOG_FIRST_DISTANCE + 400.0)
		_check_eq(bark_chase_events.size(), 2, "no further barks after both cues fired")
		bark_dog.queue_free()

	for bark_child in bark_container.get_children():
		bark_child.queue_free()
	await get_tree().process_frame
	bark_director.queue_free()
	bark_container.queue_free()
	await get_tree().process_frame

	for child in event_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	event_director.tick(0.0, GameConfig.RUN_SPEED, event_director._next_dog_distance)
	await _physics_frames(int(GameConfig.DOG_WARNING_DURATION * 60.0) + 10)
	var second_dog := event_director._active_dog
	_check(second_dog != null, "later dog encounter spawns")
	if second_dog != null:
		_check_eq(
			second_dog.sprite.texture.resource_path,
			GameConfig.DOG_TEXTURES[1],
			"second encounter alternates to dog2",
		)
		_check(second_dog.sprite.flip_h, "second encounter dog faces left")
		second_dog.queue_free()
	event_director.queue_free()
	event_container.queue_free()
	await get_tree().process_frame


func _test_home_hazards() -> void:
	var home_only: Array[int] = [
		GameConfig.HazardKind.NIGHTSTAND, GameConfig.HazardKind.ARMCHAIR,
		GameConfig.HazardKind.COFFEE_TABLE, GameConfig.HazardKind.CUSHION,
		GameConfig.HazardKind.BOOKSHELF, GameConfig.HazardKind.BOXES,
	]
	# Street: the six non-moving street props plus the two encounter kinds.
	var street_props: Array[int] = [
		GameConfig.HazardKind.MANHOLE, GameConfig.HazardKind.DEBRIS,
		GameConfig.HazardKind.BARRICADE, GameConfig.HazardKind.BRICKS,
		GameConfig.HazardKind.CONE, GameConfig.HazardKind.DUMPSTER,
	]
	var street_kinds: Array[int] = street_props.duplicate()
	street_kinds.append(GameConfig.HazardKind.DOG)
	street_kinds.append(GameConfig.HazardKind.CAR)
	# The dog never rolls through pick_kind (its own encounter clock spawns it),
	# so the street's random roll set is the props plus the car.
	var street_roll_kinds: Array[int] = street_props.duplicate()
	street_roll_kinds.append(GameConfig.HazardKind.CAR)
	# School: unchanged by the street swap. The gantry is still the one
	# overhead hazard, so the slide still has a job there.
	var school_kinds: Array[int] = [
		GameConfig.HazardKind.MANHOLE, GameConfig.HazardKind.DEBRIS,
		GameConfig.HazardKind.SIGN, GameConfig.HazardKind.GANTRY,
	]
	# Everything that must never appear indoors.
	var outdoor: Array[int] = [
		GameConfig.HazardKind.MANHOLE, GameConfig.HazardKind.DEBRIS,
		GameConfig.HazardKind.SIGN, GameConfig.HazardKind.GANTRY,
		GameConfig.HazardKind.DOG, GameConfig.HazardKind.CAR,
		GameConfig.HazardKind.BARRICADE, GameConfig.HazardKind.BRICKS,
		GameConfig.HazardKind.CONE, GameConfig.HazardKind.DUMPSTER,
	]
	var kind_name := func(kind: int) -> String:
		return String(GameConfig.HazardKind.find_key(kind))

	# HOME is furniture-only: every prop appears, nothing else does.
	for kind: int in home_only:
		_check(
			GameConfig.hazard_allows_zone(kind, GameConfig.Zone.HOME),
			"%s appears in the home zone" % kind_name.call(kind),
		)
	for kind: int in outdoor:
		_check(
			not GameConfig.hazard_allows_zone(kind, GameConfig.Zone.HOME),
			"%s never appears in the home zone" % kind_name.call(kind),
		)

	# STREET and SCHOOL keep their per-zone pools.
	for kind: int in street_kinds:
		_check(
			GameConfig.hazard_allows_zone(kind, GameConfig.Zone.STREET),
			"%s still appears in the street zone" % kind_name.call(kind),
		)
	for kind: int in school_kinds:
		_check(
			GameConfig.hazard_allows_zone(kind, GameConfig.Zone.SCHOOL),
			"%s still appears in the school zone" % kind_name.call(kind),
		)
	_check(
		not GameConfig.hazard_allows_zone(GameConfig.HazardKind.GANTRY, GameConfig.Zone.STREET),
		"the gantry no longer appears in the street",
	)
	_check(
		not GameConfig.hazard_allows_zone(GameConfig.HazardKind.SIGN, GameConfig.Zone.STREET),
		"the sign no longer appears in the street",
	)
	_check(
		not GameConfig.hazard_allows_zone(GameConfig.HazardKind.DOG, GameConfig.Zone.SCHOOL),
		"the dog still skips the school zone",
	)
	_check(
		not GameConfig.hazard_allows_zone(GameConfig.HazardKind.CAR, GameConfig.Zone.SCHOOL),
		"the car still skips the school zone",
	)
	for kind: int in home_only:
		_check(
			not GameConfig.hazard_allows_zone(kind, -1),
			"%s never rolls in ungated pattern tests" % kind_name.call(kind),
		)

	# --- Unlocks: the whole room is available from the first pixel ---------------
	var default_len := GameConfig.zone_home_length()
	for kind: int in home_only:
		_check_near(
			GameConfig.hazard_unlock(kind, default_len),
			GameConfig.hazard_unlock(kind),
			0.001,
			"%s unlocks at the configured home length by default" % kind_name.call(kind),
		)
	for seconds: float in [5.0, 20.0, 60.0, 300.0]:
		var scaled_len := GameConfig.zone_home_length(seconds)
		for kind: int in home_only:
			_check_near(
				GameConfig.hazard_unlock(kind, scaled_len),
				0.0, 0.001,
				"%s is available from the start of any %0.0f s house"
					% [kind_name.call(kind), seconds],
			)
	_check(
		GameConfig.hazard_unlock(GameConfig.HazardKind.MANHOLE, 8000.0) == 0.0,
		"street unlocks ignore the home length",
	)
	_check(
		GameConfig.hazard_unlock(GameConfig.HazardKind.GANTRY)
			== float(GameConfig.HAZARD_UNLOCK[GameConfig.HazardKind.GANTRY]),
		"the gantry keeps its fixed unlock distance",
	)
	for seconds: float in [5.0, 20.0, 60.0, 300.0]:
		var tail_len := GameConfig.zone_home_length(seconds)
		for kind: int in home_only:
			var fraction: float = GameConfig.hazard_unlock(kind, tail_len) / tail_len
			_check(
				fraction >= 0.0 and fraction < 1.0,
				"%s unlocks inside the %0.0f s house" % [kind_name.call(kind), seconds],
			)

	# --- HOME rolls are furniture-only, from distance zero on --------------------
	var home_rng := RandomNumberGenerator.new()
	home_rng.seed = 88
	var home_len := GameConfig.zone_home_length()
	var start_seen := {}
	for i in 3000:
		start_seen[SpawnDirector.pick_kind(
			0.0, home_rng, GameConfig.Zone.HOME, true, home_len)] = true
	_check_eq(start_seen.size(), 6, "home rolls at distance zero use all six props")
	for kind: int in home_only:
		_check(
			start_seen.has(kind),
			"%s is available in the first frame of home" % kind_name.call(kind),
		)
	for kind: int in outdoor:
		_check(
			not start_seen.has(kind),
			"%s never rolls inside the house" % kind_name.call(kind),
		)
	var late_seen := {}
	for i in 4000:
		late_seen[SpawnDirector.pick_kind(
			home_len * 0.8, home_rng, GameConfig.Zone.HOME, true, home_len)] = true
	_check_eq(late_seen.size(), 6, "late home rolls use all six props")
	for kind: int in outdoor:
		_check(
			not late_seen.has(kind),
			"%s never rolls late in the house" % kind_name.call(kind),
		)

	# STREET and SCHOOL never roll a home prop (the inverse freeze guard), and
	# each zone rolls exactly its own pool: the sign and gantry have moved from
	# the street to the school, and the four new props are street-only.
	var street_rng := RandomNumberGenerator.new()
	street_rng.seed = 89
	var street_seen := {}
	for i in 2000:
		street_seen[SpawnDirector.pick_kind(
			60000.0, street_rng, GameConfig.Zone.STREET)] = true
	_check_eq(street_seen.size(), street_roll_kinds.size(),
		"the street rolls exactly its six props plus the car")
	for kind: int in street_roll_kinds:
		_check(street_seen.has(kind), "%s rolls in the street" % kind_name.call(kind))
	_check(
		not street_seen.has(GameConfig.HazardKind.SIGN)
		and not street_seen.has(GameConfig.HazardKind.GANTRY),
		"the sign and gantry have left the street",
	)
	for kind: int in home_only:
		_check(
			not street_seen.has(kind),
			"%s never rolls in the street" % kind_name.call(kind),
		)
	var school_rng := RandomNumberGenerator.new()
	school_rng.seed = 90
	var school_seen := {}
	for i in 2000:
		school_seen[SpawnDirector.pick_kind(
			60000.0, school_rng, GameConfig.Zone.SCHOOL)] = true
	_check_eq(school_seen.size(), school_kinds.size(),
		"the school still rolls exactly its four kinds")
	for kind: int in school_kinds:
		_check(
			school_seen.has(kind),
			"%s still rolls in the school" % kind_name.call(kind),
		)
	for kind: int in home_only:
		_check(
			not school_seen.has(kind),
			"%s never rolls in the school" % kind_name.call(kind),
		)
	_check(
		not school_seen.has(GameConfig.HazardKind.DOG)
		and not school_seen.has(GameConfig.HazardKind.CAR),
		"dog and car still skip the school",
	)
	for kind: int in street_props:
		if kind == GameConfig.HazardKind.MANHOLE or kind == GameConfig.HazardKind.DEBRIS:
			continue
		_check(
			not school_seen.has(kind),
			"%s is street-only" % kind_name.call(kind),
		)

	# --- The fallback is zone-legal ---------------------------------------------
	_check_eq(
		GameConfig.first_zone_kind(GameConfig.Zone.HOME),
		GameConfig.HazardKind.NIGHTSTAND,
		"the home fallback is the nightstand, not street art",
	)
	_check_eq(
		GameConfig.first_zone_kind(GameConfig.Zone.STREET),
		GameConfig.HazardKind.MANHOLE,
		"the street fallback is the manhole, as before",
	)
	_check_eq(
		GameConfig.first_zone_kind(GameConfig.Zone.SCHOOL),
		GameConfig.HazardKind.MANHOLE,
		"the school fallback is the manhole, as before",
	)

	# --- Prop data sanity: art on disk, static single-image hazards -------------
	# The living-room props and the street props share one contract: art on
	# disk, scaled under the jump apex, a static single image standing on the
	# floor.
	var static_props: Array[int] = home_only.duplicate()
	static_props.append_array(street_props)
	for kind: int in static_props:
		var prop_data: Dictionary = GameConfig.HAZARD_DATA[kind]
		_check(
			ResourceLoader.exists(String(prop_data["texture"])),
			"%s art exists on disk" % kind_name.call(kind),
		)
		var prop_art := load(String(prop_data["texture"])) as Texture2D
		var prop_height := 0.0
		if prop_art != null:
			# The painted content, not the padded texture: slices keep margins.
			var prop_image := prop_art.get_image()
			if prop_image != null:
				prop_height = float(prop_image.get_used_rect().size.y)
			else:
				prop_height = float(prop_art.get_height())
		_check(
			prop_height > 0.0
			and prop_height * float(prop_data["scale"]) < GameConfig.JUMP_APEX - 10.0,
			"%s art stays visibly under the jump apex" % kind_name.call(kind),
		)
		_check(
			float(prop_data["scale"]) > 0.0 and float(prop_data["hitbox_w"]) > 0.0
			and float(prop_data["hitbox_h"]) > 0.0,
			"%s has a positive scale and hitbox" % kind_name.call(kind),
		)
		_check(
			int(prop_data["frames"]) == 0 and float(prop_data["extra_speed"]) == 0.0,
			"%s is a static single-image hazard" % kind_name.call(kind),
		)
		_check(
			float(prop_data["clearance"]) == 0.0 and not bool(prop_data["overhead"]),
			"%s stands on the floor and is jumped" % kind_name.call(kind),
		)

	# --- The dog waits while Elias is indoors ------------------------------------
	var dog_container := Node2D.new()
	add_child(dog_container)
	var dog_director := SpawnDirector.new()
	add_child(dog_director)
	dog_director.setup(dog_container, 407)
	_check(
		not dog_director._try_start_dog_encounter(
			GameConfig.DOG_FIRST_DISTANCE, GameConfig.RUN_SPEED, GameConfig.Zone.HOME),
		"the dog encounter never starts in the home zone",
	)
	_check_eq(
		dog_director._dog_reserved_lane, -1,
		"the home dog refusal reserves no lane",
	)
	_check(
		dog_director._try_start_dog_encounter(
			GameConfig.DOG_FIRST_DISTANCE, GameConfig.RUN_SPEED, GameConfig.Zone.STREET),
		"the dog encounter still starts in the street",
	)
	_check(
		dog_director._dog_reserved_lane >= 0,
		"the street dog reserves its lane",
	)
	for child in dog_container.get_children():
		child.queue_free()
	dog_director.queue_free()
	dog_container.queue_free()
	await get_tree().process_frame


func _test_medals() -> void:
	# Endless rule: distance reached, thresholds from GameConfig.
	var gold_m := GameConfig.MEDAL_DISTANCE_GOLD
	var silver_m := GameConfig.MEDAL_DISTANCE_SILVER
	_check_eq(
		GameConfig.medal_for_distance(gold_m), GameConfig.Medal.GOLD,
		"the gold distance medals gold",
	)
	_check_eq(
		GameConfig.medal_for_distance(gold_m - 1.0), GameConfig.Medal.SILVER,
		"just under the gold distance medals silver",
	)
	_check_eq(
		GameConfig.medal_for_distance(silver_m), GameConfig.Medal.SILVER,
		"the silver distance medals silver",
	)
	_check_eq(
		GameConfig.medal_for_distance(silver_m - 1.0), GameConfig.Medal.BLACK,
		"just under the silver distance medals black",
	)
	_check_eq(
		GameConfig.medal_for_distance(0.0), GameConfig.Medal.BLACK,
		"a first-step death medals black",
	)

	# Campaign rule: finishing gates the badge, score against the previous
	# best decides gold vs silver. A first clear is silver.
	_check_eq(
		GameConfig.campaign_medal(false, 5000, 0), GameConfig.Medal.BLACK,
		"dying before the line medals black no matter the score",
	)
	_check_eq(
		GameConfig.campaign_medal(true, 4600, 0), GameConfig.Medal.SILVER,
		"a first clear medals silver",
	)
	_check_eq(
		GameConfig.campaign_medal(true, 5300, 5000), GameConfig.Medal.GOLD,
		"finishing past the best medals gold",
	)
	_check_eq(
		GameConfig.campaign_medal(true, 5000, 5000), GameConfig.Medal.SILVER,
		"matching the best is not a new best",
	)
	_check_eq(
		GameConfig.campaign_medal(true, 4600, 5000), GameConfig.Medal.SILVER,
		"a clear under the best still medals silver",
	)

	# The tier clamp keeps the results screen safe against out-of-range calls.
	var screen := (load("res://scenes/results_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	(screen as ResultsScreen).set_medal(GameConfig.Medal.GOLD)
	_check_eq(
		(screen as ResultsScreen).awarded_medal(), GameConfig.Medal.GOLD,
		"the results screen awards gold on demand",
	)
	_check(
		(screen as ResultsScreen).medal_icon.texture != null,
		"the medal icon carries a texture",
	)
	screen.queue_free()


func _test_modes() -> void:
	var home := GameConfig.zone_home_length()
	var street := GameConfig.zone_street_length()
	var school := GameConfig.zone_school_length()

	_check_near(
		GameConfig.campaign_finish_distance(), home + street + school, 0.01,
		"the campaign finish sits one pass past every zone",
	)
	_check_near(
		GameConfig.campaign_finish_distance() / GameConfig.RUN_SPEED,
		GameConfig.ZONE_HOME_DURATION_SECONDS
			+ GameConfig.ZONE_STREET_DURATION_SECONDS
			+ GameConfig.CAMPAIGN_SCHOOL_SECONDS,
		0.01,
		"the campaign finish is one timed pass of home + street + school",
	)
	_check_near(
		school, GameConfig.CAMPAIGN_SCHOOL_SECONDS * GameConfig.RUN_SPEED, 0.01,
		"the school leg is CAMPAIGN_SCHOOL_SECONDS long",
	)

	_check_eq(
		GameConfig.zone_for_distance(0.0, home, street, GameConfig.RunMode.ENDLESS),
		GameConfig.Zone.HOME,
		"endless starts at home",
	)
	_check_eq(
		GameConfig.zone_for_distance(home + 1.0, home, street, GameConfig.RunMode.ENDLESS),
		GameConfig.Zone.STREET,
		"endless moves to the street like campaign",
	)
	_check_eq(
		GameConfig.zone_for_distance(home + street + 1.0, home, street, GameConfig.RunMode.ENDLESS),
		GameConfig.Zone.STREET,
		"endless stays in the street where campaign enters school",
	)
	_check_eq(
		GameConfig.zone_for_distance(
			home + street + school * 10.0, home, street, GameConfig.RunMode.ENDLESS),
		GameConfig.Zone.STREET,
		"endless never reaches the school zone",
	)
	_check_eq(
		GameConfig.zone_for_distance(home + street + 1.0, home, street, GameConfig.RunMode.CAMPAIGN),
		GameConfig.Zone.SCHOOL,
		"campaign enters the school past the street",
	)

	_check_near(GameConfig.endless_speed_multiplier(0.0), 1.0, 0.0001,
		"the endless ramp starts at 1.0x")
	_check_near(GameConfig.endless_speed_multiplier(GameConfig.ENDLESS_RAMP_DISTANCE * 0.5), 1.25, 0.0001,
		"the endless ramp is linear at half the ramp distance")
	_check_near(
		GameConfig.endless_speed_multiplier(GameConfig.ENDLESS_RAMP_DISTANCE),
		GameConfig.ENDLESS_RAMP_MAX_MULTIPLIER, 0.0001,
		"the endless ramp reaches its cap at the ramp distance")
	_check_near(
		GameConfig.endless_speed_multiplier(GameConfig.ENDLESS_RAMP_DISTANCE * 10.0),
		GameConfig.ENDLESS_RAMP_MAX_MULTIPLIER, 0.0001,
		"the endless ramp never exceeds its cap")
	var ramp_prev := 0.0
	var ramp_monotonic := true
	for ramp_step in range(1, 9):
		var ramp_mult := GameConfig.endless_speed_multiplier(
			GameConfig.ENDLESS_RAMP_DISTANCE * ramp_step / 8.0)
		if ramp_mult <= ramp_prev:
			ramp_monotonic = false
		ramp_prev = ramp_mult
	_check(ramp_monotonic, "the endless ramp only increases with distance")

	# Campaign ramp: linear from stock speed at the start line to +35% at the
	# finish, capped so a botched distance can never overspeed the world.
	var finish := home + street + school
	_check_near(GameConfig.campaign_speed_multiplier(0.0, finish), 1.0, 0.0001,
		"the campaign ramp starts at stock speed")
	_check_near(
		GameConfig.campaign_speed_multiplier(finish * 0.5, finish),
		1.0 + (GameConfig.CAMPAIGN_RAMP_MAX_MULTIPLIER - 1.0) * 0.5, 0.0001,
		"the campaign ramp is linear halfway through")
	_check_near(
		GameConfig.campaign_speed_multiplier(finish, finish),
		GameConfig.CAMPAIGN_RAMP_MAX_MULTIPLIER, 0.0001,
		"the campaign ramp reaches its cap at the finish")
	_check_near(
		GameConfig.campaign_speed_multiplier(finish * 2.0, finish),
		GameConfig.CAMPAIGN_RAMP_MAX_MULTIPLIER, 0.0001,
		"the campaign ramp never exceeds its cap")
	_check_near(
		GameConfig.campaign_speed_multiplier(1000.0, 0.0), 1.0, 0.0001,
		"a missing finish line disables the campaign ramp")
	var campaign_prev := 0.0
	var campaign_monotonic := true
	for campaign_step in range(1, 9):
		var campaign_mult := GameConfig.campaign_speed_multiplier(
			finish * campaign_step / 8.0, finish)
		if campaign_mult <= campaign_prev:
			campaign_monotonic = false
		campaign_prev = campaign_mult
	_check(campaign_monotonic, "the campaign ramp only increases with distance")


func _test_progress() -> void:
	# Campaign fractions use the per-run zone lengths, so retuned durations
	# re-proportion the bar automatically.
	var home := 1000.0
	var street := 1000.0
	var finish := 3000.0
	_check_near(GameConfig.campaign_progress(0.0, home, street, finish), 0.0, 0.0001,
		"campaign progress starts at zero")
	_check_near(GameConfig.campaign_progress(home, home, street, finish), 1000.0 / 3000.0, 0.0001,
		"campaign progress hits the home boundary at the home fraction")
	_check_near(
		GameConfig.campaign_progress(home + street, home, street, finish),
		2000.0 / 3000.0, 0.0001,
		"campaign progress hits the street boundary at the street fraction")
	_check_near(GameConfig.campaign_progress(finish, home, street, finish), 1.0, 0.0001,
		"campaign progress reaches one at the finish line")
	_check_near(GameConfig.campaign_progress(finish * 2.0, home, street, finish), 1.0, 0.0001,
		"campaign progress clamps past the finish line")
	_check_near(GameConfig.campaign_progress(0.0, home, street, 0.0), 0.0, 0.0001,
		"campaign progress guards a degenerate finish distance")

	var segs := GameConfig.campaign_segment_fractions(home, street, finish)
	_check_near(segs.x + segs.y + segs.z, 1.0, 0.0001,
		"campaign segments sum to the whole track")
	_check_near(segs.x, 1000.0 / 3000.0, 0.0001, "the home segment takes its real share")
	_check_near(segs.z, 1000.0 / 3000.0, 0.0001, "the school segment takes its real share")
	# Retuning the campaign re-proportions: a longer home grows its segment.
	var segs_long := GameConfig.campaign_segment_fractions(2000.0, 1000.0, 4000.0)
	_check_near(segs_long.x, 0.5, 0.0001,
		"a retuned longer home grows its segment share")

	# Endless milestones: px in, metres thresholds; silver tick sits at half.
	_check_near(GameConfig.endless_progress(0.0), 0.0, 0.0001,
		"endless progress starts at zero")
	_check_near(
		GameConfig.endless_progress(GameConfig.MEDAL_DISTANCE_SILVER * 100.0),
		0.5, 0.0001,
		"endless progress sits at half the track at the silver distance")
	_check_near(
		GameConfig.endless_progress(GameConfig.MEDAL_DISTANCE_GOLD * 100.0),
		1.0, 0.0001,
		"endless progress reaches one at the gold distance")
	_check_near(
		GameConfig.endless_progress(GameConfig.MEDAL_DISTANCE_GOLD * 1000.0),
		1.0, 0.0001,
		"endless progress clamps past gold")
	_check_near(GameConfig.endless_silver_fraction(), 0.5, 0.0001,
		"the silver tick sits at half the endless track")

	# The HUD component renders both modes headlessly.
	var scene := load("res://scenes/hud.tscn") as PackedScene
	_check(scene != null, "hud scene loads")
	if scene == null:
		return
	var hud_root := scene.instantiate()
	add_child(hud_root)
	var progress_hud := hud_root.get_node("HudRoot/Progress") as ProgressBarHud
	_check(progress_hud != null, "the hud hosts the progress bar")
	if progress_hud != null:
		_check(progress_hud.visible, "the progress bar starts visible")
		progress_hud.set_campaign(1500.0, 1000.0, 1000.0, 3000.0, GameConfig.Zone.STREET)
		_check_near(progress_hud.progress_fraction(), 0.5, 0.0001,
			"the campaign bar renders the mid-course fraction")
		progress_hud.set_endless(GameConfig.MEDAL_DISTANCE_GOLD * 100.0)
		_check_near(progress_hud.progress_fraction(), 1.0, 0.0001,
			"the endless bar fills at the gold distance")
		progress_hud.visible = false
	hud_root.queue_free()


func _test_game_state() -> void:
	var state := get_node_or_null("/root/GameState")
	_check(state != null, "the GameState autoload is registered")
	if state == null:
		return

	# Isolate from anything the suite did earlier, then restore.
	var keep_mode: int = state.mode
	var keep_campaign: int = state.best_campaign
	var keep_endless: int = state.best_endless
	state.best_campaign = 0
	state.best_endless = 0

	state.mode = GameConfig.RunMode.CAMPAIGN
	_check_eq(state.best_for_mode(), 0, "a fresh session has no campaign best")
	_check(state.report_score(1200), "a first campaign score reports as a new best")
	_check_eq(state.best_campaign, 1200, "the campaign best records the score")
	_check_eq(state.best_endless, 0, "the endless best is untouched by campaign runs")

	state.mode = GameConfig.RunMode.ENDLESS
	_check_eq(state.best_for_mode(), 0, "the endless best starts empty")
	_check(state.report_score(900), "a first endless score reports as a new best")
	_check_eq(state.best_endless, 900, "the endless best records its own score")
	_check_eq(state.best_campaign, 1200, "the campaign best survives endless runs")
	_check(not state.report_score(800), "an endless score under the best is not a new best")
	_check_eq(state.best_endless, 900, "the endless best only ratchets upward")
	_check_eq(
		state.best_for_mode(GameConfig.RunMode.CAMPAIGN), 1200,
		"best_for_mode can read any mode explicitly",
	)

	state.best_campaign = keep_campaign
	state.best_endless = keep_endless
	state.mode = keep_mode


func _test_score_system() -> void:
	# Combo thresholds: x2 / x3 / x4 / x5 at chains 3 / 6 / 8 / 10.
	_check_eq(GameConfig.combo_multiplier(0), 1, "chain 0 is x1")
	_check_eq(GameConfig.combo_multiplier(2), 1, "chain 2 is x1")
	_check_eq(GameConfig.combo_multiplier(3), 2, "chain 3 is x2")
	_check_eq(GameConfig.combo_multiplier(5), 2, "chain 5 is x2")
	_check_eq(GameConfig.combo_multiplier(6), 3, "chain 6 is x3")
	_check_eq(GameConfig.combo_multiplier(7), 3, "chain 7 is x3")
	_check_eq(GameConfig.combo_multiplier(8), 4, "chain 8 is x4")
	_check_eq(GameConfig.combo_multiplier(9), 4, "chain 9 is x4")
	_check_eq(GameConfig.combo_multiplier(10), 5, "chain 10 is x5")
	_check_eq(GameConfig.combo_multiplier(99), 5, "chain 99 is x5")

	# The next rung drives the HUD's "x3 · 6/8" readout.
	_check_eq(GameConfig.combo_next_threshold(0), 3, "no chain points at x2")
	_check_eq(GameConfig.combo_next_threshold(2), 3, "chain 2 points at x2")
	_check_eq(GameConfig.combo_next_threshold(3), 6, "x2 points at x3")
	_check_eq(GameConfig.combo_next_threshold(5), 6, "chain 5 points at x3")
	_check_eq(GameConfig.combo_next_threshold(6), 8, "x3 points at x4")
	_check_eq(GameConfig.combo_next_threshold(8), 10, "x4 points at x5")
	_check_eq(GameConfig.combo_next_threshold(10), 0, "x5 has no next rung")

	# One-time coin bonus per rung, bounded on purpose (max +8 per run).
	_check_eq(GameConfig.combo_tier_coin_bonus(1), 0, "no bonus below x2")
	_check_eq(GameConfig.combo_tier_coin_bonus(2), 1, "x2 pays one coin")
	_check_eq(GameConfig.combo_tier_coin_bonus(3), 2, "x3 pays two coins")
	_check_eq(GameConfig.combo_tier_coin_bonus(4), 2, "x4 pays two coins")
	_check_eq(GameConfig.combo_tier_coin_bonus(5), 3, "x5 pays three coins")
	var tier_total := 0
	for value in GameConfig.COMBO_TIER_COIN_BONUS.values():
		tier_total += int(value)
	_check_eq(tier_total, 8, "a perfect chain pays at most +8 coins")
	_check(
		GameConfig.PICKUP_GAP_MIN < GameConfig.PICKUP_GAP_MAX,
		"pickup gap range is sane",
	)

	var system := ScoreSystem.new()
	_check_eq(system.score, 0, "score starts at 0")
	_check_eq(system.item_count, 0, "item count starts at 0")
	_check_eq(system.chain, 0, "chain starts at 0")

	# Distance trickle: floor(distance / 10), incremental, no double count.
	system.add_distance(0.0)
	_check_eq(system.score, 0, "no distance points at 0")
	system.add_distance(99.0)
	_check_eq(system.score, 9, "99 px is 9 points")
	system.add_distance(150.0)
	_check_eq(system.score, 15, "150 px is 15 points total")
	system.add_distance(150.0)
	_check_eq(system.score, 15, "re-adding the same distance adds nothing")

	# Hazard passes are flat +10 with no combo effect.
	system.add_hazard_passed()
	_check_eq(system.score, 25, "hazard pass is +10")
	_check_eq(system.chain, 0, "hazard passes do not build the combo")

	# Item pickups: 1-2 x1, 3-5 x2, 6-7 x3, 8-9 x4, 10+ x5.
	var fresh := ScoreSystem.new()
	for i in 2:
		fresh.add_item_pickup()
	_check_eq(fresh.score, 100, "two x1 pickups are +100")
	_check_eq(fresh.chain, 2, "two pickups build a chain of 2")
	_check_eq(fresh.item_count, 2, "two pickups count as two items")
	fresh.add_item_pickup()
	_check_eq(fresh.score, 200, "third pickup is x2 (+100)")
	_check_eq(GameConfig.combo_multiplier(fresh.chain), 2, "chain 3 reports x2")

	for i in 7:
		fresh.add_item_pickup()
	_check_eq(fresh.item_count, 10, "ten pickups count as ten items")
	_check_eq(fresh.chain, 10, "ten pickups build a chain of 10")
	_check_eq(GameConfig.combo_multiplier(fresh.chain), 5, "chain 10 reports x5")
	# 2*50 + 3*100 + 2*150 + 2*200 + 1*250 = 1350
	_check_eq(fresh.score, 1350, "ten pickups score 1350 points")

	# Reset breaks the chain but keeps score and item count.
	fresh.reset_combo()
	_check_eq(fresh.chain, 0, "reset clears the chain")
	_check_eq(fresh.score, 1350, "reset keeps the score")
	_check_eq(fresh.item_count, 10, "reset keeps the item count")
	fresh.add_item_pickup()
	_check_eq(fresh.score, 1400, "pickup after reset is x1 again")
	# reset on an already-empty chain is a no-op (no signal spam / crash).
	fresh.reset_combo()
	fresh.reset_combo()
	_check_eq(fresh.chain, 0, "repeated reset stays at 0")

	# Tier announcements: once per rung per run, so a broken chain cannot farm
	# the coin bonus. A new ScoreSystem is a new run.
	var tier_system := ScoreSystem.new()
	var announced: Array[int] = []
	tier_system.tier_reached.connect(
		func(tier: int) -> void: announced.append(tier))
	for i in 2:
		tier_system.add_item_pickup()
	_check_eq(announced.size(), 0, "chains 1-2 announce no rung")
	for i in 3:
		tier_system.add_item_pickup()
	_check_eq(announced.size(), 1, "chain 3 announces one rung")
	_check_eq(announced[0], 2, "the first rung is x2")
	for i in 3:
		tier_system.add_item_pickup()
	_check_eq(announced.size(), 3, "chain 8 has announced three rungs")
	_check_eq(announced[1], 3, "the second rung is x3")
	_check_eq(announced[2], 4, "the third rung is x4")
	for i in 2:
		tier_system.add_item_pickup()
	_check_eq(announced.size(), 4, "chain 10 announces the final rung")
	_check_eq(announced[3], 5, "the last rung is x5")

	# Rebuilding every rung must stay silent for the rest of the run.
	tier_system.reset_combo()
	for i in GameConfig.COMBO_THRESHOLD_5 * 2:
		tier_system.add_item_pickup()
	_check_eq(announced.size(), 4, "rebuilding the ladder announces nothing new")


func _test_collectible() -> void:
	var scene := load("res://scenes/collectible.tscn") as PackedScene
	_check(scene != null, "collectible scene loads")
	if scene == null:
		return

	var item := scene.instantiate() as Collectible
	add_child(item)
	item.set_physics_process(false)
	item.setup(GameConfig.ItemKind.PENCIL, GameConfig.LANE_MIDDLE, 0.0)
	_check_eq(item.collision_layer, GameConfig.LAYER_COLLECTIBLE, "item sits on the collectible layer")
	_check_eq(item.collision_mask, 0, "item does not scan for areas itself")
	_check(not item.monitoring, "item is passive; the player's hitbox detects it")
	var texture := item.sprite.texture
	_check(texture != null, "pencil item has a texture")
	if texture != null:
		_check_eq(texture.resource_path, "res://assets/props/item_pencil.png", "pencil uses its configured art")
	var box := item.shape.shape as RectangleShape2D
	_check(box != null, "item has a rectangle shape")
	if box != null:
		_check_eq(box.size, GameConfig.ITEM_HITBOX_SIZE, "item hitbox matches config")
		_check_near(
			item.box_y_range().y,
			item.box_y_range().x + GameConfig.ITEM_HITBOX_SIZE.y,
			0.01,
			"item box has positive height",
		)
	_check_near(
		item.position.y,
		GameConfig.lane_y(GameConfig.LANE_MIDDLE),
		0.01,
		"item sits on its lane baseline",
	)
	item.queue_free()

	for kind: int in GameConfig.ITEM_DATA:
		var prop := scene.instantiate() as Collectible
		add_child(prop)
		prop.set_physics_process(false)
		prop.setup(kind, GameConfig.LANE_TOP, 0.0)
		var data: Dictionary = GameConfig.ITEM_DATA[kind]
		var prop_tex := prop.sprite.texture
		_check(prop_tex != null, "item kind %d has a texture" % kind)
		if prop_tex != null:
			_check_eq(prop_tex.resource_path, String(data["texture"]), "item kind %d uses its configured art" % kind)
		prop.queue_free()

	# collect() succeeds once, then refuses.
	var once := scene.instantiate() as Collectible
	add_child(once)
	once.set_physics_process(false)
	once.setup(GameConfig.ItemKind.BOOK, GameConfig.LANE_MIDDLE, 0.0)
	var picked := [0]
	once.picked_up.connect(func(_kind: int) -> void: picked[0] += 1)
	_check(once.collect(), "collect succeeds the first time")
	_check_eq(picked[0], 1, "picked_up fires once")
	_check(not once.collect(), "collect refuses the second time")
	_check_eq(picked[0], 1, "picked_up does not fire twice")
	once.queue_free()

	# Pickup FX: scoring is instant, but the item lives on to pop, rise and
	# fade. The scale is tweened from the item's own art scale, never from 1.
	var fx_item := scene.instantiate() as Collectible
	add_child(fx_item)
	fx_item.setup(GameConfig.ItemKind.BOOK, GameConfig.LANE_MIDDLE, 120.0)
	var base_scale := fx_item.sprite.scale
	var start_x := fx_item.position.x
	var start_y := fx_item.sprite.position.y
	_check(fx_item.collect(), "item collects and starts its FX")
	_check(is_instance_valid(fx_item), "a collected item is not freed immediately")
	_check_near(fx_item.sprite.scale.x, base_scale.x, 0.001,
		"FX starts from the item's own art scale")
	await _physics_frames(3)
	_check(fx_item.shape.disabled, "the pickup box shuts off after collection")
	_check(fx_item.sprite.position.y < start_y, "the item rises as it is collected")
	_check(fx_item.sprite.scale.x > base_scale.x, "the item pops before it shrinks")
	_check(fx_item.position.x < start_x, "the item keeps scrolling during its FX")
	_check(fx_item.collect_spark.emitting, "School Items fire the spark burst")
	await get_tree().create_timer(
		GameConfig.ITEM_COLLECT_TIME + GameConfig.COLLECT_SPARK_LIFETIME + 0.2).timeout
	_check(not is_instance_valid(fx_item), "the item frees itself when the FX ends")

	# Coins use the shorter effect with no spark, so a trail cannot stack ghosts.
	var fx_coin := scene.instantiate() as Collectible
	add_child(fx_coin)
	fx_coin.setup(GameConfig.ItemKind.COIN, GameConfig.LANE_MIDDLE, 0.0)
	_check(GameConfig.COIN_COLLECT_TIME < GameConfig.ITEM_COLLECT_TIME,
		"coin FX is shorter than the School Item FX")
	_check(fx_coin.collect(), "coin collects and starts its shorter FX")
	_check(not fx_coin.collect_spark.emitting, "coins skip the spark burst")
	await get_tree().create_timer(GameConfig.COIN_COLLECT_TIME + 0.15).timeout
	_check(not is_instance_valid(fx_coin), "the coin frees itself after its short FX")

	# missed fires when it scrolls behind the player.
	var drifter := scene.instantiate() as Collectible
	add_child(drifter)
	drifter.set_physics_process(false)
	drifter.setup(GameConfig.ItemKind.ERASER, GameConfig.LANE_MIDDLE, 100.0)
	var missed_count := [0]
	drifter.missed.connect(func() -> void: missed_count[0] += 1)
	drifter.position.x = GameConfig.PLAYER_X
	drifter._physics_process(0.5)
	_check_eq(missed_count[0], 1, "missed fires when the item passes the player")
	drifter._physics_process(0.5)
	_check_eq(missed_count[0], 1, "missed fires only once")
	_check(not drifter.collect(), "a missed item cannot be collected")
	drifter.queue_free()

	# Currency never reports a miss: a coin trail the player runs past leaves
	# the combo alone, unlike School Items.
	var coin_drift := scene.instantiate() as Collectible
	add_child(coin_drift)
	coin_drift.set_physics_process(false)
	coin_drift.setup(GameConfig.ItemKind.COIN, GameConfig.LANE_MIDDLE, 100.0)
	var coin_missed_count := [0]
	coin_drift.missed.connect(func() -> void: coin_missed_count[0] += 1)
	coin_drift.position.x = GameConfig.PLAYER_X
	coin_drift._physics_process(0.5)
	_check_eq(coin_missed_count[0], 0, "a coin past the player never fires missed")
	_check(coin_drift.collect(), "a coin past the player is still collectible")
	coin_drift.queue_free()

	# Live physics: grounded player collects, jumping player misses.
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var collected_events: Array = []
	player.item_collected.connect(func(kind: int) -> void: collected_events.append(kind))

	var live := scene.instantiate() as Collectible
	add_child(live)
	live.set_physics_process(false)
	live.setup(GameConfig.ItemKind.BAG, GameConfig.LANE_MIDDLE, 0.0)
	live.position.x = GameConfig.PLAYER_X
	await _physics_frames(4)
	_check(collected_events.size() >= 1, "grounded player collects the item (live physics)")
	if collected_events.size() > 0:
		_check_eq(int(collected_events[0]), int(GameConfig.ItemKind.BAG), "collected kind matches the spawn")

	player.reset_health()
	collected_events.clear()
	var live_high := scene.instantiate() as Collectible
	add_child(live_high)
	live_high.set_physics_process(false)
	live_high.setup(GameConfig.ItemKind.PENCIL, GameConfig.LANE_MIDDLE, 0.0)
	live_high.position.x = GameConfig.PLAYER_X
	player.air_height = GameConfig.JUMP_APEX
	player._apply_pose()
	await _physics_frames(4)
	_check(collected_events.is_empty(), "jumping player misses the floating item (live physics)")

	# Lane rule: a jump in another lane must not scoop the item, but switching
	# into its lane while overlapping does.
	var off_high := scene.instantiate() as Collectible
	add_child(off_high)
	off_high.set_physics_process(false)
	off_high.setup(GameConfig.ItemKind.BOOK, GameConfig.LANE_TOP, 0.0)
	off_high.position.x = GameConfig.PLAYER_X
	player.lane = GameConfig.LANE_MIDDLE
	player.lane_y = GameConfig.lane_y(GameConfig.LANE_MIDDLE)
	player.air_height = GameConfig.JUMP_APEX
	player._apply_pose()
	await _physics_frames(4)
	_check(
		collected_events.is_empty(),
		"a MIDDLE-lane jump cannot collect a TOP-lane item (live physics)",
	)

	player.move_lane(-1)
	_check_eq(collected_events.size(), 1, "switching into the item's lane collects it")

	# Direct guard, independent of jump geometry.
	var blocked := scene.instantiate() as Collectible
	add_child(blocked)
	blocked.set_physics_process(false)
	blocked.setup(GameConfig.ItemKind.PENCIL, GameConfig.LANE_BOTTOM, 0.0)
	player._on_hitbox_area_entered(blocked)
	_check_eq(collected_events.size(), 1, "an off-lane item is not collected")
	player.lane = GameConfig.LANE_BOTTOM
	player._on_hitbox_area_entered(blocked)
	_check_eq(collected_events.size(), 2, "a same-lane item is collected")
	blocked.queue_free()

	live_high.queue_free()
	player.queue_free()


func _test_pickup_director() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	_check_eq(SpawnDirector.choose_pickup_lane([0, 1, 2], rng), -1, "no lane open means no pickup")
	_check(SpawnDirector.choose_pickup_lane([], rng) >= 0, "empty row still yields a lane")

	# Fuzz: the chosen lane must never be occupied.
	var fuzz_violations := 0
	var fuzz_skips := 0
	for i in 10000:
		var occupied: Array[int] = []
		for lane in GameConfig.LANE_COUNT:
			if rng.randi() % 3 == 0:
				occupied.append(lane)
		var chosen := SpawnDirector.choose_pickup_lane(occupied, rng)
		if occupied.size() >= GameConfig.LANE_COUNT:
			if chosen != -1:
				fuzz_violations += 1
			fuzz_skips += 1
		elif chosen < 0 or chosen >= GameConfig.LANE_COUNT or occupied.has(chosen):
			fuzz_violations += 1
	_check_eq(fuzz_violations, 0, "10000 fuzzed pickups never pick an occupied lane")
	_check(fuzz_skips > 0, "some fuzzed rows are fully blocked (%d of 10000)" % fuzz_skips)

	# spawn_pickup respects PICKUP_LANE_CLEARANCE around SPAWN_X.
	var container := Node2D.new()
	add_child(container)
	var director := SpawnDirector.new()
	add_child(director)
	director.setup(container, 42)

	var blocker := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	container.add_child(blocker)
	blocker.set_physics_process(false)
	blocker.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_TOP, 0.0)
	blocker.position.x = GameConfig.SPAWN_X
	var lane := director.spawn_pickup(0.0, 0.0)
	_check(lane >= 0, "pickup spawns when a lane is clear")
	if lane >= 0:
		_check(lane != GameConfig.LANE_TOP, "pickup avoids the lane blocked at SPAWN_X")

	# tick() spawns pickups on its own clock (gap < 1800, so 5 s at 420 px/s triggers one).
	var before := container.get_child_count()
	for i in 5:
		director.tick(1.0, GameConfig.RUN_SPEED, float(i * 420))
	_check(container.get_child_count() > before, "tick spawns pickups between hazard rows")

	# Hazard passed signal flows to the director.
	var passer := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	add_child(passer)
	passer.set_physics_process(false)
	passer.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
	passer.position.x = GameConfig.PLAYER_X + 10.0
	var direct_passed := [0]
	passer.passed_player.connect(func() -> void: direct_passed[0] += 1)
	passer._physics_process(1.0)
	_check(direct_passed[0] >= 1, "hazard crossing the player emits passed_player")
	passer.queue_free()

	container.queue_free()
	director.queue_free()


func _test_coins() -> void:
	# --- Config contract -----------------------------------------------------
	_check(GameConfig.ITEM_DATA.has(GameConfig.ItemKind.COIN), "coin has item data")
	var coin_data: Dictionary = GameConfig.ITEM_DATA[GameConfig.ItemKind.COIN]
	_check(ResourceLoader.exists(String(coin_data["texture"])), "coin art exists on disk")
	_check(coin_data.get("currency", false), "the coin is marked as currency")
	for kind: int in GameConfig.ITEM_DATA:
		if kind == GameConfig.ItemKind.COIN:
			continue
		_check(
			not GameConfig.ITEM_DATA[kind].get("currency", false),
			"school items are not currency (kind %d)" % kind,
		)
	_check(GameConfig.COIN_RUN_MIN == 3 and GameConfig.COIN_RUN_MAX == 5,
		"coin runs drop three to five coins")
	_check(GameConfig.COIN_RUN_GAP_MIN > GameConfig.PICKUP_GAP_MAX,
		"coin runs are rarer than school item pickups")

	# --- Coin runs: one clear lane, spaced trail, reserved against rows ------
	var container := Node2D.new()
	add_child(container)
	var director := SpawnDirector.new()
	add_child(director)
	director.setup(container, 7)

	# The very first run must respect the dog's reserved lane.
	director._dog_reserved_lane = GameConfig.LANE_TOP
	var run_lane := director.spawn_coin_run(0.0, 0.0)
	_check(run_lane >= 0, "a coin run spawns in a clear lane")
	_check(run_lane != GameConfig.LANE_TOP, "a coin run never takes the dog's reserved lane")
	director._dog_reserved_lane = -1
	if run_lane >= 0:
		var coins_found: Array = []
		for child in container.get_children():
			if child is Collectible and child.get_kind() == GameConfig.ItemKind.COIN:
				coins_found.append(child)
		_check(
			coins_found.size() >= GameConfig.COIN_RUN_MIN
			and coins_found.size() <= GameConfig.COIN_RUN_MAX,
			"the run drops 3-5 coins (%d)" % coins_found.size(),
		)
		var same_lane := true
		var spaced := true
		var first_coin := coins_found[0] as Collectible
		for i in coins_found.size():
			var coin := coins_found[i] as Collectible
			if coin.lane != run_lane:
				same_lane = false
			if not is_equal_approx(
				coin.position.x - first_coin.position.x,
				float(i) * GameConfig.COIN_SPACING,
			):
				spaced = false
		_check(same_lane, "every coin of the run shares one lane")
		_check(spaced, "the trail is spaced COIN_SPACING apart")
		_check_eq(director._coin_run_lane, run_lane, "the run reserves its lane")

		# A second run is skipped while the first trail is live.
		_check_eq(director.spawn_coin_run(0.0, 0.0), -1,
			"only one coin run lives at a time")

		# Hazard rows never enter the live trail lane.
		for i in 12:
			director.spawn_row(1000.0 + 30.0 * float(i), 0.0)
		var row_violations := 0
		for child in container.get_children():
			if child is Hazard and child.lane == run_lane:
				row_violations += 1
		_check_eq(row_violations, 0, "hazard rows never enter the live coin lane")

		# Once the trail is gone the lane is released for rows and dog runs.
		for coin in coins_found:
			coin.queue_free()
		director._refresh_coin_reservation()
		_check_eq(director._coin_run_lane, -1, "the coin lane releases when the trail ends")

	container.queue_free()
	director.queue_free()

	# --- Wallet: event, write-through, round trip, defensive load ------------
	var scratch := "user://test_wallet_scratch.cfg"
	var pre_save_path := GameState.save_path
	var pre_coins := GameState.coins
	GameState.save_path = scratch
	GameState.coins = 0
	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	var coin_events: Array[int] = []
	GameState.coins_changed.connect(func(count: int) -> void: coin_events.append(count))
	GameState.add_coins(7)
	_check_eq(GameState.coins, 7, "add_coins credits the wallet")
	_check_eq(coin_events.size(), 1, "the wallet signal fires per deposit")
	_check_eq(coin_events[0], 7, "the wallet signal carries the new balance")
	GameState.add_coins(0)
	GameState.add_coins(-3)
	_check_eq(coin_events.size(), 1, "zero and negative deposits are ignored")
	_check_eq(GameState.coins, 7, "the wallet only moves on positive deposits")
	_check(FileAccess.file_exists(scratch), "the wallet writes through to disk")

	# Round trip: a fresh load reads the same balance.
	GameState.coins = 0
	GameState._load_wallet()
	_check_eq(GameState.coins, 7, "a restart reloads the saved balance")

	# A corrupt file loads as an empty wallet, never a crash.
	var garbage := FileAccess.open(scratch, FileAccess.WRITE)
	garbage.store_string("this is not a ConfigFile")
	garbage.close()
	GameState.coins = 99
	GameState._load_wallet()
	_check_eq(GameState.coins, 0, "a corrupt save loads as an empty wallet")

	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	# --- Currency routing: coins bypass the score system ----------------------
	# A wallet that already holds coins (the bug: 55 saved coins leaking into
	# a fresh run's HUD) must not touch the run's counter.
	GameState.coins = 55
	var wallet_root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(wallet_root)
	var world := wallet_root.get_node("RunWorld") as RunWorld
	world.set_physics_process(false)
	_check_eq(world.score_hud.label_text("coins"), "COINS  0",
		"a new run starts the coin counter at zero even with a full wallet")
	var score_before := world.score_system.score
	var items_before := world.score_system.item_count
	var chain_before := world.score_system.chain
	world._on_item_collected(GameConfig.ItemKind.COIN)
	_check_eq(GameState.coins, 55 + GameConfig.COIN_VALUE,
		"a collected coin credits the wallet")
	_check_eq(world.score_hud.label_text("coins"), "COINS  1",
		"the HUD counter follows the run tally, not the wallet")
	_check_eq(world.score_system.score, score_before, "coins never touch the score")
	_check_eq(world.score_system.item_count, items_before, "coins never touch the item count")
	_check_eq(world.score_system.chain, chain_before, "coins never build the combo")
	world._on_item_collected(GameConfig.ItemKind.PENCIL)
	_check_eq(world.score_system.item_count, items_before + 1,
		"school items still count through the score system")
	var chain_after_item := world.score_system.chain
	world._on_item_collected(GameConfig.ItemKind.COIN)
	_check_eq(world.score_system.chain, chain_after_item,
		"coins do not extend a live combo")
	_check_eq(GameState.coins, 55 + 2 * GameConfig.COIN_VALUE,
		"every collected coin reaches the wallet")
	_check_eq(world.coins_collected, 2, "the run tallies its own coins")
	_check_eq(world.score_hud.label_text("coins"), "COINS  2",
		"the HUD counter tracks every coin of the run")

	# The results card reports the run's coin tally.
	world.results.show_results(
		ResultsScreen.Outcome.CAUGHT, 100, 10, "HOME", 2,
		GameConfig.Medal.BLACK, world.coins_collected)
	_check_eq(world.results.stat_text("coins"), "2",
		"the results card shows the coins earned this run")
	_check(world.results.stat_text("items") == "2",
		"the items stat is unaffected by coins")
	world.results.visible = false
	wallet_root.queue_free()

	# A run with no coins reports zero on the card.
	var empty_root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(empty_root)
	var empty_world := empty_root.get_node("RunWorld") as RunWorld
	empty_world.results.show_results(
		ResultsScreen.Outcome.CAUGHT, 50, 5, "HOME", 0, GameConfig.Medal.BLACK, 0)
	_check_eq(empty_world.results.stat_text("coins"), "0",
		"a coinless run shows zero coins earned")
	empty_root.queue_free()

	# --- HUD coin readout renders whatever the run pushes ---------------------
	var hud_scene := load("res://scenes/hud.tscn") as PackedScene
	var hud_root := hud_scene.instantiate()
	add_child(hud_root)
	var hud_score := hud_root.get_node("HudRoot/Score") as ScoreHud
	hud_score.set_coins(5)
	_check_eq(hud_score.label_text("coins"), "COINS  5",
		"the coin readout renders the pushed run tally")
	_check_eq(hud_score.label_font("coins").resource_path,
		ScoreHud.SUB_FONT_PATH,
		"the coin readout uses the shared HUD font")
	hud_root.queue_free()

	# Restore the player's real save target and balance.
	GameState.save_path = pre_save_path
	GameState.coins = pre_coins


func _test_shop() -> void:
	# --- Config contract: table, art, cost curve ------------------------------
	for kind: int in GameConfig.SHOP_UPGRADES:
		var data: Dictionary = GameConfig.SHOP_UPGRADES[kind]
		_check(String(data["name"]).length() > 0, "upgrade %d has a name" % kind)
		_check(int(data["max_level"]) >= 1, "upgrade %d has a level cap" % kind)
		_check(float(data["cost_growth"]) > 1.0, "upgrade %d grows in cost" % kind)
		_check_eq(GameConfig.shop_cost(kind, 0), int(data["base_cost"]),
			"level 1 of upgrade %d costs the base" % kind)
		var last := int(data["base_cost"])
		for level in range(1, int(data["max_level"])):
			var cost := GameConfig.shop_cost(kind, level)
			_check(cost > last, "upgrade %d cost rises with level" % kind)
			last = cost
	for path: String in [
		"res://assets/icon/upgrades/speed.png",
		"res://assets/icon/upgrades/luck.png",
		"res://assets/icon/upgrades/jump.png",
		"res://assets/icon/upgrades/heart.png",
		"res://assets/icon/upgrades/shield.png",
	]:
		_check(ResourceLoader.exists(path), "shop icon exists: %s" % path)

	# --- Effect math: all five upgrades ---------------------------------------
	_check_near(GameConfig.shop_speed_multiplier(0), 1.0, 0.0001, "speed level 0 is stock")
	_check_near(GameConfig.shop_speed_multiplier(5), 1.15, 0.0001, "speed level 5 is +15%")
	_check_near(GameConfig.shop_luck_gap_factor(0), 1.0, 0.0001, "luck level 0 is stock")
	_check(GameConfig.shop_luck_gap_factor(5) < GameConfig.shop_luck_gap_factor(1),
		"luck densifies with level")
	_check_near(GameConfig.shop_jump_speed(2),
		GameConfig.JUMP_SPEED * sqrt(1.16), 0.0001, "jump launch speed scales with level")
	_check(GameConfig.shop_jump_speed(5) > GameConfig.JUMP_SPEED, "jump level 5 jumps higher")
	_check_eq(GameConfig.shop_max_hearts(0), GameConfig.MAX_HEARTS, "hearts level 0 is stock")
	_check_eq(GameConfig.shop_max_hearts(3), GameConfig.MAX_HEARTS + 3, "hearts add one each")
	_check_eq(GameConfig.shop_shield_charges(2), 2, "shield level 2 grants two charges")
	_check(GameConfig.shop_jump_speed(2) > GameConfig.shop_jump_speed(0),
		"jump upgrades exceed the base launch")

	# --- Buying: deduction, persistence, caps, rejections ---------------------
	var scratch := "user://test_shop_scratch.cfg"
	var pre_save_path := GameState.save_path
	var pre_coins := GameState.coins
	var pre_levels: Dictionary = GameState.shop_levels.duplicate()
	GameState.save_path = scratch
	GameState.coins = 1000
	GameState.shop_levels = {}
	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	var shop_events: Array[int] = []
	GameState.coins_changed.connect(func(count: int) -> void: shop_events.append(count))

	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.SPEED), 0,
		"an unbought upgrade reads level 0")
	_check(GameState.buy_upgrade(GameConfig.ShopUpgrade.SPEED), "an affordable buy succeeds")
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.SPEED), 1, "the buy raises the level")
	_check_eq(GameState.coins, 1000 - GameConfig.SHOP_UPGRADES[GameConfig.ShopUpgrade.SPEED]["base_cost"],
		"the buy deducts the price from the wallet")
	_check_eq(shop_events.size(), 1, "the wallet signal fires on a purchase")
	_check(FileAccess.file_exists(scratch), "the purchase writes through to disk")

	GameState.coins = 0
	_check(not GameState.buy_upgrade(GameConfig.ShopUpgrade.JUMP),
		"an unaffordable buy is rejected")
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.JUMP), 0,
		"a rejected buy leaves the level untouched")
	_check_eq(GameState.coins, 0, "a rejected buy never charges the wallet")

	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = 2
	_check(not GameState.buy_upgrade(GameConfig.ShopUpgrade.SHIELD),
		"a maxed upgrade cannot be bought again")
	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = 0
	_check(not GameState.buy_upgrade(999), "an unknown upgrade is rejected")

	# Round trip: levels survive a reload, and the save carries a version.
	GameState.coins = 500
	GameState.shop_levels[GameConfig.ShopUpgrade.HEARTS] = 2
	GameState._save_wallet()
	GameState.coins = 0
	GameState.shop_levels = {}
	GameState._load_wallet()
	_check_eq(GameState.coins, 500, "a restart reloads the wallet")
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.HEARTS), 2,
		"bought levels survive a restart")
	var saved := ConfigFile.new()
	_check_eq(saved.load(scratch), OK, "the scratch save parses")
	_check_eq(int(saved.get_value(GameState.SAVE_SECTION_META, GameState.SAVE_KEY_VERSION, 0)),
		GameState.SAVE_VERSION, "the save file carries its version")

	# Out-of-range stored levels clamp on load.
	GameState.shop_levels = {}
	GameState._save_wallet()
	GameState.coins = 0
	var tampered := FileAccess.open(scratch + ".tmp", FileAccess.WRITE)
	tampered.close()
	var hacked := ConfigFile.new()
	hacked.load(scratch)
	hacked.set_value(GameState.SAVE_SECTION_SHOP, str(GameConfig.ShopUpgrade.HEARTS), 9)
	hacked.save(scratch)
	GameState.shop_levels = {}
	GameState._load_wallet()
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.HEARTS),
		int(GameConfig.SHOP_UPGRADES[GameConfig.ShopUpgrade.HEARTS]["max_level"]),
		"an over leveled save clamps to the cap")

	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	# --- Player: shield absorbs, hearts pool, jump upgrade --------------------
	GameState.coins = 0
	GameState.shop_levels = {
		GameConfig.ShopUpgrade.SHIELD: 2,
	}
	var shield_scene := load("res://scenes/player.tscn") as PackedScene
	var shielded := shield_scene.instantiate() as Player
	add_child(shielded)
	shielded.set_physics_process(false)
	var shield_events: Array[int] = []
	shielded.shield_changed.connect(func(current: int, maximum: int) -> void: shield_events.append(current))
	var shield_hits: Array[int] = []
	shielded.damaged.connect(func(remaining: int) -> void: shield_hits.append(remaining))

	_check_eq(shielded.shield_max, 2, "the shield level grants two charges")
	_check_eq(shielded.shield_charges, 2, "a fresh run starts with full charges")
	_check(not shielded.take_damage(), "the first hit is absorbed")
	_check_eq(shielded.shield_charges, 1, "one charge is spent")
	_check_eq(shielded.health, GameConfig.MAX_HEARTS, "an absorbed hit costs no heart")
	_check_eq(shield_hits.size(), 0, "an absorbed hit never emits damaged")
	_check_eq(shield_events.size(), 1, "the shield signal fires per absorb")
	_check_eq(shielded.hurt_play_count, 0, "an absorbed hit stays silent")
	_check_near(shielded.invulnerable_time_left, GameConfig.I_FRAME_TIME, 0.001,
		"an absorb still grants i-frames")
	_check(not shielded.take_damage(), "a hit inside the post-absorb i-frames is ignored")
	for i in int(ceil(GameConfig.I_FRAME_TIME * 60.0)) + 2:
		shielded._physics_process(1.0 / 60.0)
	_check(not shielded.take_damage(), "the second hit is absorbed")
	_check_eq(shielded.shield_charges, 0, "both charges are spent")
	for i in int(ceil(GameConfig.I_FRAME_TIME * 60.0)) + 2:
		shielded._physics_process(1.0 / 60.0)
	_check(shielded.take_damage(), "a hit with no charges lands")
	_check_eq(shielded.health, GameConfig.MAX_HEARTS - 1, "a landed hit costs a heart")
	_check_eq(shielded.hurt_play_count, 1, "a landed hit plays the hurt sound")
	shielded.reset_health()
	_check_eq(shielded.shield_charges, 2, "reset refills the shields")
	shielded.queue_free()

	GameState.shop_levels = { GameConfig.ShopUpgrade.HEARTS: 2 }
	var tank := shield_scene.instantiate() as Player
	add_child(tank)
	tank.set_physics_process(false)
	_check_eq(tank.max_health, GameConfig.MAX_HEARTS + 2, "the hearts level extends the pool")
	_check_eq(tank.health, GameConfig.MAX_HEARTS + 2, "a fresh run starts with the full pool")
	tank.queue_free()

	GameState.shop_levels = { GameConfig.ShopUpgrade.JUMP: 2 }
	var jumper := shield_scene.instantiate() as Player
	add_child(jumper)
	jumper.set_physics_process(false)
	jumper.jump()
	_check_near(jumper.vertical_speed, GameConfig.shop_jump_speed(2), 0.0001,
		"the jump upgrade scales the launch speed")
	jumper.queue_free()

	# Restore defaults before any later tests instantiate players again.
	GameState.shop_levels = pre_levels
	GameState.coins = pre_coins
	GameState.save_path = pre_save_path
	GameState.coins_changed.emit(GameState.coins)

	# --- Spawn director: luck densifies both item clocks ----------------------
	GameState.shop_levels = { GameConfig.ShopUpgrade.LUCK: 3 }
	var container := Node2D.new()
	add_child(container)
	var director := SpawnDirector.new()
	add_child(director)
	director.setup(container, 11)
	_check_near(director._luck_gap_factor, pow(0.92, 3), 0.0001,
		"the director reads the luck factor")
	_check(director._pickup_gap <= GameConfig.PICKUP_GAP_MAX * director._luck_gap_factor,
		"the pickup gap shrinks with luck")
	_check(director._next_coin_run_gap
		<= GameConfig.COIN_RUN_GAP_MAX * director._luck_gap_factor,
		"the coin-run gap shrinks with luck")
	director.queue_free()
	container.queue_free()
	GameState.shop_levels = pre_levels
	GameState.coins = pre_coins
	GameState.save_path = pre_save_path

	# --- Run world: speed multiplies the base, not the ramp -------------------
	GameState.shop_levels = { GameConfig.ShopUpgrade.SPEED: 2 }
	var speed_root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(speed_root)
	var speed_world := speed_root.get_node("RunWorld") as RunWorld
	speed_world.set_physics_process(false)
	_check_near(speed_world._base_speed(),
		GameConfig.RUN_SPEED * GameConfig.shop_speed_multiplier(2), 0.0001,
		"the speed upgrade multiplies the campaign base speed")
	speed_world.distance = speed_world.campaign_finish_distance * 0.5
	_check_near(speed_world._base_speed(),
		GameConfig.RUN_SPEED * GameConfig.campaign_speed_multiplier(
			speed_world.distance, speed_world.campaign_finish_distance)
		* GameConfig.shop_speed_multiplier(2), 0.0001,
		"the campaign ramp stacks with the speed upgrade")
	speed_world.queue_free()
	GameState.shop_levels = pre_levels
	GameState.coins = pre_coins
	GameState.save_path = pre_save_path

	# --- HUD: shield pips live on their own movable panel below the hearts ----
	var hud_scene := load("res://scenes/hud.tscn") as PackedScene
	var hud_root := hud_scene.instantiate()
	add_child(hud_root)
	var hud := hud_root.get_node("HudRoot/Hearts") as HeartsHud
	var shield_panel := hud.get_node("ShieldPanel") as PanelContainer
	_check(shield_panel != null, "the shield has its own panel")
	_check(shield_panel.get_parent() == hud.get_node("Panel").get_parent(),
		"the shield panel is a sibling of the hearts panel, not a child")
	_check(shield_panel.position.y > hud.get_node("Panel").position.y,
		"the shield panel sits below the hearts panel")
	_check(not shield_panel.visible, "the shield panel hides when nothing is bought")
	hud.set_shields(2, 2)
	_check(shield_panel.visible, "the shield panel appears when charges exist")
	_check_eq(hud.shield_count(), 2, "two bought charges show two pips")
	hud.set_shields(1, 2)
	_check_eq(hud.shield_count(), 1, "a spent pip disappears entirely")
	hud.set_shields(0, 2)
	_check_eq(hud.shield_count(), 0, "the last spent pip disappears too")
	_check(not shield_panel.visible,
		"the shield panel disappears once every charge is spent")
	# A refill (e.g. reset_health) brings the panel back automatically.
	hud.set_shields(2, 2)
	_check(shield_panel.visible, "a refill brings the shield panel back")
	_check_eq(hud.shield_count(), 2, "a refill restores both pips")
	hud.set_shields(0, 0)
	_check(not shield_panel.visible,
		"the shield panel collapses when the upgrade is not bought")
	var row := hud.get_node("Panel/Row") as HBoxContainer
	var shield_row := hud.get_node("ShieldPanel/ShieldRow") as HBoxContainer
	_check(shield_row.get_parent() == shield_panel,
		"the shield row belongs to the shield panel")
	_check(row.get_parent() == hud.get_node("Panel"),
		"the hearts row belongs to the hearts panel")
	hud.set_shields(2, 2)
	var shield_row_node := hud.get_node("ShieldPanel/ShieldRow")
	_check_eq((shield_row_node as HBoxContainer).alignment,
		BoxContainer.ALIGNMENT_BEGIN, "shield pips left-align inside the panel")
	if shield_row_node.get_child_count() > 0:
		var pip := shield_row_node.get_child(0) as TextureRect
		if pip != null:
			_check_eq(pip.custom_minimum_size, Vector2(44, 44),
				"shield pips render at heart size (44 px)")
	hud_root.queue_free()

	# --- HUD: the real run wiring updates the shield pips on absorb ----------
	# Regression guard for the signal mismatch: shield_changed used to emit one
	# argument while set_shields takes two, so pips never vanished mid-run.
	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = 2
	var run_scene := load("res://scenes/main.tscn") as PackedScene
	var run_root := run_scene.instantiate()
	add_child(run_root)
	var run_player := run_root.get_node("RunWorld/Player") as Player
	var run_hud := run_root.get_node("RunWorld/Hud/HudRoot/Hearts") as HeartsHud
	_check(run_player != null, "the run scene has a player")
	_check(run_hud != null, "the run scene has a hearts HUD")
	if run_player != null and run_hud != null:
		run_player.set_physics_process(false)
		_check_eq(run_hud.shield_count(), 2, "a run with shields starts at two pips")
		run_player.take_damage()
		_check_eq(run_hud.shield_count(), 1, "an absorbed hit removes one pip live")
		for i in int(ceil(GameConfig.I_FRAME_TIME * 60.0)) + 2:
			run_player._physics_process(1.0 / 60.0)
		run_player.take_damage()
		_check_eq(run_hud.shield_count(), 0, "the second absorb removes the last pip")
		_check(not (run_hud.get_node("ShieldPanel") as Control).visible,
			"the panel disappears when the last charge is spent")
	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = 0
	run_root.queue_free()

	# --- Panel: cards, disabled states, focus, close --------------------------
	GameState.coins = 500
	var panel_scene := load("res://scenes/shop_panel.tscn") as PackedScene
	var panel := panel_scene.instantiate() as ShopPanel
	add_child(panel)
	_check(panel != null, "the shop panel instantiates")
	_check_eq((panel.grid as GridContainer).get_child_count(), 5,
		"the store lists one card per upgrade")
	_check(not panel.visible, "the store starts hidden")
	panel.open()
	_check(panel.visible, "open() shows the store")
	_check_eq(panel.wallet_label.text, "500", "the wallet chip shows the balance")
	var buy_button: Button = panel._cards[GameConfig.ShopUpgrade.HEARTS]["buy"]
	_check(not buy_button.disabled, "an affordable card's buy button is enabled")
	_check_eq(buy_button.text, "BUY  %d" % GameConfig.shop_cost(
		GameConfig.ShopUpgrade.HEARTS, 0), "the buy button shows the next price")

	# Icon sizing: the upgrade art is authored at 267-332 px, so it is drawn
	# downscaled and needs linear filtering. 64 px is the largest card icon that
	# still keeps the whole store inside the 1080 design viewport.
	var fit_panel := panel_scene.instantiate() as ShopPanel
	var fit_frame := Control.new()
	fit_frame.custom_minimum_size = Vector2(1920.0, 1080.0)
	add_child(fit_frame)
	fit_frame.add_child(fit_panel)
	var card_icon := (
		fit_panel._cards[GameConfig.ShopUpgrade.SPEED]["card"].get_child(0)
		as VBoxContainer).get_child(0) as TextureRect
	_check_near(card_icon.custom_minimum_size.x, ShopPanel.CARD_ICON_SIZE,
		0.001, "cards draw the upgrade icon at 64 px")
	_check_eq(card_icon.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR,
		"card icons use linear filtering for the downscale")
	var coin_icon := fit_panel.wallet_chip.get_child(0) as TextureRect
	_check_near(coin_icon.custom_minimum_size.x, ShopPanel.WALLET_ICON_SIZE,
		0.001, "the wallet coin matches the new icon scale")
	_check_eq(coin_icon.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR,
		"the wallet coin uses linear filtering")
	var store_height := fit_panel.get_combined_minimum_size().y
	_check(store_height <= 1080.0,
		"the store's natural height fits the 1080 design viewport (%.0f px)"
		% store_height)
	fit_frame.queue_free()

	# Purchase audio: one clip per completed buy, on the SFX bus, silent when
	# the purchase is rejected (unaffordable or already maxed). A buy that
	# finishes the track plays the fanfare INSTEAD of the chime. This section
	# owns the levels it touches: _test_shop restores a snapshot dict by
	# reference, so a stray level here would follow every later section.
	var hearts_before := GameState.shop_level(GameConfig.ShopUpgrade.HEARTS)
	var shield_before := GameState.shop_level(GameConfig.ShopUpgrade.SHIELD)
	var coins_before := GameState.coins
	_check(panel.upgrade_sfx != null, "the store carries an upgrade sound player")
	_check_eq(panel.upgrade_sfx.bus, "SFX", "the upgrade sound routes to the SFX bus")
	_check(panel.upgrade_sfx.stream != null, "the upgrade sound has a stream")
	_check(
		panel.upgrade_sfx.stream.resource_path.contains("upgradesound"),
		"the store chimes with the upgrade sound",
	)
	_check(panel.max_upgrade_sfx != null, "the store carries a max-upgrade fanfare")
	_check_eq(panel.max_upgrade_sfx.bus, "SFX",
		"the max-upgrade fanfare routes to the SFX bus")
	_check(panel.max_upgrade_sfx.stream != null,
		"the max-upgrade fanfare has a stream")
	_check(
		panel.max_upgrade_sfx.stream.resource_path.contains("maxupgrade"),
		"finishing a track uses the committed fanfare",
	)
	_check(panel.max_upgrade_sfx.stream != panel.upgrade_sfx.stream,
		"the fanfare and the chime are different clips")
	_check(panel.max_upgrade_sfx.volume_db > panel.upgrade_sfx.volume_db,
		"the fanfare is mixed louder than the purchase chime")

	# Max-upgrade FX contract: one shared burst, ring and stamp, all cold/hidden
	# until a finishing purchase fires them.
	_check(panel.max_burst != null, "the store carries a max-upgrade star burst")
	_check(panel.max_burst.one_shot, "the star burst fires once per celebration")
	_check(panel.max_burst.texture != null, "the star burst has a spark texture")
	_check(
		panel.max_burst.texture.resource_path.contains("spark_star"),
		"the star burst uses the committed spark art",
	)
	_check(panel.max_burst.amount >= 12, "the star burst has a full spray")
	_check_eq(panel.max_burst.z_index, 2, "the star burst draws above the card")
	_check(not panel.max_burst.emitting, "the star burst idles cold")
	_check(panel.max_ring != null, "the store carries a shockwave ring")
	_check_eq(panel.max_ring.points.size(), ShopPanel.RING_POINTS,
		"the ring is a full circle")
	_check(panel.max_ring.closed, "the ring closes its loop")
	_check_eq(panel.max_ring.z_index, 2, "the ring draws above the card")
	_check(not panel.max_ring.visible, "the shockwave ring hides at rest")
	_check(panel.max_stamp != null, "the store carries a MAX! stamp")
	_check_eq(panel.max_stamp.text, "MAX!", "the stamp reads MAX!")
	_check_eq(panel.max_stamp.z_index, 3, "the stamp draws above every other layer")
	_check(not panel.max_stamp.visible, "the MAX! stamp hides at rest")
	_check_eq(panel.max_burst_count, 0, "nothing celebrates before a purchase")
	_check_eq(panel.upgrade_play_count, 0, "the store is silent before any purchase")
	_check_eq(panel.max_upgrade_play_count, 0,
		"the store never fanfares before any purchase")

	# Mid-track purchase: the chime, never the fanfare.
	GameState.shop_levels[GameConfig.ShopUpgrade.HEARTS] = 0
	GameState.coins = 1000
	panel._on_buy_pressed(GameConfig.ShopUpgrade.HEARTS)
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.HEARTS), 1,
		"a mid-track purchase raises one level")
	_check_eq(panel.upgrade_play_count, 1, "a completed purchase plays the chime")
	_check_eq(panel.max_upgrade_play_count, 0,
		"a mid-track purchase does not fanfare")
	_check_eq(panel.max_burst_count, 0,
		"a mid-track purchase fires no celebration")
	_check(not panel.max_ring.visible, "a mid-track purchase shows no ring")
	_check(not panel.max_stamp.visible, "a mid-track purchase shows no stamp")

	# The purchase that finishes a track: the fanfare replaces the chime.
	GameState.shop_levels[GameConfig.ShopUpgrade.HEARTS] = 2
	GameState.coins = 1000
	panel._on_buy_pressed(GameConfig.ShopUpgrade.HEARTS)
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.HEARTS), 3,
		"the final purchase reaches the cap")
	_check_eq(panel.max_upgrade_play_count, 1,
		"finishing a track plays the fanfare")
	_check(panel.max_upgrade_sfx.playing, "the fanfare actually plays")
	_check_eq(panel.upgrade_play_count, 1, "the fanfare replaces the chime")
	_check_eq(panel.max_burst_count, 1,
		"finishing a track fires the celebration")
	_check(panel.max_burst.emitting, "the star burst is emitting")
	_check(panel.max_ring.visible, "the shockwave ring shows")
	_check(panel.max_ring.modulate.a > 0.0, "the ring starts opaque")
	_check(panel.max_stamp.visible, "the MAX! stamp shows")
	_check(panel.max_stamp.modulate.a > 0.0, "the stamp starts opaque")
	_check(panel.max_stamp.scale.x > 1.0,
		"the stamp pops in oversized before settling")
	_check_eq(panel.max_stamp.get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"the stamp uses the store's ExtraBold face")

	# Rejected buys stay silent on both channels.
	GameState.coins = 1000
	panel._on_buy_pressed(GameConfig.ShopUpgrade.HEARTS)
	_check_eq(panel.max_upgrade_play_count, 1,
		"a maxed card does not fanfare again")
	_check_eq(panel.upgrade_play_count, 1, "a maxed card does not chime")
	_check_eq(panel.max_burst_count, 1, "a maxed card does not re-celebrate")
	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = 2
	panel._on_buy_pressed(GameConfig.ShopUpgrade.SHIELD)
	_check_eq(panel.max_upgrade_play_count, 1,
		"every maxed card stays silent")
	_check_eq(panel.upgrade_play_count, 1, "every maxed card stays silent")
	GameState.shop_levels[GameConfig.ShopUpgrade.HEARTS] = hearts_before
	GameState.shop_levels[GameConfig.ShopUpgrade.SHIELD] = shield_before
	GameState.coins = coins_before

	# Card labels use the game's Nunito fonts, not the engine default.
	var card: Dictionary = panel._cards[GameConfig.ShopUpgrade.HEARTS]
	_check_eq((card["name"] as Label).get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"card names use Nunito ExtraBold")
	_check_eq((card["desc"] as Label).get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-SemiBold.ttf",
		"card descriptions use Nunito SemiBold")
	_check_eq((card["buy"] as Button).get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"buy buttons use Nunito ExtraBold")
	panel.close()
	_check(not panel.visible, "close() hides the store")

	GameState.coins = 0
	GameState.shop_levels = { GameConfig.ShopUpgrade.SHIELD: 2 }
	panel._refresh()
	var maxed: Button = panel._cards[GameConfig.ShopUpgrade.SHIELD]["buy"]
	_check(maxed.disabled and maxed.text == "MAX", "a maxed card reads MAX and is disabled")
	var broke: Button = panel._cards[GameConfig.ShopUpgrade.SPEED]["buy"]
	_check(broke.disabled, "an unaffordable card's buy button is disabled")
	panel._focus_first_buy()
	_check_eq(panel.close_button, get_viewport().gui_get_focus_owner(),
		"a broke player's focus lands on CLOSE")
	panel.queue_free()
	GameState.shop_levels = pre_levels
	GameState.coins = pre_coins
	GameState.save_path = pre_save_path


func _test_debug_tools() -> void:
	# The cheats live in one deletable autoload; verify its behavior on a
	# scratch save so the player's real progress is never touched.
	_check(DebugTools != null, "the debug autoload is present")
	_check(DebugTools.can_process(), "the debug autoload listens in debug builds")

	var scratch := "user://test_debug_scratch.cfg"
	var pre_save_path := GameState.save_path
	var pre_coins := GameState.coins
	var pre_levels: Dictionary = GameState.shop_levels.duplicate()
	GameState.save_path = scratch
	GameState.coins = 99
	GameState.shop_levels = { GameConfig.ShopUpgrade.SPEED: 2 }
	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)

	var cheat_events: Array[int] = []
	GameState.coins_changed.connect(func(count: int) -> void: cheat_events.append(count))

	# F9: wallet zero, upgrades kept, write-through to disk.
	DebugTools.zero_wallet()
	_check_eq(GameState.coins, 0, "zero_wallet empties the wallet")
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.SPEED), 2,
		"zero_wallet keeps bought upgrades")
	_check_eq(cheat_events.size(), 1, "zero_wallet announces the new balance")
	_check(FileAccess.file_exists(scratch), "zero_wallet writes through to disk")
	var saved := ConfigFile.new()
	_check_eq(saved.load(scratch), OK, "the cheat save parses")
	_check_eq(int(saved.get_value(GameState.SAVE_SECTION_WALLET, GameState.SAVE_KEY_COINS, -1)),
		0, "the reset balance persists on disk")

	# Shift+F9: everything back to zero, levels persist as zero too.
	DebugTools.wipe_progress()
	_check_eq(GameState.coins, 0, "wipe_progress empties the wallet")
	_check_eq(GameState.shop_level(GameConfig.ShopUpgrade.SPEED), 0,
		"wipe_progress resets bought upgrades")
	_check_eq(cheat_events.size(), 2, "wipe_progress announces the new balance")
	_check_eq(saved.load(scratch), OK, "the wiped save parses")
	_check_eq(int(saved.get_value(GameState.SAVE_SECTION_SHOP, str(GameConfig.ShopUpgrade.SPEED), -1)),
		0, "the wiped upgrade level persists on disk")

	for suffix: String in ["", ".tmp", ".bak"]:
		var stale := scratch + suffix
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	GameState.save_path = pre_save_path
	GameState.coins = pre_coins
	GameState.shop_levels = pre_levels


func _test_pursuer() -> void:
	# Config contract.
	_check_near(GameConfig.PURSUER_CHASE_FACTOR, 0.97, 0.001, "chase factor is 97%")
	_check_near(
		GameConfig.RUN_SPEED * GameConfig.PURSUER_CHASE_FACTOR,
		407.4,
		0.01,
		"chase speed is 407.4 px/s at base",
	)
	_check_near(GameConfig.MOMENTUM_DIP_TIME, 1.0, 0.001, "momentum dip lasts 1.0 s")
	_check_near(GameConfig.PURSUER_CATCH_DISTANCE, 60.0, 0.01, "catch distance is 60 px")

	# Scene + frames.
	var scene := load("res://scenes/pursuer.tscn") as PackedScene
	_check(scene != null, "pursuer scene loads")
	if scene == null:
		return
	var pursuer := scene.instantiate() as Pursuer
	add_child(pursuer)
	pursuer.set_physics_process(false)
	_check(pursuer.state == Pursuer.State.DORMANT, "pursuer starts dormant")
	_check(not pursuer.visible, "pursuer is hidden while dormant")
	_check(not pursuer.is_active(), "dormant pursuer is not active")
	_check_near(pursuer.gap, GameConfig.PURSUER_DORMANT_GAP, 0.01, "dormant gap is off-screen left")
	var frames := pursuer.sprite.sprite_frames
	_check(frames != null, "pursuer scene provides sprite frames")
	if frames != null:
		_check(frames.resource_path.ends_with("tanod_frames.tres"), "tanod frames come from committed resource")
		_check_eq(frames.get_animation_names().size(), 3, "three tanod animations exist")
		_check_eq(frames.get_frame_count("run"), 10, "tanod run has 10 frames")
		_check_eq(frames.get_frame_count("idle"), 1, "tanod idle has 1 frame")
		_check_eq(frames.get_frame_count("arrest"), 5, "arrest has 5 frames")
		_check(not frames.get_animation_loop("arrest"), "arrest does not loop")
		# Every arrest frame shares one cell size, and that height is the value
		# `_play_arrest()` uses to sit the grab on the lane line. If new art
		# ships at another size without updating the constant, the pair floats.
		var arrest_size := Vector2.ZERO
		var arrest_sizes_match := true
		for i in frames.get_frame_count("arrest"):
			var texture := frames.get_frame_texture("arrest", i)
			if texture == null:
				arrest_sizes_match = false
				continue
			if i == 0:
				arrest_size = texture.get_size()
			elif texture.get_size() != arrest_size:
				arrest_sizes_match = false
		_check(arrest_sizes_match, "every arrest frame is the same size")
		_check_near(
			arrest_size.y,
			GameConfig.ARREST_SPRITE_HEIGHT,
			0.01,
			"the arrest anchor height matches the art",
		)
	_check_eq(pursuer.sprite.animation, &"idle", "tanod previews the idle animation")

	# Wake.
	var wakes := [0]
	pursuer.chase_started.connect(func() -> void: wakes[0] += 1)
	pursuer.wake()
	_check(pursuer.state == Pursuer.State.CHASE, "wake enters chase")
	_check(pursuer.visible, "pursuer becomes visible on wake")
	_check(pursuer.is_active(), "chasing pursuer is active")
	_check_near(pursuer.gap, GameConfig.PURSUER_WAKE_GAP, 0.01,
		"wake gap uses the tuned chase distance")
	_check_eq(wakes[0], 1, "chase_started fires once")
	pursuer.wake()
	_check_eq(wakes[0], 1, "wake during chase is a no-op")
	_check_near(pursuer.gap, GameConfig.PURSUER_WAKE_GAP, 0.01, "wake during chase does not reset gap")

	# Gap dynamics: full speed grows the gap (escape), dip shrinks it (pressure).
	# Both expectations are derived from the tuned factor so retuning the chase
	# cannot silently leave stale magic numbers in the suite.
	pursuer.set_world_speed(GameConfig.RUN_SPEED)
	var gap_before := pursuer.gap
	var escape_delta := 1.0
	var escape_factor := lerpf(GameConfig.PURSUER_CHASE_FACTOR, 1.0, clampf(
		(pursuer.chase_time + escape_delta) / GameConfig.PURSUER_CHASE_RAMP_TIME, 0.0, 1.0))
	pursuer._physics_process(escape_delta)
	_check(pursuer.gap > gap_before, "full speed pulls away from the tanod")
	_check_near(pursuer.gap - gap_before,
		GameConfig.RUN_SPEED * (1.0 - escape_factor) * escape_delta, 0.01,
		"full speed grows the gap by the tuned fraction")

	pursuer.set_world_speed(GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR)
	gap_before = pursuer.gap
	var dip_delta := 1.0
	var dip_factor := lerpf(GameConfig.PURSUER_CHASE_FACTOR, 1.0, clampf(
		(pursuer.chase_time + dip_delta) / GameConfig.PURSUER_CHASE_RAMP_TIME, 0.0, 1.0))
	var dip_world := GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR
	pursuer._physics_process(dip_delta)
	_check(pursuer.gap < gap_before, "momentum dip lets the tanod gain")
	_check_near(pursuer.gap - gap_before,
		dip_world - maxf(dip_world, GameConfig.RUN_SPEED) * dip_factor, 0.01,
		"momentum dip closes the gap at the tuned rate")

	# Fade after surviving the chase.
	var fades := [0]
	pursuer.chase_faded.connect(func() -> void: fades[0] += 1)
	pursuer.chase_time = GameConfig.PURSUER_FADE_AFTER - 0.1
	pursuer.set_world_speed(GameConfig.RUN_SPEED)
	pursuer._physics_process(0.2)
	_check(pursuer.state == Pursuer.State.FADE, "surviving the chase enters fade")
	_check_eq(fades[0], 1, "chase_faded fires once")
	_check(not pursuer.is_active(), "fading pursuer is not active")
	pursuer._physics_process(GameConfig.PURSUER_FADE_TIME + 0.1)
	_check(pursuer.state == Pursuer.State.DORMANT, "fade returns to dormant")
	_check(not pursuer.visible, "pursuer hides again when dormant")

	# Endless ramp: the tanod tracks the faster of world speed and base speed.
	# A fresh instance keeps these checks independent of the counters above.
	var chaser := scene.instantiate() as Pursuer
	add_child(chaser)
	chaser.set_physics_process(false)
	chaser.wake()
	chaser.chase_time = 0.0
	chaser.set_world_speed(GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR)
	var slow_gap := chaser.gap
	chaser._physics_process(1.0)
	_check(chaser.gap < slow_gap, "a slowdown below base still lets the tanod gain")

	chaser.chase_time = GameConfig.PURSUER_CHASE_RAMP_TIME
	chaser.set_world_speed(GameConfig.RUN_SPEED * GameConfig.ENDLESS_RAMP_MAX_MULTIPLIER)
	var ramp_gap := chaser.gap
	chaser._physics_process(1.0)
	_check_near(chaser.gap, ramp_gap, 0.01, "at full endless ramp the tanod keeps pace")
	chaser.queue_free()

	# Catch by gap closing.
	pursuer.wake()
	var catches := [0]
	pursuer.caught.connect(func() -> void: catches[0] += 1)
	pursuer.gap = GameConfig.PURSUER_CATCH_DISTANCE - 10.0
	pursuer.set_world_speed(GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR)
	pursuer._physics_process(0.5)
	_check_eq(catches[0], 1, "catch fires when the gap closes")
	_check(pursuer.state == Pursuer.State.LUNGE, "catch enters the lunge death animation")
	pursuer._process(GameConfig.PURSUER_LUNGE_TIME + 0.1)
	_check_near(pursuer.gap, 0.0, 0.01, "lunge closes the gap to the player")

	# Lunge from a hazard hit (world freezes, lunge still runs in _process).
	var lunger := scene.instantiate() as Pursuer
	add_child(lunger)
	lunger.set_physics_process(false)
	var lunges := [0]
	lunger.lunge_finished.connect(func() -> void: lunges[0] += 1)
	lunger.wake()
	lunger.start_lunge()
	_check(lunger.state == Pursuer.State.LUNGE, "hazard hit starts the lunge")
	_check(lunger.is_active(), "lunging pursuer is active")
	lunger._process(GameConfig.PURSUER_LUNGE_TIME + 0.1)
	_check_eq(lunges[0], 1, "lunge_finished fires after the death animation")
	lunger.queue_free()

	# Player: hazard while active is instant loss, hearts and i-frames ignored.
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var damaged_count := [0]
	var caught_count := [0]
	var died_count := [0]
	player.damaged.connect(func(_remaining: int) -> void: damaged_count[0] += 1)
	player.caught.connect(func() -> void: caught_count[0] += 1)
	player.died.connect(func() -> void: died_count[0] += 1)

	var live := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	add_child(live)
	live.set_physics_process(false)
	live.setup(GameConfig.HazardKind.MANHOLE, player.lane, 0.0)
	live.position.x = GameConfig.PLAYER_X

	player.pursuer_active = true
	player.invulnerable_time_left = 1.0  # i-frames must not save the player
	await _physics_frames(4)
	_check_eq(caught_count[0], 1, "hazard while chased emits caught")
	_check_eq(died_count[0], 1, "hazard while chased emits died")
	_check_eq(damaged_count[0], 0, "hazard while chased never emits damaged")
	_check_eq(player.health, GameConfig.MAX_HEARTS, "hazard while chased loses no hearts")

	player.reset_health()
	caught_count[0] = 0
	died_count[0] = 0
	damaged_count[0] = 0
	player.invulnerable_time_left = 0.0
	player.pursuer_active = false
	var live2 := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	add_child(live2)
	live2.set_physics_process(false)
	live2.setup(GameConfig.HazardKind.MANHOLE, player.lane, 0.0)
	live2.position.x = GameConfig.PLAYER_X
	await _physics_frames(4)
	_check_eq(damaged_count[0], 1, "hazard while dormant emits damaged")
	_check_eq(caught_count[0], 0, "hazard while dormant never emits caught")
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "hazard while dormant loses one heart")
	live.queue_free()
	live2.queue_free()
	player.queue_free()
	pursuer.queue_free()


func _test_menu() -> void:
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	_check(menu_scene != null, "main menu scene loads")
	if menu_scene == null:
		return
	_check_eq(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://scenes/main_menu.tscn",
		"the app boots into the main menu",
	)

	var menu := menu_scene.instantiate() as MainMenu
	add_child(menu)
	if menu == null:
		return

	_check_eq(menu.campaign_button.text, "RUN TO SCHOOL", "the campaign button reads RUN TO SCHOOL")
	_check_eq(menu.endless_button.text, "ENDLESS MODE", "the endless button reads ENDLESS MODE")
	_check_eq(menu.how_to_button.text, "HOW TO PLAY", "the how-to button reads HOW TO PLAY")
	_check_eq(menu.quit_button.text, "QUIT", "the quit button reads QUIT")

	_check(not menu.campaign_button.disabled, "campaign is playable today")
	_check_eq(
		menu.campaign_button.get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"menu buttons use Nunito ExtraBold",
	)
	_check_eq(
		menu.best_label.get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"the best readout uses Nunito ExtraBold",
	)
	_check_eq(
		menu.best_label.text,
		"BEST  %06d" % GameState.best_campaign,
		"the best readout mirrors the campaign record",
	)

	_check(not menu.endless_button.disabled, "endless is playable today")
	_check_ne(
		menu.endless_button.focus_mode,
		Control.FOCUS_NONE,
		"endless can take keyboard focus",
	)
	_check(menu.endless_button.get_node_or_null("Soon") == null,
		"the endless button no longer carries a SOON pill")

	_check(not menu.how_to_panel.visible, "the how-to overlay starts hidden")
	_check_eq(
		(menu.get_node("HowToCenter") as Control).mouse_filter,
		Control.MOUSE_FILTER_IGNORE,
		"the hidden how-to container never blocks menu clicks",
	)
	_check_eq(
		menu.how_to_panel.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"the open how-to panel keeps its modal click block",
	)
	menu._on_how_to_pressed()
	_check(menu.how_to_panel.visible, "HOW TO PLAY opens the overlay")
	_check_eq(
		menu.back_button.get_theme_font("font").resource_path,
		"res://assets/fonts/Nunito-ExtraBold.ttf",
		"the overlay shares the menu button skin",
	)
	menu._on_how_to_pressed()
	_check(not menu.how_to_panel.visible, "BACK closes the overlay")
	_check(
		menu.campaign_button.pressed.is_connected(menu._on_campaign_pressed),
		"campaign is wired to launch the run",
	)
	_check(
		menu.endless_button.pressed.is_connected(menu._on_endless_pressed),
		"endless is wired to launch the run",
	)
	_check(
		menu.quit_button.pressed.is_connected(menu._on_quit_pressed),
		"quit is wired to close the app",
	)

	# The menu is a live slice of the school zone, not a static backdrop.
	var backdrop := menu.get_node_or_null("MenuBackdrop") as MenuBackdrop
	_check(backdrop != null, "the menu carries the live school-zone backdrop")
	if backdrop != null:
		_check_near(
			backdrop.scroll_speed,
			GameConfig.RUN_SPEED * MenuBackdrop.SCROLL_FACTOR, 0.001,
			"the menu strip scrolls slower than a live run",
		)
		var before_scroll := backdrop.distance
		backdrop._process(0.5)
		_check(backdrop.distance > before_scroll, "the menu backdrop scrolls over time")

	_check(menu.click_sfx != null, "the menu has a click player")
	if menu.click_sfx != null:
		_check_eq(menu.click_sfx.bus, &"SFX", "menu clicks route to the SFX bus")
		_check_near(menu.click_sfx.volume_db, MainMenu.CLICK_DB, 0.001,
			"menu clicks use the tuned UI level")

	# Launch feedback locks the menu and cannot double-fire a scene change.
	var previous_mode := GameState.mode
	menu._launch(GameConfig.RunMode.CAMPAIGN, false)
	_check_eq(menu.launch_count, 1, "a mode press starts exactly one launch")
	_check_eq(GameState.mode, GameConfig.RunMode.CAMPAIGN, "launch sets the mode before the flash")
	_check(menu.campaign_button.disabled, "launch locks the menu buttons")
	menu._launch(GameConfig.RunMode.ENDLESS, false)
	_check_eq(menu.launch_count, 1, "a second press cannot restart the launch")
	GameState.mode = previous_mode
	menu.queue_free()


func _test_menu_music() -> void:
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)

	var music := menu.menu_music
	_check(music != null, "the menu has a music player")
	if music == null:
		menu.queue_free()
		return
	var stream := music.stream as AudioStreamMP3
	_check(stream != null, "the music player carries the menu stream")
	_check_eq(music.bus, &"Music", "menu music routes to the Music bus")
	_check(music.autoplay, "menu music autoplays with the scene")
	_check(music.playing, "menu music is playing on the menu")
	_check(stream.loop, "the menu track loops (import loop enabled)")
	_check_near(stream.get_length(), 191.5, 1.0, "the menu track is the full 3:11 song")
	_check_near(music.volume_db, MainMenu.MUSIC_FADE_FROM_DB, 0.001,
		"the fade-in starts quiet before the tween steps")

	# The overlays live in the same scene, so the music must survive each of
	# them opening (user requirement: shop / how-to / settings keep playing).
	menu._on_shop_pressed()
	_check(menu.shop_panel.visible, "the shop opens over the menu")
	_check(music.playing, "the music keeps playing while the shop is open")
	menu._on_how_to_pressed()
	_check(menu.how_to_panel.visible, "how-to opens over the menu")
	_check(music.playing, "the music keeps playing while how-to is open")
	menu._on_how_to_pressed()
	menu._on_settings_pressed()
	_check(menu.settings_panel.visible, "settings opens over the menu")
	_check(music.playing, "the music keeps playing while settings is open")
	menu.shop_panel.close()
	menu.settings_panel.close()

	# The run scene now carries its own bed (it used to be menu-only). The
	# failure bed shares the Music bus, so the guarantee is one *run* bed plus
	# one explicitly separate fail bed - never a second run bed.
	var run_root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(run_root)
	var run_music: Array[AudioStreamPlayer] = []
	for player_node: Node in run_root.find_children("*", "AudioStreamPlayer", true, false):
		if (player_node as AudioStreamPlayer).bus == &"Music":
			run_music.append(player_node as AudioStreamPlayer)
	_check_eq(run_music.size(), 2,
		"the run scene carries the run bed and the fail bed")
	var run_bed := run_root.get_node_or_null("RunWorld/Music") as AudioStreamPlayer
	_check(run_bed != null, "the run bed is the Music node")
	if run_bed != null:
		_check(run_bed.stream != null, "the run bed has a stream")
	_check(run_root.get_node_or_null("RunWorld/FailMusicSfx") != null,
		"the second Music-bus player is the fail bed")
	run_root.queue_free()
	menu.queue_free()


## The run bed: routing, loop, fade-in, and the freeze-out. Runs on the shared
## world scene, so it exercises the same path a real run takes.
func _test_run_music() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld
	world.set_physics_process(false)
	# Skip the 3-2-1-GO gate: this test owns the bed, not the kickoff.
	world.begin_run()

	var music := world.music
	_check(music != null, "the run world carries a music bed")
	if music == null:
		main.queue_free()
		return
	_check_eq(music.bus, &"Music", "the run bed routes to the Music bus")
	_check(music.playing, "the run bed starts with the run")
	var stream := music.stream as AudioStreamMP3
	_check(stream != null, "the run bed carries the track")
	if stream != null:
		_check(stream.loop, "the run bed loops")
		_check_near(stream.get_length(), 140.47, 1.0, "the bed is the full 2:20 track")
	_check_near(music.volume_db, GameConfig.MUSIC_SILENT_DB, 0.001,
		"the bed starts silent before the fade-in tween steps")

	# Fade in has to land on the mix level, not just move somewhere.
	await get_tree().create_timer(GameConfig.MUSIC_FADE_IN_TIME + 0.15).timeout
	_check_near(music.volume_db, GameConfig.MUSIC_VOLUME_DB, 0.01,
		"the bed fades up to MUSIC_VOLUME_DB")

	# Ducking is a state change, not a stop.
	world._on_chase_started()
	await get_tree().create_timer(GameConfig.MUSIC_DUCK_TIME + 0.15).timeout
	_check_near(music.volume_db, GameConfig.MUSIC_DUCK_DB, 0.01,
		"a chase ducks the bed")
	_check(music.playing, "the ducked bed keeps playing")
	world._on_chase_faded()
	await get_tree().create_timer(GameConfig.MUSIC_DUCK_TIME * 2.0 + 0.15).timeout
	_check_near(music.volume_db, GameConfig.MUSIC_VOLUME_DB, 0.01,
		"the bed recovers after the chase")

	# Pausing freezes the stream: the paused tree alone would keep it playing.
	world._on_pause_changed(true)
	_check(music.stream_paused, "pausing the run freezes the bed")
	world._on_pause_changed(false)
	_check(not music.stream_paused, "resuming restarts the bed")

	# Every ending goes through _freeze_world, which owns the fade-out.
	world._freeze_world()
	_check(not world.is_running, "freezing stops the run")
	await get_tree().create_timer(GameConfig.MUSIC_FADE_OUT_TIME + 0.2).timeout
	_check(not music.playing, "the bed stops once the world freezes")
	main.queue_free()


## World-owned gameplay audio: the combo tier riser lives on RunWorld (not the
## HUD) so it freezes with the run like every other cue.
func _test_run_audio() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld
	world.set_physics_process(false)

	var tier_sfx := world.tier_sfx as AudioStreamPlayer
	_check(tier_sfx != null, "the world owns a tier-up riser")
	if tier_sfx == null:
		main.queue_free()
		return
	_check_eq(tier_sfx.bus, &"SFX", "the tier riser routes to the SFX bus")
	_check(tier_sfx.stream != null, "the tier riser has a stream")
	_check_eq(world.tier_up_play_count, 0, "no riser before any rung")

	# Failure cue: a short sting on the SFX bus, and a separate looping bed on
	# the Music bus that only starts once the sting has rung out.
	var fail_sting := world.fail_sting as AudioStreamPlayer
	var fail_music := world.fail_music as AudioStreamPlayer
	_check(fail_sting != null, "the world owns a fail sting")
	_check(fail_music != null, "the world owns a fail bed")
	if fail_sting != null and fail_music != null:
		_check_eq(fail_sting.bus, &"SFX", "the fail sting routes to the SFX bus")
		_check_eq(fail_music.bus, &"Music", "the fail bed routes to the Music bus")
		_check(fail_sting.stream != null, "the fail sting has a stream")
		_check(fail_music.stream != null, "the fail bed has a stream")
		_check(fail_sting.stream != fail_music.stream,
			"the sting and the bed are different clips")
		var sting_clip := fail_sting.stream as AudioStreamMP3
		_check(sting_clip != null, "the fail sting is the committed MP3")
		if sting_clip != null:
			_check(not sting_clip.loop, "the fail sting does not loop")
		_check_eq(world.fail_cue_play_count, 0, "no fail cue before any failure")
	main.queue_free()


## The 3-2-1-GO gate: locked until GO, the beat clock driven from RunWorld (so
## pause freezes it and the suite can step it), and no simulation on the unlock
## frame.
func _test_countdown() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld
	world.set_physics_process(false)
	var countdown := world.countdown
	var player := world.player as Player
	player.set_physics_process(false)

	_check(world.is_counting_down, "a fresh run opens on the countdown")
	_check(not world.is_running, "the run is locked during the countdown")
	_check(countdown.visible, "the countdown overlay is on screen")
	_check(countdown.is_active, "the countdown owns the clock")
	_check_eq(countdown.beat_label.text, "3", "the countdown opens on 3")
	_check_eq(countdown.beat, GameConfig.START_COUNTDOWN_BEATS,
		"three beats are queued")
	_check(not player.is_physics_processing(),
		"the player is frozen during the countdown")
	_check(not player.is_processing_unhandled_input(),
		"player input is locked during the countdown")
	_check_eq(player.sprite.animation, &"idle",
		"Elias idles at the start line, not running on the spot")
	_check(player.sprite.is_playing(), "the idle loop is running")
	_check_eq(player._current_anim, &"idle",
		"the animation state knows it is idling")
	_check(world.pause_menu._can_pause(),
		"the pause button still works during the countdown")
	_check(not world.music.playing, "the bed waits for GO")

	# Layering contract: the spoken 3-2-1-GO runs underneath the beep ladder.
	# The beeps are kept deliberately - this is a two-layer countdown.
	_check(countdown.cue_sfx != null, "the countdown carries the spoken cue")
	_check_eq(countdown.cue_sfx.bus, "SFX", "the spoken cue routes to the SFX bus")
	_check(countdown.cue_sfx.stream != null, "the spoken cue has a stream")
	_check(
		countdown.cue_sfx.stream.resource_path.contains("321go"),
		"the spoken cue uses the committed 321go sample",
	)
	_check_eq(countdown.cue_sfx.volume_db, GameConfig.COUNTDOWN_CUE_DB,
		"the spoken cue is mixed at its configured level")
	_check(countdown.cue_sfx.volume_db < countdown.tick_sfx.volume_db,
		"the voice sits under the beeps")
	_check(
		countdown.tick_sfx.stream.resource_path.contains("countdown_tick"),
		"the beep ladder is still wired",
	)
	_check(
		countdown.go_sfx.stream.resource_path.contains("countdown_go"),
		"the GO blip is still wired",
	)
	for i in countdown.CUE_OFFSETS.size() - 1:
		_check(countdown.CUE_OFFSETS[i] < countdown.CUE_OFFSETS[i + 1],
			"the spoken cue offsets ascend")
	_check(countdown.GO_CUE_OFFSET < countdown.cue_sfx.stream.get_length(),
		"the GO cue sits inside the sample")
	_check_near(countdown.last_cue_offset, countdown.CUE_OFFSETS[0], 0.001,
		"beat 3 seeks the first spoken cue")
	_check(countdown.tick_sfx.playing and countdown.cue_sfx.playing,
		"beat 3 fires the beep and the voice together")

	# Pausing the tree does not stop audio: both of them freeze by hand.
	world._on_pause_changed(true)
	_check(countdown.cue_sfx.stream_paused, "a pause freezes the spoken cue")
	world._on_pause_changed(false)
	_check(not countdown.cue_sfx.stream_paused, "unpausing resumes the cue")

	# Half a second of ticks: the clock moves, the world does not.
	for i in 10:
		world._physics_process(0.05)
	_check_near(countdown.beat_time, 0.5, 0.01, "the beat clock advances")
	_check_eq(countdown.beat_label.text, "3", "3 still holds at half a second")
	_check_near(world.distance, 0.0, 0.001, "the countdown travels no distance")
	_check_eq(world.hazards.get_child_count(), 0,
		"the countdown spawns no hazards")
	_check_eq(world.score_system.score, 0, "the countdown scores nothing")

	# 3 -> 2 on the beat, with the next rung of the tick ladder.
	for i in 12:
		world._physics_process(0.05)
	_check_eq(countdown.beat, 2, "the beat drops to 2")
	_check_eq(countdown.beat_label.text, "2", "the overlay shows 2")
	_check_eq(player.sprite.animation, &"idle",
		"the idle holds through the ticks")
	_check_near(countdown.tick_sfx.pitch_scale,
		GameConfig.COUNTDOWN_TICK_PITCH_STEP, 0.001, "the tick climbs a rung")
	_check_near(countdown.last_cue_offset, countdown.CUE_OFFSETS[1], 0.001,
		"beat 2 seeks the second spoken cue")
	_check(countdown.tick_sfx.playing and countdown.cue_sfx.playing,
		"beat 2 keeps both layers running")
	_check_eq(countdown.beat_play_count, 2, "two beats have been shown")

	# 2 -> 1.
	for i in 22:
		world._physics_process(0.05)
	_check_eq(countdown.beat_label.text, "1", "the overlay shows 1")
	_check_near(countdown.tick_sfx.pitch_scale,
		pow(GameConfig.COUNTDOWN_TICK_PITCH_STEP, 2.0), 0.001,
		"the tick climbs the last rung")
	_check_near(countdown.last_cue_offset, countdown.CUE_OFFSETS[2], 0.001,
		"beat 1 seeks the third spoken cue")

	# 1 -> GO. Step one tick at a time so the unlock frame can be checked
	# exactly: the frame that shows GO must not also simulate.
	var guard := 60
	while not countdown.go_shown and guard > 0:
		world._physics_process(0.05)
		guard -= 1
	_check(countdown.go_shown, "the countdown reaches GO")
	_check(not countdown.is_active, "GO hands the clock back to the run")
	_check_eq(countdown.beat_label.text, "GO!", "the overlay shows GO!")
	_check(not world.is_counting_down, "the countdown ends on GO")
	_check(world.is_running, "GO unlocks the run")
	_check(player.is_physics_processing(), "GO unlocks player physics")
	_check(player.is_processing_unhandled_input(), "GO unlocks player input")
	_check_eq(player.sprite.animation, &"run",
		"GO switches Elias from the idle to the run cycle")
	_check_eq(player._current_anim, &"run", "the animation state follows GO")
	_check_near(countdown.last_cue_offset, countdown.GO_CUE_OFFSET, 0.001,
		"GO seeks the spoken GO hit")
	_check(countdown.go_sfx.playing and countdown.cue_sfx.playing,
		"GO fires the blip and the voice together")
	_check(world.music.playing, "GO starts the bed")
	_check_near(world.distance, 0.0, 0.001, "the GO frame does not simulate")

	# The frame after GO is a normal live frame.
	world._physics_process(1.0 / 60.0)
	_check(world.distance > 0.0, "the frame after GO moves the run")

	# The overlay fades itself out after the GO hold, clearing the road.
	await get_tree().create_timer(
		GameConfig.START_COUNTDOWN_GO_TIME + CountdownOverlay.FADE_OUT_TIME
		+ 0.15).timeout
	_check(not countdown.visible, "the overlay clears itself after GO")
	main.queue_free()

	# Skip path: input before the delay is ignored, input after it jumps straight
	# to GO and still unlocks the run exactly once.
	var skip_root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(skip_root)
	var skip_world := skip_root.get_node("RunWorld") as RunWorld
	skip_world.set_physics_process(false)
	var unlocks := [0]
	skip_world.countdown.finished.connect(func() -> void: unlocks[0] += 1)
	var early_press := InputEventKey.new()
	early_press.pressed = true
	skip_world.countdown._unhandled_input(early_press)
	_check(not skip_world.countdown.go_shown,
		"input before the skip delay is ignored")
	for i in 10:
		skip_world._physics_process(0.05)
	skip_world.countdown._unhandled_input(early_press)
	_check(skip_world.countdown.go_shown, "a key press after the delay jumps to GO")
	_check(skip_world.is_running, "a skip still unlocks the run")
	_check_eq(skip_world.player.sprite.animation, &"run",
		"a skip also starts the run cycle")
	_check_eq(skip_world.countdown.skip_count, 1, "one skip is counted")
	_check_near(skip_world.countdown.last_cue_offset,
		skip_world.countdown.GO_CUE_OFFSET, 0.001,
		"a skip jumps the spoken cue straight to GO")
	_check_eq(unlocks[0], 1, "a skip emits finished once")
	skip_world.countdown.skip()
	_check_eq(unlocks[0], 1, "a second skip does nothing")
	skip_world.countdown.dismiss()
	_check(not skip_world.countdown.cue_sfx.playing,
		"dismiss silences the spoken cue")
	skip_world.queue_free()


## Victory reveal cues: the fanfare at the reveal, a badge pop and cue after the
## medal pop, and the level-up cue swapped in only when the session best falls.
func _test_results_audio() -> void:
	var screen := (load("res://scenes/results_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	var results := screen as ResultsScreen
	var fanfare := results.victory_sfx
	var chime := results.badge_sfx
	var record := results.record_sfx

	_check_eq(results.badge_pop_count, 0, "no badge pop before a reveal")

	_check(fanfare != null and chime != null and record != null,
		"the results screen owns its three victory cues")
	if fanfare == null or chime == null or record == null:
		screen.queue_free()
		return
	_check_eq(fanfare.bus, &"SFX", "the fanfare routes to the SFX bus")
	_check_eq(chime.bus, &"SFX", "the badge chime routes to the SFX bus")
	_check_eq(record.bus, &"SFX", "the record cue routes to the SFX bus")
	for player in [fanfare, chime, record]:
		var clip := (player as AudioStreamPlayer).stream as AudioStreamMP3
		_check(clip != null, "each victory cue is the committed MP3")
		if clip != null:
			_check(not clip.loop, "the victory cues do not loop")
	_check(fanfare.stream.resource_path.contains("victory-fanfare"),
		"the fanfare uses the downloaded fanfare")
	_check(chime.stream.resource_path.contains("victory-chime"),
		"the badge uses the downloaded chime")
	_check(record.stream.resource_path.contains("level-up"),
		"the record accent uses the downloaded level-up cue")
	_check_eq(fanfare.volume_db, GameConfig.RESULTS_FANFARE_DB,
		"the fanfare is mixed at its configured level")
	_check_eq(chime.volume_db, GameConfig.RESULTS_CHIME_DB,
		"the badge chime is mixed at its configured level")
	_check_eq(record.volume_db, GameConfig.RESULTS_RECORD_DB,
		"the record cue is mixed at its configured level")
	_check(chime.volume_db < fanfare.volume_db,
		"the badge sits under the fanfare")

	# Failure is unchanged: the world's sting and bed are the only cues.
	ResultsScreen.session_runs = 2
	results.show_results(
		ResultsScreen.Outcome.CAUGHT, 10, 1, "HOME", 0, GameConfig.Medal.BLACK, 0)
	_check(not fanfare.playing and not chime.playing and not record.playing,
		"failure results play no victory cue")
	await get_tree().create_timer(GameConfig.RESULTS_BADGE_CUE_DELAY + 0.15).timeout
	_check(not chime.playing and not record.playing,
		"failure never queues a badge cue")
	_check_eq(results.badge_pop_count, 0, "failure never pops the badge")

	# A plain victory: the fanfare leads and the chime answers the medal pop.
	GameState.best_campaign = 999999
	results.show_results(
		ResultsScreen.Outcome.VICTORY, 100, 300, "SCHOOL", 1,
		GameConfig.Medal.SILVER, 0)
	_check(fanfare.playing, "victory plays the fanfare on the reveal")
	_check(not chime.playing, "the badge cue waits for the medal pop")
	await get_tree().create_timer(GameConfig.RESULTS_BADGE_CUE_DELAY + 0.15).timeout
	_check(chime.playing, "the badge chime lands after the reveal")
	_check(not record.playing, "no record cue without a new best")
	_check_eq(results.badge_pop_count, 1, "the badge pops with the chime")
	_check(results.medal_icon.scale.x > 1.01,
		"the badge is mid-pop when the chime lands")

	# A new best swaps the chime for the level-up cue.
	GameState.best_campaign = 100
	results.show_results(
		ResultsScreen.Outcome.VICTORY, 500, 300, "SCHOOL", 2,
		GameConfig.Medal.GOLD, 0)
	_check(not chime.playing, "a new card cuts the previous badge cue")
	await get_tree().create_timer(GameConfig.RESULTS_BADGE_CUE_DELAY + 0.15).timeout
	_check(record.playing, "a new best plays the level-up cue")
	_check(not chime.playing, "the record cue replaces the badge chime")
	_check_eq(results.badge_pop_count, 2, "a new best still pops the badge")

	# The spring settles back to rest and the gold flash returns to white.
	await get_tree().create_timer(0.4).timeout
	_check_near(results.medal_icon.scale.x, 1.0, 0.01,
		"the badge pop settles back to rest")
	_check(results.medal_icon.modulate.is_equal_approx(Color.WHITE),
		"the gold flash returns to white")
	fanfare.stop()
	chime.stop()
	record.stop()
	screen.queue_free()


func _test_settings() -> void:
	# The shared panel loads with its controls wired.
	var panel_scene := load("res://scenes/settings_panel.tscn") as PackedScene
	_check(panel_scene != null, "settings panel scene loads")
	if panel_scene == null:
		return

	var panel := panel_scene.instantiate() as SettingsPanel
	add_child(panel)
	if panel == null:
		return
	_check(not panel.visible, "the settings panel starts hidden")

	# The bus layout ships Master, Music and SFX for the sliders to drive.
	_check_eq(
		AudioServer.get_bus_index("Master"), SettingsPanel.BUS_MASTER,
		"the Master bus sits at index 0",
	)
	_check_eq(
		AudioServer.get_bus_index("Music"), SettingsPanel.BUS_MUSIC,
		"the Music bus sits at index 1",
	)
	_check_eq(
		AudioServer.get_bus_index("SFX"), SettingsPanel.BUS_SFX,
		"the SFX bus sits at index 2",
	)

	# Volume helpers: percent <-> db round trip, mute at zero, clamped top.
	SettingsPanel.set_bus_volume_percent(SettingsPanel.BUS_MUSIC, 50)
	_check(
		absf(SettingsPanel.bus_volume_percent(SettingsPanel.BUS_MUSIC) - 50.0) < 0.01,
		"setting 50% music reads back 50%",
	)
	_check(
		absf(AudioServer.get_bus_volume_db(SettingsPanel.BUS_MUSIC) - linear_to_db(0.5)) < 0.01,
		"50% music lands on the matching db value",
	)
	_check(
		not AudioServer.is_bus_mute(SettingsPanel.BUS_MUSIC),
		"a mid volume leaves the bus unmuted",
	)
	SettingsPanel.set_bus_volume_percent(SettingsPanel.BUS_MUSIC, 0)
	_check(AudioServer.is_bus_mute(SettingsPanel.BUS_MUSIC), "0% music mutes the bus")
	_check_eq(SettingsPanel.bus_volume_percent(SettingsPanel.BUS_MUSIC), 0.0, "0% music reads back 0")
	SettingsPanel.set_bus_volume_percent(SettingsPanel.BUS_MUSIC, 100)
	_check(
		not AudioServer.is_bus_mute(SettingsPanel.BUS_MUSIC),
		"100% music unmutes the bus",
	)
	_check(
		absf(AudioServer.get_bus_volume_db(SettingsPanel.BUS_MUSIC)) < 0.01,
		"100% music is unity gain",
	)
	SettingsPanel.set_bus_volume_percent(SettingsPanel.BUS_MUSIC, 150)
	_check_eq(
		SettingsPanel.bus_volume_percent(SettingsPanel.BUS_MUSIC), 100.0,
		"out-of-range percents clamp to 100",
	)

	# open() syncs every control to the live state.
	panel.open()
	_check(panel.visible, "open() reveals the panel")
	_check_eq(
		panel.master_slider.value,
		SettingsPanel.bus_volume_percent(SettingsPanel.BUS_MASTER),
		"open() syncs the master slider to the bus",
	)
	_check_eq(
		panel.debug_check.button_pressed, GameState.debug_overlay,
		"open() syncs the debug check to GameState",
	)

	# The debug toggle writes through to GameState (restored right after).
	var was_debug := GameState.debug_overlay
	panel.debug_check.button_pressed = not was_debug
	_check_eq(GameState.debug_overlay, not was_debug, "the debug toggle writes through to GameState")
	GameState.set_debug_overlay(was_debug)

	# The fullscreen toggle tracks its state (window mode itself is
	# platform-dependent, so only the control is asserted).
	var was_fullscreen := panel.fullscreen_check.button_pressed
	panel.fullscreen_check.button_pressed = not was_fullscreen
	_check_eq(
		panel.fullscreen_check.button_pressed, not was_fullscreen,
		"the fullscreen check tracks its toggle",
	)
	panel.fullscreen_check.button_pressed = was_fullscreen

	# close() hides the panel and tells the host.
	var closed_fired := [false]
	panel.closed.connect(func(): closed_fired[0] = true)
	panel.close()
	_check(not panel.visible, "close() hides the panel")
	_check(closed_fired[0], "close() emits closed")
	panel.queue_free()

	# Menu integration: SETTINGS opens the panel, BACK restores the button.
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	menu._on_settings_pressed()
	_check(menu.settings_panel.visible, "the menu's SETTINGS button opens the panel")
	menu.settings_panel.close()
	_check(not menu.settings_panel.visible, "BACK hides the menu's panel")
	_check(
		menu.settings_button.has_focus(),
		"closing settings refocuses the SETTINGS button",
	)
	menu.queue_free()

	# Pause integration: the overlay swaps its button column for the panel.
	var hud := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	var pause := hud.get_node("HudRoot/Pause") as PauseMenu
	_check(pause != null, "the hud carries the pause menu")
	if pause != null:
		pause._on_settings_pressed()
		_check(not pause.center.visible, "pause settings hide the button column")
		_check(pause.settings_panel.visible, "pause settings show the shared panel")
		pause.settings_panel.close()
		_check(pause.center.visible, "closing settings restores the button column")
		_check(
			pause.settings_button.has_focus(),
			"closing pause settings refocuses SETTINGS",
		)
		# A panel left open must not survive into the next pause.
		pause._on_settings_pressed()
		pause.set_paused(true)
		_check(not pause.settings_panel.visible, "re-pausing closes a left-open panel")
		_check(pause.center.visible, "re-pausing restores the button column")
		pause.set_paused(false)

		# Clicking the corner pause button must behave exactly like Esc.
		_check(
			pause.button.pressed.is_connected(pause.toggle_pause),
			"the pause button is wired to toggle_pause",
		)
		pause.button.pressed.emit()
		_check(pause.is_paused, "clicking pause opens the overlay")
		_check(get_tree().paused, "clicking pause freezes the tree")
		_check(not pause.button.visible, "clicking pause hides the button")
		pause.toggle_pause()
		_check(not pause.is_paused, "toggling off unpauses")
		_check(not get_tree().paused, "toggling off unfreezes the tree")
		_check(pause.button.visible, "toggling off restores the button")

		# A real synthetic mouse click must land on the button, proving no
		# ancestor or sibling control blocks the pick. Local coords are used
		# because push_input() would otherwise remap through the stretch
		# transform, which headless windows do not match.
		var vp := pause.get_viewport()
		var hover := InputEventMouseMotion.new()
		hover.position = pause.button.get_global_rect().get_center()
		hover.global_position = hover.position
		vp.push_input(hover, true)
		_check(pause.button.is_hovered(), "hovering the button's rect reaches the button")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = pause.button.get_global_rect().get_center()
		press.global_position = press.position
		vp.push_input(press, true)
		var release := press.duplicate() as InputEventMouseButton
		release.pressed = false
		vp.push_input(release, true)
		_check(pause.is_paused, "a real click on the pause button opens the overlay")
		_check(get_tree().paused, "a real click freezes the tree")
		pause.set_paused(false)
		_check(not get_tree().paused, "cleanup leaves the tree unpaused")
	hud.queue_free()


func _test_ui_sfx() -> void:
	_check(UiSfx != null, "the UiSfx autoload is registered")
	if UiSfx == null:
		return
	var click := UiSfx.click_player as AudioStreamPlayer
	_check(click != null, "the ui click autoload owns a player")
	if click == null:
		return
	_check_eq(click.bus, &"SFX", "the ui click routes to the SFX bus")
	_check(click.stream != null, "the ui click player carries a stream")
	_check_eq(click.max_polyphony, 1, "a second click retriggers instead of stacking")

	# The hook is what makes the shop's runtime-built cards click without any
	# wiring in shop_panel.gd, so a button added after boot must be caught.
	var before := UiSfx.click_play_count
	var btn := Button.new()
	add_child(btn)
	btn.pressed.emit()
	_check_eq(UiSfx.click_play_count, before + 1, "a runtime-added button clicks")

	# Escape hatch: a tagged button stays silent.
	var quiet := Button.new()
	quiet.set_meta(UiSfx.SILENT_META, true)
	add_child(quiet)
	quiet.pressed.emit()
	_check_eq(UiSfx.click_play_count, before + 1, "a tagged button stays silent")

	# Re-adding must not connect the signal twice and double up the tick.
	remove_child(btn)
	add_child(btn)
	btn.pressed.emit()
	_check_eq(UiSfx.click_play_count, before + 2, "a re-added button still clicks once")

	btn.queue_free()
	quiet.queue_free()

	# Cold boot: the main menu is already in the tree before this autoload
	# turns ready, so the startup sweep - not node_added - has to hook it.
	# Sweeping twice must still leave exactly one connection per button.
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	UiSfx.hook_tree(menu)
	UiSfx.hook_tree(menu)
	add_child(menu)
	var how_to := menu.find_child("HowTo", true, false) as Button
	_check(how_to != null, "the main menu exposes its HOW TO button")
	if how_to != null:
		var swept := UiSfx.click_play_count
		how_to.pressed.emit()
		_check_eq(UiSfx.click_play_count, swept + 1,
			"a swept menu button clicks exactly once")

	# A whole subtree arriving later (change_scene_to_file, a dialog) is
	# caught too, not just a bare button added on its own.
	var late := Control.new()
	var late_btn := Button.new()
	late.add_child(late_btn)
	add_child(late)
	var late_before := UiSfx.click_play_count
	late_btn.pressed.emit()
	_check_eq(UiSfx.click_play_count, late_before + 1,
		"a button inside a later-added subtree clicks")

	menu.queue_free()
	late.queue_free()


func _test_ui_fonts() -> void:
	const TITLE_SCENES := [
		"res://scenes/hud.tscn",
		"res://scenes/main_menu.tscn",
		"res://scenes/results_screen.tscn",
		"res://scenes/settings_panel.tscn",
		"res://scenes/shop_panel.tscn",
	]

	# Every font path constant must resolve to a real font file. A missing
	# FontFile does not error - Label silently falls back to the engine
	# default - so the resource_path alone is not proof the font exists.
	var paths := {
		"score": ScoreHud.SCORE_FONT_PATH,
		"HUD sub-label": ScoreHud.SUB_FONT_PATH,
		"progress score": ProgressBarHud.SCORE_FONT_PATH,
		"progress sub-label": ProgressBarHud.SUB_FONT_PATH,
		"pause body": PauseMenu.UI_FONT_PATH,
		"pause title": PauseMenu.TITLE_FONT_PATH,
		"pause button": PauseMenu.BUTTON_FONT_PATH,
		"store name": ShopPanel.NAME_FONT.resource_path,
		"store description": ShopPanel.SUB_FONT.resource_path,
	}
	for label: String in paths:
		var path: String = paths[label]
		_check(ResourceLoader.exists(path), "the %s font file exists" % label)
		var font := load(path) as FontFile
		_check(font != null and not font.font_name.is_empty(),
			"the %s font loads with a real family name" % label)

	# Fredoka is the display face (one weight, wide uneven digits, so it must
	# never drive a ticking number); Nunito carries every functional label.
	_check_eq((load(PauseMenu.TITLE_FONT_PATH) as Font).font_name, "Fredoka One",
		"pause titles use Fredoka")
	_check((load(ScoreHud.SCORE_FONT_PATH) as Font).font_name.begins_with("Nunito"),
		"the score uses Nunito")
	_check((load(ScoreHud.SUB_FONT_PATH) as Font).font_name.begins_with("Nunito"),
		"HUD sub-labels use Nunito")

	# Each UI scene must declare its fonts as real resources too: these are the
	# paths the editor resolves when it opens the scene.
	var font_line := RegEx.new()
	font_line.compile('\\[ext_resource type="FontFile"[^\\]]*path="([^"]+)"')
	for scene_path: String in TITLE_SCENES:
		var text := FileAccess.get_file_as_string(scene_path)
		_check(not text.is_empty(), "%s is readable" % scene_path)
		var font_refs := font_line.search_all(text)
		_check(not font_refs.is_empty(), "%s declares a font resource" % scene_path)
		for hit in font_refs:
			var path := hit.get_string(1)
			_check(ResourceLoader.exists(path),
				"%s references an existing font (%s)" % [scene_path, path])
			_check(not path.contains("InterTight"),
				"%s no longer references Inter Tight" % scene_path)
		# Titles ride the Fredoka override; sharing the scene font would put
		# the display face on buttons and numbers.
		_check(text.contains('theme_override_fonts/font = ExtResource("0_titles")'),
			"%s has a Fredoka title override" % scene_path)


func _test_scenes() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		return

	var main := main_scene.instantiate()
	add_child(main)
	var world := main.get_node_or_null("RunWorld") as RunWorld
	_check(world != null, "main scene contains the run world")
	if world != null:
		world.set_physics_process(false)
		# Every scene test below assumes a live run, so skip the countdown.
		world.begin_run()
		_check(world.player != null, "run world contains the player")
		_check(world.hazards != null, "run world contains a hazard container")
		_check(world.director != null, "run world contains a spawn director")
		_check(world.hud != null, "run world contains the hearts HUD")
		_check(world.score_hud != null, "run world contains the score HUD")
		_check(world.score_system != null, "run world owns a score system")
		_check(world.pursuer != null, "run world contains the pursuer")
		_check(world.pursuer.state == Pursuer.State.DORMANT, "pursuer starts dormant")
		_check_near(world.speed, GameConfig.RUN_SPEED, 0.01, "run world starts at RUN_SPEED")
		_check(not world.results.visible, "the results screen starts hidden")
		_check_eq(world.results.title_label.text, "OUT OF HEARTS",
			"the default title is OUT OF HEARTS")
		_check_eq(world.score_system.score, 0, "score starts at 0")
		_check(world.is_running, "the run starts running")
		_check(not world.results.visible, "the game over overlay starts hidden")
		_check_near(world.speed, GameConfig.RUN_SPEED, 0.01, "run world starts at RUN_SPEED")
		if world.player != null:
			_check_eq(
				world.player.sprite.animation,
				&"run",
				"player scene previews the run animation (visible in the editor)",
			)

		if world.hud != null:
			_check_eq(world.hud.heart_count(), GameConfig.MAX_HEARTS, "HUD starts with three hearts")
			world.hud.set_hearts(1, GameConfig.MAX_HEARTS)
			_check_eq(
				world.hud.get_heart_texture(0).resource_path,
				"res://assets/heart/heart.png",
				"the first heart is full",
			)
			_check_eq(
				world.hud.get_heart_texture(1).resource_path,
				"res://assets/heart/heart_empty.png",
				"lost hearts use the empty heart art",
			)
			world.hud.set_hearts(GameConfig.MAX_HEARTS, GameConfig.MAX_HEARTS)

		if world.score_hud != null:
			_check_eq(
				world.score_hud.label_font("score").resource_path,
				ScoreHud.SCORE_FONT_PATH,
				"the score uses Nunito ExtraBold",
			)
			_check_eq(
				world.score_hud.label_font("combo").resource_path,
				ScoreHud.SUB_FONT_PATH,
				"the combo readout uses Nunito SemiBold",
			)
			_check_eq(
				world.score_hud.label_font("items").resource_path,
				ScoreHud.SUB_FONT_PATH,
				"the item count uses Nunito SemiBold",
			)
			world.score_hud.set_combo(2, 5)
			_check_eq(
				world.score_hud.label_text("combo"),
				"x2 · 5/6",
				"the combo readout shows the chain and the next rung",
			)
			var x2_color := world.score_hud.label_color("combo")
			world.score_hud.set_combo(5, 12)
			_check_eq(
				world.score_hud.label_text("combo"),
				"x5 · MAX",
				"the combo readout caps out at x5",
			)
			_check(
				world.score_hud.label_color("combo") != x2_color,
				"every rung steps the combo colour",
			)
			world.score_hud.set_combo(1, 0)
			_check_eq(world.score_hud.label_text("combo"), "", "the combo readout hides with no chain")

		if world.pause_menu != null:
			_check_eq(
				world.pause_menu.process_mode,
				Node.PROCESS_MODE_ALWAYS,
				"the pause menu keeps processing while paused",
			)
			_check(not world.pause_menu.is_paused, "the run starts unpaused")
			_check(world.pause_menu.button.visible, "the pause button is visible while running")
			world.pause_menu.set_paused(true)
			_check(get_tree().paused, "pausing freezes the tree")
			_check(world.pause_menu.overlay.visible, "pausing shows the overlay")
			_check(not world.pause_menu.button.visible, "pausing hides the pause button")
			world.pause_menu.set_paused(false)
			_check(not get_tree().paused, "resuming unfreezes the tree")
			_check(not world.pause_menu.overlay.visible, "resuming hides the overlay")
			_check(world.pause_menu.button.visible, "resuming restores the pause button")
			get_tree().paused = false

		if world.director != null:
			for i in 8:
				world._physics_process(0.25)
			_check(world.distance > 0.0, "distance advances while running")
			_check(world.hazards.get_child_count() > 0, "the director spawns hazards as distance grows")
			_check(world.score_system.score > 0, "distance scores points while running")

		if world.player != null and world.pursuer != null:
			# Damage wakes the pursuer and dips momentum (1.0 s hold + 1.5 s ease).
			world.player.invulnerable_time_left = 0.0
			world._on_player_damaged(world.player.health - 1)
			_check(world.pursuer.state == Pursuer.State.CHASE, "damage wakes the pursuer through the world")
			_check(world.momentum_time_left > 0.0, "damage starts the momentum dip")
			for i in 60:
				world._physics_process(1.0 / 60.0)
			_check_near(world.speed,
				world._base_speed() * GameConfig.MOMENTUM_DIP_FACTOR, 0.1,
				"world holds at 75% of its ramped speed during the dip")
			for i in 45:
				world._physics_process(1.0 / 60.0)
			_check(
				world.speed > world._base_speed() * GameConfig.MOMENTUM_DIP_FACTOR
				and world.speed < world._base_speed(),
				"momentum eases back gradually (%.0f px/s mid-recovery)" % world.speed,
			)
			for i in 60:
				world._physics_process(1.0 / 60.0)
			_check_near(world.speed, world._base_speed(), 0.1,
				"momentum recovers after the ease")

			# Hazards ride the road: live speed follows the dipped world speed.
			var sync_hazard := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
			world.hazards.add_child(sync_hazard)
			sync_hazard.setup(GameConfig.HazardKind.MANHOLE, GameConfig.LANE_MIDDLE, GameConfig.RUN_SPEED)
			sync_hazard.position.x = 1200.0
			world._on_player_damaged(world.player.health - 1)
			world._physics_process(1.0 / 60.0)
			sync_hazard._physics_process(1.0 / 60.0)
			_check_near(
				sync_hazard.position.x,
				1200.0 - world.speed * (1.0 / 60.0),
				2.5,
				"hazard moves with the dipped road speed",
			)
			sync_hazard.queue_free()

			# Missed item also wakes the pursuer.
			world.pursuer.state = Pursuer.State.DORMANT
			world.pursuer.visible = false
			world._on_item_missed()
			_check(world.pursuer.state == Pursuer.State.CHASE, "missed item wakes the pursuer through the world")

			# Chase death: hazard while active -> CAUGHT! after the arrest.
			world.player.pursuer_active = true
			world._on_player_caught()
			_check(not world.is_running, "caught stops the run")
			_check(world.arrest.visible, "caught shows the arrest grab")
			_check(not world.player.sprite.visible, "caught hides the player sprite")
			world._on_arrest_finished()
			_check(world.results.visible, "caught shows the game over overlay")
			_check(world.results.title_label.text == "CAUGHT!", "caught shows CAUGHT!")
			_check(
				world.results.stat_text("score") == "%06d" % world.score_system.score,
				"caught fills the final score readout",
			)

			# Failure audio: the sting and the looping bed start together on the
			# reveal, so the panel lands on one cue rather than a hand-off.
			_check_eq(world.fail_cue_play_count, 1, "a caught run queues the fail cue once")
			_check(world.fail_sting.playing, "the fail sting plays on the reveal")
			_check(world.fail_music.playing, "the fail bed starts with the sting")
			var fail_clip := world.fail_music.stream as AudioStreamMP3
			_check(fail_clip != null, "the fail bed is the committed MP3")
			if fail_clip != null:
				_check(fail_clip.loop, "the fail bed loops")
			world._play_fail_cue()
			_check_eq(world.fail_cue_play_count, 1, "the fail cue cannot restart")
			# Silence both so nothing plays through the rest of the suite.
			world.fail_sting.stop()
			world.fail_music.stop()

			# Endless: the street is terminal, the school zone never draws.
			world.set_run_mode(GameConfig.RunMode.ENDLESS)
			world.distance = world.home_zone_length + world.street_zone_length + 5000.0
			world._update_zone()
			_check_eq(world.current_zone, GameConfig.Zone.STREET,
				"endless stays in the street forever")
			_check_near(
				world._base_speed(),
				GameConfig.RUN_SPEED * GameConfig.endless_speed_multiplier(world.distance),
				0.01,
				"endless base speed rides the ramp",
			)
			world.set_run_mode(GameConfig.RunMode.CAMPAIGN)
			world._update_zone()
			_check_eq(world.current_zone, GameConfig.Zone.SCHOOL,
				"campaign enters the school at the same distance")
			world.distance = world.campaign_finish_distance + 1000.0
			_check_near(world._base_speed(),
				GameConfig.RUN_SPEED * GameConfig.CAMPAIGN_RAMP_MAX_MULTIPLIER,
				0.01,
				"campaign base speed caps its ramp past the finish")
			GameState.best_campaign = 0
			world._finished = false
			# The caught block above already revealed this overlay; a real run has
			# exactly one outcome, so clear it to model a fresh finish.
			world.results.visible = false
			world.distance = world.campaign_finish_distance
			var frozen_distance := world.distance
			var exit_start_x := world.player.position.x
			world._finish_campaign()
			_check(not world.is_running, "crossing the finish stops the run")
			_check(world.run_off_active, "the finish begins the victory run-off")
			_check(not world.results.visible,
				"the results wait until Elias leaves the frame")
			_check(world.player.sprite.flip_h == false,
				"Elias keeps facing right on his way out")
			_check_eq(String(world.player.sprite.animation), "run",
				"Elias keeps his run cycle during the run-off")
			_check_near(world.player.sprite.speed_scale,
				GameConfig.FINISH_RUN_OFF_SPEED_FACTOR, 0.001,
				"the sprint cadence matches his exit speed")
			# The scene itself never moves during the exit; only Elias does.
			for i in 10:
				world._physics_process(1.0 / 60.0)
			_check_near(world.distance, frozen_distance, 0.001,
				"the world stays frozen through the victory lap")
			_check(world.player.position.x > exit_start_x,
				"Elias runs right during the run-off")
			_check(not world.results.visible,
				"the results still wait mid run-off")
			var run_off_guard := 0
			while world.run_off_active and run_off_guard < 600:
				world._physics_process(1.0 / 60.0)
				run_off_guard += 1
			_check(not world.run_off_active, "the run-off finishes at the edge")
			_check_near(world.player.position.x, GameConfig.FINISH_RUN_OFF_EXIT_X,
				0.01, "Elias exits fully past the right edge")
			_check(world.results.visible, "the finish shows the results overlay")
			_check_eq(world.results.title_label.text, "MADE IT TO CLASS!",
				"a finished campaign reads MADE IT!")
			_check_eq(world.results.stat_text("distance"), "FINISH",
				"a finished run reports the line, not a distance")
			_check_eq(world.results.awarded_medal(), GameConfig.Medal.SILVER,
				"a first clear medals silver")
			_check_eq(world.run_off_start_count, 1, "one run-off per finish")
			_check_eq(world.run_off_finish_count, 1, "one hand-off to the results")
			world._finish_campaign()
			_check_eq(world.run_off_start_count, 1,
				"a second finish call cannot restart the run-off")
			_check_eq(world.results.title_label.text, "MADE IT TO CLASS!",
				"the finish reports exactly once")

			# Campaign spawn cutoff: the last stretch before the line is clear.
			var campaign_world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
			add_child(campaign_world)
			var far := campaign_world.get_node("RunWorld") as RunWorld
			far.begin_run()
			far.set_run_mode(GameConfig.RunMode.CAMPAIGN)
			far.distance = far.campaign_finish_distance \
				- GameConfig.CAMPAIGN_SPAWN_CUTOFF_PX + 50.0
			# Two quarter-second ticks: the ramp puts the last stretch near
			# 566 px/s, so a third tick would cross the line and end the run.
			for i in 2:
				far._physics_process(0.25)
			_check(far.is_running, "the run is still live inside the spawn cutoff")
			_check_eq(far.hazards.get_child_count(), 0,
				"the spawn cutoff band spawns nothing")
			far.distance = 0.0
			for i in 8:
				far._physics_process(0.25)
			_check(far.hazards.get_child_count() > 0,
				"the course keeps spawning before the cutoff")

			# Drive-to-finish: cross the line through real physics ticks, not a
			# direct _finish_campaign call, so the threshold itself is proven.
			# Start two seconds out; the player is made untouchable and the
			# pursuer parked so nothing can end the run early.
			GameState.best_campaign = 0
			far.set_run_mode(GameConfig.RunMode.CAMPAIGN)
			far.pursuer.state = Pursuer.State.DORMANT
			far.pursuer.gap = GameConfig.PURSUER_DORMANT_GAP
			far.player.invulnerable_time_left = 9999.0
			far.distance = far.campaign_finish_distance \
				- GameConfig.RUN_SPEED * GameConfig.CAMPAIGN_RAMP_MAX_MULTIPLIER * 2.0
			for i in 45:
				far.player.invulnerable_time_left = 9999.0
				far._physics_process(1.0 / 60.0)
			_check(far.is_running, "the run is still live two seconds before the line")
			_check(not far.results.visible,
				"no results two seconds before the line")
			_check(far._finish_debug_text().length() > 0,
				"the finish readout is available")
			# Tick until the line is crossed instead of assuming a frame count:
			# the tuned ramp changes how long two seconds of road actually takes.
			var crossed := false
			for i in 300:
				far.player.invulnerable_time_left = 9999.0
				far._physics_process(1.0 / 60.0)
				if not far.is_running:
					crossed = true
					break
			_check(crossed, "physics crossing the line stops the run")
			_check(far.run_off_active, "physics crossing the line begins the run-off")
			_check(not far.results.visible,
				"physics crossing keeps the results hidden during the exit")
			var crossed_distance := far.distance
			# 2000 px of exit at ~1418 px/s is ~1.4 s; give the guard plenty.
			for i in 240:
				far._physics_process(1.0 / 60.0)
			_check(not far.run_off_active, "the physics run-off completes")
			_check_near(far.distance, crossed_distance, 0.001,
				"the world stays frozen through the run-off")
			_check(far.results.visible, "physics crossing the line shows the results")
			_check_eq(far.results.title_label.text, "MADE IT TO CLASS!",
				"a physics-driven finish reads MADE IT!")
			_check_eq(far.fail_cue_play_count, 0,
				"a victory never queues the fail cue")
			_check(not far.fail_sting.playing, "the victory reveal is silent")
			_check(not far.fail_music.playing, "no fail bed under a victory")
			_check(far.distance < far.campaign_finish_distance + GameConfig.RUN_SPEED,
				"the world froze within a second of the line")
			_check_eq(far.results.awarded_medal(), GameConfig.Medal.SILVER,
				"a physics-driven first clear medals silver")
			_check(far.results.stat_text("score").length() > 0,
				"the finish reports a score")
			campaign_world.queue_free()

		if world.player != null:
			# Item pickup + damage resets the combo through the world wiring.
			world.score_system.add_item_pickup()
			world.score_system.add_item_pickup()
			_check_eq(world.score_system.chain, 2, "world pickups build the chain")
			world.player.invulnerable_time_left = 0.0
			world.player.take_damage()
			world._on_player_damaged(2)
			_check_eq(world.score_system.chain, 0, "damage resets the combo through the world")
			_check_eq(world.score_system.item_count, 2, "items survive a combo reset")

			# Reaching a rung pays its one-time coin bonus and fires the riser.
			_check(
				world.score_system.tier_reached.is_connected(
					world._on_tier_reached),
				"the world listens for combo rungs",
			)
			var tier_coins_before := world.coins_collected
			var tier_wallet_before := GameState.coins
			var tier_sfx_before := world.tier_up_play_count
			for i in GameConfig.COMBO_THRESHOLD_2:
				world._on_item_collected(GameConfig.ItemKind.PENCIL)
			_check_eq(world.tier_up_play_count, tier_sfx_before + 1,
				"reaching x2 fires the tier riser")
			_check_eq(world.coins_collected, tier_coins_before + 1,
				"reaching x2 pays one coin into the run tally")
			_check_eq(GameState.coins, tier_wallet_before + 1,
				"reaching x2 pays one coin into the wallet")

			# Rebuilding the same rung in the same run must pay nothing.
			world.score_system.reset_combo()
			for i in GameConfig.COMBO_THRESHOLD_2:
				world._on_item_collected(GameConfig.ItemKind.PENCIL)
			_check_eq(world.tier_up_play_count, tier_sfx_before + 1,
				"rebuilding the rung does not fire the riser again")
			_check_eq(world.coins_collected, tier_coins_before + 1,
				"rebuilding the rung does not pay again")
			_check_eq(GameState.coins, tier_wallet_before + 1,
				"rebuilding the rung does not add wallet coins")
			world.score_system.reset_combo()

			for i in GameConfig.MAX_HEARTS:
				world.player.invulnerable_time_left = 0.0
				world.player.take_damage()
			_check_eq(world.player.health, 0, "three hits empty the hearts")
			_check(not world.is_running, "the run stops when the last heart is lost")
			_check(world.results.visible, "the game over overlay appears on death")
			_check_eq(
				world.hud.get_heart_texture(0).resource_path,
				"res://assets/heart/heart_empty.png",
				"HUD hearts empty out on death",
			)
	main.queue_free()


# --- Helpers -----------------------------------------------------------------

func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _first_key(action: String) -> InputEventKey:
	var events := InputMap.action_get_events(action)
	_check(events.size() > 0, "action '%s' has at least one event" % action)
	return events[0] as InputEventKey


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_ne(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual != expected, "%s (expected NOT %s, got %s)" % [label, expected, actual])


func _check_near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (expected %.3f, got %.3f)" % [label, expected, actual])


func _report() -> void:
	print("%d checks, %d failure(s)" % [_checks, _failures])
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("TESTS FAILED")
	get_tree().quit(0 if _failures == 0 else 1)
