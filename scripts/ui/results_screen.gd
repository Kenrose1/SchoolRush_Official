class_name ResultsScreen
extends Control
## Run results: medal, outcome title, final score, session best, distance,
## zone, items, coins earned, retry, menu.
##
## Upgraded with "The Morning Report Card / Clearance Slip" styling, dynamic
## outcome stamps, stamped medal pedestal animation, and spring micro-interactions.

signal retry_pressed

enum Outcome { OUT_OF_HEARTS, CAUGHT, VICTORY }

## Runs finished since launch; the NEW BEST! badge only shows from the second
## run onward, so the first run never claims to have beaten anything.
static var session_runs := 0

const CREAM := Color(1.0, 0.94, 0.86)
const CAUGHT_COLOR := Color(1.0, 0.42, 0.35)
const VICTORY_COLOR := Color("#ffb45e")

const TITLE_TEXT := "OUT OF HEARTS"
const CAUGHT_TITLE_TEXT := "CAUGHT!"
const VICTORY_TITLE_TEXT := "MADE IT TO CLASS!"

const MENU_SCENE := "res://scenes/main_menu.tscn"

## Result medal art, one texture per GameConfig.Medal tier. The gold outline
## medal reads best on the dark panel, so it carries the top tier.
const MEDAL_TEXTURES := {
	GameConfig.Medal.BLACK: preload("res://assets/icon/medal/Medal Black 64px.png"),
	GameConfig.Medal.SILVER: preload("res://assets/icon/medal/Silver Medal 1st Outline 64px.png"),
	GameConfig.Medal.GOLD: preload("res://assets/icon/medal/Golden Medal 1st Outline 64px.png"),
}

var _medal: int = GameConfig.Medal.BLACK
var _outcome: int = Outcome.OUT_OF_HEARTS
var _is_new_best := false
## Bumped per reveal so a badge timer queued by an earlier card can never fire
## on top of the next one.
var _reveal_id := 0
## Badge pops played by this screen; the suite reads it as the reveal contract.
var badge_pop_count := 0
var _medal_tween: Tween
var _medal_flash_tween: Tween

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var medal_plate: PanelContainer = $Center/Panel/VBox/MedalPlate
@onready var medal_icon: TextureRect = $Center/Panel/VBox/MedalPlate/Medal
@onready var stats_grid: GridContainer = $Center/Panel/VBox/StatsCard/Stats
@onready var best_value: Label = $Center/Panel/VBox/StatsCard/Stats/BestValue
@onready var new_best_label: Label = $Center/Panel/VBox/NewBest
@onready var retry_button: Button = $Center/Panel/VBox/Buttons/Retry
@onready var menu_button: Button = $Center/Panel/VBox/Buttons/Menu
@onready var victory_sfx: AudioStreamPlayer = $VictoryFanfareSfx
@onready var badge_sfx: AudioStreamPlayer = $BadgeChimeSfx
@onready var record_sfx: AudioStreamPlayer = $NewRecordSfx


func _ready() -> void:
	visible = false
	# Mix levels live in GameConfig so the suite can assert them in one place.
	victory_sfx.volume_db = GameConfig.RESULTS_FANFARE_DB
	badge_sfx.volume_db = GameConfig.RESULTS_CHIME_DB
	record_sfx.volume_db = GameConfig.RESULTS_RECORD_DB
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_setup_button(retry_button)
	_setup_button(menu_button)


func _setup_button(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size * 0.5
	btn.mouse_entered.connect(func(): _animate_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _animate_button_hover(btn, false))
	btn.focus_entered.connect(func(): _animate_button_hover(btn, true))
	btn.focus_exited.connect(func(): _animate_button_hover(btn, false))


func _animate_button_hover(btn: Button, is_hovered: bool) -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovered:
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.14)
		tw.tween_property(btn, "modulate", Color(1.15, 1.15, 1.15), 0.14)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.18)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.18)


## Fill the readouts, award the medal, record the score with GameState, and
## reveal. The best shown is the current mode's record AFTER this run lands.
func show_results(
	outcome: int, score: int, distance_m: int, zone_name: String, items: int,
	medal: int, coins: int = 0,
) -> void:
	var previous_best := GameState.best_for_mode()
	var is_new_best := session_runs > 0 and score > previous_best
	GameState.report_score(score)
	session_runs += 1
	_outcome = outcome
	_is_new_best = is_new_best
	_stop_cues()

	match outcome:
		Outcome.CAUGHT:
			title_label.text = CAUGHT_TITLE_TEXT
			title_label.add_theme_color_override("font_color", CAUGHT_COLOR)
		Outcome.VICTORY:
			title_label.text = VICTORY_TITLE_TEXT
			title_label.add_theme_color_override("font_color", VICTORY_COLOR)
		_:
			title_label.text = TITLE_TEXT
			title_label.add_theme_color_override("font_color", CREAM)
	_set_stat("score", "%06d" % score)
	_set_stat("best", "%06d" % GameState.best_for_mode())
	_set_stat("distance", "FINISH" if outcome == Outcome.VICTORY else "%d m" % distance_m)
	_set_stat("zone", zone_name)
	_set_stat("items", "%d" % items)
	_set_stat("coins", "%d" % coins)
	new_best_label.visible = is_new_best
	set_medal(medal)

	visible = true
	retry_button.grab_focus()
	_play_reveal()


## Current session record for the active mode, readable by the suite.
func reported_best() -> int:
	return GameState.best_for_mode()


## Text of one stat readout ("score", "best", "distance", "zone", "items").
func stat_text(part: String) -> String:
	var node := stats_grid.get_node_or_null(NodePath(part.capitalize() + "Value"))
	if node is Label:
		return (node as Label).text
	return ""


func _set_stat(part: String, value_text: String) -> void:
	var node := stats_grid.get_node_or_null(NodePath(part.capitalize() + "Value"))
	if node is Label:
		(node as Label).text = value_text


## Swap the medal art for the awarded tier.
func set_medal(tier: int) -> void:
	_medal = clampi(tier, GameConfig.Medal.BLACK, GameConfig.Medal.GOLD)
	medal_icon.texture = MEDAL_TEXTURES[_medal]
	medal_icon.modulate = Color.WHITE


## Which tier is currently awarded, readable by the suite.
func awarded_medal() -> int:
	return _medal


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## Staggered fade-in and slam effect so results feel earned and impactful.
func _play_reveal() -> void:
	var steps: Array[Control] = [title_label]
	for child in stats_grid.get_children():
		steps.append(child)
	if new_best_label.visible:
		steps.append(new_best_label)
		new_best_label.rotation_degrees = -4.0
		new_best_label.pivot_offset = new_best_label.size * 0.5
	steps.append(retry_button)
	steps.append(menu_button)
	steps.append(medal_plate)
	for i in steps.size():
		var node := steps[i]
		node.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, 0.16).set_delay(i * 0.05)
	_pop_medal.call_deferred()
	if _outcome == Outcome.VICTORY:
		_play_victory_cues()


## Victory is the only outcome with reveal cues: the fanfare hits with the card,
## and the badge answers the medal pop a beat later. Failure stays silent here
## on purpose - RunWorld owns its sting and looping bed.
func _play_victory_cues() -> void:
	victory_sfx.play()
	_reveal_id += 1
	var id := _reveal_id
	get_tree().create_timer(GameConfig.RESULTS_BADGE_CUE_DELAY).timeout.connect(
		func() -> void: _play_badge_cue(id))


## The award accent: a new session best swaps in the level-up cue, otherwise the
## medal gets the chime. The reveal id guard drops a stale timer, and the hidden
## check covers a retry that lands before the delayed cue.
func _play_badge_cue(id: int) -> void:
	if id != _reveal_id or not visible or _outcome != Outcome.VICTORY:
		return
	_play_badge_pop()
	if _is_new_best:
		record_sfx.play()
	else:
		badge_sfx.play()


## Badge pop: a spring on the medal itself, timed to the chime. The pop is
## 1.20 -> 0.96 -> 1.0 over 0.35 s, light enough to read as an award tick rather
## than a second slam. Gold gets its flash here (not at the reveal) so the two
## hits never flicker together.
func _play_badge_pop() -> void:
	badge_pop_count += 1
	_kill_medal_tweens()
	medal_icon.pivot_offset = medal_icon.size * 0.5
	medal_icon.scale = Vector2.ONE
	medal_icon.modulate = Color.WHITE
	_medal_tween = create_tween()
	_medal_tween.tween_property(medal_icon, "scale", Vector2(1.2, 1.2), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_medal_tween.tween_property(medal_icon, "scale", Vector2(0.96, 0.96), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_medal_tween.tween_property(medal_icon, "scale", Vector2.ONE, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _medal == GameConfig.Medal.GOLD:
		_medal_flash_tween = create_tween()
		_medal_flash_tween.tween_property(medal_icon, "modulate",
			Color(1.6, 1.6, 1.6, 1.0), 0.08)
		_medal_flash_tween.tween_property(medal_icon, "modulate",
			Color.WHITE, 0.2)


## One live medal tween at a time: a retry or a re-show must not leave two
## tweens fighting over scale/modulate.
func _kill_medal_tweens() -> void:
	if _medal_tween != null and _medal_tween.is_valid():
		_medal_tween.kill()
	if _medal_flash_tween != null and _medal_flash_tween.is_valid():
		_medal_flash_tween.kill()


## Cut any cue still ringing from the previous card before filling this one.
func _stop_cues() -> void:
	_reveal_id += 1
	for player in [victory_sfx, badge_sfx, record_sfx]:
		(player as AudioStreamPlayer).stop()


## The reveal slam: the medal arrives oversized and settles. On victory the badge
## pop and the gold flash are held back for the chime half a second later, so
## the two hits do not flicker together. Other outcomes keep the original shine.
func _pop_medal() -> void:
	_kill_medal_tweens()
	medal_icon.modulate = Color.WHITE
	medal_icon.pivot_offset = medal_icon.size * 0.5
	medal_icon.scale = Vector2(1.5, 1.5)
	_medal_tween = create_tween()
	_medal_tween.tween_property(medal_icon, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _outcome != Outcome.VICTORY and _medal == GameConfig.Medal.GOLD:
		_medal_tween.tween_property(medal_icon, "modulate",
			Color(1.5, 1.5, 1.5, 1.0), 0.14)
		_medal_tween.tween_property(medal_icon, "modulate",
			Color.WHITE, 0.22)
