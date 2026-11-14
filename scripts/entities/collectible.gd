class_name Collectible
extends Area2D
## A floating School Item.
##
## The player's hitbox collects it on overlap. An item that scrolls behind the
## player emits [signal missed] once, which breaks the pickup combo.

signal picked_up(kind: GameConfig.ItemKind)
signal missed

var kind: GameConfig.ItemKind = GameConfig.ItemKind.PENCIL
var speed: float = GameConfig.RUN_SPEED
var lane: int = GameConfig.LANE_MIDDLE

var _data: Dictionary = {}
var _collected: bool = false
var _missed: bool = false
var _bob_time: float = 0.0
var _hover_y: float = -GameConfig.ITEM_HOVER_HEIGHT

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape


func _ready() -> void:
	# Passive like hazards: the player's hitbox scans for items.
	collision_layer = GameConfig.LAYER_COLLECTIBLE
	collision_mask = 0
	monitoring = false
	if not _data.is_empty():
		_apply()


func get_kind() -> GameConfig.ItemKind:
	return kind


## Configure the item. Call after add_child so the child nodes exist.
func setup(new_kind: GameConfig.ItemKind, new_lane: int, world_speed: float) -> void:
	kind = new_kind
	lane = new_lane
	speed = world_speed
	_data = GameConfig.ITEM_DATA[kind]
	_apply()


func _physics_process(delta: float) -> void:
	if _collected:
		return
	position.x -= speed * delta
	# Currency (coins) never reports a miss: a trail the player runs past
	# leaves the combo alone, unlike School Items which break it.
	var is_currency: bool = _data.get("currency", false)
	if not _missed and not is_currency and position.x < (
			GameConfig.PLAYER_X - GameConfig.ITEM_HITBOX_SIZE.x * 0.5):
		_missed = true
		missed.emit()
	if position.x < GameConfig.DESPAWN_X:
		queue_free()


func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	sprite.position.y = _hover_y + sin(_bob_time * GameConfig.ITEM_BOB_SPEED) * GameConfig.ITEM_BOB_HEIGHT


## Returns true only for the first successful collection.
func collect() -> bool:
	if _collected or _missed:
		return false
	_collected = true
	picked_up.emit(kind)
	queue_free()
	return true


## Top and bottom Y of the pickup box, relative to the lane baseline.
func box_y_range() -> Vector2:
	var height := (shape.shape as RectangleShape2D).size.y
	return Vector2(shape.position.y - height * 0.5, shape.position.y + height * 0.5)


func _apply() -> void:
	var texture := load(String(_data["texture"])) as Texture2D
	var art_scale := float(_data["scale"])

	position.y = GameConfig.lane_y(lane)
	sprite.texture = texture
	sprite.scale = Vector2(art_scale, art_scale)
	sprite.position = Vector2(0.0, _hover_y)

	var box := (shape.shape as RectangleShape2D).duplicate()
	box.size = GameConfig.ITEM_HITBOX_SIZE
	shape.shape = box
	shape.position = Vector2(0.0, _hover_y)
