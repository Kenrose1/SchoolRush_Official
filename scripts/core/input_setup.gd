extends Node
## Registers gamepad bindings at runtime, on top of the keyboard actions in
## project.godot.
##
## The menus were already controller-ready (focus neighbours, ui_cancel), so a
## pad could drive every screen but not the run itself. These bindings close
## that gap without re-serialising project.godot's input map, and they are
## additive: a missing action or an existing binding is skipped, never replaced.
##
## Bindings: d-pad / left stick for lanes, A to jump, X to slide, Start to
## pause. Touch gestures live in Player (swipe up/down to change lane, swipe
## left to slide, tap to jump).

## How many pad events were added this launch (the suite asserts it once).
var gamepad_bindings_added: int = 0

const BINDINGS := {
	"lane_up": {"buttons": [JOY_BUTTON_DPAD_UP], "axes": [JOY_AXIS_LEFT_Y, -1.0]},
	"lane_down": {"buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [JOY_AXIS_LEFT_Y, 1.0]},
	"jump": {"buttons": [JOY_BUTTON_A], "axes": []},
	"slide": {"buttons": [JOY_BUTTON_X], "axes": []},
	"pause": {"buttons": [JOY_BUTTON_START], "axes": []},
}


func _ready() -> void:
	register()


## Add every missing pad event. Idempotent, so a restart or a second call can
## never stack duplicate bindings.
func register() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			continue
		var binding: Dictionary = BINDINGS[action]
		for button: int in binding["buttons"]:
			if _has_button(action, button):
				continue
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = button
			InputMap.action_add_event(action, event)
			gamepad_bindings_added += 1
		var axes: Array = binding["axes"]
		if axes.size() < 2:
			continue
		var axis := int(axes[0])
		var value := float(axes[1])
		if _has_axis(action, axis, value):
			continue
		var motion := InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = axis
		motion.axis_value = value
		InputMap.action_add_event(action, motion)
		gamepad_bindings_added += 1


func _has_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			if (event as InputEventJoypadButton).button_index == button:
				return true
	return false


func _has_axis(action: String, axis: int, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and signf(motion.axis_value) == signf(value):
				return true
	return false
