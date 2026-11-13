class_name ProgressBarHud
extends Control
## Course progress bar in the top-center of the HUD.
##
## CAMPAIGN draws a three-segment course (HOME / STREET / SCHOOL) sized by the
## real zone lengths, with an amber fill and a dot marker riding toward the
## finish pennant. ENDLESS draws a milestone bar toward the gold medal, with a
## silver tick at the silver distance and a GOLD badge once it is reached.
## RunWorld pushes updates each frame; nothing here polls the world.

const SCORE_FONT_PATH := "res://assets/fonts/static/InterTight-ExtraBold.ttf"
const SUB_FONT_PATH := "res://assets/fonts/static/InterTight-SemiBold.ttf"
const SCORE_FONT: Font = preload(SCORE_FONT_PATH)
const SUB_FONT: Font = preload(SUB_FONT_PATH)

const TEXT_COLOR := Color(1.0, 0.94, 0.86)
const AMBER_COLOR := Color(1.0, 0.705882, 0.368627)
const AMBER_DIM := Color(1.0, 0.705882, 0.368627, 0.35)
const TRACK_BG := Color(0.08, 0.07, 0.1, 0.78)
const DOT_FILL := Color(1.0, 0.94, 0.86)

## Track geometry, in design pixels (1920x1080 space).
const TRACK_WIDTH := 600.0
const TRACK_HEIGHT := 34.0
const TRACK_RADIUS := 17.0

var _mode: int = GameConfig.RunMode.CAMPAIGN
var _distance: float = 0.0
var _home_length: float = GameConfig.zone_home_length()
var _street_length: float = GameConfig.zone_street_length()
var _finish_distance: float = GameConfig.campaign_finish_distance()
var _zone: int = GameConfig.Zone.HOME

var _bar: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-center strip between the hearts card and the score card.
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.offset_left = -TRACK_WIDTH * 0.5
	_bar.offset_right = TRACK_WIDTH * 0.5
	_bar.offset_top = 30.0
	_bar.offset_bottom = 30.0 + TRACK_HEIGHT
	_bar.draw.connect(_on_bar_draw)
	add_child(_bar)


## Campaign mode: course track with real zone proportions. Call every frame.
func set_campaign(
	distance: float,
	home_length: float,
	street_length: float,
	finish_distance: float,
	zone: int,
) -> void:
	_mode = GameConfig.RunMode.CAMPAIGN
	_distance = distance
	_home_length = home_length
	_street_length = street_length
	_finish_distance = finish_distance
	_zone = zone
	_bar.queue_redraw()


## Endless mode: milestone bar toward the gold medal. Call every frame.
func set_endless(distance: float) -> void:
	_mode = GameConfig.RunMode.ENDLESS
	_distance = distance
	_bar.queue_redraw()


## Fill fraction currently rendered, for the test suite.
func progress_fraction() -> float:
	if _mode == GameConfig.RunMode.ENDLESS:
		return GameConfig.endless_progress(_distance)
	return GameConfig.campaign_progress(
		_distance, _home_length, _street_length, _finish_distance)


func _on_bar_draw() -> void:
	var track := Rect2(Vector2.ZERO, Vector2(TRACK_WIDTH, TRACK_HEIGHT))
	# Shared track background + amber border, matching the score card skin.
	_bar.draw_rect(track, TRACK_BG, true)
	_draw_border(track)

	if _mode == GameConfig.RunMode.ENDLESS:
		_draw_endless(track)
	else:
		_draw_campaign(track)


func _draw_border(track: Rect2) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var angle := TAU * float(i) / float(steps)
		points.append(track.position + Vector2(TRACK_RADIUS, TRACK_RADIUS)
			+ Vector2(cos(angle), sin(angle)) * (TRACK_RADIUS - 1.0))
	# Rounded corners are approximated by the pill sides; a simple inset
	# outline keeps the amber ring without full rounded-rect path math.
	_bar.draw_polyline(points, AMBER_DIM, 2.0)
	_bar.draw_line(
		Vector2(track.position.x + 1.0, track.position.y + TRACK_RADIUS),
		Vector2(track.position.x + 1.0, track.position.y + TRACK_HEIGHT - TRACK_RADIUS),
		AMBER_DIM, 2.0)
	_bar.draw_line(
		Vector2(track.position.x + TRACK_WIDTH - 1.0, track.position.y + TRACK_RADIUS),
		Vector2(track.position.x + TRACK_WIDTH - 1.0, track.position.y + TRACK_HEIGHT - TRACK_RADIUS),
		AMBER_DIM, 2.0)
	_bar.draw_line(
		Vector2(track.position.x + TRACK_RADIUS, track.position.y + 1.0),
		Vector2(track.position.x + TRACK_WIDTH - TRACK_RADIUS, track.position.y + 1.0),
		AMBER_DIM, 2.0)
	_bar.draw_line(
		Vector2(track.position.x + TRACK_RADIUS, track.position.y + TRACK_HEIGHT - 1.0),
		Vector2(track.position.x + TRACK_WIDTH - TRACK_RADIUS, track.position.y + TRACK_HEIGHT - 1.0),
		AMBER_DIM, 2.0)


func _draw_campaign(track: Rect2) -> void:
	var progress := GameConfig.campaign_progress(
		_distance, _home_length, _street_length, _finish_distance)
	var segments := GameConfig.campaign_segment_fractions(
		_home_length, _street_length, _finish_distance)
	var zone_names := ["HOME", "STREET", "SCHOOL"]
	var zone_fractions := [segments.x, segments.y, segments.z]

	var fill_width := track.size.x * progress
	if fill_width > 0.0:
		_bar.draw_rect(
			Rect2(track.position, Vector2(fill_width, track.size.y)),
			Color(AMBER_COLOR, 0.55), true)

	# Segment dividers + labels; the active zone is bright, the rest dimmed.
	var cursor := track.position.x
	for i in zone_names.size():
		var width: float = track.size.x * float(zone_fractions[i])
		if i > 0:
			_bar.draw_line(
				Vector2(cursor, track.position.y + 2.0),
				Vector2(cursor, track.position.y + track.size.y - 2.0),
				Color(0.0, 0.0, 0.0, 0.35), 2.0)
		var zone_center := cursor + width * 0.5
		var reached := progress >= 1.0 or _zone >= i
		var label_color := TEXT_COLOR if reached else Color(TEXT_COLOR, 0.45)
		_bar.draw_string(
			SUB_FONT, Vector2(cursor, track.position.y + track.size.y * 0.5 + 5.0),
			zone_names[i], HORIZONTAL_ALIGNMENT_CENTER, width, 15, label_color)
		cursor += width

	# Finish pennant at the right end: pole + amber school flag.
	var pole_x := track.position.x + track.size.x - 3.0
	_bar.draw_line(
		Vector2(pole_x, track.position.y + 1.0),
		Vector2(pole_x, track.position.y + track.size.y - 1.0),
		AMBER_COLOR, 2.0)
	var flag_y := track.position.y + 3.0
	var flag := PackedVector2Array([
		Vector2(pole_x, flag_y),
		Vector2(pole_x - 14.0, flag_y + 5.0),
		Vector2(pole_x, flag_y + 10.0),
	])
	_bar.draw_colored_polygon(flag, AMBER_COLOR)

	_draw_dot(track, fill_width)


func _draw_endless(track: Rect2) -> void:
	var progress := GameConfig.endless_progress(_distance)
	var gold_reached := progress >= 1.0
	var fill_width := track.size.x * progress
	if fill_width > 0.0:
		_bar.draw_rect(
			Rect2(track.position, Vector2(fill_width, track.size.y)),
			Color(AMBER_COLOR, 0.55), true)

	# Silver tick at the silver-medal fraction.
	var silver_x := track.position.x + track.size.x * GameConfig.endless_silver_fraction()
	_bar.draw_line(
		Vector2(silver_x, track.position.y + 2.0),
		Vector2(silver_x, track.position.y + track.size.y - 2.0),
		Color(0.0, 0.0, 0.0, 0.35), 2.0)

	# Distance readout right-aligned inside the track.
	var metres := int(_distance / 100.0)
	var readout := "%d m" % metres
	var label_color := AMBER_COLOR if gold_reached else TEXT_COLOR
	_bar.draw_string(
		SUB_FONT,
		Vector2(track.position.x + track.size.x - 120.0,
			track.position.y + track.size.y * 0.5 + 5.0),
		readout, HORIZONTAL_ALIGNMENT_RIGHT, 110.0, 15, label_color)

	# Gold badge pinned at the right end once gold distance is reached.
	if gold_reached:
		var badge := Rect2(
			Vector2(track.position.x + track.size.x - 74.0, track.position.y + 4.0),
			Vector2(70.0, track.size.y - 8.0))
		_bar.draw_rect(badge, AMBER_COLOR, true)
		_bar.draw_string(
			SCORE_FONT, badge.position + Vector2(0.0, badge.size.y * 0.5 + 6.0),
			"GOLD", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 16, TRACK_BG)
		_draw_dot(track, track.size.x - 86.0)
		return

	_draw_dot(track, fill_width)


func _draw_dot(track: Rect2, fill_width: float) -> void:
	var dot_x := clampf(
		track.position.x + fill_width,
		track.position.x + 6.0,
		track.position.x + track.size.x - 6.0)
	var center := Vector2(dot_x, track.position.y + track.size.y * 0.5)
	_bar.draw_circle(center, 8.0, AMBER_COLOR)
	_bar.draw_circle(center, 5.0, DOT_FILL)
