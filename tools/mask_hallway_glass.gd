extends SceneTree
## Bakes a glass cut-out of the school corridor art.
##
##   godot --headless --path . --script tools/mask_hallway_glass.gd
##   godot --headless --path . --import
##
## The corridor art paints its windows as frosted checker panes, and that opaque
## glass hides the campus panorama drawn behind the corridor. This tool finds the
## glass and clears its alpha, leaving the frames, mullions, posters and notices
## untouched, so the sunny school panorama shows through the windows with its own
## parallax.
##
## Two passes run. The first clears the bright frosted glass of the window bays,
## which is bracketed above and below by the window's blue joinery and is wide
## enough to be a window rather than a pinned piece of paper. The second clears
## the colourless frosted panes the blue test misses - the stairwell window is
## framed by wood, not blue - by looking for wide, bright, grey runs instead. The
## result is written beside the source, so the original art stays intact; re-run
## this after editing the corridor art, then reimport.

const SRC := "res://assets/backgrounds/newschoolhallway.png"
const DST := "res://assets/backgrounds/newschoolhallway_glass.png"
## Rows searched for glass, in source pixels: the whole window band, nothing else
## bright.
const BAND_TOP := 88
const BAND_BOTTOM := 330
const GLASS_VALUE := 0.70
const GLASS_SATURATION := 0.20
## Frosted checker panes that are not framed by blue joinery are almost
## colourless; the cream wall carries yellow and sits above this saturation.
const PANE_VALUE := 0.72
const PANE_SATURATION := 0.12
## A pane's glass run may be interrupted by horizontal mullions this tall.
const RUN_GAP := 6
const MIN_RUN := 9
## How far outside a glass run to look for the window frame.
const FRAME_REACH := 6
## Bounds of the corridor's window joinery colour.
const FRAME_MIN_BLUE := 0.40
const FRAME_MAX_VALUE := 0.85
## A pane must be this wide (in columns sharing its rows); pinned paper is not.
const MIN_PANE_WIDTH := 60
## Columns searched either side when measuring that width.
const WIDTH_REACH := 80

var _cleared := 0
var _panes := 0


func _init() -> void:
	var img := Image.new()
	if img.load(SRC) != OK:
		printerr("cannot read ", SRC)
		quit(1)
		return
	# The source art is RGB with no alpha channel; give it one or the cleared
	# pixels would be written back opaque and the cut-out would be lost.
	img.convert(Image.FORMAT_RGBA8)

	var width := img.get_width()
	# Pass 1: frosted glass inside the window bays (blue joinery above and below).
	var framed_runs := _all_runs(img, width, _is_glass)
	_clear_pass(img, width, framed_runs, _is_glass, true)
	# Pass 2: wide colourless panes the blue test misses (stairwell window).
	var grey_runs := _all_runs(img, width, _is_grey_pane)
	_clear_pass(img, width, grey_runs, _is_grey_pane, false)

	var err := img.save_png(ProjectSettings.globalize_path(DST))
	print("panes=", _panes, " cleared=", _cleared, " err=", err, " -> ", DST)
	quit()


## Clear every run that qualifies as a pane: tall enough, wide enough to be
## glass, and (when [param require_frame]) bracketed by the window's blue joinery.
func _clear_pass(img: Image, width: int, runs: Array, test: Callable,
		require_frame: bool) -> void:
	for x in width:
		for run: Vector2i in runs[x]:
			var a := run.x
			var b := run.y
			if b - a < MIN_RUN:
				continue
			if require_frame and not _framed(img, x, a, b):
				continue
			if not _is_wide(runs, x, a, b):
				continue
			_panes += 1
			for y in range(a, b + 1):
				if test.call(img.get_pixel(x, y)):
					img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
					_cleared += 1


## Per column, every run of pixels passing [param test], split where the gap
## exceeds RUN_GAP. Every pane in a column is returned, so upper transoms clear
## together with the main pane instead of one of them staying frosted.
func _all_runs(img: Image, width: int, test: Callable) -> Array:
	var runs: Array = []
	runs.resize(width)
	for x in width:
		var column: Array = []
		var start := -1
		var previous := -1000
		for y in range(BAND_TOP, BAND_BOTTOM):
			if test.call(img.get_pixel(x, y)):
				if start < 0:
					start = y
				elif y - previous > RUN_GAP:
					column.append(Vector2i(start, previous))
					start = y
				previous = y
		if start >= 0:
			column.append(Vector2i(start, previous))
		runs[x] = column
	return runs


## Whether enough neighbouring columns share these rows to be a window pane.
func _is_wide(runs: Array, x: int, a: int, b: int) -> bool:
	var shared := 0
	var from := maxi(x - WIDTH_REACH, 0)
	var to := mini(x + WIDTH_REACH, runs.size() - 1)
	for other in range(from, to + 1):
		for peer: Vector2i in runs[other]:
			if peer.x <= b and peer.y >= a:
				shared += 1
				break
	return shared >= MIN_PANE_WIDTH


## Frosted panes are bright and almost grey; frames, locks and posters are not.
func _is_glass(color: Color) -> bool:
	return color.v >= GLASS_VALUE and color.s <= GLASS_SATURATION


## Colourless frosted pane, used to catch the glass the blue-frame test misses.
func _is_grey_pane(color: Color) -> bool:
	return color.v >= PANE_VALUE and color.s <= PANE_SATURATION


## Window joinery: a darker, clearly blue pixel. A plain "is it blue-ish" test
## also matched the soft blue shadow under pinned paper, and the bulletin board's
## teal margin, both of which cut holes in the wall.
func _is_frame(color: Color) -> bool:
	return (color.b >= FRAME_MIN_BLUE and color.v <= FRAME_MAX_VALUE
		and color.b > color.r * 1.45 and color.b > color.g * 1.25)


## Whether a glass run has window frame within a few rows on both sides.
func _framed(img: Image, x: int, from_y: int, to_y: int) -> bool:
	var above := false
	for step in range(1, FRAME_REACH + 1):
		var row := from_y - step
		if row < 0:
			break
		if _is_frame(img.get_pixel(x, row)):
			above = true
			break
	var below := false
	for step in range(1, FRAME_REACH + 1):
		var row := to_y + step
		if row >= img.get_height():
			break
		if _is_frame(img.get_pixel(x, row)):
			below = true
			break
	return above and below
