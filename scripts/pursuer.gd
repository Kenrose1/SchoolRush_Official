class_name Pursuer
extends Node2D
## The Barangay Guard. Opacity and gap bind to the player's speed ratio, so a
## mistake visibly lets him close in (GDD section 04).

@export_group("Pressure")
## How far behind the player he sits when at full intensity.
@export var spawn_gap := 300.0
@export var close_gap := 60.0
## Speed ratio at which he is fully visible.
@export var fade_ratio := 0.42
## Intensity above which another hit ends the run outright.
@export var lunge_threshold := 0.35

@export_group("Visuals")
@export var sprite_scale := 1.2

var state := "dormant"   # dormant | recover | lunge
var intensity := 0.0
var speed_ratio := 1.0
var player_x := Pal.LANE_X

@onready var sprite: AnimatedSprite2D = $Sprite

var _offset := spawn_gap


func _ready() -> void:
	sprite.scale = Vector2(sprite_scale, sprite_scale)
	var texture := sprite.sprite_frames.get_frame_texture("run", 0)
	if texture != null:
		sprite.offset = Vector2(0.0, -texture.get_height() * 0.5)
	sprite.play("run")
	visible = false


func _process(delta: float) -> void:
	if state == "dormant":
		visible = false
		return

	visible = true
	var gap := lerpf(spawn_gap, close_gap, intensity)
	if state == "lunge":
		gap = lerpf(_offset, -10.0, minf(1.0, delta * 9.0))
	_offset = lerpf(_offset, gap, minf(1.0, delta * 6.0))
	position.x = player_x - _offset
	modulate.a = intensity if state != "lunge" else 1.0
	sprite.speed_scale = 1.0 if state != "lunge" else 1.8
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var t := clampf(intensity, 0.0, 1.0)
	if t < 0.12 and state != "lunge":
		return
	for i in 3:
		var radius := 16.0 + i * 9.0
		draw_circle(Vector2(-30.0 - i * 18.0, -6.0 - i * 3.0), radius, Color(1, 1, 1, 0.05 * t))


## Called on every fresh hit. Returns true when this is a second hit in a row.
func appear() -> bool:
	if state == "lunge":
		return true
	if intensity > lunge_threshold:
		lunge()
		return true
	state = "recover"
	intensity = 1.0
	_offset = spawn_gap * 0.6
	Sfx.play("pursuer", 2.0)
	return false


func lunge() -> void:
	state = "lunge"
	intensity = 1.0
	Sfx.play("pursuer", 4.0)


func sync_ratio(ratio: float, lane_y: float) -> void:
	speed_ratio = clampf(ratio, 0.0, 1.0)
	position.y = lane_y
	if state == "lunge":
		return
	intensity = clampf((1.0 - speed_ratio) / fade_ratio, 0.0, 1.0)
	if intensity <= 0.01:
		state = "dormant"
	elif state == "dormant":
		state = "recover"


func is_threat() -> bool:
	return state != "dormant" and intensity > 0.3
