extends Node
## One UI click, shared by every button in the game.
##
## Autoloaded for two reasons: the tick has to survive a scene change (pressing
## CAMPAIGN still clicks as the menu is torn down), and the pause overlay keeps
## ticking while the tree is frozen.
##
## Buttons are picked up as they enter the tree, and the tree that already
## exists at boot is swept once, so scene-placed buttons and the shop's
## runtime-built buy cards need no wiring of their own.

const CLICK: AudioStream = preload("res://assets/sounds/clicksound.wav")
## A hair under the gameplay SFX (hurt/coin sit at -2 dB): a menu press repeats
## far more often than a coin pickup and must never compete with a run.
const CLICK_DB := -6.0
## Opt a button out by setting this meta; read at press time, so it can be set
## before or after the button enters the tree.
const SILENT_META := &"no_click_sfx"
## Stops a re-added button from connecting twice and double-clicking.
const HOOKED_META := &"ui_click_hooked"

## The shared player. Exposed so the suite can assert its routing.
var click_player: AudioStreamPlayer

## How many times the click has played. The audio driver is mute in headless
## tests, so they count plays rather than asking the player if it is playing.
var click_play_count: int = 0


func _ready() -> void:
	# The pause overlay runs under get_tree().paused; audio keeps playing
	# either way, but a paused node would stop seeing `pressed`.
	process_mode = Node.PROCESS_MODE_ALWAYS
	click_player = AudioStreamPlayer.new()
	click_player.name = "ClickPlayer"
	click_player.stream = CLICK
	click_player.bus = &"SFX"
	click_player.volume_db = CLICK_DB
	# Retrigger instead of stacking: the click is 30 ms long, so cutting the
	# previous copy is inaudible and keeps rapid shop clicks crisp.
	click_player.max_polyphony = 1
	add_child(click_player)
	# Autoloads turn ready only after the boot scene - the main menu - has
	# entered the tree, so node_added alone would leave every button in it
	# silent until a later scene load. Sweep what exists, then follow arrivals.
	hook_tree(get_tree().root)
	get_tree().node_added.connect(_on_node_added)


## Hook every button in `node` and below. Safe to call twice: the meta guard
## means a button swept twice still clicks exactly once.
func hook_tree(node: Node) -> void:
	if node is BaseButton:
		_hook(node as BaseButton)
	for child in node.get_children():
		hook_tree(child)


## Play the click. Buttons reach this through the tree hook; anything else
## (a future custom control) can call it directly.
func play_click() -> void:
	if click_player == null or click_player.stream == null:
		return
	click_play_count += 1
	click_player.play()


func _on_node_added(node: Node) -> void:
	hook_tree(node)


func _hook(btn: BaseButton) -> void:
	if btn.has_meta(HOOKED_META):
		return
	btn.set_meta(HOOKED_META, true)
	btn.pressed.connect(_on_button_pressed.bind(btn))


func _on_button_pressed(btn: BaseButton) -> void:
	if btn.has_meta(SILENT_META):
		return
	play_click()
