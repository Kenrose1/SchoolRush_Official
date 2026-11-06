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

## Showcase placement: one of every hazard kind, right of the player.
const SHOWCASE := [
	[GameConfig.HazardKind.MANHOLE, GameConfig.LANE_BOTTOM, 760.0],
	[GameConfig.HazardKind.DEBRIS, GameConfig.LANE_MIDDLE, 960.0],
	[GameConfig.HazardKind.SIGN, GameConfig.LANE_TOP, 1160.0],
	[GameConfig.HazardKind.GANTRY, GameConfig.LANE_MIDDLE, 1400.0],
	[GameConfig.HazardKind.DOG, GameConfig.LANE_BOTTOM, 1660.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld

	await _wait(20)
	await _shot("m2_01_run")

	# Freeze spawning, clear the live hazards, then stage one of every kind.
	world.is_running = false
	for child in world.hazards.get_children():
		child.queue_free()
	await _wait(2)
	for entry: Array in SHOWCASE:
		_spawn(world, entry[0], entry[1], entry[2])
	await _wait(2)
	await _shot("m2_02_hazards")

	world.player.take_damage()
	await _wait(2)
	await _shot("m2_03_damage")

	for i in GameConfig.MAX_HEARTS:
		world.player.invulnerable_time_left = 0.0
		world.player.take_damage()
	await _wait(2)
	await _shot("m2_04_game_over")

	get_tree().quit(0)


func _spawn(world: RunWorld, kind: GameConfig.HazardKind, lane: int, x: float) -> void:
	var hazard := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	world.hazards.add_child(hazard)
	hazard.setup(kind, lane, 0.0)
	hazard.position.x = x


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	print("shot %s err=%d" % [path, image.save_png(path)])
