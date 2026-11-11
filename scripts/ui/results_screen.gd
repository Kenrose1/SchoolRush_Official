class_name ResultsScreen
extends Control
## Run results: title, final score, session best, distance, zone, items, retry.
##
## The layout and styling live entirely in scenes/results_screen.tscn so the
## screen can be inspected and tweaked in the editor; this script only fills
## the values, colors the title, and plays the staggered reveal. The best
## score is session-only: a static that survives scene reloads (so [R] retries
## keep the record) but resets when the app closes.

signal retry_pressed

static var session_best := 0
## Runs finished since launch; the NEW BEST! badge only shows from the second
## run onward, so the first run never claims to have beaten anything.
static var session_runs := 0

const CREAM := Color(1.0, 0.94, 0.86)
const CAUGHT_COLOR := Color(1.0, 0.62, 0.52)

const TITLE_TEXT := "OUT OF HEARTS"
const CAUGHT_TITLE_TEXT := "CAUGHT!"

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var stats_grid: GridContainer = $Center/Panel/VBox/Stats
@onready var best_value: Label = $Center/Panel/VBox/Stats/BestValue
@onready var new_best_label: Label = $Center/Panel/VBox/NewBest
@onready var retry_button: Button = $Center/Panel/VBox/Retry


func _ready() -> void:
	# The scene is saved visible so the editor shows the styled panel; the game
	# hides it here and only reveals it when a run ends.
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)


## Fill the readouts, update the session best, and reveal the screen.
func show_results(
	caught: bool, score: int, distance_m: int, zone_name: String, items: int
) -> void:
	var is_new_best := session_runs > 0 and score > session_best
	session_best = maxi(session_best, score)
	session_runs += 1

	title_label.text = CAUGHT_TITLE_TEXT if caught else TITLE_TEXT
	title_label.add_theme_color_override(
		"font_color", CAUGHT_COLOR if caught else CREAM)
	_set_stat("score", "%06d" % score)
	_set_stat("best", "%06d" % session_best)
	_set_stat("distance", "%d m" % distance_m)
	_set_stat("zone", zone_name)
	_set_stat("items", "%d" % items)
	new_best_label.visible = is_new_best

	visible = true
	retry_button.grab_focus()
	_play_reveal()


## Current session record, readable by the suite.
func reported_best() -> int:
	return session_best


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


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	get_tree().reload_current_scene()


## Staggered fade-in so the results feel earned instead of dumped.
func _play_reveal() -> void:
	var steps: Array[Control] = [title_label]
	for child in stats_grid.get_children():
		steps.append(child)
	if new_best_label.visible:
		steps.append(new_best_label)
	steps.append(retry_button)
	for i in steps.size():
		var node := steps[i]
		node.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(i * 0.06)
