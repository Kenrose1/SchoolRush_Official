extends Node
## Headless checks for the rules that matter: hit detection, i-frames, slide
## clearance, combo cap and the Pursuer's instant game over.
## Run: godot --headless --path . res://tools/smoke.tscn

var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await _test_hits()
	await _test_jump_clearance()
	await _test_slide_clearance()
	await _test_pickups()
	await _test_pursuer()
	await _test_modes()
	await _test_world()
	_test_audio()
	print("smoke: %s (%d failures)" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s" % label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _new_game(mode := "campaign") -> Game:
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.mode = mode
	add_child(game)
	await _frames(3)
	return game


func _test_hits() -> void:
	print("hits + i-frames")
	var game: Game = await _new_game()
	game.call("_spawn_obstacle", "jump", game.player.lane, game.player.position.x + 10.0, "sign", 1.0)
	await _frames(2)
	_check("ground hazard costs a heart", game.hearts == 2)
	_check("post-hit i-frames engaged", game.player.invuln > 1.0 and game.player.invuln <= 1.5)
	_check("speed ratio drops on hit", game.speed_ratio() < 0.6)
	game.queue_free()
	await _frames(2)


func _test_jump_clearance() -> void:
	print("jump clearance")
	var game: Game = await _new_game()
	game.player.jump()
	game.player.set("_height", -250.0)
	game.player.set("_vy", 0.0)
	game.call("_spawn_obstacle", "jump", game.player.lane, game.player.position.x, "sign", 1.0)
	await _frames(2)
	_check("jumping clears a ground hazard", game.hearts == 3)
	game.queue_free()
	await _frames(2)


func _test_slide_clearance() -> void:
	print("slide clearance")
	var game: Game = await _new_game()
	game.player.slide()
	game.call("_spawn_obstacle", "slide", game.player.lane, game.player.position.x, "", 1.0)
	await _frames(2)
	_check("sliding passes under a barrier", game.hearts == 3)
	game.player.sliding = false
	game.player.invuln = 0.0
	game.call("_spawn_obstacle", "slide", game.player.lane, game.player.position.x, "", 1.0)
	await _frames(2)
	_check("standing hits the barrier", game.hearts == 2)
	game.queue_free()
	await _frames(2)


func _test_pickups() -> void:
	print("pickups + combo")
	var game: Game = await _new_game("endless")
	var start_score := game.score
	game.call("_spawn_pickup_item", "book", game.player.lane, game.player.position.x)
	await _frames(2)
	_check("item collected", game.items == 1)
	_check("combo climbs", game.combo == 2)
	_check("score awarded", game.score > start_score)
	game.combo = 5
	game.call("_spawn_pickup_item", "pencil", game.player.lane, game.player.position.x)
	await _frames(2)
	_check("combo caps at 5x", game.combo == 5)
	game.queue_free()
	await _frames(2)


func _test_pursuer() -> void:
	print("pursuer state machine")
	var game: Game = await _new_game("endless")
	_check("dormant before any hit", game.pursuer.state == "dormant")
	game.call("_spawn_obstacle", "jump", game.player.lane, game.player.position.x, "sign", 1.0)
	await _frames(2)
	_check("first hit spawns the pursuer", game.pursuer.state != "dormant")
	_check("pursuer is visible", game.pursuer.intensity > 0.5)
	game.player.invuln = 0.0
	game.call("_spawn_obstacle", "jump", game.player.lane, game.player.position.x, "sign", 1.0)
	await _frames(2)
	_check("second hit ends the run", not game.running)
	await _frames(90)
	_check("run reports the pursuer outcome", String(game.get("_pending").get("outcome", "")) == "pursuer")
	game.queue_free()
	await _frames(2)


func _test_world() -> void:
	print("world nodes")
	var game: Game = await _new_game("campaign")
	var background: Background = game.background
	var track: LaneTrack = game.course.get_node("Track1")
	var band_before := float(background.get("_offset"))
	var track_before := float(track.get("_offset"))
	await _frames(10)
	_check("panorama scrolls", absf(float(background.get("_offset")) - band_before) > 0.5)
	_check("lane strips scroll", absf(float(track.get("_offset")) - track_before) > 0.5)
	_check("course has three painted tracks",
		game.course.get_node_or_null("Track0") != null and game.course.get_node_or_null("Track2") != null)
	game.distance_m = game.campaign_m * 0.9
	await _frames(6)
	_check("zone change swaps the panorama", background.zone == 2)
	_check("zone change retints the strips", track.color != Color("3d3352"))
	game.queue_free()
	await _frames(2)


func _test_audio() -> void:
	print("audio")
	var music: AudioStreamWAV = Sfx.get("_music").stream
	_check("chiptune loop synthesised", music != null and music.get_length() > 4.0)
	_check("sfx bank populated", Sfx.get("_sfx").size() >= 8)


func _test_modes() -> void:
	print("modes")
	var endless: Game = await _new_game("endless")
	_check("endless has no bell", endless.bell_left == endless.bell_time)
	_check("endless hides the progress bar", endless.mode_label() == "ENDLESS SURVIVAL")
	endless.queue_free()
	await _frames(2)

	var training: Game = await _new_game("training")
	var before := training.hearts
	training.call("_spawn_obstacle", "jump", training.player.lane, training.player.position.x, "sign", 1.0)
	await _frames(3)
	_check("training is damage free", training.hearts == before)
	training.queue_free()
	await _frames(2)

	var campaign: Game = await _new_game("campaign")
	campaign.distance_m = campaign.campaign_m
	await _frames(3)
	_check("campaign wins at the classroom", not campaign.running)
	campaign.queue_free()
	await _frames(2)
