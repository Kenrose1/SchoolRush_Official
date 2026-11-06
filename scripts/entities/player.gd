class_name Player
extends CharacterBody2D
## Elias, the playable runner.
##
## M1 scope: automatic forward motion belongs to the world, while this node owns
## lane switching, jumping, sliding, and presentation. Hazards, health, and
## scoring are added in later milestones.

signal lane_changed(lane: int)
signal jumped
signal landed
signal slide_started
signal slide_finished

## Animation definitions for the individual Elias PNG frames.
const ANIMATIONS := {
	"idle": {"frames": 4, "fps": 8.0, "loop": true},
	"run": {"frames": 7, "fps": 14.0, "loop": true},
	"jump": {"frames": 3, "fps": 10.0, "loop": false},
	"slide": {"frames": 4, "fps": 8.0, "loop": true},
	"hurt": {"frames": 6, "fps": 10.0, "loop": false},
}
const FRAME_PATH := "res://assets/characters/elias/%s_%d.png"

## Current lane tier (GameConfig.LANE_TOP / MIDDLE / BOTTOM).
var lane: int = GameConfig.PLAYER_START_LANE
## Interpolated baseline Y of the current lane (the feet position).
var lane_y: float = 0.0
## Height above the lane baseline while airborne, in pixels.
var air_height: float = 0.0
## Vertical speed while airborne (positive = rising).
var vertical_speed: float = 0.0
var in_air: bool = false
var is_sliding: bool = false
var slide_time_left: float = 0.0

var _lean: float = 0.0
var _current_anim: StringName = &""

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	lane_y = GameConfig.lane_y(lane)
	_build_frames()
	_play(&"run")
	_apply_pose()


func _physics_process(delta: float) -> void:
	_update_lane(delta)
	_update_jump(delta)
	_update_slide(delta)
	_apply_pose()
	_update_animation()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("lane_up"):
		move_lane(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lane_down"):
		move_lane(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		jump()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("slide"):
		slide()
		get_viewport().set_input_as_handled()


# --- Public actions ----------------------------------------------------------

## Step one lane up (-1) or down (+1). Returns false at the outer lanes.
func move_lane(direction: int) -> bool:
	var next := GameConfig.step_lane(lane, direction)
	if next == lane:
		return false
	lane = next
	lane_changed.emit(lane)
	return true


## Start a jump. Returns false when already airborne or out of bounds.
func jump() -> bool:
	if in_air:
		return false
	if is_sliding:
		_end_slide()
	in_air = true
	air_height = 0.0
	vertical_speed = GameConfig.JUMP_SPEED
	jumped.emit()
	return true


## Start a slide. Returns false while already sliding or airborne.
func slide() -> bool:
	if is_sliding or in_air:
		return false
	is_sliding = true
	slide_time_left = GameConfig.SLIDE_DURATION
	slide_started.emit()
	return true


# --- Movement ----------------------------------------------------------------

func _update_lane(delta: float) -> void:
	var target := GameConfig.lane_y(lane)
	lane_y = move_toward(lane_y, target, GameConfig.LANE_SWITCH_SPEED * delta)

	var remaining := target - lane_y
	var lean_target := 0.0 if is_zero_approx(remaining) else -signf(remaining) * GameConfig.LANE_LEAN_DEGREES
	_lean = lerpf(_lean, lean_target, clampf(GameConfig.LANE_LEAN_SMOOTHING * delta, 0.0, 1.0))


func _update_jump(delta: float) -> void:
	if not in_air:
		return
	air_height += vertical_speed * delta
	vertical_speed -= GameConfig.GRAVITY * delta
	if air_height <= 0.0:
		air_height = 0.0
		vertical_speed = 0.0
		in_air = false
		landed.emit()


func _update_slide(delta: float) -> void:
	if not is_sliding:
		return
	slide_time_left -= delta
	if slide_time_left <= 0.0:
		_end_slide()


func _end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_time_left = 0.0
	slide_finished.emit()


# --- Presentation ------------------------------------------------------------

func _apply_pose() -> void:
	position = Vector2(GameConfig.PLAYER_X, lane_y - air_height)

	# The slide frames are already drawn crouched, so the sprite is only scaled
	# uniformly; the feet stay planted by offsetting half the scaled height.
	var sprite_scale := Vector2(GameConfig.PLAYER_SCALE, GameConfig.PLAYER_SCALE)
	sprite.scale = sprite_scale
	sprite.position = Vector2(0.0, -GameConfig.PLAYER_SPRITE_HEIGHT * sprite_scale.y * 0.5)
	sprite.rotation = deg_to_rad(_lean)


func _update_animation() -> void:
	if in_air:
		_play(&"jump")
		sprite.pause()
		# Pick the frame from vertical speed: rising, apex, falling.
		if vertical_speed > 200.0:
			sprite.frame = 0
		elif vertical_speed > -200.0:
			sprite.frame = 1
		else:
			sprite.frame = 2
		return
	if is_sliding:
		_play(&"slide")
		return
	_play(&"run")


func _play(anim: StringName) -> void:
	if _current_anim == anim:
		return
	_current_anim = anim
	sprite.play(anim)


## Ground shadow that shrinks and fades as Elias rises.
func _draw() -> void:
	var rise := clampf(air_height / GameConfig.JUMP_APEX, 0.0, 1.0)
	var radius := 34.0 * (1.0 - 0.35 * rise)
	var alpha := 0.25 * (1.0 - 0.6 * rise)
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Build SpriteFrames from the per-frame PNGs in assets/characters/elias/.
func _build_frames() -> void:
	var frames := SpriteFrames.new()
	for anim_name: String in ANIMATIONS:
		var config: Dictionary = ANIMATIONS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(config["fps"]))
		frames.set_animation_loop(anim_name, bool(config["loop"]))
		for index in int(config["frames"]):
			var path := FRAME_PATH % [anim_name, index]
			var texture := ResourceLoader.load(path) as Texture2D
			assert(texture != null, "Missing Elias frame: %s" % path)
			frames.add_frame(anim_name, texture)
	frames.remove_animation("default")
	sprite.sprite_frames = frames
