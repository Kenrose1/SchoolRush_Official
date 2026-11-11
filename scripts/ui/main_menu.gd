class_name MainMenu
extends Control
## Main menu: CAMPAIGN / ENDLESS / HOW TO PLAY / QUIT over the school backdrop.
##
## The layout and styling live entirely in scenes/main_menu.tscn (the same
## scene-owned styling as results_screen.tscn); this script only wires the
## buttons, fills the best-score readout from the session record, and toggles
## the how-to overlay. Campaign launches the current course; Endless is parked
## with a SOON pill until the run-mode system lands.

const WORLD_SCENE := "res://scenes/main.tscn"
const BEST_FORMAT := "BEST  %06d"

@onready var campaign_button: Button = $Center/Panel/VBox/Campaign
@onready var endless_button: Button = $Center/Panel/VBox/Endless
@onready var how_to_button: Button = $Center/Panel/VBox/HowTo
@onready var quit_button: Button = $Center/Panel/VBox/Quit
@onready var best_label: Label = $Center/Panel/VBox/Best
@onready var how_to_panel: PanelContainer = $HowToCenter/HowToPanel
@onready var back_button: Button = $HowToCenter/HowToPanel/VBox/Back


func _ready() -> void:
	how_to_panel.visible = false
	best_label.text = BEST_FORMAT % GameState.best_campaign
	campaign_button.pressed.connect(_on_campaign_pressed)
	how_to_button.pressed.connect(_on_how_to_pressed)
	back_button.pressed.connect(_on_how_to_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	campaign_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the how-to overlay when it is up; while the menu is bare,
	# Esc does nothing (there is nothing to pause).
	if how_to_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_how_to_pressed()
		get_viewport().set_input_as_handled()


func _on_campaign_pressed() -> void:
	# Hand the run its rules; Endless gets wired here when its button goes
	# live (GameState.mode = GameConfig.RunMode.ENDLESS).
	GameState.mode = GameConfig.RunMode.CAMPAIGN
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_how_to_pressed() -> void:
	how_to_panel.visible = not how_to_panel.visible
	if how_to_panel.visible:
		back_button.grab_focus()
	else:
		campaign_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
