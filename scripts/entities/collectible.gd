class_name Collectible
extends Area2D
## A floating School Item.
##
## The player's hitbox collects it on overlap. An item that scrolls behind the
## player emits [signal missed] once, which breaks the pickup combo.

signal picked_up(kind: GameConfig.ItemKind)
signal missed

## Presentation-only one-shot burst for School Items. Coins skip it: a coin
## trail would fire several bursts a second and turn into visual soup.
const SPARK_COUNT := 6

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
@onready var collect_spark: CPUParticles2D = $CollectSpark


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
	# A collected item keeps riding the world while its pickup FX plays, so it
	# does not look glued to the camera. Miss/despawn checks stop at that point.
	if _collected:
		position.x -= speed * delta
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


## Returns true only for the first successful collection. Scoring is instant;
## the sprite stays alive briefly for the pickup FX and frees itself at the end.
func collect() -> bool:
	if _collected or _missed:
		return false
	_collected = true
	# collect() runs during the player's physics flush, so defer the shape edit.
	shape.set_deferred("disabled", true)
	picked_up.emit(kind)
	_play_collect_fx()
	return true


## Pop, rise and fade the collected item. All tweens run in parallel from t=0;
## the shrink/fade pair is delayed until the pop finishes. The spark outlives
## the sprite fade, so the node is freed when the longer of the two is done.
func _play_collect_fx() -> void:
	var is_currency: bool = _data.get("currency", false)
	var duration := (GameConfig.COIN_COLLECT_TIME if is_currency
		else GameConfig.ITEM_COLLECT_TIME)
	var rise := (GameConfig.COIN_COLLECT_RISE if is_currency
		else GameConfig.ITEM_COLLECT_RISE)
	var base_scale := sprite.scale
	var pop_time := duration * GameConfig.COLLECT_POP_TIME_FRACTION
	var fade_time := duration - pop_time

	if not is_currency and collect_spark != null:
		collect_spark.amount = SPARK_COUNT
		collect_spark.restart()

	var tween := create_tween()
	tween.tween_property(sprite, "position:y", sprite.position.y - rise, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		sprite, "scale", base_scale * GameConfig.COLLECT_POP_SCALE, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(
		sprite, "scale", base_scale * GameConfig.COLLECT_END_SCALE, fade_time) \
		.set_delay(pop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, fade_time) \
		.set_delay(pop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Sparks are world-space but parented here, so wait them out before freeing.
	if not is_currency:
		tween.tween_interval(
			maxf(0.0, GameConfig.COLLECT_SPARK_LIFETIME - duration))
	tween.tween_callback(queue_free)


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
