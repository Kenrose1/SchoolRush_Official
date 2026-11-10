class_name HeartsHud
extends CanvasLayer
## Top-left HUD panel: the three-state heart row above the speed meter.
##
## Laid out like the UI reference - hearts first, the speed readout under them.
## The heart icons live in scenes/hearts_hud.tscn so the row can still be
## nudged in the editor; this script frames that row, adds the speed meter and
## swaps the full/empty heart art. RunWorld pushes every value.

const FULL_TEXTURE := preload("res://assets/heart/heart.png")
const EMPTY_TEXTURE := preload("res://assets/heart/heart_empty.png")

# --- Panel frame, in the 1920x1080 design space ------------------------------

const PANEL_POSITION := Vector2(32.0, 24.0)
const PANEL_SIZE := Vector2(470.0, 196.0)
const PANEL_FILL := Color(0.05, 0.10, 0.19, 0.86)
const PANEL_BORDER := Color(0.29, 0.65, 0.90, 1.0)
const PANEL_BORDER_WIDTH := 3
const PANEL_CORNER_RADIUS := 12.0

# --- Hearts ------------------------------------------------------------------

const HEART_SIZE := 64.0
const HEART_GAP := 10
const HEART_POSITION := Vector2(26.0, 18.0)

# --- Speed meter -------------------------------------------------------------

const TEXT_FONT_SIZE := 26
const LABEL_COLOR := Color(0.62, 0.82, 0.96)
const VALUE_COLOR := Color(1.0, 0.98, 0.92)
const SPEED_ROW_RECT := Rect2(28.0, 100.0, 414.0, 30.0)
const SPEED_BAR_RECT := Rect2(28.0, 136.0, 414.0, 48.0)
## Rounded end caps of the bar art stay fixed while the middle stretches.
const SPEED_BAR_CAP := 30

@onready var _row: HBoxContainer = $Row
var _hearts: Array[TextureRect] = []
var _speed_bar: TextureProgressBar
var _speed_value: Label


func _ready() -> void:
	var panel := _build_panel()
	_row.reparent(panel)
	_row.position = HEART_POSITION
	_row.add_theme_constant_override("separation", HEART_GAP)
	_collect_hearts()
	_build_speed_meter(panel)
	set_hearts(GameConfig.MAX_HEARTS, GameConfig.MAX_HEARTS)
	set_speed(GameConfig.RUN_SPEED)
	set_speed_ratio(GameConfig.RUN_SPEED / GameConfig.max_run_speed())


## Show [param current] full hearts out of [param maximum].
func set_hearts(current: int, maximum: int) -> void:
	var shown := maxi(maximum, 0)
	while _hearts.size() < shown:
		var icon := _make_icon()
		_row.add_child(icon)
		_hearts.append(icon)

	for index in _hearts.size():
		_hearts[index].visible = index < shown
		if index < shown:
			_hearts[index].texture = FULL_TEXTURE if index < current else EMPTY_TEXTURE


## Current world speed, printed beside the SPEED caption.
func set_speed(speed: float) -> void:
	if _speed_value == null:
		return
	_speed_value.text = GameConfig.format_speed(speed)


## Current speed as a fraction of the fastest zone pace (0..1).
func set_speed_ratio(ratio: float) -> void:
	if _speed_bar == null:
		return
	_speed_bar.value = clampf(ratio, 0.0, 1.0)


## Texture currently drawn for heart [param index] (used by the test suite).
func get_heart_texture(index: int) -> Texture2D:
	if index < 0 or index >= _hearts.size():
		return null
	return _hearts[index].texture


func heart_count() -> int:
	var shown_count := 0
	for icon in _hearts:
		if icon.visible:
			shown_count += 1
	return shown_count


func _build_panel() -> Panel:
	var panel := Panel.new()
	panel.name = "LeftPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(int(PANEL_CORNER_RADIUS))
	return style


func _collect_hearts() -> void:
	_hearts.clear()
	for child in _row.get_children():
		if child is TextureRect:
			var icon := child as TextureRect
			icon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
			_hearts.append(icon)
	while _hearts.size() < GameConfig.MAX_HEARTS:
		var icon := _make_icon()
		_row.add_child(icon)
		_hearts.append(icon)


## SPEED caption on the left, the live value on the right, meter underneath.
func _build_speed_meter(panel: Panel) -> void:
	var caption := _make_label(HORIZONTAL_ALIGNMENT_LEFT, LABEL_COLOR)
	caption.text = "SPEED"
	caption.position = SPEED_ROW_RECT.position
	caption.size = Vector2(SPEED_ROW_RECT.size.x, SPEED_ROW_RECT.size.y)
	panel.add_child(caption)

	_speed_value = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VALUE_COLOR)
	_speed_value.position = SPEED_ROW_RECT.position
	_speed_value.size = SPEED_ROW_RECT.size
	panel.add_child(_speed_value)

	_speed_bar = TextureProgressBar.new()
	_speed_bar.name = "SpeedBar"
	_speed_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_speed_bar.max_value = 1.0
	_speed_bar.step = 0.0001
	_speed_bar.value = 0.0
	_speed_bar.texture_under = load(GameConfig.UI_SPEED_BAR_BACK) as Texture2D
	_speed_bar.texture_progress = load(GameConfig.UI_SPEED_BAR_FILL) as Texture2D
	# Patch-stretch keeps the control's minimum size off the texture width, so
	# the bar fits the panel; the end caps stay round.
	_speed_bar.nine_patch_stretch = true
	_speed_bar.stretch_margin_left = SPEED_BAR_CAP
	_speed_bar.stretch_margin_right = SPEED_BAR_CAP
	_speed_bar.position = SPEED_BAR_RECT.position
	_speed_bar.size = SPEED_BAR_RECT.size
	_speed_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_speed_bar)


func _make_label(align: HorizontalAlignment, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = FULL_TEXTURE
	icon.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon
