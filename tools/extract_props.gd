extends SceneTree
## Dev tool: cuts the item / hazard props out of the concept sheets.
## Run with: godot --headless --path . --script res://tools/extract_props.gd

const ITEM_SHEET := "res://assets/6ce43ad7-3437-4e7e-9c28-0f55c2aba0ae.jpg"
const CHAR_SHEET := "res://assets/7e5eb8f6-b48e-457d-a99c-fb796ffd8391.jpg"
const OUT := "res://assets/sprites/props"

# name, sheet, Rect2i(x, y, w, h)
const CROPS := [
	["item_book", ITEM_SHEET, Rect2i(48, 132, 112, 126)],
	["item_pencil", ITEM_SHEET, Rect2i(548, 142, 136, 118)],
	["item_eraser", ITEM_SHEET, Rect2i(22, 620, 160, 156)],
	["item_bag", ITEM_SHEET, Rect2i(548, 636, 150, 150)],
	["haz_sign", CHAR_SHEET, Rect2i(660, 860, 92, 106)],
	["haz_manhole", CHAR_SHEET, Rect2i(750, 890, 106, 72)],
	["haz_debris", CHAR_SHEET, Rect2i(866, 872, 146, 100)],
]

var _bg := Color(0, 0, 0, 0)
var _cache := {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for crop: Array in CROPS:
		var name: String = crop[0]
		var sheet: String = crop[1]
		var rect: Rect2i = crop[2]
		var img: Image = _cache.get(sheet)
		if img == null:
			img = Image.load_from_file(ProjectSettings.globalize_path(sheet))
			img.convert(Image.FORMAT_RGBA8)
			_cache[sheet] = img
		_bg = img.get_pixel(2, 2)
		var cut := _matte(img, rect)
		_keep_largest(cut)
		cut = cut.get_region(cut.get_used_rect())
		var path := "%s/%s.png" % [OUT, name]
		cut.save_png(ProjectSettings.globalize_path(path))
		print("%s -> %s %s" % [name, cut.get_size(), path])
	quit()


func _is_bg(c: Color) -> bool:
	var d := maxf(absf(c.r - _bg.r), maxf(absf(c.g - _bg.g), absf(c.b - _bg.b)))
	return d < 0.16


func _matte(img: Image, region: Rect2i) -> Image:
	var w := region.size.x
	var h := region.size.y
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var removed := PackedByteArray()
	removed.resize(w * h)
	removed.fill(0)
	var queue: Array[int] = []
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
			var near_bg := maxf(absf(c.r - _bg.r), maxf(absf(c.g - _bg.g), absf(c.b - _bg.b))) < 0.07
			c.a = 0.0 if (removed[i] == 1 or near_bg) else 1.0
			out.set_pixel(x, y, c)
	return _trim(out)


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	return img.get_region(used)


## Erases every opaque island except the biggest one (drops labels and neighbours).
func _keep_largest(img: Image) -> void:
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
