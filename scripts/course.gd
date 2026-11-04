class_name Course
extends Node2D
## The ground and the three painted lane strips. The Player node owns the lane
## heights (they are what hazards spawn against), so the course mirrors them
## and tints the strips with the active zone colours.

## Distance from a lane baseline to the top of its painted strip.
@export var strip_lift := -46.0
@export var active_lane := 1

var lane_heights: Array[float] = [620.0, 800.0, 980.0]

var _tracks: Array[LaneTrack] = []


func _ready() -> void:
	for name in ["Track0", "Track1", "Track2"]:
		var track := get_node_or_null(name) as LaneTrack
		if track != null:
			_tracks.append(track)
	sync_lanes()
	set_active_lane(active_lane)


## Mirrors Player.lane_y so the strips always sit under the real lanes.
func sync_lanes() -> void:
	for i in _tracks.size():
		if i < lane_heights.size():
			_tracks[i].position.y = lane_heights[i] + strip_lift


func advance(step: float) -> void:
	for track in _tracks:
		track.advance(step)


func apply_theme(colors: Dictionary) -> void:
	var path: Color = colors.get("path", Color("33465c"))
	for track in _tracks:
		track.color = path
		track.apply_tint()


func set_active_lane(index: int) -> void:
	active_lane = index
	for i in _tracks.size():
		_tracks[i].set_active(i == index)
