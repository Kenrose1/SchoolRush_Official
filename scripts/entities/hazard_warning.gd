class_name HazardWarning
extends Node2D
## A flashing exclamation marker shown in a lane before a special hazard
## (dog encounter, street car) enters. Fade in, hold, fade out, then report
## finished so the caller can spawn the real hazard.

signal finished

const FADE_IN_TIME := 0.1
const FADE_OUT_TIME := 0.1

## Texture and hold time are injected by the caller; duration is the total
## seconds from the start of play() to finished.
var _texture: Texture2D = null
var _duration: float = 0.8

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	if _texture != null:
		sprite.texture = _texture
	sprite.scale = Vector2.ONE * 1.25
	modulate.a = 0.0


## Configure before adding to the tree (texture applies in _ready).
func setup(texture: Texture2D, duration: float) -> void:
	_texture = texture
	_duration = duration


func play() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(maxf(_duration - FADE_IN_TIME - FADE_OUT_TIME, 0.0))
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	queue_free()
