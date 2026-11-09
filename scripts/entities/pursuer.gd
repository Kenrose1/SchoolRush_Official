class_name Pursuer
extends Node2D
## The tanod. Dormant off-screen left, chases when the player is hit or misses
## an item, fades after surviving the chase, and lunges as a death animation
## when the player is caught or hits a hazard mid-chase.
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
## Snaps to the player's current lane (no ease-in from a stale lane).
func wake() -> void:
	if state == State.CHASE or state == State.LUNGE:
		return
	state = State.CHASE
	gap = GameConfig.PURSUER_WAKE_GAP
	chase_time = 0.0
	visible = true
	lane_y = _target_y
	_apply_pose(0.0)
	_play(&"run")
	chase_started.emit()


## Instant-loss lunge: close the gap to the player as the death animation.
## Runs even though the world is frozen; call _update_lunge from _process.
func start_lunge() -> void:
	if state == State.LUNGE:
		return
	state = State.LUNGE
	_lunge_from = gap
	_lunge_time = 0.0
	visible = true
	_play(&"run")


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
		chase_time += delta
		var factor := lerpf(
			GameConfig.PURSUER_CHASE_FACTOR,
			1.0,
			clampf(chase_time / GameConfig.PURSUER_CHASE_RAMP_TIME, 0.0, 1.0),
		)
		var pursuer_speed := GameConfig.RUN_SPEED * factor
		# World speed comes from the caller via _world_speed (set each frame).
		gap += (_world_speed - pursuer_speed) * delta
		if gap <= GameConfig.PURSUER_CATCH_DISTANCE:
			state = State.LUNGE
			_lunge_from = gap
			_lunge_time = 0.0
			_play(&"run")
			caught.emit()
			set_physics_process(false)
		elif chase_time >= GameConfig.PURSUER_FADE_AFTER:
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
			gap = GameConfig.PURSUER_DORMANT_GAP
			visible = false
			sprite.modulate.a = 1.0
			_play(&"idle")
		_apply_pose(delta)


var _world_speed: float = GameConfig.RUN_SPEED


## Set by RunWorld each physics frame before Pursuer updates.
func set_world_speed(world_speed: float) -> void:
	_world_speed = world_speed


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
