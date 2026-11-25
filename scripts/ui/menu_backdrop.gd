class_name MenuBackdrop
extends Node2D
## The main menu's live school-zone diorama.
##
## Draws the same hallway wall/floor split, parallax yard, lane bands and road
## ticks as RunWorld's school zone. The difference is intent: nothing here can
## hurt Elias or score points, so the strip just scrolls behind the menu at a
## calmer pace while a few real hazard/coin sprites drift past.

## Menu scroll is slower than a live run so the UI stays readable.
const SCROLL_FACTOR := 0.6

const SCHOOL_TEXTURE := "res://assets/backgrounds/Schoolhallway.png"
const SCHOOL_BACKGROUND_TEXTURE := "res://assets/backgrounds/SchoolBackground.png"
const SCHOOL_BACKGROUND_PARALLAX := 0.09
const SCHOOL_WALL_PARALLAX := 1.0
const SCHOOL_FLOOR_PARALLAX := 1.0
const SCHOOL_FLOOR_SPLIT_Y := 576.0
const SCHOOL_BASE := Color("#251a29")

const LANE_COLORS: Array[Color] = [Color("#3c4757"), Color("#46536b"), Color("#4f5f7d")]
const LANE_EDGE := Color("#fff6e0")
const GROUND_TICK := Color(1.0, 1.0, 1.0, 0.85)

## Ambient props reuse the game's real art and spawn spacing.
const PROP_PERIOD := 2600.0
const PROP_LEAD_X := 2000.0
const COIN_PERIOD := 4200.0
const COIN_LEAD_X := 2300.0
const COIN_SPACING := 150.0
## Props fade out before reaching the menu column instead of popping.
const PROP_FADE_START_X := 680.0
const PROP_FADE_END_X := 980.0

## Distance travelled by the menu strip, in pixels.
var distance: float = 0.0
## Test-visible scroll rate, derived from GameConfig so speed upgrades never
## change the presentation.
var scroll_speed: float = GameConfig.RUN_SPEED * SCROLL_FACTOR
## Test counter: how many ambient prop sets were drawn.
var prop_draw_count: int = 0

var _hall_texture: Texture2D
var _yard_texture: Texture2D
var _prop_textures: Dictionary = {}
var _coin_texture: Texture2D


func _process(delta: float) -> void:
	distance += scroll_speed * delta
	queue_redraw()


## Draw the school layer stack, then lane paint, then the drifting props.
func _draw() -> void:
	var view := GameConfig.DESIGN_SIZE
	_draw_school(view)
	_draw_lane_paint(view)
	_draw_ambient_props()


func _draw_school(view: Vector2) -> void:
	var horizon := GameConfig.lane_y(0) - GameConfig.LANE_HALF_HEIGHT
	draw_rect(Rect2(Vector2.ZERO, view), SCHOOL_BASE)

	if _yard_texture == null:
		_yard_texture = load(SCHOOL_BACKGROUND_TEXTURE) as Texture2D
	if _yard_texture != null:
		_draw_loops(
			_yard_texture,
			Rect2(Vector2.ZERO, Vector2(view.x, horizon)),
			SCHOOL_BACKGROUND_PARALLAX,
		)

	if _hall_texture == null:
		_hall_texture = load(SCHOOL_TEXTURE) as Texture2D
	if _hall_texture == null:
		return

	var src := _hall_texture.get_size()
	var split := clampf(SCHOOL_FLOOR_SPLIT_Y, 0.0, src.y)
	var wall_src := Rect2(Vector2.ZERO, Vector2(src.x, split))
	var floor_src := Rect2(Vector2(0.0, split), Vector2(src.x, src.y - split))
	_draw_loops(_hall_texture, Rect2(Vector2.ZERO, Vector2(view.x, horizon)), SCHOOL_WALL_PARALLAX, wall_src)
	_draw_loops(_hall_texture, Rect2(Vector2(0.0, horizon), Vector2(view.x, view.y - horizon)), SCHOOL_FLOOR_PARALLAX, floor_src)


## Cream lane edges, tinted bands and white ticks, identical to the run scene.
func _draw_lane_paint(view: Vector2) -> void:
	for lane in GameConfig.LANE_COUNT:
		var y := GameConfig.lane_y(lane)
		var top := y - GameConfig.LANE_HALF_HEIGHT
		draw_rect(Rect2(0.0, top, view.x, GameConfig.LANE_HALF_HEIGHT * 2.0), Color(LANE_COLORS[lane], 0.18))
		draw_line(Vector2(0.0, top), Vector2(view.x, top), Color(LANE_EDGE, 0.55), 3.0)
		_draw_ticks(y)


## Tile a texture horizontally across a band, looped at `parallax`.
func _draw_loops(texture: Texture2D, destination: Rect2, parallax: float, source := Rect2()) -> void:
	if texture == null:
		return
	if source.size.x < 1.0:
		source = Rect2(Vector2.ZERO, texture.get_size())
	var offset := fmod(distance * parallax, destination.size.x)
	var x := -offset
	while x < GameConfig.DESIGN_WIDTH:
		draw_texture_rect_region(
			texture,
			Rect2(Vector2(x, destination.position.y), destination.size),
			source,
			Color.WHITE,
		)
		x += destination.size.x


func _draw_ticks(y: float) -> void:
	var period := GameConfig.GROUND_TICK_LENGTH + GameConfig.GROUND_TICK_GAP
	var x := -fmod(distance, period)
	while x < GameConfig.DESIGN_WIDTH:
		draw_rect(Rect2(x, y - 2.0, GameConfig.GROUND_TICK_LENGTH, 4.0), GROUND_TICK)
		x += period


## Real hazard/coin art on real lanes, driven by the same scroll distance.
## Deterministic indices keep the arrangement stable across frames and runs.
func _draw_ambient_props() -> void:
	prop_draw_count += 1
	var first_hazard := int(floor(distance / PROP_PERIOD)) - 1
	for i in range(first_hazard, first_hazard + 4):
		var x := float(i) * PROP_PERIOD - distance + PROP_LEAD_X
		var alpha := _prop_alpha(x)
		if alpha <= 0.0:
			continue
		var lane := posmod(i, GameConfig.LANE_COUNT)
		var kind_index := posmod(i, 3)
		var hazard_kind := int([
			GameConfig.HazardKind.MANHOLE,
			GameConfig.HazardKind.DEBRIS,
			GameConfig.HazardKind.SIGN,
		][kind_index])
		_draw_prop(_hazard_texture(hazard_kind), x, GameConfig.lane_y(lane),
			float(GameConfig.HAZARD_DATA[hazard_kind]["scale"]), alpha)

	var first_coin := int(floor(distance / COIN_PERIOD)) - 1
	for i in range(first_coin, first_coin + 3):
		var start_x := float(i) * COIN_PERIOD - distance + COIN_LEAD_X
		var lane := posmod(i + 1, GameConfig.LANE_COUNT)
		for c in GameConfig.COIN_RUN_MIN:
			var x := start_x + float(c) * COIN_SPACING
			var alpha := _prop_alpha(x)
			if alpha <= 0.0:
				continue
			var y := GameConfig.lane_y(lane) - GameConfig.ITEM_HOVER_HEIGHT
			_draw_prop(_coin_art(), x, y, 0.62, alpha)


func _prop_alpha(x: float) -> float:
	return clampf((x - PROP_FADE_START_X) / (PROP_FADE_END_X - PROP_FADE_START_X), 0.0, 1.0)


## Draw a centre-bottom anchored prop so its feet land on the lane line.
func _draw_prop(texture: Texture2D, x: float, bottom_y: float, scale: float, alpha: float) -> void:
	if texture == null:
		return
	var size := texture.get_size() * scale
	draw_texture_rect(
		texture,
		Rect2(Vector2(x - size.x * 0.5, bottom_y - size.y), size),
		false,
		Color(1.0, 1.0, 1.0, alpha),
	)


func _hazard_texture(kind: int) -> Texture2D:
	if not _prop_textures.has(kind):
		var path := String((GameConfig.HAZARD_DATA[kind] as Dictionary)["texture"])
		_prop_textures[kind] = load(path) as Texture2D
	return _prop_textures[kind] as Texture2D


func _coin_art() -> Texture2D:
	if _coin_texture == null:
		var data := GameConfig.ITEM_DATA[GameConfig.ItemKind.COIN] as Dictionary
		_coin_texture = load(String(data["texture"])) as Texture2D
	return _coin_texture
