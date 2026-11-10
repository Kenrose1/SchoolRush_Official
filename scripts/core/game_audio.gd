extends Node
## Game-wide sound effects plus the master volume and mute state.
##
## Registered as the GameAudio autoload. Every clip is synthesised by
## tools/build_audio.gd, so the project carries no third-party audio. Playback
## runs through a small pool of players so overlapping sounds never cut each
## other off, and muting only silences the bus: the volume slider keeps its
## value for when the player unmutes.

## Clip name -> file. Keep in step with tools/build_audio.gd.
const SOUNDS := {
	&"pickup": "res://assets/audio/pickup.wav",
	&"jump": "res://assets/audio/jump.wav",
	&"hit": "res://assets/audio/hit.wav",
	&"ui_click": "res://assets/audio/ui_click.wav",
	&"finish": "res://assets/audio/finish.wav",
}
const POOL_SIZE := 8
const DEFAULT_VOLUME := 0.8

## Master volume, 0..1.
var volume: float = DEFAULT_VOLUME:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_apply_bus()

## Whether every sound is silenced.
var muted: bool = false:
	set(value):
		muted = value
		_apply_bus()

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	# Sounds keep playing while the tree is paused (menu clicks, the pause beep).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_apply_bus()


## Play [param sound] on the next free voice. Unknown names are ignored.
func play(sound: StringName) -> void:
	if muted or _players.is_empty():
		return
	var path: String = SOUNDS.get(sound, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


## Flip mute and return the new state, so callers can swap their glyph.
func toggle_muted() -> bool:
	muted = not muted
	return muted


func _apply_bus() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, muted)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
