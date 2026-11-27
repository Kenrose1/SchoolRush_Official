extends SceneTree
## Sinks the barrier's far post so its base sits on the road line, then trims
## the sheet to its used rect. One-off build step for the angled barrier art.

const SOURCE := "res://assets/hazards/haz_barricade.png"
## The far post is a straight shaft from here down to its disc.
const SHAFT_TOP := 440
const SHAFT_BOTTOM := 512
const SHAFT_LEFT := 340
const SHAFT_RIGHT := 444
const DISC_TOP := 512
const DISC_BOTTOM := 665
const DISC_LEFT := 270
const DISC_RIGHT := 515
## Rows the far base has to drop to reach the near base's ground line.
const SINK := 310


func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		print("missing source")
		quit(1)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var size := image.get_size()
	print("in %s" % size)

	var shaft := image.get_region(Rect2i(
		SHAFT_LEFT, SHAFT_TOP, SHAFT_RIGHT - SHAFT_LEFT, SHAFT_BOTTOM - SHAFT_TOP))
	var disc := image.get_region(Rect2i(
		DISC_LEFT, DISC_TOP, DISC_RIGHT - DISC_LEFT, DISC_BOTTOM - DISC_TOP))

	# Clear the old shaft tail and disc, then rebuild them lower: the shaft is
	# stretched (it is a straight bar, so a vertical stretch keeps its shading)
	# and the disc keeps its shape at the new ground line.
	image.fill_rect(Rect2i(
		DISC_LEFT, DISC_TOP, DISC_RIGHT - DISC_LEFT, DISC_BOTTOM - DISC_TOP),
		Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(
		SHAFT_LEFT, SHAFT_TOP, SHAFT_RIGHT - SHAFT_LEFT, DISC_BOTTOM - SHAFT_TOP),
		Color(0, 0, 0, 0))

	shaft.resize(shaft.get_width(), shaft.get_height() + SINK, Image.INTERPOLATE_NEAREST)
	image.blit_rect(shaft, Rect2i(Vector2i.ZERO, shaft.get_size()),
		Vector2i(SHAFT_LEFT, SHAFT_TOP))
	image.blit_rect(disc, Rect2i(Vector2i.ZERO, disc.get_size()),
		Vector2i(DISC_LEFT, DISC_TOP + SINK))

	var used := image.get_used_rect()
	print("used after sink %s" % used)
	var cropped := image.get_region(used)
	print("out %s" % cropped.get_size())
	print("save err=%d" % cropped.save_png(ProjectSettings.globalize_path(SOURCE)))
	# Ground lines and beam underside, measured from the new bottom edge.
	var bottom := used.position.y + used.size.y
	for col in [420, 620, 900, 1080]:
		var last := -1
		for y in cropped.get_height():
			if cropped.get_pixel(col, y).a > 0.35:
				last = y
		print("col %d lowest opaque=%d => %.1f px above bottom at scale 0.22" % [
			col, last, float(cropped.get_height() - last) * 0.22])
	print("bottom row source y=%d" % bottom)
	quit(0)
