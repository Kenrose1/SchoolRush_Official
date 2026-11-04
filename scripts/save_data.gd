extends Node
## Local persistence: high scores live in user://save.cfg (GDD section 08).

const SAVE_PATH := "user://save.cfg"

var best_campaign := 0
var best_endless := 0
var best_distance := 0
var best_combo := 1
var runs := 0


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_campaign = int(cfg.get_value("scores", "campaign", 0))
	best_endless = int(cfg.get_value("scores", "endless", 0))
	best_distance = int(cfg.get_value("scores", "distance", 0))
	best_combo = int(cfg.get_value("scores", "combo", 1))
	runs = int(cfg.get_value("scores", "runs", 0))


func best_for(mode: String) -> int:
	match mode:
		"campaign":
			return best_campaign
		"endless":
			return best_endless
		_:
			return 0


## Stores a finished run and returns true when it beat the old record.
func submit_run(mode: String, score: int, distance_m: int, combo: int) -> bool:
	var is_record := false
	match mode:
		"campaign":
			if score > best_campaign:
				best_campaign = score
				is_record = true
		"endless":
			if score > best_endless:
				best_endless = score
				is_record = true
	best_distance = maxi(best_distance, distance_m)
	best_combo = maxi(best_combo, combo)
	runs += 1
	save_data()
	return is_record


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "campaign", best_campaign)
	cfg.set_value("scores", "endless", best_endless)
	cfg.set_value("scores", "distance", best_distance)
	cfg.set_value("scores", "combo", best_combo)
	cfg.set_value("scores", "runs", runs)
	cfg.save(SAVE_PATH)
