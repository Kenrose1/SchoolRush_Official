class_name Player
extends CharacterBody2D
## Elias, the playable runner.
##
## Owns lane switching, jumping, sliding, health, and presentation. Forward
## motion and distance belong to the world; the pursuer and scoring arrive in
## later milestones.

signal lane_changed(lane: int)
signal jumped
signal landed
signal slide_started
signal slide_finished
signal damaged(remaining_hearts: int)
signal health_changed(current: int, maximum: int)
signal died

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

var health: int = GameConfig.MAX_HEARTS
var invulnerable_time_left: float = 0.0

var _lean: float = 0.0
var _hurt_time_left: float = 0.0
var _current_anim: StringName = &""

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape

## Per-instance copy so sliding cannot resize shapes shared between players.
var _box: RectangleShape2D


func _ready() -> void:
	lane_y = GameConfig.lane_y(lane)
	# Layers come from GameConfig so collision setup lives in one place.
	hitbox.collision_layer = GameConfig.LAYER_PLAYER
	hitbox.collision_mask = GameConfig.PLAYER_MASK
	hitbox.monitoring = true
	_box = (hitbox_shape.shape as RectangleShape2D).duplicate()
	hitbox_shape.shape = _box
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_update_hitbox()
	_play(&"run")
	_apply_pose()
	health_changed.emit(health, GameConfig.MAX_HEARTS)


func _physics_process(delta: float) -> void:
	_update_lane(delta)
	_update_jump(delta)
	_update_slide(delta)
	_update_invulnerability(delta)
	_update_hitbox()
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


## Whether a hit would register right now.
func can_take_damage() -> bool:
	return health > 0 and invulnerable_time_left <= 0.0


## Apply damage unless invulnerable. Returns true when the hit landed.
func take_damage(amount: int = 1) -> bool:
	if not can_take_damage():
		return false
	health = maxi(health - amount, 0)
	invulnerable_time_left = GameConfig.I_FRAME_TIME
	_hurt_time_left = GameConfig.HURT_ANIM_TIME
	damaged.emit(health)
	health_changed.emit(health, GameConfig.MAX_HEARTS)
	if health == 0:
		died.emit()
	return true


## Restore full health and clear invulnerability (used by tests and retries).
func reset_health() -> void:
	health = GameConfig.MAX_HEARTS
	invulnerable_time_left = 0.0
	_hurt_time_left = 0.0
	health_changed.emit(health, GameConfig.MAX_HEARTS)


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
	if is_sliding:
		slide_time_left -= delta
		if slide_time_left <= 0.0:
			_end_slide()

	if _hurt_time_left > 0.0:
		_hurt_time_left = maxf(_hurt_time_left - delta, 0.0)


func _update_invulnerability(delta: float) -> void:
	if invulnerable_time_left > 0.0:
		invulnerable_time_left = maxf(invulnerable_time_left - delta, 0.0)


func _end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_time_left = 0.0
	slide_finished.emit()


# --- Collision ---------------------------------------------------------------

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hazard:
		take_damage()


## Resize and re-anchor the box: feet stay at the origin, height follows slide.
func _update_hitbox() -> void:
	if _box == null:
		return
	var height := GameConfig.HITBOX_SIZE.y
	if is_sliding:
		height *= GameConfig.SLIDE_HITBOX_HEIGHT_FACTOR
	_box.size = Vector2(GameConfig.HITBOX_SIZE.x, height)
	hitbox_shape.position = Vector2(0.0, -height * 0.5)


# --- Presentation ------------------------------------------------------------

func _apply_pose() -> void:
	position = Vector2(GameConfig.PLAYER_X, lane_y - air_height)

	# The slide frames are already drawn crouched, so the sprite is only scaled
	# uniformly; the feet stay planted by offsetting half the scaled height.
	var sprite_scale := Vector2(GameConfig.PLAYER_SCALE, GameConfig.PLAYER_SCALE)
	sprite.scale = sprite_scale
	sprite.position = Vector2(0.0, -GameConfig.PLAYER_SPRITE_HEIGHT * sprite_scale.y * 0.5)
	sprite.rotation = deg_to_rad(_lean)

	# Blink while invulnerable so the i-frame window is readable.
	if invulnerable_time_left > 0.0:
		var phase := fmod(invulnerable_time_left * GameConfig.I_FRAME_BLINK_HZ, 1.0)
		sprite.modulate.a = 0.35 if phase < 0.5 else 1.0
	else:
		sprite.modulate.a = 1.0


func _update_animation() -> void:
	if _hurt_time_left > 0.0:
		_play(&"hurt")
		return
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
