extends Node
## Session state shared across scene changes: the selected run mode, the
## per-mode best scores, and the persistent coin wallet.
##
## The menu writes [member mode] before starting a run; RunWorld reads it in
## _ready and ResultsScreen reports finished scores back here. Bests are
## session-only for now - they reset when the app closes.

## Which rules the next run plays by (GameConfig.RunMode).
var mode: int = GameConfig.RunMode.CAMPAIGN

## Best final score per mode, updated by ResultsScreen when a run ends.
var best_campaign: int = 0
var best_endless: int = 0

## Emitted when the debug overlay preference flips (settings panel or F3).
signal debug_overlay_changed(shown: bool)

## Whether the run's debug readout shows. Session-only: it resets to the
## GameConfig.DEBUG_OVERLAY default on every launch.
var debug_overlay: bool = GameConfig.DEBUG_OVERLAY

## Emitted every time the coin wallet moves. The HUD subscribes to this -
## it never polls the wallet (game-ui-ux: event-driven HUD).
signal coins_changed(count: int)

const SAVE_PATH_DEFAULT := "user://schoolrush_save.cfg"
const SAVE_SECTION_WALLET := "wallet"
const SAVE_KEY_COINS := "coins"

## Where the wallet persists. The suite repoints this at a scratch file so
## tests never touch the player's real save.
var save_path: String = SAVE_PATH_DEFAULT

## The persistent coin wallet. Loaded from disk in _ready, written through on
## every pickup so a crash can only ever lose the newest coin.
var coins: int = 0


func _ready() -> void:
	_load_wallet()


## Flip the debug overlay preference and broadcast it.
func set_debug_overlay(value: bool) -> void:
	if value == debug_overlay:
		return
	debug_overlay = value
	debug_overlay_changed.emit(value)


## Add currency to the wallet, broadcast it, and write through to disk.
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)
	_save_wallet()


## Atomic wallet write: save to a temp file, keep the last good save as .bak,
## then swap in. A crash mid-save leaves the old save or the new one - never a
## half-written file.
func _save_wallet() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(save_path):
		# Carry existing sections over so future save data survives the swap.
		config.load(save_path)
	config.set_value(SAVE_SECTION_WALLET, SAVE_KEY_COINS, coins)
	var tmp_path := save_path + ".tmp"
	if config.save(tmp_path) != OK:
		return
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp_path, save_path)


## Defensive load: try the save, then the .bak backup. A garbage or missing
## file just means an empty wallet, never a crash.
func _load_wallet() -> void:
	coins = 0
	var config := ConfigFile.new()
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		if config.load(path) == OK:
			coins = maxi(int(config.get_value(SAVE_SECTION_WALLET, SAVE_KEY_COINS, 0)), 0)
			return


## The best score that matters for the current [member mode].
func best_for_mode(for_mode: int = -1) -> int:
	var which := mode if for_mode < 0 else for_mode
	return best_campaign if which == GameConfig.RunMode.CAMPAIGN else best_endless


## Record a finished score for the current mode. Returns true when it beats the
## previous best (a first run always reports true - callers decide whether
## that counts as a "NEW BEST" celebration).
func report_score(score: int, for_mode: int = -1) -> bool:
	var which := mode if for_mode < 0 else for_mode
	var is_new := score > best_for_mode(which)
	if which == GameConfig.RunMode.CAMPAIGN:
		best_campaign = maxi(best_campaign, score)
	else:
		best_endless = maxi(best_endless, score)
	return is_new
