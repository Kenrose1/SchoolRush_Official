extends Node
## Seeded headless sweep of the endless ramp: plays whole runs with
## SolvabilityBot and reports whether every row was beatable.
##
## Run with:
##   godot --headless --fixed-fps 60 --path . res://tools/solvability_bot.tscn -- --seeds 5
##
## Options (after the bare --):
##   --seeds N        how many seeds to play (default 3)
##   --first-seed N   first seed value (default 1)
##   --target PX      distance that counts as surviving the ramp (default: both
##                    endless ramps bottomed out, 123,600 px)
##   --lane-lock S    seconds a lane change locks the next (default 0: the
##                    rules set no cooldown, so the bot plays the strongest
##                    legal line; 0.16 models a human's glide instead)
##   --jump           let the bot jump (default off: a lane change is free and
##                    a jump is 0.54 s in the air, so the strongest line for
##                    "can this row be beaten" never leaves the ground)
##   --quiet          only print the summary
##
## A death is printed with the contacts and the last decisions that led to it,
## so a failure is a specific row to inspect, not just a distance.
##
## Exit code 0 means every seed reached the target with no death and no frame
## where all three lanes were already occupied.

const MAIN_SCENE := preload("res://scenes/main.tscn")
## Scratch save: this audit must never touch the player's real wallet, upgrades
## or bests, so the whole sweep runs against a throwaway file and never saves.
const SCRATCH_SAVE := "user://solvability_bot_scratch.cfg"
## Safety net: a run that somehow never ends is cut off here.
const MAX_RUN_SECONDS := 600.0

var _seeds: int = 3
var _first_seed: int = 1
var _target: float = SolvabilityBot.DEFAULT_TARGET
var _quiet: bool = false
## 0 = strongest legal play (a lane change has no cooldown in this game); a
## positive value models a human's glide between lane changes.
var _lane_lock: float = 0.0
## Off by default: a lane change is free and a jump is 0.54 s of road in the
## air, so the strongest line for "can this row be beaten" stays grounded.
var _use_jump: bool = false
var _reports: Array[Dictionary] = []


func _ready() -> void:
	_parse_args()
	var real_save := GameState.save_path
	var real_levels: Dictionary = GameState.shop_levels.duplicate()
	var real_coins := GameState.coins
	var real_mode := GameState.mode

	GameState.save_path = SCRATCH_SAVE
	GameState.shop_levels = {}
	GameState.coins = 0
	GameState.mode = GameConfig.RunMode.ENDLESS

	print("School Rush - endless solvability sweep")
	print("  seeds %d..%d   target %s px (%d m)   fixed 60 Hz   lane lock %.2f s" % [
		_first_seed, _first_seed + _seeds - 1,
		_thousands(int(_target)), int(_target / 100.0), _lane_lock])

	var started := Time.get_ticks_msec()
	for i in _seeds:
		var report := await _play(_first_seed + i)
		_reports.append(report)
		if not _quiet:
			print(_format_seed(report))
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	var failed := _print_summary(elapsed)

	GameState.save_path = real_save
	GameState.shop_levels = real_levels
	GameState.coins = real_coins
	GameState.mode = real_mode
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SCRATCH_SAVE + suffix):
			DirAccess.remove_absolute(SCRATCH_SAVE + suffix)
	get_tree().quit(1 if failed else 0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				_seeds = maxi(int(args[i + 1]) if i + 1 < args.size() else _seeds, 1)
			"--first-seed":
				_first_seed = int(args[i + 1]) if i + 1 < args.size() else _first_seed
			"--target":
				_target = float(args[i + 1]) if i + 1 < args.size() else _target
			"--quiet":
				_quiet = true
			"--lane-lock":
				_lane_lock = float(args[i + 1]) if i + 1 < args.size() else _lane_lock
			"--jump":
				_use_jump = true


## Play one seeded endless run to the target (or to a death) and hand back the
## bot's report.
func _play(seed_value: int) -> Dictionary:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld
	world.set_run_mode(GameConfig.RunMode.ENDLESS)
	# Re-seed the director: _ready already primed it from the clock.
	world.director.setup(world.hazards, seed_value)
	world.begin_run()

	var bot := SolvabilityBot.new()
	bot.target_distance = _target
	bot.lane_lock_time = _lane_lock
	bot.use_jump = _use_jump
	# A child of the world, so its decision runs after the world's own frame.
	world.add_child(bot)
	bot.attach(world)
	bot.start()

	var deadline := Time.get_ticks_msec() + int(MAX_RUN_SECONDS * 1000.0)
	while not bot.is_done():
		await get_tree().physics_frame
		if Time.get_ticks_msec() > deadline:
			break

	var report := bot.report()
	report["seed"] = seed_value
	report["timed_out"] = not bot.is_done()
	main.queue_free()
	await get_tree().process_frame
	return report


func _format_seed(report: Dictionary) -> String:
	var metres := int(float(report["distance"]) / 100.0)
	var seen: String = _format_kinds(report["hazards_seen"] as Dictionary)
	var head := "  seed %-4d %s  reached %s px (%d m) in %.1f s" % [
		int(report["seed"]),
		"PASS" if report["reached"] else "FAIL",
		_thousands(int(float(report["distance"]))),
		metres,
		float(report["seconds"]),
	]
	var body := "hazards %d [%s]  jumps %d  slides %d  switches %d  hits %d" % [
		int(report["hazards_passed"]), seen, int(report["jumps"]),
		int(report["slides"]), int(report["lane_switches"]), int(report["hits"]),
	]
	var tail := "tightest %d escape route(s) at %s px" % [
		int(report["min_free_lanes"]),
		_thousands(int(float(report["tightest_distance"]))),
	]
	if int(report["no_path_frames"]) > 0:
		tail += "   pinned at %s px (%d frames with no legal lane)" % [
			_thousands(int(float(report["no_path_distance"]))),
			int(report["no_path_frames"]),
		]
		tail += "\n        pinned by: %s" % str(report["pinned_report"])
	var lines := "%s\n        %s\n        %s" % [head, body, tail]
	for hit: Dictionary in (report["hit_log"] as Array):
		lines += "\n        hit at %s px: %s lane %d, air %s slide %s lock %.2f\n          %s" % [
			_thousands(int(float(hit["distance"]))),
			String(GameConfig.HazardKind.keys()[int(hit["kind"])]),
			int(hit["lane"]), "yes" if bool(hit["in_air"]) else "no",
			"yes" if bool(hit["sliding"]) else "no", float(hit["lane_lock"]),
			str(hit["threats"]),
		]
		for contact: String in (hit["contacts"] as Array):
			lines += "\n            contact: %s" % contact
		for decision: String in (hit["decisions"] as Array):
			lines += "\n            decided: %s" % decision
	if not (report["death"] as Dictionary).is_empty():
		lines += "\n        died in lane %s near %s" % [
			report["death"].get("lane", "?"),
			str(report["death"].get("nearby", [])),
		]
	return lines


func _format_kinds(seen: Dictionary) -> String:
	var parts: Array[String] = []
	for key: String in seen:
		parts.append("%s %d" % [key, int(seen[key])])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _print_summary(elapsed: float) -> bool:
	var passed := 0
	var deaths := 0
	var boxed_in := 0
	var pinned := 0
	var pinned_earliest := 0.0
	var tightest := GameConfig.LANE_COUNT
	for report in _reports:
		if bool(report["reached"]):
			passed += 1
		if not (report["death"] as Dictionary).is_empty():
			deaths += 1
		if int(report["min_free_lanes"]) <= 0:
			boxed_in += 1
		if int(report["no_path_frames"]) > 0:
			pinned += 1
			var at := float(report["no_path_distance"])
			if pinned_earliest <= 0.0 or at < pinned_earliest:
				pinned_earliest = at
		tightest = mini(tightest, int(report["min_free_lanes"]))

	print("")
	print("  %d/%d seeds reached %s px (%d m)" % [
		passed, _reports.size(), _thousands(int(_target)), int(_target / 100.0)])
	print("  deaths %d   runs with zero escape routes %d" % [deaths, boxed_in])
	print("  fewest escape routes seen in any frame: %d" % tightest)
	if pinned > 0:
		print("  runs with a pinned frame (no lane reachable for the next 1.4 s): %d, earliest at %s px" % [
			pinned, _thousands(int(pinned_earliest))])
	else:
		print("  runs with a pinned frame: 0 (every loss had a lane he could have taken)")
	print("  sweep took %.1f s of wall clock" % elapsed)
	var failed := passed != _reports.size()
	print("  RESULT: %s" % ("FAIL - the bot did not survive the ramp; the traces above "
		+ "show the rows it lost to" if failed
		else "PASS - the bot survived every row the ramp generated"))
	return failed


func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0:
			out += ","
		out += text[i]
	return ("-" if value < 0 else "") + out
