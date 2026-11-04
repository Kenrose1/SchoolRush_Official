class_name Pal
## Shared colours and per-zone colour scripts, sampled from the concept sheets.

const INK := Color("07101d")
const NAVY := Color("0b1a2e")
const NAVY_SOFT := Color("13304d")
const WHITE := Color("eaf2fb")
const MUTED := Color("90a9c4")
const GREEN := Color("1f8a5c")
const GREEN_DARK := Color("11523a")
const GREEN_LIGHT := Color("49c98a")
const YELLOW := Color("f5c542")
const ORANGE := Color("e08a3c")
const RED := Color("e05a4f")
const CREAM := Color("f2e2bc")
const SKIN := Color("e7b48c")

## Each zone paints the lane strips; the panorama itself comes from the art in
## res://assets/backgrounds.
const ZONES: Array[Dictionary] = [
	{
		"name": "HOME",
		"title": "6:58 AM // BEDROOM DASH",
		"path": Color("3d3352"),
		"accent": Color("f5c542"),
	},
	{
		"name": "STREET",
		"title": "7:20 AM // BARANGAY STREET",
		"path": Color("2f4157"),
		"accent": Color("49c98a"),
	},
	{
		"name": "SCHOOL",
		"title": "7:52 AM // CAMPUS RUN",
		"path": Color("2b4a3d"),
		"accent": Color("f2e2bc"),
	},
]

## Lane baselines (where the feet of a runner touch down).
const LANE_Y: Array[float] = [620.0, 800.0, 980.0]
const LANE_X := 560.0


static func zone_colors(index: int) -> Dictionary:
	# Duplicated so callers can lerp their own copy of the palette.
	return ZONES[clampi(index, 0, ZONES.size() - 1)].duplicate()
