class_name HitBurst
extends Sprite2D
## One-shot flash played from a pre-drawn spritesheet (Brackeys VFX Bundle).
##
## Sprite2D + a frame counter is enough here: the sheet is a fixed 6x4 grid and
## the effect never loops, so a SpriteFrames resource would only add indirection.
## The node stays in the player scene, hidden, and is replayed on each hit - no
## allocation during a run.

## Playback rate of the sheet. The source is authored for ~30 fps; 34 keeps the
## whole flash under half a second so it reads as an impact, not a smoke cloud.
@export var fps: float = 34.0
## Frames in the grid. The impact sheet is 6 columns x 4 rows.
@export var frame_count: int = 24

var _playing: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


## Restart the flash from frame 0. Safe to call while already playing.
func play() -> void:
	frame = 0
	_elapsed = 0.0
	_playing = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var index := int(_elapsed * fps)
	if index >= frame_count:
		_playing = false
		visible = false
		set_process(false)
		return
	frame = index
