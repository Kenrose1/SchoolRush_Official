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
	fullscreen_check.set_pressed_no_signal(GameState.fullscreen)
	debug_check.set_pressed_no_signal(GameState.debug_overlay)


## Slider moves apply AND persist, so levels survive a restart. The pure
## helpers below stay side-effect free for callers that only need the mixer.
func _on_volume_changed(percent: float, bus: int) -> void:
	GameState.set_audio_percent(bus, percent)


func _on_fullscreen_toggled(pressed: bool) -> void:
	GameState.set_fullscreen(pressed)


func _on_debug_toggled(pressed: bool) -> void:
	GameState.set_debug_overlay(pressed)


# --- Bus volume helpers ------------------------------------------------------

## A bus's volume as a 0-100 percent, readable back by the slider. Delegates to
## GameState so persistence and the UI share one implementation.
static func bus_volume_percent(bus: int) -> float:
	return GameState.bus_percent(bus)


## Set a bus's volume from a 0-100 percent. Zero also mutes the bus so the
## slider bottom acts as an off switch. Does not touch the save; the slider
## handler persists through GameState.set_audio_percent.
static func set_bus_volume_percent(bus: int, percent: float) -> void:
	GameState.set_bus_percent(bus, percent)
