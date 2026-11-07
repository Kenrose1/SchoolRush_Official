extends SceneTree
## Builds the tanod SpriteFrames resource from the officer sheet slices.
##
## The run frames (run_0..run_9.png, 200x260) were sliced from
## officer_sheet.png (Pixel Art Officer Running Sprite Sheet, 10 frames).
## To re-slice: crop the sheet with column-projection detection, save
## run_N.png, update RUN_FRAMES below, re-run this script.
##
## Run after adding, removing, or re-timing frames:
##   godot --headless --path . --script res://tools/build_tanod_frames.gd
##
## The generated .tres is committed and assigned in scenes/pursuer.tscn so the
## animations are visible and editable in the editor.

const TARGET := "res://assets/characters/tanod/tanod_frames.tres"
const FRAME_PATH := "res://assets/characters/tanod/run_%d.png"

const RUN_FRAMES := 10
const RUN_FPS := 14.0
const IDLE_FPS := 8.0


func _init() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", IDLE_FPS)
	frames.set_animation_loop("idle", true)
	var idle_texture := ResourceLoader.load(FRAME_PATH % 0) as Texture2D
	if idle_texture == null:
		push_error("Missing frame: %s" % FRAME_PATH % 0)
		quit(1)
		return
	frames.add_frame("idle", idle_texture)

	frames.add_animation("run")
	frames.set_animation_speed("run", RUN_FPS)
	frames.set_animation_loop("run", true)
	for index in RUN_FRAMES:
		var path := FRAME_PATH % index
		var texture := ResourceLoader.load(path) as Texture2D
		if texture == null:
			push_error("Missing frame: %s" % path)
			quit(1)
			return
		frames.add_frame("run", texture)
	frames.remove_animation("default")

	var err := ResourceSaver.save(frames, TARGET)
	if err != OK:
		push_error("Could not save %s (error %d)" % [TARGET, err])
		quit(1)
		return
	print("Wrote %s" % TARGET)
	quit(0)
