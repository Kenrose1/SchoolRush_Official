extends Node
## Session state shared across scene changes: the selected run mode and the
## per-mode best scores.
##
## The menu writes [member mode] before starting a run; RunWorld reads it in
## _ready and ResultsScreen reports finished scores back here. Bests are
## session-only for now - they reset when the app closes. A save file would
## slot in here without touching any caller.

## Which rules the next run plays by (GameConfig.RunMode).
var mode: int = GameConfig.RunMode.CAMPAIGN

## Best final score per mode, updated by ResultsScreen when a run ends.
var best_campaign: int = 0
var best_endless: int = 0


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
