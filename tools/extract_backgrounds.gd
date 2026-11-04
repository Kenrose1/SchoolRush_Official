extends SceneTree
## Dev tool: crops the three zone panoramas out of the painted background sheet
## and writes them as looping strips in res://assets/backgrounds/.
##   godot --headless --path . --script res://tools/extract_backgrounds.gd

const SHEET := "res://assets/326eb1f4-293d-4bfe-8033-407ab0131a36.jpg"
const OUT_DIR := "res://assets/backgrounds"
const NAMES := ["zone_home", "zone_street", "zone_school"]
const MARGIN := 8
const COVERAGE := 0.5
const DELTA := 0.05


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if sheet == null:
		push_error("cannot read " + SHEET)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var bg := sheet.get_pixel(2, 2)
	var bands := _bands(sheet, bg)
	print("sheet %s  bands %d" % [sheet.get_size(), bands.size()])

	# Every zone gets the same canvas height, anchored on its floor, so the
	# strips can share one scale and line up with the course.
	var rects: Array[Rect2i] = []
	var common := 99999
	for band: Vector2i in bands:
		var span := _x_span(sheet, bg, band)
		if span.x >= span.y:
			continue
		var rect := Rect2i(span.x + MARGIN, band.x + MARGIN,
			(span.y - span.x + 1) - MARGIN * 2, (band.y - band.x + 1) - MARGIN * 2)
		rects.append(rect)
		common = mini(common, rect.size.y)

	for i in rects.size():
		var rect := rects[i]
		rect.position.y += rect.size.y - common
		rect.size.y = common
		var name: String = NAMES[i] if i < NAMES.size() else "zone_%d" % i
		var crop := sheet.get_region(rect)
		var path := "%s/%s.png" % [OUT_DIR, name]
		crop.save_png(ProjectSettings.globalize_path(path))
		print("  %s  crop %s" % [name, rect])
	quit()


func _bands(sheet: Image, bg: Color) -> Array[Vector2i]:
	var w := sheet.get_width()
	var h := sheet.get_height()
	var step := 4
	var total := w / step
	var out: Array[Vector2i] = []
	var start := -1
	for y in h:
		var covered := 0
		for x in range(0, w, step):
			if _delta(sheet.get_pixel(x, y), bg) > DELTA:
				covered += 1
		var is_art := float(covered) / float(total) > COVERAGE
		if is_art and start < 0:
			start = y
		elif not is_art and start >= 0:
			out.append(Vector2i(start, y - 1))
			start = -1
	if start >= 0:
		out.append(Vector2i(start, h - 1))
	var kept: Array[Vector2i] = []
	for run in out:
		if run.y - run.x >= 45:
			kept.append(run)
	return kept


func _x_span(sheet: Image, bg: Color, band: Vector2i) -> Vector2i:
	var w := sheet.get_width()
	var rows := band.y - band.x + 1
	var step := maxi(1, rows / 40)
	var left := -1
	var right := -1
	for x in w:
		var covered := 0
		for y in range(band.x, band.y + 1, step):
			if _delta(sheet.get_pixel(x, y), bg) > DELTA:
				covered += 1
		if covered > 3:
			if left < 0:
				left = x
			right = x
	return Vector2i(maxi(0, left), mini(w - 1, right))


func _delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
