class_name CountdownOverlay
extends Control
## 3-2-1-GO! overlay shown before every run start.
##
## Presentation only. The beat clock is advanced by RunWorld (not _process), so
## pausing freezes the countdown and the suite can drive it deterministically.
## RunWorld listens for [signal finished] to unlock the run on the GO frame,
## which is why GO is the unlock cue and not just a flourish: ending on "1"
## would leave the player guessing when the controls went live.
##
## The three numbers climb a pitch ladder (one sample, COUNTDOWN_TICK_PITCH_STEP
## per beat); GO is its own brighter sample. A spoken 3-2-1-GO sample is layered
## underneath, seeked to each cue so both layers land on the same beat.

## Emitted on the GO frame, exactly once per countdown. The run unlocks here,
## while the GO pop is still on screen, so there are no dead frames.
signal finished

const CREAM := Color(1.0, 0.94, 0.86)
const AMBER := Color("#ffb45e")
## Beat label pivot: the Label keeps a fixed 440x260 box (it never shrinks to
## its text), so the pop can scale from a stable centre without waiting a frame
## for a layout pass.
const BEAT_PIVOT := Vector2(220.0, 130.0)
const BEAT_NUMBER_SIZE := 160
const BEAT_GO_SIZE := 190
## Pop overshoot: transient juice, gone in under a quarter second.
const POP_TIME := 0.22
const POP_SCALE := 1.35
const GO_POP_SCALE := 1.5
## The number fades out before the next one appears, so two beats never overlap.
const BEAT_FADE_TIME := 0.16
## Final fade of the whole overlay once the GO cue has held.
const FADE_OUT_TIME := 0.2
## Cue onsets inside 321go.mp3, measured from the sample: "3", "2", "1", "GO".
## The overlay seeks to each one per beat instead of free-running the file, so
## the voice lands on the number even though the recording's own spacing drifts
## slightly from the 1 s beat clock - and a skip can jump straight to GO.
const CUE_OFFSETS: Array[float] = [0.5, 1.51, 2.44]
const GO_CUE_OFFSET := 3.48

## True while the overlay owns the screen and the run is still locked.
var is_active: bool = false
## True once the GO beat has been shown (the run is unlocked from then on).
var go_shown: bool = false
## Numbers left on the current beat: 3, 2, 1. Unused after GO.
var beat: int = GameConfig.START_COUNTDOWN_BEATS
## Seconds spent on the current beat, driven by [method advance].
var beat_time: float = 0.0
## Test counters: how many beats were shown, and how many skips happened.
var beat_play_count: int = 0
var skip_count: int = 0
## Last position the spoken cue was seeked to. The headless dummy audio driver
## has no advancing playback clock, so the suite asserts this instead.
var last_cue_offset: float = -1.0

## Which rung of the ladder the next tick sits on (reset by begin()).
var _tick_index: int = 0
var _tween: Tween

@onready var scrim: ColorRect = $Scrim
@onready var beat_label: Label = $Center/Beat
@onready var tick_sfx: AudioStreamPlayer = $TickSfx
@onready var go_sfx: AudioStreamPlayer = $GoSfx
@onready var cue_sfx: AudioStreamPlayer = %CueSfx


func _ready() -> void:
	visible = false
	beat_label.pivot_offset = BEAT_PIVOT
	tick_sfx.volume_db = GameConfig.COUNTDOWN_SFX_DB
	go_sfx.volume_db = GameConfig.COUNTDOWN_SFX_DB
	cue_sfx.volume_db = GameConfig.COUNTDOWN_CUE_DB


## Start the countdown from beat 3. Safe to call again after a dismiss.
func begin() -> void:
	_kill_tween()
	visible = true
	modulate.a = 1.0
	scrim.color.a = 0.55
	is_active = true
	go_shown = false
	beat = GameConfig.START_COUNTDOWN_BEATS
	beat_time = 0.0
	_tick_index = 0
	beat_play_count = 0
	skip_count = 0
	last_cue_offset = -1.0
	# A restart during the previous GO tail must not carry that voice over.
	cue_sfx.stop()
	_show_beat()


## Jump straight to GO (input skip). The GO frame still unlocks the run, so a
## skip costs the player the beat count but never the kickoff.
func skip() -> void:
	if not is_active or go_shown:
		return
	skip_count += 1
	_show_go()


## Advance the beat clock. Called from RunWorld._physics_process, which is why
## a paused tree freezes the countdown for free.
func advance(delta: float) -> void:
	if not is_active or go_shown:
		return
	beat_time += delta
	if beat_time < GameConfig.START_COUNTDOWN_BEAT_TIME:
		return
	beat -= 1
	if beat > 0:
		beat_time = 0.0
		_show_beat()
	else:
		_show_go()


## Hide without unlocking on GO. Used when a run is started directly (tests) or
## the overlay is abandoned; the real path always reaches GO first.
func dismiss() -> void:
	_kill_tween()
	# The beeps are 0.1 s one-shots and can ring out; the spoken cue is seconds
	# long and would otherwise talk over the run.
	cue_sfx.stop()
	is_active = false
	visible = false
	modulate.a = 1.0


## Pausing the tree does not stop audio, so the voice is frozen by hand (same
## rule as RunWorld's music bed). A mid-tick beep is short enough to ring out.
func set_audio_paused(paused: bool) -> void:
	cue_sfx.stream_paused = paused


## Any input after START_COUNTDOWN_SKIP_DELAY fast-forwards to GO. Mouse motion
## and release events are ignored so a stray hand on the desktop does not skip.
## The pause action never reaches here: PauseMenu consumes it first.
func _unhandled_input(event: InputEvent) -> void:
	if not is_active or go_shown:
		return
	if beat_time < GameConfig.START_COUNTDOWN_SKIP_DELAY:
		return
	# The pause menu owns its key; skipping must never swallow it.
	if event.is_action_pressed("pause"):
		return
	if event is InputEventMouseMotion:
		return
	if event is InputEventKey and not (event as InputEventKey).pressed:
		return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		return
	if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return
	skip()
	get_viewport().set_input_as_handled()


# --- Beats -------------------------------------------------------------------

## Show a number, or (via _show_go) the GO cue. The pop is a TRANS_BACK
## overshoot so the beat lands; the tail fade keeps the swap clean.
func _show_beat() -> void:
	_kill_tween()
	beat_play_count += 1
	beat_label.text = str(beat)
	beat_label.add_theme_color_override("font_color", CREAM)
	beat_label.add_theme_font_size_override("font_size", BEAT_NUMBER_SIZE)
	beat_label.modulate = Color(1, 1, 1, 1)
	beat_label.scale = Vector2(POP_SCALE, POP_SCALE)
	_tween = create_tween()
	_tween.tween_property(beat_label, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var hold := GameConfig.START_COUNTDOWN_BEAT_TIME - POP_TIME - BEAT_FADE_TIME
	_tween.tween_interval(maxf(hold, 0.0))
	_tween.tween_property(beat_label, "modulate:a", 0.0, BEAT_FADE_TIME)
	_play_tick()


func _show_go() -> void:
	if go_shown:
		return
	_kill_tween()
	go_shown = true
	is_active = false
	beat_time = 0.0
	beat_play_count += 1
	beat_label.text = "GO!"
	beat_label.add_theme_color_override("font_color", AMBER)
	beat_label.add_theme_font_size_override("font_size", BEAT_GO_SIZE)
	beat_label.modulate = Color(1, 1, 1, 1)
	beat_label.scale = Vector2(GO_POP_SCALE, GO_POP_SCALE)
	go_sfx.play()
	_play_cue(GO_CUE_OFFSET)
	# Fade the scrim first so the road is clear while the run starts moving,
	# then take the GO cue with it.
	var tw := create_tween()
	_tween = tw
	tw.tween_property(scrim, "color:a", 0.0, FADE_OUT_TIME)
	tw.parallel().tween_property(beat_label, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(GameConfig.START_COUNTDOWN_GO_TIME - POP_TIME, 0.0))
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	tw.tween_callback(_on_faded)
	# Unlock on this frame: the signal comes after the visuals are set up.
	finished.emit()


func _on_faded() -> void:
	visible = false
	modulate.a = 1.0


## One sample, one rung per beat: ~660 / 832 / 1048 Hz for 3 / 2 / 1. The
## spoken cue is seeked underneath on the same beat.
func _play_tick() -> void:
	tick_sfx.pitch_scale = pow(GameConfig.COUNTDOWN_TICK_PITCH_STEP, _tick_index)
	_play_cue(CUE_OFFSETS[_tick_index])
	_tick_index += 1
	tick_sfx.play()


## Layer the spoken 3-2-1-GO sample under the beeps. Seeking per cue (rather
## than letting the file free-run) keeps each word on its beat and lets a skip
## jump straight to the GO hit.
func _play_cue(offset: float) -> void:
	last_cue_offset = offset
	cue_sfx.play(offset)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
