class_name PauseMenu
extends Control
## Pause button and overlay in the top-right corner.
##
## Upgraded with "Hall Pass" school card aesthetic, spring button micro-interactions,
## and full controller/keyboard focus navigation.

signal pause_changed(paused: bool)

const UI_FONT_PATH := "res://assets/fonts/static/InterTight-SemiBold.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/static/InterTight-ExtraBold.ttf"
const UI_FONT: Font = preload(UI_FONT_PATH)
const TITLE_FONT: Font = preload(TITLE_FONT_PATH)

const CREAM := Color(1.0, 0.94, 0.86)
const PANEL := Color(0.1, 0.09, 0.13, 0.85)
const PANEL_HOVER := Color(0.18, 0.14, 0.22, 0.95)
const PANEL_PRESSED := Color(0.06, 0.05, 0.08, 0.95)
const AMBER := Color("#ffb45e")
const AMBER_PRESSED := Color("#e09a4a")

const GLYPH_SHEET_PATH := "res://assets/icon/button UI.png"
const GLYPH_REGION := Rect2(80.0, 96.0, 16.0, 16.0)
const GLYPH_PIXEL_SIZE := 64

const MENU_SCENE := "res://scenes/main_menu.tscn"

var is_paused: bool = false
var _world: RunWorld = null

@onready var button: Button = $Button
@onready var overlay: Control = $Overlay
@onready var title: Label = $Overlay/Center/Panel/VBox/Title
@onready var resume_button: Button = $Overlay/Center/Panel/VBox/Resume
@onready var restart_button: Button = $Overlay/Center/Panel/VBox/Restart
@onready var settings_button: Button = $Overlay/Center/Panel/VBox/Settings
@onready var quit_button: Button = $Overlay/Center/Panel/VBox/Quit


func _ready() -> void:
	get_tree().paused = false
	overlay.visible = false
	button.icon = _make_pause_icon()
	_style_icon_button()
	_style_menu_button(resume_button)
	_style_menu_button(restart_button)
	_style_menu_button(settings_button)
	_style_menu_button(quit_button)
	_style_title()
	
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


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


func set_paused(value: bool) -> void:
	if value and not _can_pause():
		return
	if value == is_paused:
		return
	is_paused = value
	get_tree().paused = value
	overlay.visible = value
	button.visible = not value and _can_pause()
	if value:
		resume_button.grab_focus()
	pause_changed.emit(value)


func _can_pause() -> bool:
	return _world == null or (_world.is_running and not _world.results.visible)


func _on_resume_pressed() -> void:
	set_paused(false)


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


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
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", GLYPH_PIXEL_SIZE)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color(1.15, 1.15, 1.15))
	button.add_theme_color_override("icon_pressed_color", Color(0.82, 0.82, 0.82))
	
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.mouse_entered.connect(func(): _animate_button_hover(button, true))
	button.mouse_exited.connect(func(): _animate_button_hover(button, false))


func _style_menu_button(button_node: Button) -> void:
	button_node.add_theme_font_override("font", TITLE_FONT)
	button_node.add_theme_font_size_override("font_size", 28)
	button_node.add_theme_color_override("font_color", CREAM)
	button_node.add_theme_color_override("font_focus_color", CREAM)
	button_node.add_theme_color_override("font_hover_color", CREAM)
	button_node.add_theme_color_override("font_pressed_color", CREAM)
	button_node.add_theme_stylebox_override("normal", _panel_style(PANEL, Color(AMBER, 0.25), 2, 14))
	button_node.add_theme_stylebox_override("hover", _panel_style(PANEL_HOVER, AMBER, 4, 14))
	button_node.add_theme_stylebox_override("focus", _panel_style(PANEL_HOVER, AMBER, 4, 14))
	button_node.add_theme_stylebox_override("pressed", _panel_style(PANEL_PRESSED, AMBER_PRESSED, 2, 14))
	
	button_node.pivot_offset = button_node.custom_minimum_size * 0.5
	button_node.mouse_entered.connect(func(): _animate_button_hover(button_node, true))
	button_node.mouse_exited.connect(func(): _animate_button_hover(button_node, false))
	button_node.focus_entered.connect(func(): _animate_button_hover(button_node, true))
	button_node.focus_exited.connect(func(): _animate_button_hover(button_node, false))


func _animate_button_hover(btn: Button, is_hovered: bool) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovered:
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.14)
		tw.tween_property(btn, "modulate", Color(1.15, 1.15, 1.15), 0.14)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.18)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.18)


func _style_title() -> void:
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)


func _panel_style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(14)
	style.content_margin_left = margin * 2
	style.content_margin_right = margin * 2
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style
