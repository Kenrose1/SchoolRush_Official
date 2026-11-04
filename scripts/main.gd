extends Node
## Screen flow: title -> run -> pause/help -> results (GDD section 05).
## Each screen is its own editable scene in res://scenes/; this script only
## swaps them and carries the run result between them.

const GAME_SCENE := preload("res://scenes/game.tscn")
const PAUSE_SCENE := preload("res://scenes/pause_screen.tscn")
const RESULT_SCENE := preload("res://scenes/result_screen.tscn")

@onready var menu_world: Node2D = $MenuWorld
@onready var title_screen: Control = $TitleScreen

var _ui_layer: CanvasLayer
var _screen: Control
var _game: Game
var _state := "title"
var _mode := "campaign"
var _last_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	title_screen.mode_chosen.connect(_start_game)
	Sfx.set_intensity(0.1)
	Sfx.start_music()
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match _state:
		"title":
			match key.keycode:
				KEY_1:
					_start_game("campaign")
				KEY_2:
					_start_game("endless")
				KEY_3:
					_start_game("training")
				KEY_Q:
					get_tree().quit()
		"play":
			if key.keycode == KEY_ESCAPE:
				_pause()
		"paused":
			if key.keycode == KEY_ESCAPE:
				_resume()
		"result":
			if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_restart()
			elif key.keycode == KEY_ESCAPE:
				_quit_to_title()


func _clear_screen() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _show_screen(scene: PackedScene) -> Control:
	_clear_screen()
	var screen := scene.instantiate() as Control
	_screen = screen
	_ui_layer.add_child(screen)
	return screen


# --- screens ---------------------------------------------------------------

func _show_title() -> void:
	_state = "title"
	_clear_screen()
	menu_world.visible = true
	title_screen.visible = true
	title_screen.call("refresh")


func _start_game(mode: String) -> void:
	_mode = mode
	menu_world.visible = false
	title_screen.visible = false
	_clear_screen()
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		_game = null
	_game = GAME_SCENE.instantiate() as Game
	_game.mode = mode
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	_game.finished.connect(_on_run_finished)
	add_child(_game)
	_state = "play"
	Sfx.play("click")


func _pause() -> void:
	if _game == null or _state != "play":
		return
	_state = "paused"
	get_tree().paused = true
	var screen := _show_screen(PAUSE_SCENE)
	screen.resume_requested.connect(_resume)
	screen.restart_requested.connect(_restart)
	screen.menu_requested.connect(_quit_to_title)


func _resume() -> void:
	if _state != "paused":
		return
	get_tree().paused = false
	_clear_screen()
	_state = "play"


func _restart() -> void:
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		_game = null
	_start_game(_mode)


func _quit_to_title() -> void:
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
		_game = null
	_clear_screen()
	Sfx.stop_music()
	Sfx.start_music()
	Sfx.set_intensity(0.1)
	_show_title()


# --- results ---------------------------------------------------------------

func _on_run_finished(result: Dictionary) -> void:
	_last_result = result
	_state = "result"
	var mode := String(result.get("mode", "campaign"))
	var is_record := Save.submit_run(
		mode,
		int(result.get("score", 0)),
		int(result.get("distance", 0)),
		int(result.get("combo", 1)),
	)
	var screen := _show_screen(RESULT_SCENE)
	screen.retry_requested.connect(_restart)
	screen.menu_requested.connect(_quit_to_title)
	screen.present(result, is_record, Save.best_for(mode))
