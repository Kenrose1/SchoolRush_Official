class_name LaneTrack
extends Node2D
## One painted lane strip. Two sprites share the same tile so the track can
## scroll forever; the colour is a zone tint multiplied over the tile.

@export_range(0, 2) var lane := 1
## Per-lane brightness so the back track sits back and the front one steps up.
@export_range(0.4, 1.6) var shade := 1.0
@export var scroll_scale := 1.0
## How much the track lifts when Elias is standing on it.
@export_range(0.0, 0.4) var active_lift := 0.12

var color := Color("33465c")
var active := false

@onready var tile_a: Sprite2D = $TileA
@onready var tile_b: Sprite2D = $TileB

var _offset := 0.0


func _ready() -> void:
	apply_tint()
	_place(_tile_width())


## Called by the course each frame with the distance covered.
func advance(step: float) -> void:
	var width := _tile_width()
	if width <= 0.0:
		return
	_offset = fposmod(_offset - step * scroll_scale, width) - width
	_place(width)


func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	apply_tint()


func apply_tint() -> void:
	var tint := color
	if shade < 1.0:
		tint = tint.darkened(1.0 - shade)
	elif shade > 1.0:
		tint = tint.lightened(shade - 1.0)
	if active:
		tint = tint.lightened(active_lift)
	modulate = tint


func _tile_width() -> float:
	if tile_a.texture == null:
		return 0.0
	return tile_a.texture.get_width() * tile_a.scale.x


func _place(width: float) -> void:
	if width <= 0.0:
		return
	tile_a.position.x = _offset
	tile_b.position.x = _offset + width
