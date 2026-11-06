extends SceneTree
## Registers the gameplay input actions in project.godot.
##
## Run once (or whenever the bindings change):
##   godot --headless --path . --script res://tools/setup_input.gd
##
## Bindings use physical keycodes so the layout works on non-QWERTY keyboards.
## Keys come from Section V of the design document, minus dash (dropped in v1.4).

func _init() -> void:
	_register("lane_up", [KEY_W, KEY_UP])
	_register("lane_down", [KEY_S, KEY_DOWN])
	_register("jump", [KEY_SPACE])
	_register("slide", [KEY_CTRL])
	_register("pause", [KEY_ESCAPE])

	var err := ProjectSettings.save()
	if err != OK:
		push_error("Could not save project settings (error %d)" % err)
		quit(1)
		return
	print("Input actions written to project.godot")
	quit(0)


func _register(action: String, keys: Array) -> void:
	var events: Array[InputEvent] = []
	for key: Key in keys:
		var event := InputEventKey.new()
		event.device = -1  # accept the action from any device
		event.physical_keycode = key
		events.append(event)
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.5, "events": events})
