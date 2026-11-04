extends Control
## Pause / help overlay. Copy lives in scenes/pause_screen.tscn.

signal resume_requested
signal restart_requested
signal menu_requested

@onready var resume_button: Button = $Resume
@onready var restart_button: Button = $Restart
@onready var menu_button: Button = $Menu


func _ready() -> void:
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	resume_button.grab_focus()
