class_name SolvabilityBot
extends Node
## Autoplay audit: drives a live RunWorld's Elias from hazard state alone.
##
## Every decision reads the same thing a player can see - the hazard nodes on
## screen - and every action goes through the public Player verbs the input map
## calls, on the game's own physics frames. Nothing is re-implemented, so a
## sweep that walks a seeded endless run past the point where both ramps bottom
## out is real evidence about the generated rows: not one death, and not one
## frame where all three lanes were already occupied.
##
## The pure helpers (box maths, threat times, clearance checks) are static so
## the suite can assert them without a world.
##
## Usage: see tools/solvability_bot.gd.

signal finished

## Seconds of clear road a lane needs before it is worth keeping. This is the
## bot's look-ahead: it has to be well longer than a row gap, or it only starts
## looking for a way out once the other lanes are already taken - which is how
## a standing runner gets boxed between a row and a car.
const SAFE_TIME := 1.00
## A replacement lane has to be this much safer than the current one.
const SWITCH_MARGIN := 0.18
## Far hazards are not a decision yet; anything past this is ignored. It has to
## cover the plan horizon, not just the next row, or the search sees gaps that
## are already spoken for by a hazard two rows out.
const LOOKAHEAD_PX := 2600.0
## Height a jump has to clear a hazard box by, so a graze never counts.
const JUMP_MARGIN := 4.0
## Start the jump when contact is this close: late enough that the apex still
## covers the crossing window, early enough to beat a human's reaction.
const JUMP_TRIGGER := 0.30
## Duck this late so SLIDE_DURATION still covers the whole crossing window.
const SLIDE_TRIGGER := 0.10
## How much more road a lane needs before it is worth a lane change, so a
## near-tie never turns into weaving.
const ESCAPE_MARGIN := 0.06
## Lane choice is scored, not thresholded: how much a second of clear road is
## worth against the plan's survival estimate, and a nudge towards one-step
## moves so an equal lane next door is taken over an equal lane two away.
const SCORE_ROAD := 2.0
const SCORE_SURVIVE := 0.5
const SCORE_NEAR := 0.05
## A step needs at least this much road in the lane he lands in. Less than a
## couple of frames is a coin flip, and the coin is his box arriving inside the
## prop's box before either has moved.
const STEP_MIN_LEAD := 0.04
## Extra lead on top of the glide when asking whether the destination will be
## clear on arrival: absorbs the one-frame quantisation of the windows.
const ARRIVAL_PAD := 0.05
## A destination lane has to be clear for longer than the glide, or he arrives
## in its band while its hazard is still in his box. LANE_SWITCH_TIME plus a
## little, since the box is wide and the lean widens it further.
const GLIDE_SAFE_TIME := GameConfig.LANE_SWITCH_TIME + 0.08
## Lane planning: how far ahead the search looks, and the grid it looks on.
## One lane change is allowed per step; a change takes TRANSIT_TIME before his
## band has left the old lane and reached the new one.
## The horizon has to cover two or three rows: with a shorter one the bot sees
## a row arriving in the destination, leaves, sees the row it left, and walks
## into a wall it could have sidestepped by planning once.
const PLAN_HORIZON := 2.4
const PLAN_STEP := 0.1
const TRANSIT_TIME := GameConfig.LANE_SWITCH_TIME
## Padding on Elias's box in the contact maths. He leans 6 degrees while
## changing lanes, so the rotated box is ~12 px wider than HITBOX_SIZE.x; a
## model that trusts the unrotated width calls a lane clear while its corner is
## already touching. This is the difference between dodging and clipping.
const CONTACT_SLACK := 12.0
## Breathing room needed after an action ends before the next hazard in the
## same lane may land there; a shorter gap means the body cannot take it.
const RECOVERY_TIME := 0.10
## Seconds a lane change locks the next one. The rules do not gate lane
## changes - move_lane() is instant and Player has no cooldown - so the audit
## plays lock-free by default: the question is whether a row CAN be beaten, so
## the bot gets the strongest legal line. tools/solvability_bot.gd's
## --lane-lock models a human's 0.16 s glide instead, for a second opinion.
var lane_lock_time: float = 0.0
## Whether the bot is willing to jump. Off by default: a lane change is free and
## instant, while a jump is 0.54 s of road in the air with no duck available, so
## the strongest line for answering "can this row be beaten" never leaves the
## ground. Turn it on to audit the jump itself.
var use_jump: bool = false

## The run being played. Set by attach().
var world: RunWorld = null
## Both endless ramps are fully bottomed out at this distance, so surviving it
## is the strongest statement the ramp allows: max speed and the row-gap floor.
const DEFAULT_TARGET := (
	GameConfig.ROW_GAP_RAMP_DISTANCE + GameConfig.ENDLESS_ROW_GAP_RAMP_DISTANCE
)
## Distance (px) that counts as "the ramp was survived".
var target_distance: float = DEFAULT_TARGET

## Result state, read through report() once finished fires.
var reached: bool = false
var death: Dictionary = {}
var hits: int = 0
## One snapshot per hit: what the bot was doing and what its threat view was,
## so a failure can be read instead of guessed at.
var hit_log: Array[Dictionary] = []
## Ring buffer of the last few box contacts, dumped with a hit.
var contact_log: Array[String] = []
## Ring buffer of the last few decisions, dumped with a hit.
var decision_log: Array[String] = []
var _last_action: String = ""
var _last_threats: Array[Dictionary] = []
## Lane horizons from the last decision, for the failure trace.
var _last_horizon: Array = [0.0, 0.0, 0.0]
## Per-lane x-overlap windows from the current decision, reused while it picks
## a lane so every candidate is judged on the same picture of the road.
var _windows: Array = [[], [], []]
var time_played: float = 0.0
var frames: int = 0
var jumps: int = 0
var slides: int = 0
var lane_switches: int = 0
var hazards_passed: int = 0
## How many of each kind the run actually met, so a pass cannot be a run that
## only saw one easy prop.
var hazards_seen: Dictionary = {}
## Fewest lanes that were free at one instant (3 = never squeezed).
var min_free_lanes: int = GameConfig.LANE_COUNT
## Distance at which that tightest moment happened.
var tightest_distance: float = 0.0
## Frames where only one lane was free; how often the rows actually pinched.
var tight_frames: int = 0
## Frames where the 1.2 s lane search found no lane he could legally stand in
## for even one step: the definition of a row nobody could beat, in this model.
var no_path_frames: int = 0
## First distance at which that happened (0 = never).
var no_path_distance: float = 0.0
## The windows that pinned him, at that first frame, for the report.
var pinned_report: String = ""

var _running: bool = false
var _done: bool = false
var _lane_lock: float = 0.0
## Off by default; --jump turns the arc back on for a second opinion.
var _seen_ids: Dictionary = {}


## Point the bot at a live world and hook the events a report needs.
func attach(run_world: RunWorld) -> void:
	world = run_world
	if world == null:
		return
	world.player.died.connect(_on_player_died)
	world.player.damaged.connect(_on_player_damaged)
	world.director.hazard_passed.connect(_on_hazard_passed)
	# Every box contact, with the exact state it happened in: a hit is otherwise
	# read off positions that have already moved on by the time the signal is out.
	world.player.hitbox.area_entered.connect(_on_area_entered)


## Begin playing. The bot only acts while the world itself says it is live, so
## the countdown, a pause, the death hold and the results card all freeze it.
func start() -> void:
	_running = true


## True once the run ended, by reaching the target or by dying.
func is_done() -> bool:
	return _done


func report() -> Dictionary:
	return {
		"reached": reached,
		"distance": world.distance if world != null else 0.0,
		"target": target_distance,
		"seconds": time_played,
		"frames": frames,
		"death": death,
		"hits": hits,
		"jumps": jumps,
		"slides": slides,
		"lane_switches": lane_switches,
		"hazards_passed": hazards_passed,
		"hazards_seen": hazards_seen.duplicate(),
		"hit_log": hit_log.duplicate(),
		"min_free_lanes": min_free_lanes,
		"tightest_distance": tightest_distance,
		"tight_frames": tight_frames,
		"no_path_frames": no_path_frames,
		"no_path_distance": no_path_distance,
		"pinned_report": pinned_report,
	}


# --- Playing -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _running or _done or world == null:
		return
	# A death or a freeze ends the run for the bot too; the report keeps what
	# happened up to that frame.
	if not world.is_running:
		_finish(false)
		return
	time_played += delta
	frames += 1
	_lane_lock = maxf(_lane_lock - delta, 0.0)

	var hazards := live_hazards()
	_count_new_kinds(hazards)

	if world.distance >= target_distance:
		reached = true
		_finish(true)
		return
	_decide(hazards)
	decision_log.append("d=%.0f L%d t=[%.2f %.2f %.2f] h=[%.2f %.2f %.2f] %s" % [
		world.distance, world.player.lane,
		float(_last_threats[0]["time"]), float(_last_threats[1]["time"]),
		float(_last_threats[2]["time"]),
		float(_last_horizon[0]), float(_last_horizon[1]), float(_last_horizon[2]),
		_last_action])
	if decision_log.size() > 8:
		decision_log.pop_front()


## Hazard children that can still touch Elias (items and warnings are ignored).
## A hazard whose centre is already past him still counts while its tail is
## inside his box: the hit gate is the overlap, not the centre, and forgetting
## that is exactly how a lane change gets him clipped.
func live_hazards() -> Array[Hazard]:
	var out: Array[Hazard] = []
	if world == null:
		return out
	var half_player := GameConfig.HITBOX_SIZE.x * 0.5 + CONTACT_SLACK
	for child in world.hazards.get_children():
		if not child is Hazard:
			continue
		var hazard := child as Hazard
		var half_hazard := (hazard.shape.shape as RectangleShape2D).size.x * 0.5
		if hazard.position.x + half_hazard < GameConfig.PLAYER_X - half_player - 4.0:
			continue
		out.append(hazard)
	return out


func _decide(hazards: Array[Hazard]) -> void:
	var player := world.player
	var threats := lane_threats(hazards)
	_last_threats = threats
	_last_action = "hold"
	_note_tightness(threats)
	var current: Dictionary = threats[player.lane]
	var current_time := lane_time(threats, player.lane)

	# Lane-only policy: stand in the lane with the most road in front of it and
	# leave the moment another lane genuinely beats this one. There is no "safe
	# enough" band on purpose - a lane that is merely comfortable now is exactly
	# where a boxed-in death begins. The one brake is the glide: the hit box only
	# leaves this lane's band after LANE_SWITCH_TIME, so a destination must stay
	# clear for longer than that, or the switch itself is the mistake.
	var windows := _lane_windows(hazards)
	var plan := plan_lanes(windows, player.lane)
	_windows = windows
	_last_horizon = plan["values"]
	# Score a lane on all the road in front of it, then let the search break the
	# ties: an empty lane beats a lane blocked in a second, and between two lanes
	# that both look clear the one the plan survives longer wins. Scoring on the
	# search alone saturates at the horizon and stops the bot moving at all.
	# Every lane is a candidate, not just the two next door: a row covers two
	# lanes, so the only way out can be two lanes away, and holding because the
	# middle lane is blocked is how a pair kills him while an empty lane sits
	# there. Ties keep him where he is, and a single step is preferred over two.
	#
	# Road is measured from the moment his box actually arrives in that band, not
	# from now: the logical lane changes on the frame, but the box crosses in
	# LANE_SWITCH_TIME per lane, so a prop whose window closes before he gets
	# there is not in his way at all.
	var values: Array = plan["values"]
	var safest: int = player.lane
	var safest_score := current_time * SCORE_ROAD + float(values[0]) * SCORE_SURVIVE
	for lane in GameConfig.LANE_COUNT:
		if lane == player.lane:
			continue
		var steps := absi(lane - player.lane)
		var road := lane_time(threats, lane)
		if road <= 0.0:
			continue
		var score := road * SCORE_ROAD
		score += SCORE_SURVIVE * (float(values[lane - player.lane + 1]) if steps == 1 else 0.0)
		if steps == 1:
			score += SCORE_NEAR
		if score > safest_score:
			safest_score = score
			safest = lane
	# A lane search says nothing about ducking, so a beam overhead is not a pin:
	# the duck is instant and free, and counting those frames would overstate
	# how often the ramp shuts every lane.
	var duck_available := current["hazard"] != null \
		and (current["hazard"] as Hazard).requires_slide
	if bool(plan["dead"]) and not duck_available:
		# No first move survives even a step of the plan, and nothing on the body
		# saves him: the row is genuinely unsurvivable. Record it, then fall back
		# to the lane with the most road so a bad model cannot fake a wall.
		no_path_frames += 1
		if no_path_distance <= 0.0:
			no_path_distance = world.distance
			pinned_report = _windows_report(windows)
		for lane in GameConfig.LANE_COUNT:
			if lane_time(threats, lane) > lane_time(threats, safest):
				safest = lane
	if _lane_lock <= 0.0 and safest != player.lane:
		# Judge the lane he lands in, not the one he crosses. A pair of lanes can
		# be shut while the third is wide open, and crossing the shut one is free:
		# the hit gate is the lane he is in at the end of the frame, so two taps in
		# one frame are a legal escape the middle lane cannot take away.
		var target_road := lane_time(threats, safest)
		var desperate := current_time <= 0.0
		if (desperate or target_road > STEP_MIN_LEAD) and (desperate
				or target_road > GLIDE_SAFE_TIME or target_road > current_time + ESCAPE_MARGIN):
			_last_action = "plan->%d" % safest
			_switch_toward(safest)
			return

	var hazard: Hazard = current["hazard"]
	var start := float(current["start"])
	var end := float(current["end"])

	# Nothing better to move to. A beam already overhead is still survivable:
	# the duck shrinks his box on the same frame, so it needs no lead time.
	if hazard != null and hazard.requires_slide and not player.is_sliding \
			and start <= 0.05 and not player.in_air:
		if player.slide():
			slides += 1
			_last_action = "duck"
		return

	# Otherwise the lane has to be survived in place. Only spend the body when
	# the action's whole lifetime is clear: a jump is 0.54 s of road and a prop
	# landing inside it is the one thing he cannot dodge from the air.
	if hazard == null or player.in_air:
		return
	var hold_until := end
	if hazard.requires_slide:
		hold_until = maxf(end, SLIDE_TRIGGER + GameConfig.SLIDE_DURATION)
	else:
		hold_until = maxf(end, JUMP_TRIGGER + GameConfig.JUMP_AIRTIME)
	var follow := _follow_up(hazard, threats)
	var follow_time := INF if follow == null else overlap_times(follow).x
	if follow_time < hold_until + RECOVERY_TIME:
		return
	if hazard.requires_slide:
		if start <= SLIDE_TRIGGER and player.slide():
			slides += 1
			_last_action = "slide"
		return
	if use_jump and not player.is_sliding and jump_can_clear(hazard, start, end):
		if start <= JUMP_TRIGGER and jump_covers(hazard, start, end):
			if player.jump():
				jumps += 1
				_last_action = "jump"


## Per-lane x-overlap windows from now, in seconds: when a lane's road is
## physically taken by a hazard's box (lean slack included).
func _lane_windows(hazards: Array[Hazard]) -> Array:
	var windows: Array = [[], [], []]
	for hazard in hazards:
		if hazard.lane < 0 or hazard.lane >= GameConfig.LANE_COUNT:
			continue
		# A beam is not a wall: ducking shrinks his box on the frame it matters,
		# at no cost and with no lead time. Counting beams here would tell the
		# search every lane is shut whenever three beams line up, and a "pinned"
		# frame has to mean nothing could have saved him - not "he had to duck".
		if hazard.requires_slide:
			continue
		var times := overlap_times(hazard)
		if times.y <= 0.0:
			continue
		windows[hazard.lane].append(times)
	return windows


## Clear seconds from `from_time` until the next window opens in this lane; 0
## when a window already covers that moment.
static func lane_road(windows: Array, from_time: float) -> float:
	if _blocked_at(windows, from_time):
		return 0.0
	var road := INF
	for window: Vector2 in windows:
		if window.x >= from_time:
			road = minf(road, window.x - from_time)
	return road


## The per-lane windows at a pinned frame, as text: the evidence that a frame
## really had no lane free rather than the model just disliking the options.
static func _windows_report(windows: Array) -> String:
	var parts: Array[String] = []
	for lane in GameConfig.LANE_COUNT:
		var spans: Array[String] = []
		for window: Vector2 in windows[lane]:
			spans.append("%.2f-%.2f" % [window.x, window.y])
		parts.append("L%d %s" % [lane, "none" if spans.is_empty() else ", ".join(spans)])
	return " | ".join(parts)


static func _blocked_at(windows: Array, moment: float) -> bool:
	for window: Vector2 in windows:
		if window.x <= moment and moment <= window.y:
			return true
	return false


static func _blocked_span(windows: Array, from_time: float, to_time: float) -> bool:
	for window: Vector2 in windows:
		if window.x <= to_time and from_time <= window.y:
			return true
	return false


## Score each legal first move by how long the player survives from there, over
## the next PLAN_HORIZON seconds: stay put while a lane stays clear, or step
## sideways when the destination stays clear for the whole glide. Returns
## {"best": lane, "values": [stay, up, down], "dead": bool}, where a value is
## the seconds survived under that first move and "dead" means even the best
## move runs out inside the horizon. Picking the first move by survival time is
## what stops the bot stepping out of one row into the next one.
static func plan_lanes(windows: Array, start_lane: int) -> Dictionary:
	var steps := int(round(PLAN_HORIZON / PLAN_STEP))
	var alive: Array = []
	for i in steps + 1:
		alive.append([false, false, false])
	alive[0][start_lane] = true
	for step in steps:
		var moment := float(step + 1) * PLAN_STEP
		for lane in GameConfig.LANE_COUNT:
			if not alive[step][lane]:
				continue
			if not _blocked_at(windows[lane], moment):
				alive[step + 1][lane] = true
			# One or two lanes in a step: the rules set no cooldown, so the bot
			# crosses two in one frame and the search must not call that a wall.
			for distance in [1, 2]:
				for direction in [-1, 1]:
					var other: int = lane + distance * direction
					if other < 0 or other >= GameConfig.LANE_COUNT:
						continue
					if _blocked_span(windows[other], moment,
							moment + TRANSIT_TIME * distance):
						continue
					alive[step + 1][other] = true
	# Backward pass: the furthest alive step reachable from each state.
	var survivor: Array = []
	for step in steps + 1:
		survivor.append([0, 0, 0])
	for lane in GameConfig.LANE_COUNT:
		if alive[steps][lane]:
			survivor[steps][lane] = steps
	for step in range(steps - 1, -1, -1):
		for lane in GameConfig.LANE_COUNT:
			if not alive[step][lane]:
				continue
			var furthest := step
			if alive[step + 1][lane]:
				furthest = maxi(furthest, int(survivor[step + 1][lane]))
			for direction in [-1, 1]:
				var other: int = lane + direction
				if other < 0 or other >= GameConfig.LANE_COUNT:
					continue
				if alive[step + 1][other]:
					furthest = maxi(furthest, int(survivor[step + 1][other]))
			survivor[step][lane] = furthest

	# The first move decides: stay, or step one lane either way.
	var best := start_lane
	var best_value := -1.0
	var values: Array = [0.0, 0.0, 0.0]
	for offset in [0, -1, 1, -2, 2]:
		var lane: int = start_lane + offset
		if lane < 0 or lane >= GameConfig.LANE_COUNT:
			continue
		var value := 0.0
		if alive[1][lane]:
			value = float(survivor[1][lane]) * PLAN_STEP
		if offset >= -1 and offset <= 1:
			values[offset + 1] = value
		if value > best_value:
			best_value = value
			best = lane
	return {"best": best, "values": values, "dead": best_value <= 0.0}


## Step towards the target lane. The rules set no cooldown on a lane change and
## the hit gate is the logical lane, so two taps in one frame cross two lanes;
## the bot walks one lane at a time so a one-step move stays one step.
func _switch_toward(target_lane: int) -> void:
	var guard := 0
	while world.player.lane != target_lane and guard < GameConfig.LANE_COUNT:
		guard += 1
		var direction := signi(target_lane - world.player.lane)
		if direction == 0 or not world.player.move_lane(direction):
			return
		lane_switches += 1
		_lane_lock = lane_lock_time


func _count_new_kinds(hazards: Array[Hazard]) -> void:
	for hazard in hazards:
		var id := hazard.get_instance_id()
		if _seen_ids.has(id):
			continue
		_seen_ids[id] = true
		var key := String(GameConfig.HazardKind.keys()[hazard.kind])
		hazards_seen[key] = int(hazards_seen.get(key, 0)) + 1


## Track how pinched the rows get. An escape route is a lane whose road is
## clear right now, or a lane whose hazard is under him but can still be
## ducked or jumped: an occupied lane is only a dead end when neither verb
## works. Zero escape routes would be a frame nobody could survive.
func _note_tightness(threats: Array[Dictionary]) -> void:
	var escapes := 0
	for threat in threats:
		if float(threat["time"]) > 0.0:
			escapes += 1
			continue
		var hazard: Hazard = threat["hazard"]
		if hazard == null:
			escapes += 1
			continue
		if hazard.requires_slide or jump_can_clear(
			hazard, float(threat["start"]), float(threat["end"])):
			escapes += 1
	if escapes < min_free_lanes:
		min_free_lanes = escapes
		tightest_distance = world.distance
	if escapes <= 1:
		tight_frames += 1


func _on_area_entered(area: Area2D) -> void:
	if not area is Hazard:
		return
	var hazard := area as Hazard
	contact_log.append("%s L%d x=%.0f | player L%d x=%.0f air %s slide %s lock %.2f" % [
		String(GameConfig.HazardKind.keys()[hazard.kind]), hazard.lane,
		hazard.position.x, world.player.lane, world.player.position.x,
		"yes" if world.player.in_air else "no",
		"yes" if world.player.is_sliding else "no", _lane_lock])
	if contact_log.size() > 6:
		contact_log.pop_front()


func _on_hazard_passed() -> void:
	hazards_passed += 1


func _on_player_damaged(_remaining: int) -> void:
	hits += 1
	hit_log.append({
		"distance": world.distance,
		"lane": world.player.lane,
		"kind": world.player.last_damage_kind,
		"in_air": world.player.in_air,
		"sliding": world.player.is_sliding,
		"lane_lock": _lane_lock,
		"threats": _threat_summary(),
		"contacts": contact_log.duplicate(),
		"decisions": decision_log.duplicate(),
	})
	if death.is_empty():
		death = {
			"distance": world.distance,
			"lane": world.player.lane,
			"kind": world.player.last_damage_kind,
			"hearts_left": world.player.health,
		}


func _on_player_died() -> void:
	death = {
		"distance": world.distance,
		"lane": world.player.lane,
		"kind": world.player.last_damage_kind,
		"hearts_left": 0,
		"nearby": _describe_hazards(),
	}
	_finish(false)


func _finish(passed: bool) -> void:
	if _done:
		return
	_done = true
	_running = false
	if world != null:
		# Stop the run before the world can show a results card: this is an
		# audit, not a played run, and nothing here may touch the player's save.
		world.is_running = false
		world.set_physics_process(false)
		world.player.set_physics_process(false)
	if passed:
		reached = true
	finished.emit()


## One-line description of what was on screen at the failure, for the report.
## Nearest first, because the closest box is the one that hit.
func _describe_hazards() -> Array[String]:
	var hazards := live_hazards()
	hazards.sort_custom(func(a: Hazard, b: Hazard) -> bool:
		return absf(a.position.x - GameConfig.PLAYER_X) < absf(b.position.x - GameConfig.PLAYER_X))
	var out: Array[String] = []
	for hazard in hazards:
		out.append("%s lane %d x %.0f" % [
			String(GameConfig.HazardKind.keys()[hazard.kind]),
			hazard.lane, hazard.position.x])
	return out


## Compact per-lane threat view, for the hit log.
func _threat_summary() -> String:
	var parts: Array[String] = []
	for lane in GameConfig.LANE_COUNT:
		var near: Hazard = null
		var near_time := INF
		for hazard in live_hazards():
			if hazard.lane != lane:
				continue
			var times := overlap_times(hazard)
			if times.y <= 0.0:
				continue
			if times.x < near_time:
				near_time = times.x
				near = hazard
		if near == null:
			parts.append("L%d clear" % lane)
		else:
			parts.append("L%d %s t=%.2f" % [
				lane, String(GameConfig.HazardKind.keys()[near.kind]), near_time])
	# Raw dump of everything close enough to be touching, whatever its lane or
	# direction, so a hit can be traced to the actual box.
	var close: Array[String] = []
	for hazard in live_hazards():
		if absf(hazard.position.x - GameConfig.PLAYER_X) > 260.0:
			continue
		close.append("%s@L%d:%.0f" % [
			String(GameConfig.HazardKind.keys()[hazard.kind]),
			hazard.lane, hazard.position.x])
	parts.append("near [%s]" % ", ".join(close))
	return " | ".join(parts)


## The next hazard in [param hazard]'s lane: the one that would land right
## after the action taken for it.
func _follow_up(hazard: Hazard, threats: Array[Dictionary]) -> Hazard:
	var current := overlap_times(hazard)
	var found: Hazard = null
	var best_time := INF
	for hazard_threat in threats:
		var other: Hazard = hazard_threat["hazard"]
		if other == null or other == hazard or other.lane != hazard.lane:
			continue
		var times := overlap_times(other)
		if times.y <= 0.0 or times.x <= current.y:
			continue
		if times.x < best_time:
			best_time = times.x
			found = other
	return found


# --- Decision maths (pure, so the suite can assert it) -----------------------

## Seconds until a hazard's box starts and stops overlapping Elias's x-span:
## first contact is its near edge reaching his near edge, last contact is its
## far edge clearing his far edge. A hazard that has already gone past returns
## (-1, -1); one that is already on top of him reports a start of 0.
static func overlap_times(hazard: Hazard) -> Vector2:
	var half_hazard := (hazard.shape.shape as RectangleShape2D).size.x * 0.5
	var half_player := GameConfig.HITBOX_SIZE.x * 0.5 + CONTACT_SLACK
	var closing := closing_speed(hazard)
	if closing <= 0.0:
		return Vector2(INF, INF)
	var start := (
		hazard.position.x - half_hazard - (GameConfig.PLAYER_X + half_player)
	) / closing
	var end := (
		hazard.position.x + half_hazard - (GameConfig.PLAYER_X - half_player)
	) / closing
	if end <= 0.0:
		return Vector2(-1.0, -1.0)
	return Vector2(maxf(start, 0.0), end)


## How fast a hazard closes on Elias: the live world speed it rides plus its own
## extra_speed (the car sweeps, the dog trots faster than the road).
static func closing_speed(hazard: Hazard) -> float:
	return hazard.speed + float(GameConfig.HAZARD_DATA[hazard.kind].get("extra_speed", 0.0))


## Per-lane view of "what reaches me first, and when": one entry per lane with
## time/start/end/hazard. A lane with nothing in reach reports INF.
static func lane_threats(hazards: Array[Hazard]) -> Array[Dictionary]:
	var threats: Array[Dictionary] = []
	for lane in GameConfig.LANE_COUNT:
		threats.append({"time": INF, "start": INF, "end": INF, "hazard": null})
	for hazard in hazards:
		var lane := hazard.lane
		if lane < 0 or lane >= threats.size():
			continue
		if hazard.position.x > GameConfig.PLAYER_X + LOOKAHEAD_PX:
			continue
		var times := overlap_times(hazard)
		if times.y <= 0.0:
			continue
		if times.x < float(threats[lane]["time"]):
			threats[lane] = {
				"time": times.x, "start": times.x, "end": times.y, "hazard": hazard,
			}
	return threats


## What a lane is worth right now. A lane whose box is on top of him but is an
## overhead kind is still livable, because a duck shrinks his box the same
## frame; any other overlap is a dead end.
static func lane_time(threats: Array[Dictionary], lane: int) -> float:
	if lane < 0 or lane >= threats.size():
		return -1.0
	var time := float(threats[lane]["time"])
	if time > 0.0:
		return time
	var hazard: Hazard = threats[lane]["hazard"]
	if hazard != null and hazard.requires_slide:
		return 0.01
	return 0.0


## The lane worth standing in: the safest one, unless the current lane is
## already safe enough (hysteresis keeps him from weaving for no reason).
static func best_lane(threats: Array[Dictionary], current_lane: int) -> int:
	if current_lane >= 0 and current_lane < threats.size():
		if float(threats[current_lane]["time"]) > SAFE_TIME:
			return current_lane
	var best := current_lane
	var best_time := -INF
	for lane in threats.size():
		var time := lane_time(threats, lane)
		# Ties go to the current lane, then to the nearer one, so a choice
		# between two equally open lanes never turns into a diagonal dash.
		if lane == current_lane:
			time += 0.001
		elif absi(lane - current_lane) == 1:
			time += 0.0005
		if time > best_time:
			best_time = time
			best = lane
	return best


## Elias's height above the lane baseline `t` seconds after a jump launch.
static func air_height_at(t: float, launch_speed: float = GameConfig.JUMP_SPEED) -> float:
	return maxf(launch_speed * t - 0.5 * GameConfig.GRAVITY * t * t, 0.0)


## True when a jump launched now keeps his feet above the hazard's whole box
## for the entire crossing window. A car fails (its box is 100 px tall and
## sweeps for 0.31 s); a 64 px road prop passes.
static func jump_covers(
	hazard: Hazard,
	t_start: float,
	t_end: float,
	launch_speed: float = GameConfig.JUMP_SPEED,
) -> bool:
	if hazard.requires_slide or t_end <= 0.0:
		return false
	var top := -hazard.box_y_range().x + JUMP_MARGIN
	var t := maxf(t_start, 0.0)
	while t <= t_end:
		if air_height_at(t, launch_speed) < top:
			return false
		t += 1.0 / 60.0
	return air_height_at(t_end, launch_speed) >= top


## True when a slide started right now still covers the crossing window.
static func slide_covers(t_start: float, t_end: float) -> bool:
	return t_start >= 0.0 and t_end > 0.0 and t_end <= GameConfig.SLIDE_DURATION - 0.02


## Whether ducking at SLIDE_TRIGGER will cover the whole pass. This is the
## plan-ahead form: a barricade is still 0.4 s out when it first matters, so a
## check that only asked "does a slide started now fit" would always say no and
## the bot would dodge a beam it is supposed to duck under.
static func slide_can_cover(t_start: float, t_end: float) -> bool:
	if t_end <= t_start:
		return false
	return (t_end - t_start) <= GameConfig.SLIDE_DURATION - SLIDE_TRIGGER - 0.02


## How long a jump keeps him above a hazard's box top, in seconds. Zero when
## the arc never gets over it at all.
static func jump_clear_window(
	hazard: Hazard,
	launch_speed: float = GameConfig.JUMP_SPEED,
) -> float:
	var apex := launch_speed * launch_speed / (2.0 * GameConfig.GRAVITY)
	var top := -hazard.box_y_range().x + JUMP_MARGIN
	if top >= apex:
		return 0.0
	return 2.0 * sqrt(2.0 * (apex - top) / GameConfig.GRAVITY)


## Whether some jump timing can clear this hazard's whole pass. This is the
## difference between "jump it when it is close" and "this one has to be
## dodged": the debris pass (0.39 s) outlasts the arc above it (0.34 s), while
## a 64 px prop (0.28 s) fits.
static func jump_can_clear(hazard: Hazard, t_start: float, t_end: float) -> bool:
	if hazard.requires_slide or t_end <= t_start:
		return false
	return jump_clear_window(hazard) >= (t_end - t_start) + 0.05
