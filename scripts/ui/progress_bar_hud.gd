class_name ProgressBarHud
extends Control
## Course progress bar in the top-center of the HUD.
##
## CAMPAIGN draws an expressive 'Morning Rush Roadmap' (HOME -> STREET -> SCHOOL)
## styled as a student desk ruler and road hybrid. Features landmark zone badges,
## a swinging school bell destination, vibrant sunrise gradient fill with speed
## stripes, and an animated running Elias avatar marker.
##
## ENDLESS draws a milestone road with metallic silver and gold medal pins,
## dynamic distance odometer, and a championship gold crest upon completion.
##
## Preserves 100% compatibility with GameConfig and the test suite.

const SCORE_FONT_PATH := "res://assets/fonts/static/InterTight-ExtraBold.ttf"
const SUB_FONT_PATH := "res://assets/fonts/static/InterTight-SemiBold.ttf"
const SCORE_FONT: Font = preload(SCORE_FONT_PATH)
const SUB_FONT: Font = preload(SUB_FONT_PATH)

const TEXT_COLOR := Color(1.0, 0.94, 0.86)
const AMBER_COLOR := Color(1.0, 0.705882, 0.368627)
const AMBER_BRIGHT := Color(1.0, 0.82, 0.45)
const AMBER_DIM := Color(1.0, 0.705882, 0.368627, 0.35)
const SUNRISE_ORANGE := Color(1.0, 0.45, 0.18, 0.75)
const TRACK_BG := Color(0.08, 0.07, 0.1, 0.88)
const DOT_FILL := Color(1.0, 0.94, 0.86)
const SILVER_COLOR := Color(0.85, 0.88, 0.94)

## Track geometry, in design pixels (1920x1080 space).
const TRACK_WIDTH := 600.0
const TRACK_HEIGHT := 38.0
const TRACK_RADIUS := 19.0

const RUN_FRAMES: Array[Texture2D] = [
	preload("res://assets/characters/elias/run_0.png"),
	preload("res://assets/characters/elias/run_1.png"),
	preload("res://assets/characters/elias/run_2.png"),
	preload("res://assets/characters/elias/run_3.png"),
	preload("res://assets/characters/elias/run_4.png"),
	preload("res://assets/characters/elias/run_5.png"),
	preload("res://assets/characters/elias/run_6.png"),
]

var _mode: int = GameConfig.RunMode.CAMPAIGN
var _distance: float = 0.0
var _home_length: float = GameConfig.zone_home_length()
var _street_length: float = GameConfig.zone_street_length()
var _finish_distance: float = GameConfig.campaign_finish_distance()
var _zone: int = GameConfig.Zone.HOME

var _bar: Control
var _track_style: StyleBoxFlat
var _fill_style: StyleBoxFlat
var _anim_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_styles()

	# The drawing surface comes from scenes/progress_bar_hud.tscn (top-center),
	# so its geometry is editable in the editor Inspector.
	_bar = $Bar
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_on_bar_draw)


func _process(delta: float) -> void:
	_anim_time += delta
	if is_instance_valid(_bar):
		_bar.queue_redraw()


func _setup_styles() -> void:
	_track_style = StyleBoxFlat.new()
	_track_style.bg_color = TRACK_BG
	_track_style.border_color = AMBER_DIM
	_track_style.set_border_width_all(2)
	_track_style.set_corner_radius_all(int(TRACK_RADIUS))
	_track_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	_track_style.shadow_size = 6
	_track_style.shadow_offset = Vector2(0, 3)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = Color(AMBER_COLOR.r, AMBER_COLOR.g, AMBER_COLOR.b, 0.6)
	_fill_style.corner_radius_top_left = int(TRACK_RADIUS)
	_fill_style.corner_radius_bottom_left = int(TRACK_RADIUS)


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

	# 1. Base pill container with shadow and obsidian glass skin.
	_bar.draw_style_box(_track_style, track)

	# 2. Desk ruler millimeter ticks along bottom edge.
	_draw_ruler_ticks(track)

	var progress := progress_fraction()
	var fill_width := track.size.x * clampf(progress, 0.0, 1.0)

	# 3. Unfilled road center dashes ahead of player.
	_draw_road_dashes(track, fill_width)

	# 4. Animated progress fill with speed stripes & energy edge.
	if fill_width > 0.0:
		_draw_progress_fill(track, fill_width, progress)

	# 5. Mode-specific milestones and avatars.
	if _mode == GameConfig.RunMode.ENDLESS:
		_draw_endless(track, fill_width, progress)
	else:
		_draw_campaign(track, fill_width, progress)


func _draw_ruler_ticks(track: Rect2) -> void:
	var tick_bottom := track.position.y + track.size.y - 2.0
	var tick_start := track.position.x + 18.0
	var tick_end := track.position.x + track.size.x - 18.0
	var step := 12.0
	var i := 0
	var x := tick_start
	while x <= tick_end:
		var tick_len := 3.0
		var tick_col := Color(1.0, 0.706, 0.369, 0.18)
		if i % 10 == 0:
			tick_len = 7.0
			tick_col = Color(1.0, 0.85, 0.6, 0.45)
		elif i % 5 == 0:
			tick_len = 5.0
			tick_col = Color(1.0, 0.706, 0.369, 0.3)
		_bar.draw_line(
			Vector2(x, tick_bottom - tick_len),
			Vector2(x, tick_bottom),
			tick_col, 1.0
		)
		x += step
		i += 1


func _draw_road_dashes(track: Rect2, fill_width: float) -> void:
	var mid_y := track.position.y + track.size.y * 0.5
	var start_x := maxf(track.position.x + fill_width + 12.0, track.position.x + 24.0)
	var end_x := track.position.x + track.size.x - 28.0
	var dash_len := 10.0
	var gap := 12.0
	var x := start_x
	while x + dash_len <= end_x:
		_bar.draw_line(
			Vector2(x, mid_y),
			Vector2(x + dash_len, mid_y),
			Color(1.0, 0.94, 0.86, 0.12),
			2.0
		)
		x += dash_len + gap


func _draw_progress_fill(track: Rect2, fill_width: float, progress: float) -> void:
	var is_full := fill_width >= track.size.x - 2.0
	_fill_style.corner_radius_top_right = int(TRACK_RADIUS) if is_full else 0
	_fill_style.corner_radius_bottom_right = int(TRACK_RADIUS) if is_full else 0

	var fill_rect := Rect2(track.position, Vector2(fill_width, track.size.y))
	_bar.draw_style_box(_fill_style, fill_rect)

	# Sunrise warm gradient overlay band
	var gradient_rect := Rect2(track.position, Vector2(fill_width, track.size.y * 0.4))
	_bar.draw_rect(gradient_rect, Color(1.0, 0.82, 0.45, 0.18), true)

	# Diagonal speed hazard stripes
	var stripe_gap := 28.0
	var offset := fmod(_anim_time * 24.0, stripe_gap)
	var sx := track.position.x - 10.0 + offset
	while sx < track.position.x + fill_width:
		var x1 := clampf(sx, track.position.x + 4.0, track.position.x + fill_width - 2.0)
		var x2 := clampf(sx + 14.0, track.position.x + 4.0, track.position.x + fill_width - 2.0)
		if x2 > x1:
			_bar.draw_line(
				Vector2(x1, track.position.y + track.size.y - 4.0),
				Vector2(x2, track.position.y + 4.0),
				Color(1.0, 1.0, 1.0, 0.08),
				3.0
			)
		sx += stripe_gap

	# Glass highlight rim across top
	_bar.draw_line(
		Vector2(track.position.x + 12.0, track.position.y + 3.0),
		Vector2(track.position.x + fill_width - 4.0, track.position.y + 3.0),
		Color(1.0, 1.0, 1.0, 0.22),
		1.5
	)

	# Leading edge energy crest glow
	var lead_x := track.position.x + fill_width
	if !is_full:
		_bar.draw_line(
			Vector2(lead_x, track.position.y + 3.0),
			Vector2(lead_x, track.position.y + track.size.y - 3.0),
			Color(1.0, 0.6, 0.2, 0.35),
			6.0
		)
		_bar.draw_line(
			Vector2(lead_x, track.position.y + 2.0),
			Vector2(lead_x, track.position.y + track.size.y - 2.0),
			Color(1.0, 0.95, 0.85, 0.95),
			2.5
		)


func _draw_campaign(track: Rect2, fill_width: float, progress: float) -> void:
	var segments := GameConfig.campaign_segment_fractions(
		_home_length, _street_length, _finish_distance)
	var zone_names := ["HOME", "STREET", "SCHOOL"]
	var zone_fractions := [segments.x, segments.y, segments.z]

	# Segment dividers + labels + active zone pill
	var cursor := track.position.x
	for i in zone_names.size():
		var width: float = track.size.x * float(zone_fractions[i])
		var zone_center := cursor + width * 0.5
		var reached := progress >= 1.0 or _zone >= i
		var is_active := _zone == i

		# Divider notches between zones
		if i > 0:
			_draw_zone_divider(Vector2(cursor, track.position.y), track.size.y)

		# Active zone halo pill
		if is_active:
			var pill_w := minf(width - 16.0, 84.0)
			var pill_rect := Rect2(
				Vector2(zone_center - pill_w * 0.5, track.position.y + 5.0),
				Vector2(pill_w, track.size.y - 10.0)
			)
			_bar.draw_rect(pill_rect, Color(1.0, 0.706, 0.369, 0.16), true)
			_bar.draw_rect(pill_rect, AMBER_DIM, false, 1.5)

		# Zone label
		var label_color := AMBER_BRIGHT if is_active else (TEXT_COLOR if reached else Color(TEXT_COLOR, 0.38))
		_bar.draw_string(
			SUB_FONT,
			Vector2(cursor, track.position.y + track.size.y * 0.5 + 5.0),
			zone_names[i],
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			14,
			label_color
		)

		# Home landmark icon at zone 0
		if i == 0:
			_draw_home_icon(Vector2(cursor + 24.0, track.position.y + track.size.y * 0.5), reached)

		cursor += width

	# Destination: Schoolhouse with swinging bell tower + pennant
	_draw_school_destination(
		Vector2(track.position.x + track.size.x - 22.0, track.position.y + track.size.y * 0.5),
		progress
	)

	# Animated runner avatar
	_draw_runner_avatar(track, fill_width)


func _draw_zone_divider(top_pos: Vector2, height: float) -> void:
	var mid_y := top_pos.y + height * 0.5
	_bar.draw_line(
		Vector2(top_pos.x, top_pos.y + 4.0),
		Vector2(top_pos.x, top_pos.y + height - 4.0),
		Color(0.0, 0.0, 0.0, 0.4),
		2.0
	)
	# Diamond milestone notch
	var diamond := PackedVector2Array([
		Vector2(top_pos.x, mid_y - 4.0),
		Vector2(top_pos.x + 3.0, mid_y),
		Vector2(top_pos.x, mid_y + 4.0),
		Vector2(top_pos.x - 3.0, mid_y),
	])
	_bar.draw_colored_polygon(diamond, AMBER_DIM)


func _draw_home_icon(center: Vector2, reached: bool) -> void:
	var color := AMBER_COLOR if reached else Color(AMBER_COLOR, 0.4)
	var roof := PackedVector2Array([
		Vector2(center.x - 7.0, center.y - 1.0),
		Vector2(center.x, center.y - 8.0),
		Vector2(center.x + 7.0, center.y - 1.0),
	])
	_bar.draw_colored_polygon(roof, color)
	_bar.draw_rect(Rect2(center.x + 2.0, center.y - 8.0, 2.0, 4.0), color, true)
	_bar.draw_rect(Rect2(center.x - 5.0, center.y - 1.0, 10.0, 7.0), color, true)
	_bar.draw_rect(Rect2(center.x - 1.5, center.y + 1.0, 3.0, 3.0), TRACK_BG, true)


func _draw_school_destination(center: Vector2, progress: float) -> void:
	var color := AMBER_COLOR if progress >= 0.85 else Color(AMBER_COLOR, 0.7)

	# School facade base
	_bar.draw_rect(Rect2(center.x - 9.0, center.y - 2.0, 18.0, 10.0), color, true)
	_bar.draw_rect(Rect2(center.x - 2.5, center.y + 1.0, 5.0, 7.0), TRACK_BG, true)

	# Triangular pediment roof
	var pediment := PackedVector2Array([
		Vector2(center.x - 11.0, center.y - 2.0),
		Vector2(center.x, center.y - 9.0),
		Vector2(center.x + 11.0, center.y - 2.0),
	])
	_bar.draw_colored_polygon(pediment, color)

	# Belfry tower cupola
	_bar.draw_rect(Rect2(center.x - 3.0, center.y - 13.0, 6.0, 4.0), color, true)

	# School bell with sprint wobble when close
	var bell_wobble := 0.0
	if progress >= 0.85:
		bell_wobble = sin(_anim_time * 16.0) * 2.0
	var bell := PackedVector2Array([
		Vector2(center.x - 2.0 + bell_wobble, center.y - 9.0),
		Vector2(center.x + 2.0 + bell_wobble, center.y - 9.0),
		Vector2(center.x + 3.0 + bell_wobble, center.y - 6.0),
		Vector2(center.x - 3.0 + bell_wobble, center.y - 6.0),
	])
	_bar.draw_colored_polygon(bell, AMBER_BRIGHT)

	# School Pennant flag waving at roof peak
	var pole_x := center.x + 6.0
	_bar.draw_line(
		Vector2(pole_x, center.y - 16.0),
		Vector2(pole_x, center.y - 2.0),
		AMBER_COLOR, 1.5
	)
	var flag_wave := sin(_anim_time * 10.0) * 1.5
	var pennant := PackedVector2Array([
		Vector2(pole_x, center.y - 16.0),
		Vector2(pole_x + 9.0 + flag_wave, center.y - 12.0),
		Vector2(pole_x, center.y - 8.0),
	])
	_bar.draw_colored_polygon(pennant, Color(1.0, 0.42, 0.28))


func _draw_endless(track: Rect2, fill_width: float, progress: float) -> void:
	var gold_reached := progress >= 1.0

	# 1. Silver milestone tick & medal pin at silver distance
	var silver_fraction := GameConfig.endless_silver_fraction()
	var silver_x := track.position.x + track.size.x * silver_fraction
	_draw_silver_milestone(Vector2(silver_x, track.position.y), track.size.y, progress >= silver_fraction)

	# 2. Distance readout with athletic odometer styling
	var metres := int(_distance / 100.0)
	var readout := "%s m" % _format_number(metres)
	var label_color := AMBER_BRIGHT if gold_reached else TEXT_COLOR
	_bar.draw_string(
		SUB_FONT,
		Vector2(track.position.x + track.size.x - 140.0, track.position.y + track.size.y * 0.5 + 5.0),
		readout,
		HORIZONTAL_ALIGNMENT_RIGHT,
		130.0,
		15,
		label_color
	)

	# 3. Gold badge / championship trophy pinned at end
	if gold_reached:
		var badge := Rect2(
			Vector2(track.position.x + track.size.x - 84.0, track.position.y + 4.0),
			Vector2(80.0, track.size.y - 8.0)
		)
		_bar.draw_rect(badge, AMBER_COLOR, true)
		_bar.draw_rect(badge, AMBER_BRIGHT, false, 2.0)
		_bar.draw_string(
			SCORE_FONT,
			badge.position + Vector2(0.0, badge.size.y * 0.5 + 6.0),
			"GOLD",
			HORIZONTAL_ALIGNMENT_CENTER,
			badge.size.x,
			16,
			TRACK_BG
		)
		_draw_runner_avatar(track, track.size.x - 96.0)
		return

	_draw_runner_avatar(track, fill_width)


func _draw_silver_milestone(top_pos: Vector2, height: float, reached: bool) -> void:
	var color := SILVER_COLOR if reached else Color(SILVER_COLOR, 0.35)
	_bar.draw_line(
		Vector2(top_pos.x, top_pos.y + 4.0),
		Vector2(top_pos.x, top_pos.y + height - 4.0),
		Color(0.0, 0.0, 0.0, 0.4),
		2.0
	)
	var star := PackedVector2Array([
		Vector2(top_pos.x, top_pos.y + 5.0),
		Vector2(top_pos.x + 3.0, top_pos.y + 9.0),
		Vector2(top_pos.x, top_pos.y + 13.0),
		Vector2(top_pos.x - 3.0, top_pos.y + 9.0),
	])
	_bar.draw_colored_polygon(star, color)


func _draw_runner_avatar(track: Rect2, fill_width: float) -> void:
	var dot_x := clampf(
		track.position.x + fill_width,
		track.position.x + 18.0,
		track.position.x + track.size.x - 18.0
	)
	var cadence_bob := sin(_anim_time * 14.0) * 1.5
	var center := Vector2(dot_x, track.position.y + track.size.y * 0.5 + cadence_bob)

	# Kinetic speed trail (fading micro-particles)
	_bar.draw_circle(Vector2(dot_x - 14.0, center.y), 3.5, Color(AMBER_COLOR, 0.38))
	_bar.draw_circle(Vector2(dot_x - 22.0, center.y - cadence_bob * 0.5), 2.2, Color(AMBER_COLOR, 0.22))
	_bar.draw_circle(Vector2(dot_x - 29.0, center.y), 1.2, Color(AMBER_COLOR, 0.10))

	# Avatar circular badge base
	_bar.draw_circle(center + Vector2(0, 2), 15.0, Color(0.0, 0.0, 0.0, 0.45)) # Shadow
	_bar.draw_circle(center, 14.0, AMBER_COLOR) # Gold rim
	_bar.draw_circle(center, 12.0, Color(0.12, 0.1, 0.16)) # Dark glass interior

	# Render miniature running student sprite (Elias)
	if not RUN_FRAMES.is_empty():
		var frame_index := int(fmod(_anim_time * 10.0 + _distance * 0.015, float(RUN_FRAMES.size())))
		var frame_tex := RUN_FRAMES[frame_index]
		if frame_tex != null:
			var sprite_rect := Rect2(center.x - 7.0, center.y - 10.5, 14.0, 21.0)
			_bar.draw_texture_rect(frame_tex, sprite_rect, false)
	else:
		_bar.draw_circle(center, 5.0, DOT_FILL)

	# Highlighting rim arc
	_bar.draw_arc(center, 12.0, -PI * 0.75, -PI * 0.25, 8, Color(1, 1, 1, 0.35), 1.5)


func _format_number(n: int) -> String:
	var s := str(n)
	var res := ""
	var len_s := s.length()
	for i in len_s:
		if i > 0 and (len_s - i) % 3 == 0:
			res += ","
		res += s[i]
	return res
