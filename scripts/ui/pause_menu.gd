class_name PauseMenu
extends Control
## Pause button and overlay in the top-right corner.
##
## The scene (scenes/hud.tscn) owns the layout, text, and visibility; this
## script crops the pause tile from the shared button-icon sheet, applies the
## plum-and-amber theming, and drives [member SceneTree.paused]. The node must
## stay PROCESS_MODE_ALWAYS so it still receives Esc and clicks while the rest
## of the game is frozen.
##
## Colours follow the game's sunset palette: dark plum panels with amber icons
## and cream type, matching the lane edges and the game-over overlay.

signal pause_changed(paused: bool)

const UI_FONT_PATH := "res://assets/fonts/static/InterTight-SemiBold.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/static/InterTight-ExtraBold.ttf"
const UI_FONT: Font = preload(UI_FONT_PATH)
const TITLE_FONT: Font = preload(TITLE_FONT_PATH)

const CREAM := Color(1.0, 0.94, 0.86)
const PANEL := Color(0.08, 0.07, 0.10, 0.72)
const PANEL_HOVER := Color(0.13, 0.11, 0.16, 0.86)
const PANEL_PRESSED := Color(0.05, 0.04, 0.07, 0.90)
const AMBER := Color("#ffb45e")
const AMBER_HOVER := Color("#ffcf8a")
const AMBER_PRESSED := Color("#e09a4a")

const GLYPH_SHEET_PATH := "res://assets/icon/button UI.png"
## Cell 6 of row 7 in the 16x16 icon sheet: the orange "pause" tile.
const GLYPH_REGION := Rect2(80.0, 96.0, 16.0, 16.0)
## 16 -> 64 is an exact 4x scale, so the pixel art stays crisp.
const GLYPH_PIXEL_SIZE := 64

const MENU_SCENE := "res://scenes/main_menu.tscn"

## True while the tree is frozen by this menu.
var is_paused: bool = false

var _world: RunWorld = null

@onready var button: Button = $Button
@onready var overlay: Control = $Overlay
@onready var title: Label = $Overlay/VBox/Title
@onready var resume_button: Button = $Overlay/VBox/Resume
@onready var restart_button: Button = $Overlay/VBox/Restart
@onready var quit_button: Button = $Overlay/VBox/Quit


func _ready() -> void:
	# A reloaded run must never inherit a paused tree from the previous one.
	get_tree().paused = false
	overlay.visible = false
	button.icon = _make_pause_icon()
	_style_icon_button()
	_style_menu_button(resume_button)
	_style_menu_button(restart_button)
	_style_menu_button(quit_button)
	_style_title()
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


## Hand the menu the world it should watch (called by RunWorld).
func setup(world: RunWorld) -> void:
	_world = world


func _process(_delta: float) -> void:
	if not is_paused:
		button.visible = _can_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_paused:
		set_paused(false)
	elif _can_pause():
		set_paused(true)
	get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	set_paused(not is_paused)


## Freeze or resume the tree. Refuses to pause once the run has ended.
func set_paused(value: bool) -> void:
	if value and not _can_pause():
		return
	if value == is_paused:
		return
	is_paused = value
	get_tree().paused = value
	overlay.visible = value
	button.visible = not value and _can_pause()
	pause_changed.emit(value)


## The run is pausable while it is live and the game-over overlay is hidden.
func _can_pause() -> bool:
	return _world == null or (_world.is_running and not _world.results.visible)


func _on_resume_pressed() -> void:
	set_paused(false)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	# MENU: leave the run for the main menu instead of killing the app.
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Presentation ------------------------------------------------------------

## The orange pause tile from the shared button-icon sheet, cropped to one 16x16
## cell. The art already carries the warm gradient, so the states only tint it
## slightly and let the panel styling do the hover feedback.
func _make_pause_icon() -> AtlasTexture:
	var sheet := load(GLYPH_SHEET_PATH) as Texture2D
	if sheet == null:
		return null
	var icon := AtlasTexture.new()
	icon.atlas = sheet
	icon.region = GLYPH_REGION
	return icon


func _style_icon_button() -> void:
	button.expand_icon = true
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", GLYPH_PIXEL_SIZE)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color(1.1, 1.1, 1.1))
	button.add_theme_color_override("icon_pressed_color", Color(0.82, 0.82, 0.82))
	button.add_theme_stylebox_override("normal", _panel_style(PANEL, Color(0, 0, 0, 0), 1, 0))
	button.add_theme_stylebox_override("hover", _panel_style(PANEL_HOVER, AMBER, 2, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(PANEL_PRESSED, AMBER_PRESSED, 2, 0))


func _style_menu_button(button_node: Button) -> void:
	button_node.add_theme_font_override("font", UI_FONT)
	button_node.add_theme_font_size_override("font_size", 32)
	button_node.add_theme_color_override("font_color", CREAM)
	button_node.add_theme_color_override("font_hover_color", CREAM)
	button_node.add_theme_color_override("font_pressed_color", CREAM)
	button_node.add_theme_stylebox_override("normal", _panel_style(PANEL, Color(CREAM, 0.16), 2, 16))
	button_node.add_theme_stylebox_override("hover", _panel_style(PANEL_HOVER, AMBER, 2, 16))
	button_node.add_theme_stylebox_override("pressed", _panel_style(PANEL_PRESSED, AMBER_PRESSED, 2, 16))


func _style_title() -> void:
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)


func _panel_style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style
