class_name Background
extends Node2D
## The painted zone panorama, wrapped across two sprites so it can drift
## forever. Zone Textures holds one strip per zone; the course swaps them.

@export_group("Panorama")
## One looping strip per zone, in course order (home, street, school).
@export var zone_textures: Array[Texture2D] = []
@export_range(0, 2) var zone := 0
## How tall the strip is drawn on screen. Scale follows from the texture.
@export var band_height := 470.0
## Fraction of the run speed the backdrop drifts at.
@export_range(0.0, 1.0) var parallax := 0.16
## Self-drive, used by the title screen where no run is driving the world.
@export var idle_speed := 0.0
@export var tint := Color.WHITE

@onready var band_a: Sprite2D = $BandA
@onready var band_b: Sprite2D = $BandB

var _offset := 0.0


func _ready() -> void:
	band_a.modulate = tint
	band_b.modulate = tint
	set_zone(zone)


func _process(delta: float) -> void:
	if idle_speed > 0.0:
		advance(idle_speed * delta)


## Scrolls the panorama. The course feeds this the distance covered this frame.
func advance(step: float) -> void:
	var width := strip_width()
	if width <= 0.0:
		return
	_offset = fposmod(_offset - step * parallax, width) - width
	_place(width)


func set_zone(index: int) -> void:
	zone = clampi(index, 0, maxi(0, zone_textures.size() - 1))
	if zone_textures.is_empty():
		return
	var texture := zone_textures[zone]
	if texture == null:
		return
	var scale_factor := band_height / float(texture.get_height())
	for band in [band_a, band_b]:
		band.texture = texture
		band.scale = Vector2(scale_factor, scale_factor)
	_place(strip_width())


func strip_width() -> float:
	if band_a.texture == null:
		return 0.0
	return band_a.texture.get_width() * band_a.scale.x


func _place(width: float) -> void:
	band_a.position.x = _offset
	band_b.position.x = _offset + width
