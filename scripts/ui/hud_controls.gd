class_name HudControls
extends CanvasLayer
## Control rail and settings card.
##
## The rail is its own panel in the top-right corner, outside the hearts/speed
## box and sharing the HUD panels' top and bottom line, so the whole interface
## stays on one bar. The five green atlas buttons are pause/play, restart, mute,
## settings and quit. The layer runs with PROCESS_MODE_ALWAYS so its buttons keep
## receiving input while the tree is paused; the pause toggle is also bound to the
## "pause" action, which doubles as the settings card's close key.

## Rail panel in the 1920x1080 design space: its own box in the top-right corner,
## clear of the hearts/speed panel and as tall as the rest of the top bar. Two
## columns of 44 px buttons give the five controls room without a taller panel.
const RAIL_POSITION := Vector2(1792.0, 24.0)
const RAIL_SIZE := Vector2(96.0, 196.0)
const BUTTON_COUNT := 5
const BUTTON_COLUMNS := 2
const BUTTON_SIZE := 40.0
const BUTTON_GAP := 8.0
const ROW_GAP := 6.0
const RAIL_PADDING := 4.0
## Top of the first row: three rows of 40 px + 6 px gaps, centred in the panel.
const BUTTON_TOP := 32.0
const ICON_SIZE := 24.0
const PANEL_FILL := Color(0.05, 0.10, 0.19, 0.86)
const PANEL_BORDER := Color(0.29, 0.65, 0.90, 1.0)
const PANEL_BORDER_WIDTH := 3
const PANEL_CORNER_RADIUS := 12.0
## Canvas layer of the settings card: above the game-over overlay's layer 20.
const SETTINGS_LAYER := 30

var _pause_button: GreenButton
var _mute_button: GreenButton
var _settings: SettingsPanel
var _overlay: Control
var _paused_by_settings: bool = false


func _ready() -> void:
	# Keep this layer alive while get_tree().paused is true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_build_rail()
	_build_settings()
	_apply_state()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings != null and _settings.is_open():
		_close_settings()
	else:
		_toggle_pause()
	get_viewport().set_input_as_handled()


## Freeze/unfreeze the whole run.
func _toggle_pause() -> void:
	GameAudio.play(&"ui_click")
	get_tree().paused = not get_tree().paused
	_apply_state()


## Start the run over from the first zone, even if the tree was paused.
func _restart() -> void:
	GameAudio.play(&"ui_click")
	get_tree().paused = false
	get_tree().reload_current_scene()


## Leave the game.
func _quit() -> void:
	GameAudio.play(&"ui_click")
	get_tree().paused = false
	get_tree().quit()


## Silence every sound without disturbing the volume slider.
func _toggle_mute() -> void:
	GameAudio.play(&"ui_click")
	GameAudio.toggle_muted()
	_apply_state()


func _open_settings() -> void:
	GameAudio.play(&"ui_click")
	_settings.open()
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_settings = true
	_apply_state()


func _close_settings() -> void:
	if _settings != null:
		_settings.close()


func _on_settings_closed() -> void:
	if _paused_by_settings:
		get_tree().paused = false
		_paused_by_settings = false
	_apply_state()


## Reflect pause, mute and settings state on the rail glyphs and overlay.
func _apply_state() -> void:
	var paused := get_tree().paused
	var settings_open := _settings != null and _settings.is_open()
	if _pause_button != null:
		_pause_button.set_glyph(
			GameConfig.UI_PLAY_TILE if paused and not settings_open
			else GameConfig.UI_PAUSE_TILE)
	if _mute_button != null:
		_mute_button.set_glyph(
			GameConfig.UI_SOUND_OFF_TILE if GameAudio.muted
			else GameConfig.UI_SOUND_ON_TILE)
	if _overlay != null:
		_overlay.visible = paused and not settings_open


func _build_rail() -> void:
	var rail := Panel.new()
	rail.name = "Rail"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.position = RAIL_POSITION
	rail.size = RAIL_SIZE
	rail.add_theme_stylebox_override("panel", _panel_style())
	add_child(rail)

	_pause_button = _add_button(rail, "PauseButton", GameConfig.UI_PAUSE_TILE,
		_toggle_pause)
	_add_button(rail, "RestartButton", GameConfig.UI_RETRY_TILE, _restart)
	_mute_button = _add_button(rail, "MuteButton", GameConfig.UI_SOUND_ON_TILE,
		_toggle_mute)
	_add_button(rail, "SettingsButton", GameConfig.UI_SETTINGS_TILE, _open_settings)
	_add_button(rail, "QuitButton", GameConfig.UI_QUIT_TILE, _quit)


func _add_button(rail: Control, button_name: String, glyph: Vector2i,
		action: Callable) -> GreenButton:
	var index := rail.get_child_count()
	var button := GreenButton.create(glyph, BUTTON_SIZE, ICON_SIZE)
	button.name = button_name
	var column := index % BUTTON_COLUMNS
	var row := index / BUTTON_COLUMNS
	var x := RAIL_PADDING + float(column) * (BUTTON_SIZE + BUTTON_GAP)
	# An odd last button centres itself instead of leaving a hole in the grid.
	if index == BUTTON_COUNT - 1 and BUTTON_COUNT % BUTTON_COLUMNS != 0:
		x = (RAIL_SIZE.x - BUTTON_SIZE) * 0.5
	button.position = Vector2(x, BUTTON_TOP + float(row) * (BUTTON_SIZE + ROW_GAP))
	button.pressed.connect(action)
	rail.add_child(button)
	return button


func _build_settings() -> void:
	# Its own layer above the game-over overlay (layer 20), so the card is never
	# drawn underneath the CAUGHT!/ESCAPED screens.
	var layer := CanvasLayer.new()
	layer.name = "SettingsLayer"
	layer.layer = SETTINGS_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	_settings.closed.connect(_on_settings_closed)
	layer.add_child(_settings)


## Frame shared with the HUD panels, so the rail reads as part of the top bar.
func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(int(PANEL_CORNER_RADIUS))
	return style


## Full-screen dim + centred "PAUSED" label, hidden until the run is paused.
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.04, 0.05, 0.08, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var label := Label.new()
	label.name = "PausedLabel"
	label.text = "PAUSED"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(label)
