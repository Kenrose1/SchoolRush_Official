extends CharacterBody2D

const MOVE_SPEED := 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing_direction := "down"

func _ready() -> void:
	_play_animation("idle")

func _physics_process(_delta: float) -> void:
	var input_direction := _get_input_direction()
	velocity = input_direction * MOVE_SPEED
	move_and_slide()

	if input_direction != Vector2.ZERO:
		_update_facing_direction(input_direction)
		_play_animation("run")
	else:
		_play_animation("idle")

func _get_input_direction() -> Vector2:
	var horizontal := Input.get_axis("ui_left", "ui_right")
	var vertical := Input.get_axis("ui_up", "ui_down")

	if Input.is_key_pressed(KEY_A):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D):
		horizontal += 1.0
	if Input.is_key_pressed(KEY_W):
		vertical -= 1.0
	if Input.is_key_pressed(KEY_S):
		vertical += 1.0

	return Vector2(horizontal, vertical).limit_length(1.0)

func _update_facing_direction(input_direction: Vector2) -> void:
	if input_direction.x < 0.0 and input_direction.y > 0.0:
		facing_direction = "left_down"
	elif input_direction.x < 0.0 and input_direction.y < 0.0:
		facing_direction = "left_up"
	elif input_direction.x > 0.0 and input_direction.y > 0.0:
		facing_direction = "right_down"
	elif input_direction.x > 0.0 and input_direction.y < 0.0:
		facing_direction = "right_up"
	elif input_direction.x != 0.0:
		facing_direction = "right" if input_direction.x > 0.0 else "left"
	else:
		facing_direction = "down" if input_direction.y > 0.0 else "up"

func _play_animation(animation_type: String) -> void:
	var animation_name := animation_type + "_" + _get_animation_direction()
	animated_sprite.flip_h = facing_direction in ["left", "left_down", "left_up"]
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

func _get_animation_direction() -> String:
	match facing_direction:
		"left_down", "right_down":
			return "down_left"
		"left", "right":
			return "left"
		"left_up", "right_up":
			return "up_left"
		_:
			return facing_direction
