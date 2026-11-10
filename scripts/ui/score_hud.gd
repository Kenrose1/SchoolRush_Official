class_name ScoreHud
extends CanvasLayer
## Top-centre progress panel and top-right score panel.
##
## Laid out like the UI reference: the corridor progress bar with its distance
## readout and finish flag across the middle of the screen, then score, combo
## and School Item count on the right. Values are pushed by RunWorld every
## physics frame; this node only formats and draws.

const PANEL_TOP := 24.0
const PANEL_FILL := Color(0.05, 0.10, 0.19, 0.86)
const PANEL_BORDER := Color(0.29, 0.65, 0.90, 1.0)
const PANEL_BORDER_WIDTH := 3
const PANEL_CORNER_RADIUS := 12.0
const LABEL_COLOR := Color(0.62, 0.82, 0.96)
const VALUE_COLOR := Color(1.0, 0.98, 0.92)
const COMBO_COLOR := Color(1.0, 0.83, 0.30)
const CAPTION_FONT_SIZE := 24

# --- Centre progress panel ---------------------------------------------------

## The panel is exactly as tall as the side panels, so all four panels of the top
## bar share one top and one bottom line.
const PROGRESS_PANEL_WIDTH := 700.0
const PROGRESS_PANEL_HEIGHT := 196.0
const PROGRESS_FONT_SIZE := 34
## Text over meter, centred as a block in the panel.
const PROGRESS_TEXT_RECT := Rect2(26.0, 40.0, 590.0, 46.0)
const PROGRESS_BAR_RECT := Rect2(26.0, 104.0, 590.0, 52.0)
## Checkered flag that marks the end of the meter, centred on the bar.
const FLAG_RECT := Rect2(628.0, 98.0, 46.0, 64.0)
const FLAG_CELL := 7.0
const FLAG_COLUMNS := 4
## The loading fill is tinted green so the meter reads as progress, like the
## reference. The loading overlay strip is deliberately not used: its white
## hazard stripes sit on top of the fill and hide the progress colour.
const PROGRESS_TINT := Color(0.55, 1.0, 0.45)

# --- Right score panel -------------------------------------------------------

const SCORE_PANEL_WIDTH := 460.0
const SCORE_PANEL_HEIGHT := 196.0
## The control rail's footprint in the top-right corner, kept in step with
## scripts/ui/hud_controls.gd.
const CONTROLS_RAIL_WIDTH := 96.0
## Right margin of the score panel: it stops short of the control rail, which
## owns the corner itself.
const SCORE_PANEL_RIGHT_MARGIN := 32.0 + CONTROLS_RAIL_WIDTH + 16.0
const SCORE_FONT_SIZE := 56
const COMBO_FONT_SIZE := 38
const ITEM_FONT_SIZE := 30
const ITEM_ICON_SIZE := 18.0
const SCORE_CAPTION_RECT := Rect2(26.0, 12.0, 240.0, 30.0)
const SCORE_VALUE_RECT := Rect2(26.0, 38.0, 250.0, 62.0)
const COMBO_CAPTION_RECT := Rect2(296.0, 12.0, 150.0, 30.0)
const COMBO_VALUE_RECT := Rect2(296.0, 38.0, 150.0, 54.0)
const ITEM_ICON_POSITION := Vector2(296.0, 130.0)
const ITEM_VALUE_RECT := Rect2(348.0, 112.0, 100.0, 42.0)

var _distance_label: Label
var _distance_bar: TextureProgressBar
var _score_label: Label
var _combo_label: Label
var _items_label: Label


func _ready() -> void:
	_build_progress_panel()
	_build_score_panel()
	set_score(0)
	set_distance(0.0, GameConfig.zone_home_length())
	set_distance_progress(0.0)
	set_combo(1, 0)
	set_items(0)


func set_score(score: int) -> void:
	_score_label.text = "%06d" % score


## Distance run so far and the distance that ends the current zone.
func set_distance(distance: float, goal: float) -> void:
	_distance_label.text = "%s / %s" % [
		GameConfig.format_distance(distance),
		GameConfig.format_distance(goal),
	]


## Progress (0..1) through the zone currently being run.
func set_distance_progress(progress: float) -> void:
	_distance_bar.value = clampf(progress, 0.0, 1.0)


func set_combo(multiplier: int, chain: int) -> void:
	_combo_label.text = "" if chain <= 0 else "x%d" % multiplier


func set_items(count: int) -> void:
	_items_label.text = "x %d" % count


func _build_progress_panel() -> void:
	var panel := Panel.new()
	panel.name = "ProgressPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -PROGRESS_PANEL_WIDTH * 0.5
	panel.offset_right = PROGRESS_PANEL_WIDTH * 0.5
	panel.offset_top = PANEL_TOP
	panel.offset_bottom = PANEL_TOP + PROGRESS_PANEL_HEIGHT
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	_distance_label = _make_label(
		HORIZONTAL_ALIGNMENT_CENTER, VALUE_COLOR, PROGRESS_FONT_SIZE)
	_distance_label.position = PROGRESS_TEXT_RECT.position
	_distance_label.size = PROGRESS_TEXT_RECT.size
	panel.add_child(_distance_label)

	_distance_bar = TextureProgressBar.new()
	_distance_bar.name = "ProgressBar"
	_distance_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_distance_bar.max_value = 1.0
	_distance_bar.step = 0.0001
	_distance_bar.value = 0.0
	_distance_bar.texture_under = load(GameConfig.UI_LOADING_TRACK) as Texture2D
	_distance_bar.texture_progress = load(GameConfig.UI_LOADING_FILL) as Texture2D
	_distance_bar.tint_progress = PROGRESS_TINT
	# The loading strips are 1200 px wide; patch-stretching keeps the control at
	# the panel width instead of the texture width.
	_distance_bar.nine_patch_stretch = true
	_distance_bar.position = PROGRESS_BAR_RECT.position
	_distance_bar.size = PROGRESS_BAR_RECT.size
	_distance_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_distance_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_distance_bar)

	_build_flag(panel)


## Checkered finish flag at the end of the progress meter.
func _build_flag(panel: Panel) -> void:
	var flag := Control.new()
	flag.name = "FinishFlag"
	flag.position = FLAG_RECT.position
	flag.size = FLAG_RECT.size
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(flag)

	var pole := ColorRect.new()
	pole.color = Color(0.86, 0.91, 0.98)
	pole.position = Vector2(0.0, 4.0)
	pole.size = Vector2(5.0, FLAG_RECT.size.y - 4.0)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.add_child(pole)

	var grid := GridContainer.new()
	grid.columns = FLAG_COLUMNS
	grid.position = Vector2(5.0, 4.0)
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.add_child(grid)
	for index in FLAG_COLUMNS * FLAG_COLUMNS:
		var cell := ColorRect.new()
		@warning_ignore("integer_division")
		var even := (index + index / FLAG_COLUMNS) % 2 == 0
		cell.color = Color(0.97, 0.98, 1.0) if even else Color(0.06, 0.09, 0.14)
		cell.custom_minimum_size = Vector2(FLAG_CELL, FLAG_CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)


func _build_score_panel() -> void:
	var panel := Panel.new()
	panel.name = "ScorePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -(SCORE_PANEL_RIGHT_MARGIN + SCORE_PANEL_WIDTH)
	panel.offset_right = -SCORE_PANEL_RIGHT_MARGIN
	panel.offset_top = PANEL_TOP
	panel.offset_bottom = PANEL_TOP + SCORE_PANEL_HEIGHT
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var caption := _make_label(HORIZONTAL_ALIGNMENT_LEFT, LABEL_COLOR, CAPTION_FONT_SIZE)
	caption.text = "SCORE"
	caption.position = SCORE_CAPTION_RECT.position
	caption.size = SCORE_CAPTION_RECT.size
	panel.add_child(caption)

	_score_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VALUE_COLOR, SCORE_FONT_SIZE)
	_score_label.position = SCORE_VALUE_RECT.position
	_score_label.size = SCORE_VALUE_RECT.size
	panel.add_child(_score_label)

	var combo_caption := _make_label(
		HORIZONTAL_ALIGNMENT_RIGHT, LABEL_COLOR, CAPTION_FONT_SIZE)
	combo_caption.text = "COMBO"
	combo_caption.position = COMBO_CAPTION_RECT.position
	combo_caption.size = COMBO_CAPTION_RECT.size
	panel.add_child(combo_caption)

	_combo_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, COMBO_COLOR, COMBO_FONT_SIZE)
	_combo_label.position = COMBO_VALUE_RECT.position
	_combo_label.size = COMBO_VALUE_RECT.size
	panel.add_child(_combo_label)

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.texture = load(GameConfig.UI_ITEM_ICON) as Texture2D
	icon.position = ITEM_ICON_POSITION
	icon.size = Vector2(ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.scale = Vector2(0.5, 0.5)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	_items_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VALUE_COLOR, ITEM_FONT_SIZE)
	_items_label.position = ITEM_VALUE_RECT.position
	_items_label.size = ITEM_VALUE_RECT.size
	panel.add_child(_items_label)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(int(PANEL_CORNER_RADIUS))
	return style


func _make_label(align: HorizontalAlignment, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
