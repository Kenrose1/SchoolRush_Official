extends Node
## TEMPORARY debug cheats: F8/Shift+F8 add coins, F9 zeroes the coin wallet
## (keeping bought upgrades), Shift+F9 wipes the whole save (coins + upgrades).
##
## Everything - including the save write - lives in this one file so the
## feature can be removed later by deleting this script and its autoload
## line in project.godot. Nothing else in the game references it.
##
## The keys are ignored in release exports (OS.is_debug_build gate), so even
## a forgotten autoload can never expose cheats to players.

const HINT := "debug: F8 = +500 coins, Shift+F8 = +5000 coins, F9 = reset wallet to 0, Shift+F9 = wipe coins and upgrades"


func _ready() -> void:
	# Keep listening while the pause menu is up.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	print(HINT)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F8:
		GameState.add_coins(5000 if key.shift_pressed else 500)
		print("debug: wallet topped up to %d coins" % GameState.coins)
		get_viewport().set_input_as_handled()
		return
	if key.physical_keycode == KEY_F9:
		if key.shift_pressed:
			wipe_progress()
		else:
			zero_wallet()
		get_viewport().set_input_as_handled()


## Zero the coin wallet. Bought upgrade levels are untouched, so the shop
## cards keep their pips and only affordability changes.
func zero_wallet() -> void:
	GameState.coins = 0
	GameState.coins_changed.emit(0)
	GameState._save_wallet()
	print("debug: wallet reset to 0 (upgrades kept)")


## Full fresh start: wallet and every upgrade level back to zero.
func wipe_progress() -> void:
	GameState.coins = 0
	GameState.shop_levels = {}
	GameState.coins_changed.emit(0)
	GameState._save_wallet()
	print("debug: progress wiped (coins and upgrades reset)")
