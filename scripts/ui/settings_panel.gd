class_name SettingsPanel
extends PanelContainer
## Reusable settings panel: volume sliders (Master / Music / SFX), a
## fullscreen toggle, a debug-overlay toggle, and a BACK button.
##
## Embedded by both the main menu and the pause overlay; the panel knows
## nothing about its host - hosts connect to [signal closed] to restore focus.

signal closed

## AudioServer bus indices, matching default_bus_layout.tres.
const BUS_MASTER := 0
const BUS_MUSIC := 1
const BUS_SFX := 2

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var debug_check: CheckButton = %DebugCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	# Hidden at runtime; the scene root stays visible so the panel can be
	# styled in the editor (same arrangement as the results screen).
	visible = false
	master_slider.value_changed.connect(_on_volume_changed.bind(BUS_MASTER))
	music_slider.value_changed.connect(_on_volume_changed.bind(BUS_MUSIC))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(BUS_SFX))
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	debug_check.toggled.connect(_on_debug_toggled)
	back_button.pressed.connect(close)


## Show the panel with every control synced to the live settings.
func open() -> void:
	_sync_controls()
	visible = true
	master_slider.grab_focus()


## Hide the panel and tell the host to restore focus.
func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Esc backs out of the panel. Consuming it here keeps the host's own
	# Esc handlers (how-to close, pause toggle) from also firing.
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Control wiring ----------------------------------------------------------

## Push the current AudioServer / window / debug state into the controls.
func _sync_controls() -> void:
	master_slider.set_value_no_signal(bus_volume_percent(BUS_MASTER))
	music_slider.set_value_no_signal(bus_volume_percent(BUS_MUSIC))
	sfx_slider.set_value_no_signal(bus_volume_percent(BUS_SFX))
	fullscreen_check.set_pressed_no_signal(
		get_window().mode == Window.MODE_FULLSCREEN
	)
	debug_check.set_pressed_no_signal(GameState.debug_overlay)


func _on_volume_changed(percent: float, bus: int) -> void:
	set_bus_volume_percent(bus, percent)


func _on_fullscreen_toggled(pressed: bool) -> void:
	var window := get_window()
	if window == null:
		return
	window.mode = Window.MODE_FULLSCREEN if pressed else Window.MODE_WINDOWED


func _on_debug_toggled(pressed: bool) -> void:
	GameState.set_debug_overlay(pressed)


# --- Bus volume helpers ------------------------------------------------------

## A bus's volume as a 0-100 percent, readable back by the slider.
static func bus_volume_percent(bus: int) -> float:
	var db := AudioServer.get_bus_volume_db(bus)
	if db <= -60.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


## Set a bus's volume from a 0-100 percent. Zero also mutes the bus so the
## slider bottom acts as an off switch.
static func set_bus_volume_percent(bus: int, percent: float) -> void:
	var clamped := clampf(percent, 0.0, 100.0)
	AudioServer.set_bus_mute(bus, clamped <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(clamped / 100.0, 0.0001)))
