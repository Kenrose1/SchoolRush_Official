extends Control
## End-of-run summary. The panel, rows and buttons are scene nodes; this script
## fills in the numbers for the run that just ended.

signal retry_requested
signal menu_requested

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Title
@onready var line_label: Label = $Line
@onready var score_value: Label = $ScoreValue
@onready var items_value: Label = $ItemsValue
@onready var distance_value: Label = $DistanceValue
@onready var combo_value: Label = $ComboValue
@onready var record_label: Label = $Record
@onready var best_label: Label = $Best
@onready var runs_label: Label = $Runs
@onready var retry_button: Button = $Retry
@onready var menu_button: Button = $Menu


func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())


func present(result: Dictionary, is_record: bool, best_score: int) -> void:
	var outcome := String(result.get("outcome", ""))
	title_label.text = _outcome_title(outcome)
	line_label.text = _outcome_line(outcome)
	score_value.text = "%06d" % int(result.get("score", 0))
	items_value.text = str(int(result.get("items", 0)))
	distance_value.text = "%d m" % int(result.get("distance", 0))
	combo_value.text = "x%d" % int(result.get("combo", 1))
	record_label.visible = is_record
	best_label.text = "Best %s: %d" % [String(result.get("mode", "campaign")), best_score]
	runs_label.text = "Total runs: %d" % Save.runs

	var color := _outcome_color(outcome)
	title_label.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.17, 0.98)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	retry_button.grab_focus()


func _outcome_color(outcome: String) -> Color:
	match outcome:
		"win", "training_done":
			return Pal.YELLOW
		"pursuer":
			return Pal.RED
		"bell":
			return Pal.ORANGE
		_:
			return Pal.GREEN_LIGHT


func _outcome_title(outcome: String) -> String:
	match outcome:
		"win":
			return "MADE IT BEFORE THE BELL"
		"training_done":
			return "TRAINING COMPLETE"
		"pursuer":
			return "THE PURSUER GOT YOU"
		"bell":
			return "THE BELL ALREADY RANG"
		_:
			return "OUT OF HEARTS"


func _outcome_line(outcome: String) -> String:
	match outcome:
		"win":
			return "You slide into class as the 8:00 bell rings. Attendance saved."
		"training_done":
			return "Lane switches, jumps and slides are muscle memory now."
		"pursuer":
			return "Two mistakes in a row and the Barangay Guard closed the gap."
		"bell":
			return "Too slow today. The classroom filled up without you."
		_:
			return "Three hits and Elias is out of the commute."
