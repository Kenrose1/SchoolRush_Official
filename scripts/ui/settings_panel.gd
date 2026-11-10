class_name SettingsPanel
extends Control
## Modal settings card: master volume and fullscreen.
##
## Built in code beside the control rail and hidden until the rail's gear button
## opens it. The card uses the HUD panel style and the same green atlas buttons,
## so the settings screen matches the rest of the interface. The panel itself
## only edits settings; pausing the run while it is open is the rail's job.

signal closed

const CARD_SIZE := Vector2(720.0, 430.0)
const CARD_FILL := Color(0.05, 0.10, 0.19, 0.96)
const CARD_BORDER := Color(0.29, 0.65, 0.90, 1.0)
const CARD_BORDER_WIDTH := 3
const CARD_CORNER_RADIUS := 14.0
const TITLE_FONT_SIZE := 44
const ROW_FONT_SIZE := 26
const HINT_COLOR := Color(0.62, 0.82, 0.96)
const VALUE_COLOR := Color(1.0, 0.98, 0.92)
const BUTTON_SIZE := 56.0
const ICON_SIZE := 34.0
const CLOSE_SIZE := 72.0
const CLOSE_ICON_SIZE := 40.0

var _slider: HSlider
var _volume_label: Label
var _fullscreen_button: GreenButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	_refresh()


## Show the card and pull its controls in line with the live settings.
func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.04, 0.05, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var card := Panel.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.anchor_left = 0.5
	card.anchor_top = 0.5
	card.anchor_right = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -CARD_SIZE.x * 0.5
	card.offset_top = -CARD_SIZE.y * 0.5
	card.offset_right = CARD_SIZE.x * 0.5
	card.offset_bottom = CARD_SIZE.y * 0.5
	card.add_theme_stylebox_override("panel", _card_style())
	add_child(card)

	var title := _make_label("SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, VALUE_COLOR,
		TITLE_FONT_SIZE)
	title.position = Vector2(40.0, 26.0)
	title.size = Vector2(640.0, 54.0)
	card.add_child(title)

	var volume_caption := _make_label("VOLUME", HORIZONTAL_ALIGNMENT_LEFT, HINT_COLOR,
		ROW_FONT_SIZE)
	volume_caption.position = Vector2(40.0, 100.0)
	volume_caption.size = Vector2(200.0, 36.0)
	card.add_child(volume_caption)

	_volume_label = _make_label("", HORIZONTAL_ALIGNMENT_RIGHT, VALUE_COLOR, ROW_FONT_SIZE)
	_volume_label.position = Vector2(400.0, 100.0)
	_volume_label.size = Vector2(280.0, 36.0)
	card.add_child(_volume_label)

	_slider = HSlider.new()
	_slider.name = "VolumeSlider"
	_slider.min_value = 0.0
	_slider.max_value = 100.0
	_slider.step = 1.0
	_slider.position = Vector2(40.0, 148.0)
	_slider.size = Vector2(640.0, 32.0)
	_slider.value_changed.connect(_on_volume_changed)
	card.add_child(_slider)

	var screen_caption := _make_label("FULLSCREEN", HORIZONTAL_ALIGNMENT_LEFT, HINT_COLOR,
		ROW_FONT_SIZE)
	screen_caption.position = Vector2(40.0, 214.0)
	screen_caption.size = Vector2(320.0, 36.0)
	card.add_child(screen_caption)

	_fullscreen_button = GreenButton.create(GameConfig.UI_CHECK_TILE, BUTTON_SIZE, ICON_SIZE)
	_fullscreen_button.name = "FullscreenButton"
	_fullscreen_button.position = Vector2(CARD_SIZE.x - 40.0 - BUTTON_SIZE, 204.0)
	_fullscreen_button.tooltip_text = "Toggle fullscreen"
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	card.add_child(_fullscreen_button)

	var close_button := GreenButton.create(
		GameConfig.UI_QUIT_TILE, CLOSE_SIZE, CLOSE_ICON_SIZE)
	close_button.name = "CloseButton"
	close_button.tooltip_text = "Close settings"
	close_button.position = Vector2(
		CARD_SIZE.x - 40.0 - CLOSE_SIZE, CARD_SIZE.y - 40.0 - CLOSE_SIZE)
	close_button.pressed.connect(_on_close_pressed)
	card.add_child(close_button)

	var close_hint := _make_label("[ESC]", HORIZONTAL_ALIGNMENT_LEFT, HINT_COLOR, 24)
	close_hint.position = Vector2(40.0, CARD_SIZE.y - 76.0)
	close_hint.size = Vector2(200.0, 36.0)
	card.add_child(close_hint)


func _on_volume_changed(value: float) -> void:
	GameAudio.volume = value / 100.0
	_volume_label.text = "%d%%" % int(value)


func _toggle_fullscreen() -> void:
	GameAudio.play(&"ui_click")
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if fullscreen
		else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh()


func _on_close_pressed() -> void:
	GameAudio.play(&"ui_click")
	close()


func _refresh() -> void:
	if _slider == null:
		return
	_slider.set_value_no_signal(GameAudio.volume * 100.0)
	_volume_label.text = "%d%%" % int(round(GameAudio.volume * 100.0))
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_button.modulate.a = 1.0 if fullscreen else 0.45


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_FILL
	style.border_color = CARD_BORDER
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(int(CARD_CORNER_RADIUS))
	return style


func _make_label(text: String, align: HorizontalAlignment, color: Color,
		font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
