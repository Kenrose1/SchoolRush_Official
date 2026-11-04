class_name Player
extends Node2D
## Elias. The scene owns the sprite; this script only moves it.
## Everything tunable is exported so it can be edited in the Inspector.

@export_group("Lanes")
## Feet height for the top, middle and bottom lane.
@export var lane_y: Array[float] = [620.0, 800.0, 980.0]
@export_range(0, 2) var lane := 1

@export_group("Movement")
@export var gravity := 2950.0
@export var jump_speed := 1180.0
@export var slide_time := 0.72
@export var lane_glide := 16.0

@export_group("Survival")
@export var iframe_time := 1.5
## AABB in local pixels, kept a little tighter than the art (GDD section 03).
@export var hitbox_stand := Rect2(-61, -175, 122, 175)
@export var hitbox_slide := Rect2(-54, -96, 108, 96)

@export_group("Visuals")
@export var sprite_scale := 1.15
@export var shadow_radius := 46.0

var speed := 620.0
var invuln := 0.0
var sliding := false
var airborne := false

@onready var sprite: AnimatedSprite2D = $Sprite

var _slide_timer := 0.0
var _vy := 0.0
var _height := 0.0
var _lane_y := 0.0
var _hurt_timer := 0.0
var _anim := "run"


func _ready() -> void:
	_lane_y = lane_y[lane]
	position = Vector2(position.x, _lane_y)
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	# The frames are padded to one canvas, so this anchors the feet at the origin.
	var texture := sprite.sprite_frames.get_frame_texture("run", 0)
	if texture != null:
		sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
	sprite.play("run")


func _process(delta: float) -> void:
	_lane_y = lerpf(_lane_y, lane_y[lane], minf(1.0, lane_glide * delta))

	if airborne:
		_vy += gravity * delta
		_height += _vy * delta
		if _height >= 0.0:
			_height = 0.0
			_vy = 0.0
			airborne = false

	if sliding:
		_slide_timer -= delta
		if _slide_timer <= 0.0 and not airborne:
			sliding = false

	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)
		sprite.modulate.a = 0.35 if fmod(invuln, 0.16) < 0.08 else 1.0
	else:
		sprite.modulate.a = 1.0

	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	position = Vector2(position.x, _lane_y + _height)
	_animate(delta)
	queue_redraw()


func _animate(_delta: float) -> void:
	var next := "run"
	if _hurt_timer > 0.0:
		next = "hurt"
	elif sliding:
		next = "slide"
	elif airborne:
		next = "jump"
	elif speed < 1.0:
		next = "idle"

	if next == "jump":
		# Hold a pose chosen by vertical velocity instead of looping.
		var frame := 0 if _vy < -250.0 else (1 if _vy < 250.0 else 2)
		if _anim != "jump":
			sprite.play("jump")
			sprite.pause()
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count("jump") - 1)
		_anim = "jump"
		return

	if next != _anim:
		_anim = next
		sprite.play(_anim)
	if _anim == "run":
		sprite.speed_scale = clampf(speed / 620.0, 0.8, 1.6)
	elif _anim == "hurt":
		sprite.speed_scale = 1.0


func _draw() -> void:
	var t := clampf(-_height / 260.0, 0.0, 1.0)
	var radius := lerpf(shadow_radius, shadow_radius * 0.56, t)
	draw_set_transform(Vector2(0.0, -_height), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, lerpf(0.28, 0.10, t)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func move_lane(direction: int) -> void:
	var next := clampi(lane + direction, 0, lane_y.size() - 1)
	if next != lane:
		lane = next


func jump() -> bool:
	if airborne or sliding:
		return false
	airborne = true
	_vy = -jump_speed
	_height = 0.0
	Sfx.play("jump", -3.0)
	return true


func slide() -> bool:
	if sliding:
		return false
	sliding = true
	_slide_timer = slide_time
	if airborne:
		_vy = maxf(_vy, 900.0)
	Sfx.play("slide", -6.0)
	return true


func hurt() -> void:
	_hurt_timer = 0.34
	invuln = iframe_time
	sprite.modulate.a = 0.4


func hit_rect() -> Rect2:
	var local := hitbox_slide if sliding else hitbox_stand
	var lane_top := lane_y[lane] + _height + local.position.y
	return Rect2(Vector2(position.x + local.position.x, lane_top), local.size)


func is_invulnerable() -> bool:
	return invuln > 0.0
