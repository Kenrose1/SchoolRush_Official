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

	# The menu boots first in the real app; capture it, then drop it so the
	# run scene below is unaffected.
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _wait(2)
	await _shot("m5_00_menu")
	# Settings panel open, captured from the menu host.
	menu._on_settings_pressed()
	await _wait(2)
	await _shot("m5_01_settings")
	menu.settings_panel.close()
	menu.queue_free()
	await _wait(2)

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld

	await _wait(20)
	await _shot("m5_01_home")
	await _shot("m3_01_run")

	# M5: pause button + overlay. Rendering keeps running while the tree is
	# paused, so wait on the draw signal rather than on physics frames.
	world.pause_menu.set_paused(true)
	await _shot("m5_06_paused")
	world.pause_menu._on_settings_pressed()
	await _shot("m5_07_pause_settings")
	world.pause_menu.settings_panel.close()
	world.pause_menu.set_paused(false)
	await _wait(2)

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
	await _wait(10)
	# Show the results deterministically. Endless mode so the staged 1000 m run
	# shows the top-tier gold distance medal, then let the reveal finish (~1 s).
	world.set_run_mode(GameConfig.RunMode.ENDLESS)
	world.distance = 100000.0
	world._show_game_over(ResultsScreen.Outcome.CAUGHT)
	# Restore campaign so later course captures show the FINISH readout.
	world.set_run_mode(GameConfig.RunMode.CAMPAIGN)
	world.distance = 5880.0
	await _wait(90)
	await _shot("m4_02_caught")

	# Endless deep-street staging: ramped SPEED in the debug readout, street
	# backdrop, no FINISH line. The run is stopped, so the frame is stable.
	world.results.visible = false
	world.arrest.visible = false
	world.player.sprite.visible = true
	world.set_run_mode(GameConfig.RunMode.ENDLESS)
	world.distance = (
		world.home_zone_length + world.street_zone_length
		+ GameConfig.ENDLESS_RAMP_DISTANCE * 0.75
	)
	world.speed = world._base_speed()
	world._update_zone()
	world._update_debug()
	world.queue_redraw()
	await _shot("m5_08_endless")
	world.set_run_mode(GameConfig.RunMode.CAMPAIGN)
	world.distance = 5880.0

	# M5: hold the zone fade mid-way, then reveal the street zone.
	world.results.visible = false
	world.arrest.visible = false
	world.player.sprite.visible = true
	world.set_process(false)
	world.distance = world.home_zone_length + 1.0
	world._update_zone()
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

	# The arrest animation from the M4 capture can finish late and re-show the
	# overlay; drop its one-shot callbacks so the remaining zone shots stay clean.
	var arrest_finished := Callable(world, "_on_arrest_finished")
	if world.arrest.animation_finished.is_connected(arrest_finished):
		world.arrest.animation_finished.disconnect(arrest_finished)
	var lunge_finished := Callable(world, "_on_lunge_finished")
	if world.pursuer.lunge_finished.is_connected(lunge_finished):
		world.pursuer.lunge_finished.disconnect(lunge_finished)
	world.results.visible = false
	world.arrest.visible = false
	world.player.sprite.visible = true

	# Street -> School: hold the second fade mid-way, then stage a hazard run
	# in the hallway and reveal the terminal school zone.
	world.distance = world.home_zone_length + world.street_zone_length + 1.0
	world._update_zone()
	world._zone_fade_time_left = GameConfig.ZONE_FADE_TIME * 0.5
	world._zone_fade.color.a = 0.5
	world._update_debug()
	world.queue_redraw()
	await _wait(2)
	await _shot("m5_04_school_fade")

	world._zone_fade_time_left = 0.0
	world._zone_fade.color.a = 0.0
	for child in world.hazards.get_children():
		child.queue_free()
	await _wait(2)
	for entry: Array in SHOWCASE:
		_spawn(world, entry[0], entry[1], entry[2])
	for entry: Array in ITEM_SHOWCASE:
		_spawn_item(world, entry[0], entry[1], entry[2])
	world._update_debug()
	world.queue_redraw()
	await _wait(2)
	await _shot("m5_05_school")

	# Campaign: cross the finish line for the MADE IT! victory. Stage a best
	# below the run's score so the capture shows the gold badge.
	world.set_run_mode(GameConfig.RunMode.CAMPAIGN)
	GameState.best_campaign = 500
	world._finished = false
	world.distance = world.campaign_finish_distance
	world._finish_campaign()
	await _wait(90)
	await _shot("m5_08_campaign_finish")

	get_tree().quit(0)


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
