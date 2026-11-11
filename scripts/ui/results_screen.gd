class_name ResultsScreen
extends Control
## Run results: medal, outcome title, final score, session best, distance,
## zone, items, retry, menu.
##
## The layout and styling live entirely in scenes/results_screen.tscn so the
## screen can be inspected and tweaked in the editor; this script only fills
## the values, colors the title, and plays the staggered reveal. Bests are
## per run mode and live in the GameState autoload, so a campaign record never
## mixes with an endless one.

signal retry_pressed

enum Outcome { OUT_OF_HEARTS, CAUGHT, VICTORY }

## Runs finished since launch; the NEW BEST! badge only shows from the second
## run onward, so the first run never claims to have beaten anything.
static var session_runs := 0

const CREAM := Color(1.0, 0.94, 0.86)
const CAUGHT_COLOR := Color(1.0, 0.62, 0.52)
const VICTORY_COLOR := Color("#ffb45e")

const TITLE_TEXT := "OUT OF HEARTS"
const CAUGHT_TITLE_TEXT := "CAUGHT!"
const VICTORY_TITLE_TEXT := "MADE IT!"

const MENU_SCENE := "res://scenes/main_menu.tscn"

## Result medal art, one texture per GameConfig.Medal tier. The gold outline
## medal reads best on the dark panel, so it carries the top tier.
const MEDAL_TEXTURES := {
	GameConfig.Medal.BLACK: preload("res://assets/icon/medal/Medal Black 64px.png"),
	GameConfig.Medal.SILVER: preload("res://assets/icon/medal/Silver Medal 1st Outline 64px.png"),
	GameConfig.Medal.GOLD: preload("res://assets/icon/medal/Golden Medal 1st Outline 64px.png"),
}

var _medal: int = GameConfig.Medal.BLACK

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var medal_plate: PanelContainer = $Center/Panel/VBox/MedalPlate
@onready var medal_icon: TextureRect = $Center/Panel/VBox/MedalPlate/Medal
@onready var stats_grid: GridContainer = $Center/Panel/VBox/Stats
@onready var best_value: Label = $Center/Panel/VBox/Stats/BestValue
@onready var new_best_label: Label = $Center/Panel/VBox/NewBest
@onready var retry_button: Button = $Center/Panel/VBox/Buttons/Retry
@onready var menu_button: Button = $Center/Panel/VBox/Buttons/Menu


func _ready() -> void:
	# The scene is saved visible so the editor shows the styled panel; the game
	# hides it here and only reveals it when a run ends.
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


## Fill the readouts, award the medal, record the score with GameState, and
## reveal. The best shown is the current mode's record AFTER this run lands.
func show_results(
	outcome: int, score: int, distance_m: int, zone_name: String, items: int,
	medal: int,
) -> void:
	var previous_best := GameState.best_for_mode()
	var is_new_best := session_runs > 0 and score > previous_best
	GameState.report_score(score)
	session_runs += 1

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


## Staggered fade-in so the results feel earned instead of dumped. The medal
## lands last with a scale pop, and a gold run gets a shine sweep after it.
func _play_reveal() -> void:
	var steps: Array[Control] = [title_label]
	for child in stats_grid.get_children():
		steps.append(child)
	if new_best_label.visible:
		steps.append(new_best_label)
	steps.append(retry_button)
	steps.append(menu_button)
	steps.append(medal_plate)
	for i in steps.size():
		var node := steps[i]
		node.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(i * 0.06)
	_pop_medal.call_deferred()


## The award moment: scale-pop from oversized to rest, then a shine sweep on
## gold. Deferred so the container layout settles before the pivot is set.
func _pop_medal() -> void:
	medal_icon.pivot_offset = medal_icon.size * 0.5
	medal_icon.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(medal_icon, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _medal == GameConfig.Medal.GOLD:
		tween.tween_property(medal_icon, "modulate",
			Color(1.4, 1.4, 1.4, 1.0), 0.12)
		tween.tween_property(medal_icon, "modulate",
			Color.WHITE, 0.22)
