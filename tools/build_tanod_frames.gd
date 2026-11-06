extends SceneTree
## Builds the tanod SpriteFrames resource from the per-frame PNGs.
##
## Run after adding, removing, or re-timing frames:
##   godot --headless --path . --script res://tools/build_tanod_frames.gd
##
## The generated .tres is committed and assigned in scenes/pursuer.tscn so the
## animations are visible and editable in the editor.

const TARGET := "res://assets/characters/tanod/tanod_frames.tres"
const FRAME_PATH := "res://assets/characters/tanod/%s_%d.png"

const ANIMATIONS := {
	"idle": {"frames": 4, "fps": 8.0, "loop": true},
	"run": {"frames": 9, "fps": 14.0, "loop": true},
}


func _init() -> void:
	var frames := SpriteFrames.new()
	for anim_name in ANIMATIONS:
		var config: Dictionary = ANIMATIONS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(config["fps"]))
		frames.set_animation_loop(anim_name, bool(config["loop"]))
		for index in int(config["frames"]):
			var path := FRAME_PATH % [anim_name, index]
			var texture := ResourceLoader.load(path) as Texture2D
			if texture == null:
				push_error("Missing frame: %s" % path)
				quit(1)
				return
			frames.add_frame(anim_name, texture)
	frames.remove_animation("default")

	var err := ResourceSaver.save(frames, TARGET)
	if err != OK:
		push_error("Could not save %s (error %d)" % [TARGET, err])
		quit(1)
		return
	print("Wrote %s" % TARGET)
	quit(0)
