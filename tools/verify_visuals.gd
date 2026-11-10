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

## Showcase placement: one of every active hazard kind, right of the player.
## Dog is parked for M4 (re-adds in M6), so it is not staged.
const SHOWCASE := [
	[GameConfig.HazardKind.MANHOLE, GameConfig.LANE_BOTTOM, 760.0],
	[GameConfig.HazardKind.DEBRIS, GameConfig.LANE_MIDDLE, 960.0],
	[GameConfig.HazardKind.SIGN, GameConfig.LANE_TOP, 1160.0],
	[GameConfig.HazardKind.GANTRY, GameConfig.LANE_MIDDLE, 1400.0],
]

## Showcase for School Items: one of each kind across the lanes.
const ITEM_SHOWCASE := [
	[GameConfig.ItemKind.PENCIL, GameConfig.LANE_TOP, 740.0],
	[GameConfig.ItemKind.ERASER, GameConfig.LANE_MIDDLE, 940.0],
	[GameConfig.ItemKind.BOOK, GameConfig.LANE_BOTTOM, 1140.0],
	[GameConfig.ItemKind.BAG, GameConfig.LANE_MIDDLE, 1340.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld

	await _wait(20)
	await _shot("m5_01_home")
	await _shot("m3_01_run")

	# Freeze spawning, clear the live objects, then stage hazards + items.
	world.is_running = false
	for child in world.hazards.get_children():
		child.queue_free()
	await _wait(2)
	for entry: Array in SHOWCASE:
		_spawn(world, entry[0], entry[1], entry[2])
	for entry: Array in ITEM_SHOWCASE:
		_spawn_item(world, entry[0], entry[1], entry[2])
	await _wait(2)
	await _shot("m3_02_items_and_hazards")

	# Build a combo so the multiplier readout is populated.
	for i in 12:
		world.score_system.add_item_pickup()
	await _wait(2)
	await _shot("m3_03_combo")

	# M4: wake the tanod and capture the chase, then the CAUGHT! lunge.
	world.is_running = true
	world._on_player_damaged(2)
	await _wait(30)
	await _shot("m4_01_chase")

	world._on_player_caught()
	await _wait(30)
	await _shot("m4_02_caught")

	# M5: hold the zone fade mid-way, then reveal the terminal street.
	world.game_over_root.visible = false
	world.arrest.visible = false
	world.player.sprite.visible = true
	world.set_process(false)
	world.distance = world.home_zone_length + 1.0
	world._update_zone()
	_sync_hud(world)
	world._zone_fade_time_left = GameConfig.ZONE_FADE_TIME * 0.5
	world._zone_fade.color.a = 0.5
	world._update_debug()
	world.queue_redraw()
	await _wait(2)
	await _shot("m5_02_zone_fade")

	world._zone_fade_time_left = 0.0
	world._zone_fade.color.a = 0.0
	world._update_debug()
	world.queue_redraw()
	await _wait(2)
	await _shot("m5_03_street")

	# Stop the arrest strip and clear the overlay so it cannot cover the frames.
	world.arrest.stop()
	world.arrest.visible = false
	world.game_over_root.visible = false

	# M6: cross the street boundary and capture the school corridor, where the
	# campus panorama shows through the hallway glass.
	world.distance = world.home_zone_length + world.street_zone_length + 1.0
	world._update_zone()
	_sync_hud(world)
	world._zone_fade_time_left = 0.0
	world._zone_fade.color.a = 0.0
	world._update_debug()
	world.queue_redraw()
	await _wait(2)
	await _shot("m6_01_school")

	# Shift by half a tile so a loop junction sits mid-screen: with the mirrored
	# loop this frame must show no seam.
	world.distance += GameConfig.DESIGN_WIDTH * 0.5
	_sync_hud(world)
	world.queue_redraw()
	await _wait(2)
	await _shot("m6_02_school_seam")

	# Game over overlay, so the retry button art is captured too.
	world._show_game_over(true)
	await _wait(2)
	await _shot("m6_03_game_over")

	# Endgame: the artist's hallway slides in over the last screen of corridor,
	# then the scroll stops on it and Elias covers the rest to the exit door.
	world.game_over_root.visible = false
	world.player.sprite.visible = true
	world.player.sprite.play(&"run")
	world.distance = world._finale_distance() - GameConfig.DESIGN_WIDTH * 0.45
	world.queue_redraw()
	await _wait(2)
	await _shot("m7_00_approach")

	world.distance = world._finale_distance()
	world._start_finale()
	world.hud.set_speed(GameConfig.FINALE_RUN_SPEED)
	world.hud.set_speed_ratio(1.0)
	world.player._apply_pose()
	world.queue_redraw()
	await _wait(2)
	await _shot("m7_01_doors_ahead")

	world.player.forward_offset = world._door_offset() * 0.6
	world.player.forward_offset_y = (
		world._door_threshold_y() - world.player.lane_y) * 0.6
	world.player.depth_scale = lerpf(1.0, GameConfig.FINALE_DEPTH_SCALE, 0.6)
	world.player._apply_pose()
	await _wait(2)
	await _shot("m7_02_dash")

	world._finish_run()
	await _wait(2)
	await _shot("m7_03_escaped")

	# Settings card, opened the way the rail's gear button opens it.
	var controls := main.get_node_or_null("RunWorld/Controls")
	if controls != null:
		controls.call("_open_settings")
		await _wait(2)
		await _shot("m8_00_settings")
		controls.call("_close_settings")

	get_tree().quit(0)


## The captures jump zones while the run is paused, so push the same HUD values
## a physics frame would, or the meters show the last live frame instead.
func _sync_hud(world: RunWorld) -> void:
	world.base_speed = GameConfig.zone_run_speed(world.current_zone)
	world.speed = world.base_speed
	world.score_hud.set_distance(world.distance, world._zone_goal_distance())
	world.score_hud.set_distance_progress(world._zone_progress())
	world.hud.set_speed(world.speed)
	world.hud.set_speed_ratio(world.speed / GameConfig.max_run_speed())


func _spawn(world: RunWorld, kind: GameConfig.HazardKind, lane: int, x: float) -> void:
	var hazard := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	world.hazards.add_child(hazard)
	hazard.setup(kind, lane, 0.0)
	hazard.position.x = x


func _spawn_item(world: RunWorld, kind: GameConfig.ItemKind, lane: int, x: float) -> void:
	var item := (load("res://scenes/collectible.tscn") as PackedScene).instantiate() as Collectible
	world.hazards.add_child(item)
	item.setup(kind, lane, 0.0)
	item.position.x = x


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	print("shot %s err=%d" % [path, image.save_png(path)])
