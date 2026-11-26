class_name Player
extends CharacterBody2D
## Elias, the playable runner.
##
## Owns lane switching, jumping, sliding, health, and presentation. Forward
## motion and distance belong to the world; the pursuer and scoring arrive in
## later milestones.

signal lane_changed(lane: int)
signal jumped
signal landed
signal slide_started
signal slide_finished
signal damaged(remaining_hearts: int)
signal health_changed(current: int, maximum: int)
signal shield_changed(current: int, maximum: int)
signal shield_used(charges: int)
signal item_collected(kind: int)
signal died
signal caught

## Current lane tier (GameConfig.LANE_TOP / MIDDLE / BOTTOM).
var lane: int = GameConfig.PLAYER_START_LANE
## Interpolated baseline Y of the current lane (the feet position).
var lane_y: float = 0.0
## Height above the lane baseline while airborne, in pixels.
var air_height: float = 0.0
## Vertical speed while airborne (positive = rising).
var vertical_speed: float = 0.0
var in_air: bool = false
var is_sliding: bool = false
var slide_time_left: float = 0.0

var health: int = GameConfig.MAX_HEARTS
## Effective heart cap: MAX_HEARTS plus the bought Heart upgrades.
var max_health: int = GameConfig.MAX_HEARTS
## Run-cycle cadence relative to the speed the sheet is timed for. RunWorld
## pushes the live ground speed every frame (see set_run_speed_scale) so the
## feet keep up with the road instead of skating through ramps and dips.
var run_speed_scale: float = 1.0
## Per-run shield charges (bought in the shop). A charge absorbs one hazard
## hit with no heart loss and no combo break.
var shield_charges: int = 0
var shield_max: int = 0
var invulnerable_time_left: float = 0.0
## Test counter: how many times the hurt sound actually fired.
var hurt_play_count: int = 0
## Test counter: how many times the car-death animation actually fired.
var death_play_count: int = 0
## Once a fatal car hit plays the knockdown, nothing may swap it back to hurt.
var _death_played: bool = false
## Counted for the test suite; pitch is re-rolled per launch (see below).
var jump_play_count: int = 0
## Test counters: how many times each pickup sound actually fired. A coin
## trail can fire several times a second, so the split (coin vs item) is
## asserted rather than assumed.
var coin_play_count: int = 0
var item_play_count: int = 0
## Test counters for the VFX: ground-dust bursts (launch + landing) and the
## impact flash. Presentation-only work still gets a counter so the suite can
## hold the trigger conditions (e.g. shield absorbs must not flash).
var dust_burst_count: int = 0
var hit_burst_count: int = 0
## Seconds of cyan flash left after a shield absorbed a hit. Presentation only.
var shield_flash_time: float = 0.0

## Pitch spread for the jump sound: each launch re-rolls playback pitch in
## 1.0 ± this value, so consecutive jumps never sound identical.
const JUMP_PITCH_VARIATION := 0.05

## How long the cyan "blocked" tint lasts after a shield charge absorbs a hit.
const SHIELD_FLASH_TIME := 0.25

## Touch: a drag shorter than this counts as a tap (jump). Anything longer is a
## swipe, resolved on the dominant axis.
const TOUCH_SWIPE_MIN := 48.0

## Where the current touch started (design-space pixels).
var _touch_start: Vector2 = Vector2.ZERO
var _touch_started: bool = false
## Test counter: touch gestures that turned into a gameplay action.
var touch_action_count: int = 0

## Ground dust is presentation only, but takeoff should read lighter than a
## landing, so each beat sets its own particle count and launch speed.
const JUMP_DUST_AMOUNT := 8
const LAND_DUST_AMOUNT := 14

## Pitch spread for the coin pickup, same trick. A coin trail lands every
## ~0.14 s (60 px spacing at RUN_SPEED), so without it the trail machine-guns.
## Items stay at pitch 1.0: they are the rarer reward and get one stable voice.
const PICKUP_PITCH_VARIATION := 0.06

var _lean: float = 0.0
var _hurt_time_left: float = 0.0
var _current_anim: StringName = &""
## True while RunWorld holds Elias at the start line for the 3-2-1 countdown.
## The physics lock already stops him moving, but the run cycle would read as
## sprinting on the spot, so the body idles instead. Public because the world
## owns the countdown; the setter re-plays the pose immediately since physics is
## switched off while the overlay is up.
var waiting_at_start: bool = false:
	set(value):
		if waiting_at_start == value:
			return
		waiting_at_start = value
		_update_animation()
## Per-launch pitch variation for the jump sound, so repeated jumps do not
## sound like a machine gun.
var _sfx_rng := RandomNumberGenerator.new()

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape
@onready var land_dust: CPUParticles2D = $LandDust
@onready var hit_burst: HitBurst = $HitBurst
@onready var hurt_sfx: AudioStreamPlayer = %HurtSfx
@onready var jump_sfx: AudioStreamPlayer = %JumpSfx
@onready var coin_sfx: AudioStreamPlayer = %CoinSfx
@onready var item_sfx: AudioStreamPlayer = %ItemSfx

## Per-instance copy so sliding cannot resize shapes shared between players.
var _box: RectangleShape2D


func _ready() -> void:
	lane_y = GameConfig.lane_y(lane)
	_sfx_rng.randomize()
	# Shop upgrades: bigger heart pool and starting shield charges.
	max_health = GameConfig.shop_max_hearts(GameState.shop_level(GameConfig.ShopUpgrade.HEARTS))
	health = max_health
	shield_max = GameConfig.shop_shield_charges(GameState.shop_level(GameConfig.ShopUpgrade.SHIELD))
	shield_charges = shield_max
	# Layers come from GameConfig so collision setup lives in one place.
	hitbox.collision_layer = GameConfig.LAYER_PLAYER
	hitbox.collision_mask = GameConfig.PLAYER_MASK
	hitbox.monitoring = true
	_box = (hitbox_shape.shape as RectangleShape2D).duplicate()
	hitbox_shape.shape = _box
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_update_hitbox()
	_play(&"run")
	_apply_pose()
	health_changed.emit(health, max_health)
	shield_changed.emit(shield_charges, shield_max)


func _physics_process(delta: float) -> void:
	_update_lane(delta)
	_update_jump(delta)
	_update_slide(delta)
	_update_invulnerability(delta)
	_update_hitbox()
	_apply_pose()
	_update_animation()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("lane_up"):
		move_lane(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lane_down"):
		move_lane(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		jump()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("slide"):
		slide()
		get_viewport().set_input_as_handled()


# --- Touch -------------------------------------------------------------------

## Tap to jump, swipe up/down to change lane, swipe left to slide. A right swipe
## does nothing (there is nothing to run into on that side), which keeps a
## stray horizontal drag from firing an action by accident.
func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_start = event.position
		_touch_started = true
		return
	if not _touch_started:
		return
	_touch_started = false
	var delta := event.position - _touch_start
	if delta.length() < TOUCH_SWIPE_MIN:
		if jump():
			touch_action_count += 1
		return
	if absf(delta.x) > absf(delta.y):
		if delta.x < 0.0 and slide():
			touch_action_count += 1
		return
	if delta.y < 0.0:
		if move_lane(-1):
			touch_action_count += 1
	elif move_lane(1):
		touch_action_count += 1


# --- Public actions ----------------------------------------------------------

## Step one lane up (-1) or down (+1). Returns false at the outer lanes.
func move_lane(direction: int) -> bool:
	var next := GameConfig.step_lane(lane, direction)
	if next == lane:
		return false
	lane = next
	lane_changed.emit(lane)
	_resolve_overlaps()
	return true


## Retime the run cycle to the live ground speed: 1.0 is the authored cadence,
## 0.75 is a fully dipped momentum frame, 1.4 is the clamp. Cheap enough to
## call every physics frame; a steady speed never disturbs the playback.
func set_run_speed_scale(scale: float) -> void:
	run_speed_scale = clampf(scale,
		GameConfig.RUN_ANIM_SPEED_SCALE_MIN, GameConfig.RUN_ANIM_SPEED_SCALE_MAX)
	if _current_anim == &"run" and is_instance_valid(sprite):
		sprite.speed_scale = run_speed_scale


## Start a jump. Returns false when already airborne or out of bounds.
func jump() -> bool:
	if in_air:
		return false
	if is_sliding:
		_end_slide()
	in_air = true
	air_height = 0.0
	# Spring Shoes upgrade scales the launch speed (and so the apex).
	vertical_speed = GameConfig.shop_jump_speed(
		GameState.shop_level(GameConfig.ShopUpgrade.JUMP))
	_play_jump_sound()
	_burst_ground_dust(JUMP_DUST_AMOUNT, 60.0)
	jumped.emit()
	return true


## Start a slide. Returns false while already sliding or airborne.
func slide() -> bool:
	if is_sliding or in_air:
		return false
	is_sliding = true
	slide_time_left = GameConfig.SLIDE_DURATION
	slide_started.emit()
	return true


## Whether a hit would register right now.
func can_take_damage() -> bool:
	return health > 0 and invulnerable_time_left <= 0.0


## Apply damage unless invulnerable. A shield charge absorbs the hit first:
## no heart loss, no combo break, but the brief i-frame grace still applies.
## Returns true only when the hit landed (a heart was lost).
func take_damage(amount: int = 1, source_kind: int = -1) -> bool:
	if not can_take_damage():
		return false
	if shield_charges > 0:
		shield_charges = maxi(shield_charges - 1, 0)
		invulnerable_time_left = GameConfig.I_FRAME_TIME
		shield_flash_time = SHIELD_FLASH_TIME
		shield_changed.emit(shield_charges, shield_max)
		shield_used.emit(shield_charges)
		return false
	health = maxi(health - amount, 0)
	invulnerable_time_left = GameConfig.I_FRAME_TIME
	_hurt_time_left = GameConfig.HURT_ANIM_TIME
	_play_hurt_sound()
	_flash_hit_burst()
	damaged.emit(health)
	health_changed.emit(health, max_health)
	if health == 0:
		if source_kind == GameConfig.HazardKind.CAR:
			_play_death()
		died.emit()
	return true


## Hurt sound fires only when a heart is actually lost - shield absorbs and
## i-frame-blocked hits stay silent. Counted for the test suite.
## Car impacts swap the generic hurt pose for the dedicated knockdown sheet.
## Counted so the suite can prove it only fires for a fatal car hit.
func _play_death() -> void:
	death_play_count += 1
	_death_played = true
	_play(&"death")


func _play_hurt_sound() -> void:
	hurt_play_count += 1
	hurt_sfx.play()


## Jump sound fires once per actual launch (jump() returns early mid-air), with
## a re-rolled pitch in ±JUMP_PITCH_VARIATION so repeats do not sound identical.
func _play_jump_sound() -> void:
	jump_play_count += 1
	jump_sfx.pitch_scale = 1.0 + _sfx_rng.randf_range(
		-JUMP_PITCH_VARIATION, JUMP_PITCH_VARIATION)
	jump_sfx.play()


## Pickup audio, split by reward channel: COIN gets the short jingle with a
## re-rolled pitch (a trail fires every ~0.14 s), every School Item gets the
## heavier item jingle at one stable pitch. Called from _collect_item, right
## after the collect signal, so audio and scoring never disagree.
func _play_pickup_sound(kind: int) -> void:
	if kind == GameConfig.ItemKind.COIN:
		coin_play_count += 1
		coin_sfx.pitch_scale = 1.0 + _sfx_rng.randf_range(
			-PICKUP_PITCH_VARIATION, PICKUP_PITCH_VARIATION)
		coin_sfx.play()
	else:
		item_play_count += 1
		item_sfx.pitch_scale = 1.0
		item_sfx.play()


## Presentation-only dust puff shared by takeoff and landing. The emitter runs
## in world space, so the puffs stay behind while Elias keeps running. Counter
## is for the suite: takeoff and landing must both burst exactly once.
func _burst_ground_dust(count: int, speed: float) -> void:
	if land_dust == null:
		return
	dust_burst_count += 1
	land_dust.amount = count
	land_dust.initial_velocity_min = speed * 0.5
	land_dust.initial_velocity_max = speed
	land_dust.restart()


## Impact flash from the pre-drawn sheet. Only a real heart loss reaches here —
## shield absorbs and i-frame-blocked hits return before this call — so the
## flash never lies about damage.
func _flash_hit_burst() -> void:
	if hit_burst == null:
		return
	hit_burst_count += 1
	hit_burst.play()


## Restore full health and shields and clear invulnerability (used by tests
## and retries).
func reset_health() -> void:
	health = max_health
	shield_charges = shield_max
	invulnerable_time_left = 0.0
	shield_flash_time = 0.0
	_hurt_time_left = 0.0
	_death_played = false
	health_changed.emit(health, max_health)
	shield_changed.emit(shield_charges, shield_max)


# --- Movement ----------------------------------------------------------------

func _update_lane(delta: float) -> void:
	var target := GameConfig.lane_y(lane)
	lane_y = move_toward(lane_y, target, GameConfig.LANE_SWITCH_SPEED * delta)

	var remaining := target - lane_y
	var lean_target := 0.0 if is_zero_approx(remaining) else -signf(remaining) * GameConfig.LANE_LEAN_DEGREES
	_lean = lerpf(_lean, lean_target, clampf(GameConfig.LANE_LEAN_SMOOTHING * delta, 0.0, 1.0))


func _update_jump(delta: float) -> void:
	if not in_air:
		return
	air_height += vertical_speed * delta
	vertical_speed -= GameConfig.GRAVITY * delta
	if air_height <= 0.0:
		air_height = 0.0
		vertical_speed = 0.0
		in_air = false
		_burst_ground_dust(LAND_DUST_AMOUNT, 105.0)
		landed.emit()


func _update_slide(delta: float) -> void:
	if is_sliding:
		slide_time_left -= delta
		if slide_time_left <= 0.0:
			_end_slide()

	if _hurt_time_left > 0.0:
		_hurt_time_left = maxf(_hurt_time_left - delta, 0.0)


func _update_invulnerability(delta: float) -> void:
	if invulnerable_time_left > 0.0:
		invulnerable_time_left = maxf(invulnerable_time_left - delta, 0.0)
	if shield_flash_time > 0.0:
		shield_flash_time = maxf(shield_flash_time - delta, 0.0)


func _end_slide() -> void:
	if not is_sliding:
		return
	is_sliding = false
	slide_time_left = 0.0
	slide_finished.emit()


# --- Collision ---------------------------------------------------------------

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hazard:
		_hit_hazard(area as Hazard)
	elif area is Collectible:
		_collect_item(area as Collectible)


## Hazards are lane-bound: a jump can lift the hitbox into a neighbouring
## lane's band, but only boxes in Elias's logical lane may hurt him.
func _hit_hazard(hazard: Hazard) -> void:
	if hazard.lane != lane:
		return
	# A hit always costs a heart. While the tanod is chasing, RunWorld also
	# knocks him closer (see Pursuer.knock_closer); that visible knock is what
	# turns a second mistake into the catch, replacing the old silent
	# instant-loss rule.
	take_damage(1, hazard.kind)


## School Items obey the same lane rule: nothing is picked up across lanes,
## even when a jump overlaps a neighbouring lane's item box.
func _collect_item(item: Collectible) -> void:
	if item.lane != lane:
		return
	if item.collect():
		item_collected.emit(item.get_kind())
		_play_pickup_sound(item.get_kind())


## Re-check boxes already touching the hitbox after a logical lane change, so
## switching into an overlapping hazard/item still registers immediately.
func _resolve_overlaps() -> void:
	if hitbox == null:
		return
	for area in hitbox.get_overlapping_areas():
		if area is Hazard:
			_hit_hazard(area as Hazard)
		elif area is Collectible:
			_collect_item(area as Collectible)


## Resize and re-anchor the box: feet stay at the origin, height follows slide.
func _update_hitbox() -> void:
	if _box == null:
		return
	var height := GameConfig.HITBOX_SIZE.y
	if is_sliding:
		height *= GameConfig.SLIDE_HITBOX_HEIGHT_FACTOR
	_box.size = Vector2(GameConfig.HITBOX_SIZE.x, height)
	hitbox_shape.position = Vector2(0.0, -height * 0.5)


# --- Presentation ------------------------------------------------------------

func _apply_pose() -> void:
	position = Vector2(GameConfig.PLAYER_X, lane_y - air_height)

	# The slide frames are already drawn crouched, so the sprite is only scaled
	# uniformly; the feet stay planted by offsetting half the scaled height.
	var sprite_scale := Vector2(GameConfig.PLAYER_SCALE, GameConfig.PLAYER_SCALE)
	sprite.scale = sprite_scale
	sprite.position = Vector2(0.0, -GameConfig.PLAYER_SPRITE_HEIGHT * sprite_scale.y * 0.5)
	sprite.rotation = deg_to_rad(_lean)

	# Blink while invulnerable so the i-frame window is readable. A shield
	# absorb tints him cyan for a beat, so the block reads as a block.
	var alpha := 1.0
	if invulnerable_time_left > 0.0:
		var phase := fmod(invulnerable_time_left * GameConfig.I_FRAME_BLINK_HZ, 1.0)
		alpha = 0.35 if phase < 0.5 else 1.0
	if shield_flash_time > 0.0:
		sprite.modulate = Color(0.55, 0.95, 1.0, alpha)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, alpha)


func _update_animation() -> void:
	if _death_played:
		return
	# Held at the start line: standing still reads better than a run cycle
	# playing on the spot while the countdown ticks.
	if waiting_at_start:
		_play(&"idle")
		return
	if _hurt_time_left > 0.0:
		_play(&"hurt")
		return
	if in_air:
		_play(&"jump")
		sprite.pause()
		# Pick the frame from vertical speed: rising, apex, falling.
		if vertical_speed > 200.0:
			sprite.frame = 0
		elif vertical_speed > -200.0:
			sprite.frame = 1
		else:
			sprite.frame = 2
		return
	if is_sliding:
		_play(&"slide")
		return
	_play(&"run")
	# Re-applied every frame: the zone swap and the victory run-off set their own
	# exit cadence directly, and this is what brings the cycle back in step.
	sprite.speed_scale = run_speed_scale


func _play(anim: StringName) -> void:
	if _current_anim == anim:
		return
	_current_anim = anim
	sprite.play(anim)


## Ground shadow that shrinks and fades as Elias rises.
func _draw() -> void:
	var rise := clampf(air_height / GameConfig.JUMP_APEX, 0.0, 1.0)
	var radius := 34.0 * (1.0 - 0.35 * rise)
	var alpha := 0.25 * (1.0 - 0.6 * rise)
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
