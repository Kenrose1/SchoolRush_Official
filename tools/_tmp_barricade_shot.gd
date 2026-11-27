extends Node

const OUT := "res://tools/sources/_tmp_barricade_check.png"
const OUT_SLIDE := "res://tools/sources/_tmp_barricade_slide.png"


func _spawn(world: RunWorld, kind: GameConfig.HazardKind, lane: int, x: float) -> Hazard:
	var hazard := (load("res://scenes/hazard.tscn") as PackedScene).instantiate() as Hazard
	world.hazards.add_child(hazard)
	hazard.set_physics_process(false)
	hazard.setup(kind, lane, 0.0)
	hazard.position.x = x
	return hazard


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("saved err=%d %s" % [image.save_png(path), path])


func _ready() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var world := main.get_node("RunWorld") as RunWorld
	world.begin_run()
	for i in 5:
		await get_tree().physics_frame
	world.is_running = false
	world.player.set_physics_process(false)
	for child in world.hazards.get_children():
		child.queue_free()
	world.distance = world.home_zone_length + 1.0
	world._update_zone()
	world._update_debug()
	world.queue_redraw()
	await get_tree().physics_frame

	var lane := GameConfig.LANE_MIDDLE
	_spawn(world, GameConfig.HazardKind.BARRICADE, lane, 900.0)
	_spawn(world, GameConfig.HazardKind.BARRICADE, GameConfig.LANE_TOP, 1250.0)
	_spawn(world, GameConfig.HazardKind.BARRICADE, GameConfig.LANE_BOTTOM, 1250.0)
	_spawn(world, GameConfig.HazardKind.CONE, lane, 1150.0)
	var live := _spawn(world, GameConfig.HazardKind.BARRICADE, lane, GameConfig.PLAYER_X)

	var marker := Line2D.new()
	marker.points = PackedVector2Array([
		Vector2(0, GameConfig.lane_y(lane)),
		Vector2(2000, GameConfig.lane_y(lane))])
	marker.width = 2.0
	marker.default_color = Color.MAGENTA
	marker.z_index = 200
	world.hazards.add_child(marker)

	world.player.lane = lane
	world.player.lane_y = GameConfig.lane_y(lane)
	world.player.is_sliding = false
	world.player._update_hitbox()
	world.player._apply_pose()
	world.player._update_animation()
	for i in 4:
		await get_tree().physics_frame
	print("beam band %s" % str(live.box_y_range()))
	var card: Control = world.score_hud._card
	var score_label: Label = world.score_hud._score_label
	var items_label: Label = world.score_hud._items_label
	print("vp=%s card=%s score_rect=%s align=%d items=%s" % [
		get_viewport().get_visible_rect().size, card.get_global_rect(),
		score_label.get_global_rect(), score_label.horizontal_alignment,
		items_label.get_global_rect()])
	await _shot(OUT)

	world.player.is_sliding = true
	world.player.slide_time_left = GameConfig.SLIDE_DURATION
	world.player._update_hitbox()
	world.player._apply_pose()
	world.player._update_animation()
	world.player.sprite.play(&"slide")
	await get_tree().physics_frame
	world.player.sprite.frame = 2
	print("slide anim=%s frame=%d box=%s" % [
		String(world.player.sprite.animation), world.player.sprite.frame,
		str(world.player._box.size)])
	await _shot(OUT_SLIDE)
	get_tree().quit(0)
