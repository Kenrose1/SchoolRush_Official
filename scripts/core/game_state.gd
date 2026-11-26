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
const SAVE_SECTION_META := "meta"
const SAVE_KEY_VERSION := "version"
## 1 -> 2: best scores, audio levels, fullscreen and the debug overlay are
## persisted. A v1 save still loads - every new key defaults on read.
const SAVE_VERSION := 2
const SAVE_SECTION_WALLET := "wallet"
const SAVE_KEY_COINS := "coins"
const SAVE_SECTION_SHOP := "shop"
const SAVE_SECTION_BESTS := "bests"
const SAVE_KEY_BEST_CAMPAIGN := "campaign"
const SAVE_KEY_BEST_ENDLESS := "endless"
const SAVE_SECTION_SETTINGS := "settings"
const SAVE_KEY_MASTER := "master"
const SAVE_KEY_MUSIC := "music"
const SAVE_KEY_SFX := "sfx"
const SAVE_KEY_FULLSCREEN := "fullscreen"
const SAVE_KEY_DEBUG := "debug_overlay"

## Audio bus indices, matching default_bus_layout.tres.
const BUS_MASTER := 0
const BUS_MUSIC := 1
const BUS_SFX := 2

## Where the wallet persists. The suite repoints this at a scratch file so
## tests never touch the player's real save.
var save_path: String = SAVE_PATH_DEFAULT

## The persistent coin wallet. Loaded from disk in _ready, written through on
## every pickup so a crash can only ever lose the newest coin.
var coins: int = 0

## Bought upgrade levels (GameConfig.ShopUpgrade -> level), defaulting to 0.
## Persisted in the same save file as the wallet.
var shop_levels: Dictionary = {}

## Saved audio levels, 0-100 per bus. Applied on boot and on every change.
var master_percent: float = 100.0
var music_percent: float = 100.0
var sfx_percent: float = 100.0

## Saved display mode. Restored on boot so a fullscreen player stays
## fullscreen and their volumes survive a restart.
var fullscreen: bool = false


func _ready() -> void:
	_load_wallet()
	_apply_audio_settings()
	_apply_window_mode()


## Flip the debug overlay preference, broadcast it and persist it.
func set_debug_overlay(value: bool) -> void:
	if value == debug_overlay:
		return
	debug_overlay = value
	debug_overlay_changed.emit(value)
	_save_wallet()


## Push every saved bus level onto the mixer.
func _apply_audio_settings() -> void:
	set_bus_percent(BUS_MASTER, master_percent)
	set_bus_percent(BUS_MUSIC, music_percent)
	set_bus_percent(BUS_SFX, sfx_percent)


## Push the saved window mode onto the real window. Headless runs (the suite,
## the visual tools) have no display to switch.
func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED


## A bus's volume as a 0-100 percent.
static func bus_percent(bus: int) -> float:
	var db := AudioServer.get_bus_volume_db(bus)
	if db <= -60.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


## Apply a 0-100 percent level to a bus. Zero also mutes it, so the bottom of
## the slider is an off switch.
static func set_bus_percent(bus: int, percent: float) -> void:
	var clamped := clampf(percent, 0.0, 100.0)
	AudioServer.set_bus_mute(bus, clamped <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(clamped / 100.0, 0.0001)))


## Set one bus level, apply it and write it through to the save.
func set_audio_percent(bus: int, percent: float) -> void:
	var clamped := clampf(percent, 0.0, 100.0)
	match bus:
		BUS_MASTER:
			master_percent = clamped
		BUS_MUSIC:
			music_percent = clamped
		BUS_SFX:
			sfx_percent = clamped
	set_bus_percent(bus, clamped)
	_save_wallet()


## Toggle fullscreen, apply it and write it through to the save.
func set_fullscreen(value: bool) -> void:
	if fullscreen == value:
		return
	fullscreen = value
	_apply_window_mode()
	_save_wallet()


## The current level of an upgrade (0 when never bought).
func shop_level(kind: int) -> int:
	var level := int(shop_levels.get(kind, 0))
	if GameConfig.SHOP_UPGRADES.has(kind):
		return clampi(level, 0, int(GameConfig.SHOP_UPGRADES[kind]["max_level"]))
	return clampi(level, 0, 99)


## Spend coins to raise an upgrade one level. Returns false when the upgrade
## is maxed or the wallet cannot cover the cost - the wallet never changes
## in that case.
func buy_upgrade(kind: int) -> bool:
	if not GameConfig.SHOP_UPGRADES.has(kind):
		return false
	var level := shop_level(kind)
	if level >= int(GameConfig.SHOP_UPGRADES[kind]["max_level"]):
		return false
	var cost := GameConfig.shop_cost(kind, level)
	if coins < cost:
		return false
	coins -= cost
	coins_changed.emit(coins)
	shop_levels[kind] = level + 1
	_save_wallet()
	return true


## Add currency to the wallet, broadcast it, and write through to disk.
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)
	_save_wallet()


## Atomic save write: wallet, shop levels, best scores and settings all go to a
## temp file, the last good save is kept as .bak, then the temp is swapped in.
## A crash mid-save leaves the old save or the new one - never a half-written
## file.
func _save_wallet() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(save_path):
		# Carry existing sections over so future save data survives the swap.
		config.load(save_path)
	config.set_value(SAVE_SECTION_META, SAVE_KEY_VERSION, SAVE_VERSION)
	config.set_value(SAVE_SECTION_WALLET, SAVE_KEY_COINS, coins)
	for kind: int in GameConfig.SHOP_UPGRADES:
		config.set_value(SAVE_SECTION_SHOP, str(kind), shop_level(kind))
	config.set_value(SAVE_SECTION_BESTS, SAVE_KEY_BEST_CAMPAIGN, best_campaign)
	config.set_value(SAVE_SECTION_BESTS, SAVE_KEY_BEST_ENDLESS, best_endless)
	config.set_value(SAVE_SECTION_SETTINGS, SAVE_KEY_MASTER, master_percent)
	config.set_value(SAVE_SECTION_SETTINGS, SAVE_KEY_MUSIC, music_percent)
	config.set_value(SAVE_SECTION_SETTINGS, SAVE_KEY_SFX, sfx_percent)
	config.set_value(SAVE_SECTION_SETTINGS, SAVE_KEY_FULLSCREEN, fullscreen)
	config.set_value(SAVE_SECTION_SETTINGS, SAVE_KEY_DEBUG, debug_overlay)
	var tmp_path := save_path + ".tmp"
	if config.save(tmp_path) != OK:
		return
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, save_path + ".bak")
	DirAccess.rename_absolute(tmp_path, save_path)


## Defensive load: try the save, then the .bak backup. A garbage or missing
## file just means a fresh profile, never a crash. Unknown or out-of-range
## values fall back to their defaults.
func _load_wallet() -> void:
	coins = 0
	shop_levels = {}
	best_campaign = 0
	best_endless = 0
	master_percent = 100.0
	music_percent = 100.0
	sfx_percent = 100.0
	fullscreen = false
	debug_overlay = GameConfig.DEBUG_OVERLAY
	var config := ConfigFile.new()
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		if config.load(path) == OK:
			_migrate(config)
			coins = maxi(int(config.get_value(SAVE_SECTION_WALLET, SAVE_KEY_COINS, 0)), 0)
			for kind: int in GameConfig.SHOP_UPGRADES:
				shop_levels[kind] = clampi(
					int(config.get_value(SAVE_SECTION_SHOP, str(kind), 0)), 0,
					int(GameConfig.SHOP_UPGRADES[kind]["max_level"]))
			best_campaign = maxi(int(config.get_value(
				SAVE_SECTION_BESTS, SAVE_KEY_BEST_CAMPAIGN, 0)), 0)
			best_endless = maxi(int(config.get_value(
				SAVE_SECTION_BESTS, SAVE_KEY_BEST_ENDLESS, 0)), 0)
			master_percent = clampf(float(config.get_value(
				SAVE_SECTION_SETTINGS, SAVE_KEY_MASTER, 100.0)), 0.0, 100.0)
			music_percent = clampf(float(config.get_value(
				SAVE_SECTION_SETTINGS, SAVE_KEY_MUSIC, 100.0)), 0.0, 100.0)
			sfx_percent = clampf(float(config.get_value(
				SAVE_SECTION_SETTINGS, SAVE_KEY_SFX, 100.0)), 0.0, 100.0)
			fullscreen = bool(config.get_value(
				SAVE_SECTION_SETTINGS, SAVE_KEY_FULLSCREEN, false))
			debug_overlay = bool(config.get_value(
				SAVE_SECTION_SETTINGS, SAVE_KEY_DEBUG, GameConfig.DEBUG_OVERLAY))
			return


## Forward an older save to the current format. v1 -> v2 only added keys, and
## every new key defaults on read, so this just stamps the version; later
## migrations can rewrite values here.
func _migrate(config: ConfigFile) -> void:
	var version := int(config.get_value(SAVE_SECTION_META, SAVE_KEY_VERSION, 0))
	if version >= SAVE_VERSION:
		return
	config.set_value(SAVE_SECTION_META, SAVE_KEY_VERSION, SAVE_VERSION)


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
	# Bests persist so the campaign's gold medal and the menu readout survive a
	# restart instead of resetting to nothing every launch.
	_save_wallet()
	return is_new
