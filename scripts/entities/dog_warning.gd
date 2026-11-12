class_name DogWarning
extends Node2D

signal finished

const FADE_IN_TIME := 0.1
const FADE_OUT_TIME := 0.1
const MARKER_TEXTURE := preload("res://assets/signs/exclamation/Exclamation Mark 1st Outline 64px.png")

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = MARKER_TEXTURE
	sprite.scale = Vector2.ONE * 1.25
	modulate.a = 0.0


func play() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(maxf(GameConfig.DOG_WARNING_DURATION - FADE_IN_TIME - FADE_OUT_TIME, 0.0))
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	queue_free()
