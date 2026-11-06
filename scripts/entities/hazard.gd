class_name Hazard
extends Area2D
## A lane-bound obstacle.
##
## Kinds, art, scale, and hitbox sizes live in GameConfig.HAZARD_DATA. Hazards
## travel left at the world speed and despawn behind the player. Static and
## moving kinds alike stay locked to their spawn lane for now.

signal passed_player

## Vertical offset of the sprite/hitbox when it is not pushed up by clearance.
const FRAME_FPS := 10.0

var kind: GameConfig.HazardKind = GameConfig.HazardKind.MANHOLE
var lane: int = GameConfig.LANE_MIDDLE
var speed: float = GameConfig.RUN_SPEED
var damage: int = 1
var requires_slide: bool = false

## Reserved for lane-changing hazards; nothing uses it yet (decision: keep
## moving obstacles lane-locked for v1).
var lane_locked: bool = true

var _data: Dictionary = {}
var _frame_timer: float = 0.0
var _passed: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape


func _ready() -> void:
	# Hazards are passive: the player's hitbox scans for them.
	collision_layer = GameConfig.LAYER_HAZARD
	collision_mask = 0
	monitoring = false
	if not _data.is_empty():
		_apply()


## Configure the hazard. Call after add_child so the child nodes exist.
func setup(new_kind: GameConfig.HazardKind, new_lane: int, world_speed: float) -> void:
	kind = new_kind
	lane = new_lane
	speed = world_speed
	_data = GameConfig.HAZARD_DATA[kind]
	requires_slide = bool(_data["overhead"])
	_apply()


func _physics_process(delta: float) -> void:
	position.x -= (speed + float(_data.get("extra_speed", 0.0))) * delta
	if not _passed and position.x < GameConfig.PLAYER_X:
		_passed = true
		passed_player.emit()
	if position.x < GameConfig.DESPAWN_X:
		queue_free()


func _process(delta: float) -> void:
	var frames := int(_data.get("frames", 0))
	if frames <= 1:
		return
	_frame_timer += delta
	var frame_time := 1.0 / FRAME_FPS
	if _frame_timer >= frame_time:
		_frame_timer -= frame_time
		sprite.frame = (sprite.frame + 1) % frames


## Top and bottom Y of the collision box, relative to the lane baseline.
func box_y_range() -> Vector2:
	var height := (shape.shape as RectangleShape2D).size.y
	return Vector2(shape.position.y - height * 0.5, shape.position.y + height * 0.5)


func _apply() -> void:
	var texture := load(String(_data["texture"])) as Texture2D
	var art_scale := float(_data["scale"])
	var clearance := float(_data["clearance"])

	position.y = GameConfig.lane_y(lane)

	sprite.texture = texture
	sprite.scale = Vector2(art_scale, art_scale)
	sprite.hframes = maxi(int(_data["frames"]), 1)
	sprite.frame = 0
	sprite.position = Vector2(0.0, -clearance - texture.get_height() * art_scale * 0.5)

	var box := (shape.shape as RectangleShape2D).duplicate()
	box.size = Vector2(float(_data["hitbox_w"]), float(_data["hitbox_h"]))
	shape.shape = box
	shape.position = Vector2(0.0, -clearance - box.size.y * 0.5)
