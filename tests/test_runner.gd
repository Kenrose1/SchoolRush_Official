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


func _ready() -> void:
	await get_tree().process_frame

	_section("GameConfig")
	_test_config()

	_section("Zones")
	_test_zones()

	_section("Input map")
	_test_input()

	_section("Player")
	await _test_player()

	_section("Health")
	_test_health()

	_section("Hazards")
	await _test_hazard()

	_section("Spawn director")
	_test_spawn_director()

	_section("Score system")
	_test_score_system()

	_section("School Items")
	await _test_collectible()

	_section("Pickup director")
	_test_pickup_director()

	_section("Pursuer")
	await _test_pursuer()

	_section("Scenes")
	_test_scenes()

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
	_check_eq(GameConfig.format_speed(315.0), "315 px/s", "speed reads in px/s")
	_check_eq(GameConfig.format_distance(1638.0), "16.4 m", "distance reads in metres")
	_check_eq(GameConfig.format_distance(0.0), "0.0 m", "distance starts at zero")
	_check_eq(
		GameConfig.ZONE_SPEED_FACTOR.size(),
		GameConfig.ZONE_ORDER.size(),
		"every zone has a pace",
	)
	_check_near(
		GameConfig.zone_run_speed(GameConfig.Zone.HOME),
		GameConfig.RUN_SPEED,
		0.01,
		"home runs at the base speed",
	)
	_check(
		GameConfig.zone_run_speed(GameConfig.Zone.STREET) > GameConfig.zone_run_speed(GameConfig.Zone.HOME)
		and GameConfig.zone_run_speed(GameConfig.Zone.SCHOOL) > GameConfig.zone_run_speed(GameConfig.Zone.STREET),
		"each zone change steps the pace up",
	)
	_check_near(
		GameConfig.max_run_speed(),
		GameConfig.zone_run_speed(GameConfig.Zone.SCHOOL),
		0.01,
		"the fastest pace drives the speed meter",
	)
	_check(GameConfig.UI_BUTTON_TILE > 0, "the UI atlas tile size is positive")
	_check(
		ResourceLoader.exists(GameConfig.UI_BUTTON_TEXTURE),
		"the UI button atlas is on disk",
	)


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
	_check(GameConfig.ZONE_FADE_TIME > 0.0, "zone fade has a length")
	_check_near(
		GameConfig.zone_home_length(),
		GameConfig.ZONE_HOME_DURATION_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"home length derives from duration and speed",
	)

	var length := GameConfig.zone_home_length()
	_check_eq(GameConfig.zone_for_distance(0.0), GameConfig.Zone.HOME, "the run opens at home")
	_check_eq(
		GameConfig.zone_for_distance(length - 1.0),
		GameConfig.Zone.HOME,
		"home holds right up to the boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance(length),
		GameConfig.Zone.STREET,
		"street starts exactly at the boundary",
	)
	var street := GameConfig.zone_street_length()
	_check_near(
		street,
		GameConfig.ZONE_STREET_DURATION_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"street length derives from duration and speed",
	)
	_check_eq(
		GameConfig.zone_for_distance(length + street - 1.0),
		GameConfig.Zone.STREET,
		"street holds right up to the boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance(length + street),
		GameConfig.Zone.SCHOOL,
		"school starts exactly at the street boundary",
	)
	_check_eq(
		GameConfig.zone_for_distance((length + street) * 10.0),
		GameConfig.Zone.SCHOOL,
		"school is terminal",
	)

	var custom := GameConfig.zone_home_length(20.0)
	_check_near(custom, 20.0 * GameConfig.RUN_SPEED, 0.01, "a custom duration scales the boundary")
	_check_near(
		GameConfig.zone_home_length(0.5),
		GameConfig.ZONE_HOME_MIN_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"home duration clamps at the minimum",
	)
	_check_near(
		GameConfig.zone_street_length(0.5),
		GameConfig.ZONE_STREET_MIN_SECONDS * GameConfig.RUN_SPEED,
		0.01,
		"street duration clamps at the minimum",
	)
	_check_eq(
		GameConfig.zone_for_distance(custom, custom),
		GameConfig.Zone.STREET,
		"a per-run override moves the boundary",
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
	_check_near(
		GameConfig.SCHOOL_FLOOR_SPLIT_RATIO,
		GameConfig.SCHOOL_FLOOR_SPLIT_Y / GameConfig.SCHOOL_SOURCE_HEIGHT,
		0.0001,
		"the school floor split ratio survives a texture downscale",
	)
	var school_split_px := GameConfig.SCHOOL_FLOOR_SPLIT_RATIO * GameConfig.SCHOOL_SOURCE_HEIGHT
	_check(
		school_split_px > 0.0 and school_split_px < GameConfig.SCHOOL_SOURCE_HEIGHT,
		"the school floor split lands inside the hallway texture",
	)
	_check(
		GameConfig.SCHOOL_WALL_START_Y >= 0.0
			and GameConfig.SCHOOL_WALL_START_RATIO < GameConfig.SCHOOL_FLOOR_SPLIT_RATIO,
		"the corridor wall slice starts above the floor line",
	)
	_check(
		GameConfig.SCHOOL_END_FLOOR_SPLIT_RATIO > 0.0
			and GameConfig.SCHOOL_END_FLOOR_SPLIT_RATIO < 1.0,
		"the endgame floor split lands inside its art",
	)
	_check(
		GameConfig.SCHOOL_EXIT_X_FRACTION > 0.0 and GameConfig.SCHOOL_EXIT_X_FRACTION < 1.0,
		"the exit door fraction lands inside the endgame art",
	)
	_check(
		GameConfig.FINALE_RUN_SPEED > 0.0
			and GameConfig.zone_school_length()
				>= GameConfig.ZONE_SCHOOL_MIN_SECONDS * GameConfig.RUN_SPEED,
		"the corridor lasts at least the minimum before the finale",
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
		_check(
			ResourceLoader.exists(world.SCHOOL_TEXTURE)
				and world.SCHOOL_TEXTURE.ends_with("newschoolhallway_glass.png"),
			"the corridor uses the cut-out new school hallway art",
		)
		var corridor_art := load(world.SCHOOL_TEXTURE) as Texture2D
		if corridor_art != null:
			var art_image := corridor_art.get_image()
			var clear_pixels := 0
			for y in range(120, 220, 4):
				for x in range(0, art_image.get_width(), 20):
					if art_image.get_pixel(x, y).a < 0.5:
						clear_pixels += 1
			_check(
				clear_pixels > 20,
				"the corridor windows are cut out for the campus parallax",
			)
		_check(
			ResourceLoader.exists(world.SCHOOL_CAMPUS_TEXTURE),
			"the school campus panorama is on disk",
		)
		_check(
			ResourceLoader.exists(GameConfig.SCHOOL_END_TEXTURE),
			"the endgame hallway art is on disk",
		)
		_check_near(
			world.school_zone_length,
			GameConfig.zone_school_length(),
			0.01,
			"the world derives its school boundary",
		)
		_check(
			world._finale_distance()
				> world.home_zone_length + world.street_zone_length,
			"the endgame hallway comes after the school corridor",
		)
		_check(
			GameConfig.school_exit_x() > GameConfig.PLAYER_X
				and GameConfig.school_exit_x() < GameConfig.DESIGN_WIDTH,
			"the exit door stands on the final screen, ahead of the player",
		)
		_check(
			world.SCHOOL_CAMPUS_PARALLAX < world.SCHOOL_WALL_PARALLAX,
			"the campus drifts slower than the corridor (mirror parallax)",
		)
		_check_eq(
			world.SCHOOL_WALL_PARALLAX,
			world.SCHOOL_FLOOR_PARALLAX,
			"school wall and floor scroll in lockstep",
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

		var fade: ColorRect = world._zone_fade
		_check(fade != null, "the world owns a zone fade rect")
		if fade != null:
			_check_eq(fade.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the zone fade ignores the mouse")
			var fade_layer := fade.get_parent() as CanvasLayer
			_check(fade_layer != null, "the zone fade lives in a CanvasLayer")
			if fade_layer != null:
				_check(fade_layer.layer > 0, "the fade layer draws above the world")
			_check_near(fade.anchor_right, 1.0, 0.001, "the zone fade spans the viewport width")
			_check_near(fade.anchor_bottom, 1.0, 0.001, "the zone fade spans the viewport height")
			_check_near(fade.color.a, 0.0, 0.001, "the zone fade starts transparent")

			# Force the boundary and hold the clock; no frames pass here.
			var seen: Array = []
			world.zone_changed.connect(func(zone: GameConfig.Zone) -> void: seen.append(zone))
			world.distance = world.home_zone_length + 1.0
			world._update_zone()
			_check_eq(world.current_zone, GameConfig.Zone.STREET, "crossing the boundary switches to street")
			_check_eq(seen.size(), 1, "the zone change emits exactly once")
			if seen.size() == 1:
				_check_eq(seen[0], GameConfig.Zone.STREET, "the signal reports the street")
			_check_near(fade.color.a, 1.0, 0.001, "the fade covers the screen at the swap")
			_check_near(
				world._zone_fade_time_left,
				GameConfig.ZONE_FADE_TIME,
				0.001,
				"the fade clock starts at ZONE_FADE_TIME",
			)

			world._process(GameConfig.ZONE_FADE_TIME * 0.5)
			_check_near(fade.color.a, 0.5, 0.01, "the fade eases out over its duration")
			world._process(GameConfig.ZONE_FADE_TIME)
			_check_near(fade.color.a, 0.0, 0.001, "the fade clears when the clock runs out")
			_check_near(world._zone_fade_time_left, 0.0, 0.001, "the fade clock stops at zero")

			world._update_zone()
			_check_near(fade.color.a, 0.0, 0.001, "the street is stable (no repeat fade)")

			world.distance = world.home_zone_length + world.street_zone_length + 1.0
			world._update_zone()
			_check_eq(
				world.current_zone,
				GameConfig.Zone.SCHOOL,
				"crossing the street boundary switches to school",
			)
			_check_eq(seen.size(), 2, "the school change emits exactly once")
			if seen.size() == 2:
				_check_eq(seen[1], GameConfig.Zone.SCHOOL, "the signal reports the school")
			_check_near(fade.color.a, 1.0, 0.001, "the fade covers the screen at the school swap")
			world._process(GameConfig.ZONE_FADE_TIME)
			_check_near(fade.color.a, 0.0, 0.001, "the school fade clears")
			world._update_zone()
			_check_near(fade.color.a, 0.0, 0.001, "the school is terminal (no third fade)")

			# The run ends on the endgame hallway: the scroll stops there and
			# Elias covers the last stretch to the exit door himself.
			world.is_running = true
			world.distance = world._finale_distance() - 10.0
			world._physics_process(0.5)
			_check(world.finale_started, "running out of corridor starts the finale")
			_check_near(
				world.distance,
				world._finale_distance(),
				0.001,
				"the scroll stops exactly on the endgame hallway",
			)
			var door_offset := world._door_offset()
			_check(door_offset > 0.0, "the exit door stands ahead of the player")
			world._physics_process(0.5)
			_check(
				world.player.forward_offset > 0.0
					and world.player.forward_offset < door_offset,
				"Elias covers the last stretch himself",
			)
			_check(
				world.player.depth_scale < 1.0
					and world.player.depth_scale > GameConfig.FINALE_DEPTH_SCALE,
				"the doorway shrink follows the dash",
			)
			world._physics_process(3.0)
			_check_near(
				world.player.forward_offset,
				door_offset,
				0.001,
				"Elias covers the full stretch to the door",
			)
			_check_near(
				world.player.position.x,
				GameConfig.school_exit_x(),
				0.5,
				"Elias stops in the doorway",
			)
			_check_near(
				world.player.position.y,
				world._door_threshold_y(),
				0.5,
				"Elias stands on the door threshold, not on his lane",
			)
			_check(
				world._door_threshold_y() < GameConfig.lane_y(GameConfig.LANE_MIDDLE),
				"the doorway sits above the lane Elias was running in",
			)
			_check_near(
				world.player.depth_scale,
				GameConfig.FINALE_DEPTH_SCALE,
				0.001,
				"Elias is fully receded by the time he reaches the door",
			)
			_check_near(
				world.player.sprite.scale.x,
				GameConfig.PLAYER_SCALE * GameConfig.FINALE_DEPTH_SCALE,
				0.001,
				"the recede shows on the sprite",
			)
			_check(not world.is_running, "reaching the door ends the run")
			_check(world.escape_label.visible, "the finished run shows the escape overlay")
			_check(not world.caught_label.visible, "the finish is not a catch")
			_check(not world.game_over_label.visible, "the finish is not a loss")
	main.queue_free()


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
		_check_eq(frames.get_animation_names().size(), 5, "five Elias animations exist")
		_check_eq(frames.get_frame_count("run"), 12, "run animation has 12 frames")
		_check_eq(frames.get_frame_count("jump"), 3, "jump animation has 3 frames")
		_check_eq(frames.get_frame_count("slide"), 4, "slide animation has 4 frames")
		var first_run := frames.get_frame_texture("run", 0)
		_check(first_run != null, "run frame 0 has a texture")
		if first_run != null:
			_check(first_run.resource_path.ends_with("run_new_01.png"), "run frame 0 is run_new_01.png")
		var last_run := frames.get_frame_texture("run", 11)
		_check(last_run != null, "run frame 11 has a texture")
		if last_run != null:
			_check(last_run.resource_path.ends_with("run_new_12.png"), "run frame 11 is run_new_12.png")
		_check(frames.get_animation_loop("run"), "run animation loops")
		_check(not frames.get_animation_loop("jump"), "jump animation does not loop")
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

	_check(player.take_damage(), "the first hit lands")
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "the first hit removes one heart")
	_check_eq(damaged_events.size(), 1, "damaged fires once")
	_check_eq(health_events.size(), 2, "health_changed fires on damage")
	_check_near(player.invulnerable_time_left, GameConfig.I_FRAME_TIME, 0.001, "a hit starts the i-frame window")
	_check(not player.can_take_damage(), "the player is invulnerable right after a hit")
	_check(not player.take_damage(), "a hit inside the i-frame window is ignored")
	_check_eq(player.health, GameConfig.MAX_HEARTS - 1, "the ignored hit costs no heart")

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

	player.reset_health()
	_check_eq(player.health, GameConfig.MAX_HEARTS, "reset_health restores every heart")
	_check_eq(deaths[0], 1, "reset does not re-fire died")

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
	mover.position.x = GameConfig.DESPAWN_X - 1.0
	mover._physics_process(0.016)
	_check(mover.is_queued_for_deletion(), "hazards despawn behind the player")

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
	# Dog is parked for M4 (weight 0), so 4 kinds spawn.
	_check_eq(late_kinds.size(), GameConfig.HAZARD_DATA.size() - 1, "four kinds spawn once unlocked")


func _test_score_system() -> void:
	# Combo thresholds.
	_check_eq(GameConfig.combo_multiplier(0), 1, "chain 0 is x1")
	_check_eq(GameConfig.combo_multiplier(2), 1, "chain 2 is x1")
	_check_eq(GameConfig.combo_multiplier(3), 2, "chain 3 is x2")
	_check_eq(GameConfig.combo_multiplier(5), 2, "chain 5 is x2")
	_check_eq(GameConfig.combo_multiplier(6), 3, "chain 6 is x3")
	_check_eq(GameConfig.combo_multiplier(9), 3, "chain 9 is x3")
	_check_eq(GameConfig.combo_multiplier(10), 5, "chain 10 is x5")
	_check_eq(GameConfig.combo_multiplier(99), 5, "chain 99 is x5")
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

	# Item pickups: 1-2 x1, 3-5 x2, 6-9 x3, 10 x5.
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
	# 2*50 + 3*100 + 4*150 + 1*250 = 1250
	_check_eq(fresh.score, 1250, "ten pickups score 1250 points")

	# Reset breaks the chain but keeps score and item count.
	fresh.reset_combo()
	_check_eq(fresh.chain, 0, "reset clears the chain")
	_check_eq(fresh.score, 1250, "reset keeps the score")
	_check_eq(fresh.item_count, 10, "reset keeps the item count")
	fresh.add_item_pickup()
	_check_eq(fresh.score, 1300, "pickup after reset is x1 again")
	# reset on an already-empty chain is a no-op (no signal spam / crash).
	fresh.reset_combo()
	fresh.reset_combo()
	_check_eq(fresh.chain, 0, "repeated reset stays at 0")


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


func _test_pursuer() -> void:
	# Config contract.
	_check_near(GameConfig.PURSUER_CHASE_FACTOR, 0.95, 0.001, "chase factor is 95%")
	_check_near(
		GameConfig.RUN_SPEED * GameConfig.PURSUER_CHASE_FACTOR,
		399.0,
		0.01,
		"chase speed is 399 px/s at base",
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
		_check_eq(frames.get_frame_count("arrest"), 7, "arrest has 7 frames")
		_check(not frames.get_animation_loop("arrest"), "arrest does not loop")
	_check_eq(pursuer.sprite.animation, &"idle", "tanod previews the idle animation")

	# Wake.
	var wakes := [0]
	pursuer.chase_started.connect(func() -> void: wakes[0] += 1)
	pursuer.wake()
	_check(pursuer.state == Pursuer.State.CHASE, "wake enters chase")
	_check(pursuer.visible, "pursuer becomes visible on wake")
	_check(pursuer.is_active(), "chasing pursuer is active")
	_check_near(pursuer.gap, GameConfig.PURSUER_WAKE_GAP, 0.01, "wake gap is 700 px")
	_check_eq(wakes[0], 1, "chase_started fires once")
	pursuer.wake()
	_check_eq(wakes[0], 1, "wake during chase is a no-op")
	_check_near(pursuer.gap, GameConfig.PURSUER_WAKE_GAP, 0.01, "wake during chase does not reset gap")

	# Gap dynamics: full speed grows the gap (escape), dip shrinks it (pressure).
	# Factor eases 0.95 -> 1.0 over 10 s, so speed is ~401 at chase_time~1.
	pursuer.set_world_speed(GameConfig.RUN_SPEED)
	var gap_before := pursuer.gap
	pursuer._physics_process(1.0)
	_check(pursuer.gap > gap_before, "full speed pulls away from the tanod")
	_check_near(pursuer.gap, gap_before + 19.0, 3.0, "gap grows ~19 px/s at full speed")

	pursuer.set_world_speed(GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR)
	gap_before = pursuer.gap
	pursuer._physics_process(1.0)
	_check(pursuer.gap < gap_before, "momentum dip lets the tanod gain")
	_check_near(pursuer.gap - gap_before, -86.0, 4.0, "gap shrinks ~86 px/s while dipped")

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
		_check(world.player != null, "run world contains the player")
		_check(world.hazards != null, "run world contains a hazard container")
		_check(world.director != null, "run world contains a spawn director")
		_check(world.hud != null, "run world contains the hearts HUD")
		_check(world.score_hud != null, "run world contains the score HUD")
		_check(world.score_system != null, "run world owns a score system")
		_check(world.pursuer != null, "run world contains the pursuer")
		_check(world.retry_button != null, "the game over screen owns a retry button")
		if world.retry_button != null:
			_check(
				not world.retry_button.is_visible_in_tree(),
				"the retry button starts hidden with the overlay",
			)
			var normal := world.retry_button.texture_normal
			_check(normal is AtlasTexture, "the retry button draws the green atlas face")
			if normal is AtlasTexture:
				var face_tile := GameConfig.UI_BUTTON_TILE
				_check_eq(
					(normal as AtlasTexture).region,
					Rect2(
						float(GameConfig.UI_BUTTON_FACE_TILE.x * face_tile),
						float(GameConfig.UI_BUTTON_FACE_TILE.y * face_tile),
						float(face_tile),
						float(face_tile),
					),
					"the retry button picks the plain green tile",
				)
			_check(world.retry_icon != null, "the retry button carries an icon")
			if world.retry_icon != null:
				var atlas := world.retry_icon.texture as AtlasTexture
				_check(atlas != null, "the retry icon draws an atlas tile")
				if atlas != null:
					var tile := GameConfig.UI_BUTTON_TILE
					_check_eq(
						atlas.region,
						Rect2(
							float(GameConfig.UI_RETRY_TILE.x * tile),
							float(GameConfig.UI_RETRY_TILE.y * tile),
							float(tile),
							float(tile),
						),
						"the retry icon picks the circular arrow tile",
					)
		_check(world.pursuer.state == Pursuer.State.DORMANT, "pursuer starts dormant")
		_check_near(world.speed, GameConfig.RUN_SPEED, 0.01, "run world starts at RUN_SPEED")
		_check_near(
			world.base_speed,
			GameConfig.zone_run_speed(world.current_zone),
			0.01,
			"the world runs at its zone pace",
		)
		_check(not world.caught_label.visible, "caught label starts hidden")
		_check(world.game_over_label.visible, "out-of-hearts label is the default")
		_check_eq(world.score_system.score, 0, "score starts at 0")
		_check(world.is_running, "the run starts running")
		_check(not world.game_over_root.visible, "the game over overlay starts hidden")
		_check_near(world.speed, GameConfig.RUN_SPEED, 0.01, "run world starts at RUN_SPEED")
		if world.player != null:
			_check_eq(
				world.player.sprite.animation,
				&"run",
				"player scene previews the run animation (visible in the editor)",
			)

		if world.score_hud != null:
			_check(
				world.score_hud.get_node_or_null("ProgressPanel") != null,
				"the score HUD builds its progress panel",
			)
			_check(
				world.score_hud.get_node_or_null("ScorePanel") != null,
				"the score HUD builds its score panel",
			)
			var score_panel := world.score_hud.get_node_or_null("ScorePanel") as Control
			var progress_panel := world.score_hud.get_node_or_null("ProgressPanel") as Control
			if score_panel != null and progress_panel != null:
				_check_near(
					progress_panel.size.y,
					score_panel.size.y,
					0.01,
					"the top panels share one height",
				)

			# The control rail holds the green button strip under the left panel.
			var controls := world.get_node_or_null("Controls")
			_check(controls != null, "the HUD builds the control rail")
			if controls != null:
				var rail := controls.get_node_or_null("Rail") as Control
				_check(rail != null, "the rail groups the green buttons")
				if rail != null:
					var buttons := rail.find_children("*", "TextureButton", true, false)
					_check_eq(buttons.size(), 5, "the rail holds every green control")
					for button in buttons:
						var icon := (button as TextureButton).get_node_or_null("Icon") as TextureRect
						_check(
							icon != null and icon.texture != null,
							"every rail button shows a glyph",
						)
						_check(
							(button as TextureButton).pressed.get_connections().size() > 0,
							"every rail button is wired to an action",
						)
					var left_panel := world.hud.get_node_or_null("LeftPanel") as Control
					if left_panel != null:
						_check(
							not left_panel.get_global_rect().intersects(rail.get_global_rect()),
							"the control rail sits outside the hearts panel",
						)
					if score_panel != null:
						_check_near(
							rail.get_global_rect().position.y,
							score_panel.get_global_rect().position.y,
							0.01,
							"the control rail shares the top bar line",
						)
						_check(
							rail.get_global_rect().position.x
								>= score_panel.get_global_rect().end.x,
							"the control rail sits right of the score panel",
						)
				var settings := controls.find_child("Settings", true, false) as Control
				_check(
					settings != null and not settings.visible,
					"the settings card waits closed on the rail layer",
				)
			if score_panel != null and progress_panel != null:
				_check(
					progress_panel.get_global_rect().end.x
						<= score_panel.get_global_rect().position.x,
					"the top panels do not overlap",
				)

			# Sound: one autoload owns every clip, and the end screens can quit.
			var audio := main.get_tree().root.get_node_or_null("GameAudio")
			_check(audio != null, "the audio autoload is registered")
			for clip in ["pickup", "jump", "hit", "ui_click", "finish"]:
				_check(
					ResourceLoader.exists("res://assets/audio/%s.wav" % clip),
					"the %s sound is on disk" % clip,
				)
			if audio != null:
				audio.set("volume", 1.5)
				_check_near(audio.get("volume"), 1.0, 0.0001, "the master volume clamps to 0..1")
				audio.set("volume", GameAudio.DEFAULT_VOLUME)
				_check(audio.call("toggle_muted"), "mute flips on")
				_check(not audio.call("toggle_muted"), "mute flips back off")
				# The rail's mute button must follow that state, glyph and all.
				var mute_button := controls.get_node_or_null(
					"Rail/MuteButton") as TextureButton
				if mute_button != null:
					var mute_icon := mute_button.get_node_or_null("Icon") as TextureRect
					var sound_on := (mute_icon.texture as AtlasTexture).region.position
					audio.set("muted", true)
					controls.call("_apply_state")
					var sound_off := (mute_icon.texture as AtlasTexture).region.position
					audio.set("muted", false)
					controls.call("_apply_state")
					_check(
						sound_on != sound_off
							and (mute_icon.texture as AtlasTexture).region.position == sound_on,
						"the mute glyph follows the sound state",
					)
			var quit_button := world.get_node_or_null(
				"GameOver/Root/QuitButton") as TextureButton
			_check(quit_button != null, "the end screens offer a quit button")
			if quit_button != null:
				_check(
					quit_button.texture_normal != null,
					"the quit button uses the green face",
				)
			var distance_bars := world.score_hud.find_children(
				"ProgressBar", "TextureProgressBar", true, false)
			_check_eq(distance_bars.size(), 1, "the score HUD owns the distance meter")
			if distance_bars.size() == 1:
				_check_eq(
					distance_bars[0].texture_progress.resource_path,
					GameConfig.UI_LOADING_FILL,
					"the distance meter fills with the loading art",
				)
			_check(
				ResourceLoader.exists(GameConfig.UI_LOADING_TRACK),
				"the distance meter loading art is on disk",
			)

		if world.hud != null:
			_check(
				world.hud.get_node_or_null("LeftPanel") != null,
				"the hearts HUD builds its left panel",
			)
			var speed_bars := world.hud.find_children(
				"SpeedBar", "TextureProgressBar", true, false)
			_check_eq(speed_bars.size(), 1, "the hearts HUD owns the speed meter")
			if speed_bars.size() == 1:
				_check_eq(
					speed_bars[0].texture_progress.resource_path,
					GameConfig.UI_SPEED_BAR_FILL,
					"the speed meter fills with the bar art",
				)
			_check(
				ResourceLoader.exists(GameConfig.UI_SPEED_BAR_FILL),
				"the speed meter bar art is on disk",
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
			_check_near(world.speed, GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR, 0.1, "world holds at 315 px/s during the dip")
			for i in 45:
				world._physics_process(1.0 / 60.0)
			_check(
				world.speed > GameConfig.RUN_SPEED * GameConfig.MOMENTUM_DIP_FACTOR
				and world.speed < GameConfig.RUN_SPEED,
				"momentum eases back gradually (%.0f px/s mid-recovery)" % world.speed,
			)
			for i in 60:
				world._physics_process(1.0 / 60.0)
			_check_near(world.speed, GameConfig.RUN_SPEED, 0.1, "momentum recovers after the ease")

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
			_check(world.game_over_root.visible, "caught shows the game over overlay")
			_check(world.caught_label.visible, "caught shows CAUGHT!")
			_check(not world.game_over_label.visible, "caught hides OUT OF HEARTS")

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

			for i in GameConfig.MAX_HEARTS:
				world.player.invulnerable_time_left = 0.0
				world.player.take_damage()
			_check_eq(world.player.health, 0, "three hits empty the hearts")
			_check(not world.is_running, "the run stops when the last heart is lost")
			_check(world.game_over_root.visible, "the game over overlay appears on death")
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


func _check_near(actual: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (expected %.3f, got %.3f)" % [label, expected, actual])


func _report() -> void:
	print("%d checks, %d failure(s)" % [_checks, _failures])
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("TESTS FAILED")
	get_tree().quit(0 if _failures == 0 else 1)
