extends SceneTree
## Builds Elias's 12-frame run cycle from the raw JPEG renders.
##
## The renders have no alpha, so the flat backdrop is keyed out with a
## border flood fill (interior darks such as the shorts and shoes are not
## connected to the edge and therefore survive). Every frame shares one crop
## rect, so the character never jitters, and the feet sit on the canvas floor.
##
## Run: godot --headless --path . --script res://tools/build_elias_run.gd

const SOURCE_DIR := "res://assets/characters/elias/"
const SOURCE_FRAMES: Array[String] = [
	"frame1", "frame2jpg", "frame3", "frame4", "frame5", "frame6",
	"frame7", "frame8", "frame9", "frame10", "frame11", "frame12",
]
## Width every frame is normalised to before keying. frame1 ships at half
## resolution, so normalising first keeps all frames in the same pixel space.
const WORK_WIDTH := 688
## Final canvas: the size of the existing Elias sprite frames.
const CANVAS := Vector2i(123, 189)
const MARGIN := 3
## How far a border pixel may drift from the corner colour and still count as
## backdrop. The renders are JPEGs, so the flat grey carries slight noise.
const KEY_TOLERANCE := 0.06


func _initialize() -> void:
	var frames: Array[Image] = []
	for name in SOURCE_FRAMES:
		var path := SOURCE_DIR + name + ".jpg"
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			push_error("could not load " + path)
			quit(1)
			return
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != WORK_WIDTH:
			var height := int(round(float(WORK_WIDTH) * img.get_height() / img.get_width()))
			img.resize(WORK_WIDTH, height, Image.INTERPOLATE_LANCZOS)
		_key_backdrop(img)
		frames.append(img)

	# One crop rect for the whole cycle, so the silhouette cannot jitter.
	var bounds := Rect2i()
	var first := true
	for img in frames:
		var used := img.get_used_rect()
		print("frame bbox=", used)
		if used.size == Vector2i.ZERO:
			push_error("a frame keyed away completely")
			quit(1)
			return
		bounds = used if first else bounds.merge(used)
		first = false

	var scale := minf(
		float(CANVAS.x - MARGIN * 2) / bounds.size.x,
		float(CANVAS.y - MARGIN * 2) / bounds.size.y,
	)
	var target := Vector2i(
		maxi(int(round(bounds.size.x * scale)), 1),
		maxi(int(round(bounds.size.y * scale)), 1),
	)
	print("bounds=", bounds, " scale=%.4f target=%s" % [scale, target])

	for index in frames.size():
		var slice := frames[index].get_region(bounds)
		slice.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(
			slice,
			Rect2i(Vector2i.ZERO, target),
			Vector2i((CANVAS.x - target.x) / 2, CANVAS.y - MARGIN - target.y),
		)
		var out := "%srun_new_%02d.png" % [SOURCE_DIR, index + 1]
		canvas.save_png(ProjectSettings.globalize_path(out))
		print("saved ", out)
	quit(0)


## Flood the flat backdrop from the image border, then drop every opaque speck
## that is not connected to the character, so JPEG noise cannot inflate the
## shared crop rect. Clears everything else to alpha 0.
func _key_backdrop(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var backdrop := img.get_pixel(2, 2)
	var mask := PackedByteArray()
	mask.resize(w * h)
	mask.fill(0)

	var stack := PackedInt32Array()
	for x in w:
		stack.push_back(x)
		stack.push_back((h - 1) * w + x)
	for y in h:
		stack.push_back(y * w)
		stack.push_back(y * w + w - 1)

	while stack.size() > 0:
		var index := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if mask[index] == 1:
			continue
		var x := index % w
		var y := index / w
		if not _is_backdrop(img.get_pixel(x, y), backdrop):
			continue
		mask[index] = 1
		if x > 0 and mask[index - 1] == 0:
			stack.push_back(index - 1)
		if x < w - 1 and mask[index + 1] == 0:
			stack.push_back(index + 1)
		if y > 0 and mask[index - w] == 0:
			stack.push_back(index - w)
		if y < h - 1 and mask[index + w] == 0:
			stack.push_back(index + w)

	var keep := _largest_blob(w, h, mask)
	for index in w * h:
		if mask[index] == 1 or keep[index] == 0:
			var color := img.get_pixel(index % w, index / w)
			img.set_pixel(index % w, index / w, Color(color.r, color.g, color.b, 0.0))


## Mask of the biggest opaque blob: the character. Anything smaller is noise.
func _largest_blob(w: int, h: int, backdrop: PackedByteArray) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var best := PackedByteArray()
	best.resize(w * h)
	best.fill(0)
	var best_size := 0

	for start in w * h:
		if backdrop[start] == 1 or seen[start] == 1:
			continue
		var blob := PackedByteArray()
		blob.resize(w * h)
		blob.fill(0)
		var size := 0
		var stack := PackedInt32Array([start])
		seen[start] = 1
		while stack.size() > 0:
			var index := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			blob[index] = 1
			size += 1
			var x := index % w
			var y := index / w
			for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var next: int = ny * w + nx
				if seen[next] == 1 or backdrop[next] == 1:
					continue
				seen[next] = 1
				stack.push_back(next)
		if size > best_size:
			best_size = size
			best = blob
	return best


func _is_backdrop(color: Color, backdrop: Color) -> bool:
	return (
		absf(color.r - backdrop.r) <= KEY_TOLERANCE
		and absf(color.g - backdrop.g) <= KEY_TOLERANCE
		and absf(color.b - backdrop.b) <= KEY_TOLERANCE
	)
