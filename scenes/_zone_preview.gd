extends Node2D
## TEMPORARY preview: jumps the run straight to the school corridor so the
## hallway background can be captured without playing 39 seconds of the course.

func _ready() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var world := main.get_node("RunWorld") as RunWorld
	world.set_physics_process(false)
	world.distance = world.home_zone_length + world.street_zone_length + 1.0
	world._update_zone()
	world._zone_fade_time_left = 0.0
	world._zone_fade.color.a = 0.0
	world.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var tex: Texture2D = world._school_texture
	var lines := ""
	if tex != null:
		lines += "path=%s\nsize=%s\n" % [tex.resource_path, tex.get_size()]
	else:
		lines += "texture null\n"
	var campus: Texture2D = world._school_campus_texture
	lines += "campus=%s\n" % (campus.resource_path if campus != null else "null")
	var f := FileAccess.open("res://_school_tex_debug.txt", FileAccess.WRITE)
	f.store_string(lines)
	f.close()