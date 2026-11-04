class_name Obstacle
extends Node2D
## A hazard on the course. The scene holds the sprite, so the art and size are
## visible and editable in the editor; this script handles motion and the AABB.

@export_enum("jump", "slide") var kind := "jump"
@export_range(0, 2) var lane := 1
## Fraction of the sprite used as the hit box.
@export var hitbox_ratio := Vector2(0.72, 0.88)
## Slide barriers only: vertical band above the lane line that blocks Elias.
@export var band_top := 212.0
@export var band_bottom := 100.0

var x := 0.0
var lane_height := -1.0

@onready var sprite: Sprite2D = $Sprite


func _process(_delta: float) -> void:
	position.x = x


## Called by the spawner right after instancing.
func setup(kind_name: String, lane_index: int, start_x: float, prop: String, prop_scale: float, lane_y := -1.0) -> void:
	kind = kind_name
	lane = lane_index
	x = start_x
	lane_height = lane_y if lane_y > 0.0 else Pal.LANE_Y[lane]
	position = Vector2(x, lane_height)
	if kind == "jump" and prop_scale > 0.0:
		sprite.scale = Vector2(prop_scale, prop_scale)
	_apply_prop(prop)


func _apply_prop(prop: String) -> void:
	if kind != "jump" or prop == "":
		return
	var path := "res://assets/sprites/props/haz_%s.png" % prop
	if ResourceLoader.exists(path):
		sprite.texture = load(path)


func advance(distance: float) -> void:
	x -= distance


func rect() -> Rect2:
	if kind == "jump":
		var texture := sprite.texture
		var base := Vector2(56, 64)
		if texture != null:
			base = Vector2(texture.get_width(), texture.get_height()) * sprite.scale
		var size := Vector2(
			maxf(46.0, base.x * hitbox_ratio.x),
			maxf(40.0, base.y * hitbox_ratio.y),
		)
		return Rect2(Vector2(x - size.x * 0.5, lane_height - size.y), size)
	return Rect2(
		Vector2(x - 108.0, lane_height - band_top),
		Vector2(216.0, band_top - band_bottom),
	)
