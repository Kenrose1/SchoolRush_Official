class_name Pickup
extends Node2D
## A school item. The scene holds the sprite and glow; the spawner only sets the
## kind, lane and start position.

@export_enum("book", "pencil", "eraser", "bag") var kind := "book"
@export_range(0, 2) var lane := 1
@export var bob_height := 132.0
@export var bob_amount := 9.0
@export var sprite_scale := 0.85
@export var pickup_size := Vector2(78, 78)

const TEXTURES := {
	"book": "res://assets/sprites/props/item_book.png",
	"pencil": "res://assets/sprites/props/item_pencil.png",
	"eraser": "res://assets/sprites/props/item_eraser.png",
	"bag": "res://assets/sprites/props/item_bag.png",
}

var x := 0.0
var collected := false

@onready var sprite: Sprite2D = $Sprite

var _base_y := 0.0
var _t := 0.0


func _ready() -> void:
	sprite.texture = load(TEXTURES.get(kind, TEXTURES["book"]))
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	_base_y = position.y
	if _base_y == 0.0:
		_base_y = Pal.LANE_Y[lane] - bob_height
		position.y = _base_y


func _process(delta: float) -> void:
	_t += delta
	position = Vector2(x, _base_y + sin(_t * 3.4) * bob_amount)
	sprite.rotation = sin(_t * 2.0) * 0.08


## Called by the spawner right after instancing.
func setup(kind_name: String, lane_index: int, start_x: float, lane_y := -1.0) -> void:
	kind = kind_name
	lane = lane_index
	x = start_x
	var base := lane_y if lane_y > 0.0 else Pal.LANE_Y[lane]
	_base_y = base - bob_height
	position = Vector2(x, _base_y)
	if is_node_ready() and sprite != null:
		sprite.texture = load(TEXTURES.get(kind, TEXTURES["book"]))
		sprite.scale = Vector2(sprite_scale, sprite_scale)


func advance(distance: float) -> void:
	x -= distance


func rect() -> Rect2:
	return Rect2(Vector2(x, position.y) - pickup_size * 0.5, pickup_size)
