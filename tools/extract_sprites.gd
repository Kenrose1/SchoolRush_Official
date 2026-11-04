extends SceneTree
## Dev tool: slices character frames out of the concept sheets, keys out the
## flat navy background and writes transparent PNGs into res://assets/sprites/.
## Run with: godot --headless --path . --script res://tools/extract_sprites.gd

const ELIAS_SHEET := "res://assets/6720bca8-a440-4168-b4b0-4475094daa35.png"
const GUARD_SHEET := "res://assets/8bdad4a4-bb2a-43f9-a8dd-228e78ceb7af.png"
const OUT_ROOT := "res://assets/sprites"

# Panel regions (x, y, w, h) inside the sheets.
const REGIONS := {
	"elias": {
		"idle": Rect2i(20, 512, 450, 244),
		"run": Rect2i(478, 512, 772, 244),
		"jump": Rect2i(20, 766, 440, 238),
		"slide": Rect2i(478, 766, 428, 238),
		"hurt": Rect2i(20, 1014, 456, 232),
	},
	"guard": {
		"idle": Rect2i(20, 512, 450, 244),
		"run": Rect2i(478, 512, 772, 244),
	},
}

var _bg := Color(0, 0, 0, 0)


func _initialize() -> void:
	for job: Array in [[ELIAS_SHEET, "elias"], [GUARD_SHEET, "guard"]]:
		_slice_sheet(String(job[0]), String(job[1]))
	print("extract: done")
	quit()


func _slice_sheet(sheet_path: String, sheet_name: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(sheet_path))
	if img == null:
		push_error("cannot load " + sheet_path)
		return
	img.convert(Image.FORMAT_RGBA8)
	_bg = img.get_pixel(2, 2)
	print("sheet %s bg=%s" % [sheet_name, _bg])

	# Collect every frame first so the whole character can share one canvas.
	var collected := {}
	var canvas := Vector2i(1, 1)
	for anim_name: String in REGIONS[sheet_name]:
		var region: Rect2i = REGIONS[sheet_name][anim_name]
		var cutout := _matte(img, region)
		var frames := _find_blobs(cutout)
		var images: Array[Image] = []
		for box: Rect2i in frames:
			var cut := _cut(cutout, box, 2)
			images.append(cut)
			canvas.x = maxi(canvas.x, cut.get_width())
			canvas.y = maxi(canvas.y, cut.get_height())
		collected[anim_name] = images
		print("  %s.%s -> %d frames" % [sheet_name, anim_name, frames.size()])

	# Uniform, bottom-centred frames keep AnimatedSprite2D aligned in the editor.
	var dir := "%s/%s" % [OUT_ROOT, sheet_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for anim_name: String in collected:
		var images: Array = collected[anim_name]
		for i in images.size():
			var frame: Image = images[i]
			var padded := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
			padded.fill(Color(0, 0, 0, 0))
			var offset := Vector2i(
				(canvas.x - frame.get_width()) / 2,
				canvas.y - frame.get_height(),
			)
			padded.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), offset)
			padded.save_png(ProjectSettings.globalize_path("%s/%s_%d.png" % [dir, anim_name, i]))
	print("  sheet canvas %s" % canvas)


func _is_bg(c: Color) -> bool:
	var d := maxf(absf(c.r - _bg.r), maxf(absf(c.g - _bg.g), absf(c.b - _bg.b)))
	return d < 0.12


## Returns the region with the background flooded out to full transparency.
func _matte(img: Image, region: Rect2i) -> Image:
	var w := region.size.x
	var h := region.size.y
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var removed := PackedByteArray()
	removed.resize(w * h)
	removed.fill(0)
	var queue: Array[int] = []
	# Seed the flood from every bg-like pixel on the region border.
	for x in w:
		for y: int in [0, h - 1]:
			var i := y * w + x
			if removed[i] == 0 and _is_bg(img.get_pixel(region.position.x + x, region.position.y + y)):
				removed[i] = 1
				queue.push_back(i)
	for y in h:
		for x: int in [0, w - 1]:
			var i := y * w + x
			if removed[i] == 0 and _is_bg(img.get_pixel(region.position.x + x, region.position.y + y)):
				removed[i] = 1
				queue.push_back(i)
	while not queue.is_empty():
		var idx: int = queue.pop_back()
		var px := idx % w
		var py := idx / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := px + d.x
			var ny := py + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var nidx := ny * w + nx
			if removed[nidx] == 1:
				continue
			if _is_bg(img.get_pixel(region.position.x + nx, region.position.y + ny)):
				removed[nidx] = 1
				queue.push_back(nidx)
	for y in h:
		for x in w:
			var c := img.get_pixel(region.position.x + x, region.position.y + y)
			var i := y * w + x
			var near_bg := maxf(absf(c.r - _bg.r), maxf(absf(c.g - _bg.g), absf(c.b - _bg.b))) < 0.045
			if removed[i] == 1 or near_bg:
				c.a = 0.0
			else:
				c.a = 1.0
			out.set_pixel(x, y, c)
	return out


func _find_blobs(img: Image) -> Array[Rect2i]:
	var w := img.get_width()
	var h := img.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			mask[y * w + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes: Array[Rect2i] = []
	var stack: Array[int] = []
	for start in w * h:
		if mask[start] == 0 or seen[start] == 1:
			continue
		seen[start] = 1
		stack.clear()
		stack.push_back(start)
		var minx := w
		var maxx := 0
		var miny := h
		var maxy := 0
		var count := 0
		var blob := PackedByteArray()
		while not stack.is_empty():
			var idx: int = stack.pop_back()
			blob.push_back(idx)
			var px := idx % w
			var py := idx / w
			count += 1
			minx = mini(minx, px)
			maxx = maxi(maxx, px)
			miny = mini(miny, py)
			maxy = maxi(maxy, py)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := px + d.x
				var ny := py + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nidx := ny * w + nx
				if mask[nidx] == 1 and seen[nidx] == 0:
					seen[nidx] = 1
					stack.push_back(nidx)
		var bw := maxx - minx + 1
		var bh := maxy - miny + 1
		if count < 900 or bw < 45 or bw > 300 or bh < 60 or bh > 300:
			continue
		if float(count) / float(bw * bh) < 0.08:
			continue
		var blob_mask := PackedByteArray()
		blob_mask.resize(w * h)
		blob_mask.fill(0)
		for idx: int in blob:
			blob_mask[idx] = 1
		boxes.append(Rect2i(minx, miny, bw, bh))
	boxes.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	return boxes


func _cut(img: Image, box: Rect2i, pad: int) -> Image:
	var w := img.get_width()
	var x0 := maxi(0, box.position.x - pad)
	var y0 := maxi(0, box.position.y - pad)
	var x1 := mini(w, box.position.x + box.size.x + pad)
	var y1 := mini(img.get_height(), box.position.y + box.size.y + pad)
	var out := img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	out.convert(Image.FORMAT_RGBA8)
	_keep_largest_blob(out)
	return out


## Erases every opaque island except the biggest one (kills neighbour slivers).
func _keep_largest_blob(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-1)
	var sizes: Array[int] = []
	var stack: Array[Vector2i] = []
	for sy in h:
		for sx in w:
			if labels[sy * w + sx] != -1 or img.get_pixel(sx, sy).a <= 0.5:
				continue
			var id := sizes.size()
			sizes.append(0)
			stack.clear()
			stack.push_back(Vector2i(sx, sy))
			labels[sy * w + sx] = id
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				sizes[id] += 1
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := p.x + d.x
					var ny := p.y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if labels[ny * w + nx] != -1 or img.get_pixel(nx, ny).a <= 0.5:
						continue
					labels[ny * w + nx] = id
					stack.push_back(Vector2i(nx, ny))
	var best := -1
	var best_size := 0
	for id in sizes.size():
		if sizes[id] > best_size:
			best_size = sizes[id]
			best = id
	for y in h:
		for x in w:
			if labels[y * w + x] == best:
				continue
			var c := img.get_pixel(x, y)
			c.a = 0.0
			img.set_pixel(x, y, c)
