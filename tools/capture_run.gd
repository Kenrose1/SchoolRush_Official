extends Node
## Dev harness: drives the real screen flow and saves screenshots so the build
## can be reviewed without a human at the keyboard.
## Run: godot --path . res://tools/capture_run.tscn

const SHOT_DIR := "res://screenshots"

var _main: Node
var _game: Game


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _wait(20)

	var scene: PackedScene = load("res://scenes/main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	await _wait(30)
	await _shot("01_title")

	_main.call("_start_game", "campaign")
	await _wait(2)
	_game = _main.get("_game")
	await _wait(60)
	await _shot("02_run_start")

	# Wait for live hazards to enter the frame.
	for i in 400:
		if _game.get("_obstacles").size() >= 2:
			break
		await _wait(1)
	await _shot("03_run_obstacles")
	_report("obstacles")

	# A slide barrier right beside Elias, for the visual check.
	_game.player.lane = 1
	_game.call("_spawn_obstacle", "slide", 1, 900.0, "", 1.0)
	_game.call("_spawn_obstacle", "jump", 2, 1300.0, "sign", 1.0)
	await _wait(3)
	await _shot("03b_barrier")

	# Lane switch, then a jump.
	_game.player.move_lane(-1)
	await _wait(10)
	_game.player.jump()
	await _wait(12)
	await _shot("04_jump")
	await _wait(50)

	# Slide under a barrier.
	_game.player.slide()
	await _wait(8)
	await _shot("05_slide")
	await _wait(40)

	# Take a hit so the Pursuer spawns.
	_game.hearts = 3
	_game.call("_hit")
	await _wait(18)
	await _shot("06_pursuer")
	print("pursuer state=%s visible=%s intensity=%.2f pos=%s" % [
		_game.pursuer.state, _game.pursuer.visible, _game.pursuer.intensity, _game.pursuer.position,
	])

	# School zone palette.
	_game.distance_m = 980.0
	_game.set("_next_spawn_m", 1010.0)
	for obstacle in _game.get("_obstacles"):
		obstacle.queue_free()
	_game.get("_obstacles").clear()
	await _wait(120)
	await _shot("06b_school_zone")

	_main.call("_pause")
	await _wait(12)
	await _shot("07_pause")
	_main.call("_resume")
	await _wait(10)

	_game.call("_finish", "win", 0.0)
	await _wait(40)
	await _shot("08_result")

	print("capture: complete")
	await _wait(2)
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, name]
	image.save_png(ProjectSettings.globalize_path(path))
	print("shot %s %s" % [path, image.get_size()])


func _report(label: String) -> void:
	if _game == null:
		return
	print(
		"%s: dist=%.1f score=%d speed=%.0f lane=%d ratio=%.2f pursuer=%s obstacles=%d"
		% [
			label,
			_game.distance_m,
			int(_game.score),
			_game.speed,
			_game.player.lane,
			_game.speed_ratio(),
			_game.pursuer.state,
			_game.get("_obstacles").size(),
		]
	)
