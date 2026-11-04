extends Control
## Title screen. Layout and copy live in scenes/title_screen.tscn; this script
## only wires the buttons and fills in the saved records.

signal mode_chosen(mode: String)

@onready var best_label: Label = $Best
@onready var campaign_button: Button = $Campaign
@onready var endless_button: Button = $Endless
@onready var training_button: Button = $Training


func _ready() -> void:
	campaign_button.pressed.connect(func() -> void: _choose("campaign"))
	endless_button.pressed.connect(func() -> void: _choose("endless"))
	training_button.pressed.connect(func() -> void: _choose("training"))
	refresh()
	campaign_button.grab_focus()


## Called every time the menu comes back, so the record line stays current.
func refresh() -> void:
	best_label.text = "BEST CAMPAIGN %d     RUNS %d" % [Save.best_for("campaign"), Save.runs]


func _choose(mode: String) -> void:
	Sfx.play("click")
	mode_chosen.emit(mode)
