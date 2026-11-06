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

	_section("Input map")
	_test_input()

	_section("Player")
	await _test_player()

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

	# Presentation.
	var frames := player.sprite.sprite_frames
	_check(frames != null, "player builds sprite frames")
	if frames != null:
		_check_eq(frames.get_animation_names().size(), 5, "five Elias animations exist")
		_check_eq(frames.get_frame_count("run"), 7, "run animation has 7 frames")
		_check_eq(frames.get_frame_count("jump"), 3, "jump animation has 3 frames")
		_check_eq(frames.get_frame_count("slide"), 4, "slide animation has 4 frames")
	player._physics_process(1.0 / 60.0)
	_check_eq(player.sprite.animation, &"run", "running animation tracks the ground state")

	player.queue_free()


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
		_check(world.player != null, "run world contains the player")
		_check_near(world.speed, GameConfig.RUN_SPEED, 0.01, "run world starts at RUN_SPEED")
	main.queue_free()


# --- Helpers -----------------------------------------------------------------

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
