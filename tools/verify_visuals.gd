extends Node
## Visual smoke test for a milestone.
##
## Headless runs cannot show layout or sprite problems, so this boots the real
## game, drives the input map, and writes viewport captures to user://captures/.
##
##   godot --path . res://tools/verify_visuals.tscn
##
## Captures land in %APPDATA%\Godot\app_userdata\SchoolRush\captures\.

const OUT_DIR := "user://captures"


func _ready() -> void:
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	await _wait(45)
	await _shot("frames_01_run")
	await _press(KEY_SPACE)
	await _wait(10)
	await _shot("frames_02_jump")
	await _wait(28)
	await _press(KEY_CTRL)
	await _wait(8)
	await _shot("frames_03_slide")
	get_tree().quit(0)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var up := InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	print("shot %s err=%d" % [path, image.save_png(path)])
