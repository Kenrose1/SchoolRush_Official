class_name Pursuer
extends Node2D
## The tanod. Dormant off-screen left, chases when the player is hit, fades
## after surviving the chase, and lunges as a death animation when the player
## is caught or hits a hazard mid-chase.
##
## A wake always starts with an entrance dash from off the left edge, so he is
## never seen appearing out of nowhere: the slide-in is what tells the player
## he is now behind them. The dash is faster than the world scrolls, so his run
## cycle is scaled by the same ratio for the length of the entrance and put
## back to 1.0 once he settles at the chase gap.
##
## The chase is measured against the player's un-dipped base speed, so the
## momentum dip after a hit closes the gap at every speed ramp. A clean dip
## looms down to PURSUER_ESCAPE_FLOOR but can never catch on its own: a second
## mistake during the chase (RunWorld.knock_closer) is what ends the run.
##
## Speeds are relative to the world speed handed in each frame, so the momentum
## dip (world slows, tanod doesn't) is what lets him close the gap.

signal chase_started
signal chase_faded
signal caught
signal lunge_finished

enum State { DORMANT, CHASE, FADE, LUNGE }

var state: State = State.DORMANT
## Pixels behind the player (positive = behind, left of PLAYER_X).
var gap: float = GameConfig.PURSUER_DORMANT_GAP
## Seconds spent in the current chase.
var chase_time: float = 0.0
## Lane baseline the tanod tracks (follows the player).
var lane_y: float = GameConfig.lane_y(GameConfig.LANE_MIDDLE)

var _fade_time_left: float = 0.0
## Seconds left in the off-screen slide-in that opens a chase.
var _enter_time: float = 0.0
## Player's un-dipped world speed, set by RunWorld each frame. The chase is a
## fraction of this, not of the live (possibly dipped) speed.
var _base_speed: float = GameConfig.RUN_SPEED
var _lunge_time: float = 0.0
var _lunge_from: float = 0.0
var _current_anim: StringName = &""

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	visible = false
	_target_y = lane_y
	_apply_pose(0.0)
	_play(&"idle")


## Whether a hazard hit would be an instant loss right now.
func is_active() -> bool:
	return state == State.CHASE or state == State.LUNGE


## Wake up and enter the chase. No-op unless dormant or fading.
## Starts off the left edge and slides in (see _physics_process), so the tanod
## can never pop onto the screen. Snaps to the player's current lane (no
## ease-in from a stale lane).
func wake() -> void:
	if state == State.CHASE or state == State.LUNGE:
		return
	state = State.CHASE
	gap = GameConfig.PURSUER_ENTER_GAP
	chase_time = 0.0
	_enter_time = GameConfig.PURSUER_ENTER_TIME
	visible = true
	lane_y = _target_y
	# The feet have to keep the ground while he dashes in.
	sprite.speed_scale = GameConfig.PURSUER_ENTER_SPEED_FACTOR
	_apply_pose(0.0)
	_play(&"run")
	chase_started.emit()


## Force the lunge death animation (debug/tests). Does not report a catch;
## a real catch goes through [_start_catch].
func start_lunge() -> void:
	if state == State.LUNGE:
		return
	_begin_lunge()


## Shared lunge setup: the death animation, without the caught signal.
func _begin_lunge() -> void:
	state = State.LUNGE
	_enter_time = 0.0
	# A hit mid-dash ends the entrance; the lunge plays at the stock cycle.
	sprite.speed_scale = 1.0
	_lunge_from = gap
	_lunge_time = 0.0
	visible = true
	_play(&"run")
	set_physics_process(false)


## The gap closed onto Elias: run the lunge and report the catch exactly once.
func _start_catch() -> void:
	if state == State.LUNGE:
		return
	_begin_lunge()
	caught.emit()


## Take px off the gap because Elias was hit while the tanod is chasing. This
## is the second-mistake rule: the dip alone stops at PURSUER_ESCAPE_FLOOR, so
## only a knock turns the chase into a catch.
func knock_closer(px: float) -> void:
	if state != State.CHASE or _enter_time > 0.0:
		return
	gap = maxf(gap - px, 0.0)
	if gap <= GameConfig.PURSUER_CATCH_DISTANCE:
		_start_catch()


func _process(delta: float) -> void:
	if state != State.LUNGE:
		return
	_lunge_time += delta
	var t := clampf(_lunge_time / GameConfig.PURSUER_LUNGE_TIME, 0.0, 1.0)
	gap = lerpf(_lunge_from, 0.0, t)
	_apply_pose(delta)
	if t >= 1.0:
		lunge_finished.emit()
		set_process(false)


## Advance the chase. Call once per physics frame with the current world speed.
func _physics_process(delta: float) -> void:
	if state == State.DORMANT or state == State.LUNGE:
		_apply_pose(delta)
		return

	if state == State.CHASE:
		# Entrance dash: he comes in from off the left edge rather than
		# appearing at the chase gap. The chase clock starts after he lands,
		# so the entrance never eats into the survive-the-chase window.
		if _enter_time > 0.0:
			_enter_time = maxf(_enter_time - delta, 0.0)
			gap = move_toward(
				gap,
				GameConfig.PURSUER_WAKE_GAP,
				GameConfig.PURSUER_ENTER_SPEED * delta,
			)
			if _enter_time <= 0.0:
				# Arrived: back to the stock run cycle for the chase.
				sprite.speed_scale = 1.0
			_apply_pose(delta)
			return
		chase_time += delta
		var factor := lerpf(
			GameConfig.PURSUER_CHASE_FACTOR,
			1.0,
			clampf(chase_time / GameConfig.PURSUER_CHASE_RAMP_TIME, 0.0, 1.0),
		)
		var pursuer_speed := maxf(_base_speed, GameConfig.RUN_SPEED) * factor
		# World speed comes from the caller via _world_speed (set each frame).
		var closing := (_world_speed - pursuer_speed) * delta
		if gap >= GameConfig.PURSUER_ESCAPE_FLOOR:
			# Clamp the whole step, not just its result: one long frame can
			# close more than the floor and would otherwise skip past the
			# catch check into an unearned death.
			gap = maxf(gap + closing, GameConfig.PURSUER_ESCAPE_FLOOR)
		# A clean dip looms down to the floor and stops there; only a knock from
		# a mistake during the chase is allowed to close the last stretch.
		if gap <= GameConfig.PURSUER_CATCH_DISTANCE:
			_start_catch()
			return
		if chase_time >= GameConfig.PURSUER_FADE_AFTER:
			state = State.FADE
			_fade_time_left = GameConfig.PURSUER_FADE_TIME
			chase_faded.emit()
		_apply_pose(delta)
		return

	if state == State.FADE:
		_fade_time_left -= delta
		sprite.modulate.a = clampf(_fade_time_left / GameConfig.PURSUER_FADE_TIME, 0.0, 1.0)
		gap -= 60.0 * delta
		if _fade_time_left <= 0.0:
			state = State.DORMANT
			_enter_time = 0.0
			gap = GameConfig.PURSUER_DORMANT_GAP
			visible = false
			sprite.modulate.a = 1.0
			sprite.speed_scale = 1.0
			_play(&"idle")
		_apply_pose(delta)


var _world_speed: float = GameConfig.RUN_SPEED


## Set by RunWorld each physics frame before Pursuer updates.
func set_world_speed(world_speed: float) -> void:
	_world_speed = world_speed


## Set by RunWorld each physics frame: the player's un-dipped speed. Keeping the
## chase tied to the base is what lets the momentum dip close the gap at every
## speed ramp instead of only at the start of a run.
func set_base_speed(base_speed: float) -> void:
	_base_speed = base_speed


func _apply_pose(delta: float) -> void:
	lane_y = move_toward(lane_y, _target_y, GameConfig.LANE_SWITCH_SPEED * delta)
	position = Vector2(GameConfig.PLAYER_X - gap, lane_y)
	sprite.scale = Vector2(GameConfig.PURSUER_SCALE, GameConfig.PURSUER_SCALE)
	sprite.position = Vector2(0.0, -GameConfig.PURSUER_SPRITE_HEIGHT * GameConfig.PURSUER_SCALE * 0.5)


var _target_y: float = GameConfig.lane_y(GameConfig.LANE_MIDDLE)


## Track the player's lane baseline (called by RunWorld each frame).
func track(player_y: float) -> void:
	_target_y = player_y


func _play(anim: StringName) -> void:
	if _current_anim == anim:
		return
	_current_anim = anim
	sprite.play(anim)
