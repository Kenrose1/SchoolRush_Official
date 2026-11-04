extends SceneTree
## Dev tool: scaffolds the UI textures and every editable scene in res://scenes/.
## WARNING: running this overwrites those scene files, so only use it to
## re-scaffold. Edit the .tscn files directly for normal changes.
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_scenes.gd -- --phase=scenes

const UI_DIR := "res://assets/ui"
const PROP_DIR := "res://assets/sprites/props"
const WORLD_DIR := "res://assets/world"
const BG_DIR := "res://assets/backgrounds"
const SCENE_DIR := "res://scenes"
const FONT_OUTLINE := 10
## Zone panorama strips are drawn this tall; the sprite scale follows.
const BAND_HEIGHT := 470.0
const LANE_LIFT := -46.0
const GROUND_TOP := 470.0

var _root: Node


func _initialize() -> void:
	var phase := "scenes"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UI_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	if phase == "textures":
		_build_textures()
		print("build_scenes: textures written")
	else:
		_build_spritesheets()
		_build_background()
		_build_track()
		_build_course()
		_build_player()
		_build_pursuer()
		_build_obstacles()
		_build_pickup()
		_build_hud()
		_build_title()
		_build_pause()
		_build_result()
		_build_game()
		_build_main()
		print("build_scenes: scenes written")
	quit()


# --- textures --------------------------------------------------------------

func _build_textures() -> void:
	_write_heart()
	_write_glow()
	_write_vignette()
	_write_gantry()
	_write_lane_tile()
	_write_ground()
	_write_fade()


func _image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _save_image(img: Image, name: String, dir := UI_DIR) -> void:
	img.save_png(ProjectSettings.globalize_path("%s/%s" % [dir, name]))
	print("  texture %s/%s %s" % [dir, name, img.get_size()])


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, color)


func _fill_circle(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	for py in range(int(cy - radius), int(cy + radius) + 1):
		for px in range(int(cx - radius), int(cx + radius) + 1):
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			if Vector2(px + 0.5, py + 0.5).distance_to(Vector2(cx, cy)) <= radius:
				img.set_pixel(px, py, color)


func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := int(minf(a.x, minf(b.x, c.x)))
	var max_x := int(maxf(a.x, maxf(b.x, c.x)))
	var min_y := int(minf(a.y, minf(b.y, c.y)))
	var max_y := int(maxf(a.y, maxf(b.y, c.y)))
	for py in range(maxi(0, min_y), mini(img.get_height(), max_y + 1)):
		for px in range(maxi(0, min_x), mini(img.get_width(), max_x + 1)):
			var p := Vector2(px + 0.5, py + 0.5)
			var d1 := (p - a).cross(b - a)
			var d2 := (p - b).cross(c - b)
			var d3 := (p - c).cross(a - c)
			var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (has_neg and has_pos):
				img.set_pixel(px, py, color)


func _write_heart() -> void:
	var img := _image(48, 48)
	_fill_circle(img, 17.0, 18.0, 11.5, Color.WHITE)
	_fill_circle(img, 31.0, 18.0, 11.5, Color.WHITE)
	_fill_triangle(img, Vector2(5, 20), Vector2(43, 20), Vector2(24, 44), Color.WHITE)
	_save_image(img, "heart.png")


func _write_glow() -> void:
	var img := _image(128, 128)
	for y in 128:
		for x in 128:
			var d := Vector2(x + 0.5 - 64.0, y + 0.5 - 64.0).length() / 64.0
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.0) * 0.55
			img.set_pixel(x, y, Color(0.30, 0.78, 0.55, a))
	_save_image(img, "glow.png")


func _write_vignette() -> void:
	var w := 480
	var h := 270
	var img := _image(w, h)
	var center := Vector2(w * 0.5, h * 0.5)
	var outer := center.length()
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / outer
			var a := pow(clampf((d - 0.5) / 0.5, 0.0, 1.0), 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_save_image(img, "vignette.png")


func _write_gantry() -> void:
	var w := 232
	var h := 212
	var img := _image(w, h)
	var beam := Rect2i(0, 0, w, 64)
	# Legs and feet.
	_fill_rect(img, 0, 0, 15, h, Color("39485c"))
	_fill_rect(img, w - 15, 0, 15, h, Color("39485c"))
	_fill_rect(img, 0, h - 12, 38, 12, Color("2b3646"))
	_fill_rect(img, w - 38, h - 12, 38, 12, Color("2b3646"))
	_fill_rect(img, 0, 42, 15, 6, Color("2b3646"))
	_fill_rect(img, w - 15, 42, 15, 6, Color("2b3646"))
	# Striped beam.
	var stripes := 0
	while stripes * 34 < w:
		var color := Pal.YELLOW if stripes % 2 == 0 else Color("161b24")
		_fill_rect(img, stripes * 34, 0, 33, 64, color)
		stripes += 1
	_fill_rect(img, 0, 0, w, 6, Pal.INK)
	_fill_rect(img, 0, 58, w, 6, Pal.INK)
	# Hanging sign.
	_fill_rect(img, 78, 64, 76, 46, Pal.YELLOW.darkened(0.05))
	_fill_rect(img, 86, 73, 60, 6, Pal.INK)
	_fill_rect(img, 86, 84, 40, 6, Pal.INK)
	_fill_rect(img, 78, 64, 76, 4, Pal.INK)
	_save_image(img, "haz_gantry.png", PROP_DIR)


func _write_lane_tile() -> void:
	var w := 1920
	var h := 132
	var img := _image(w, h)
	# Values below one are tints of the zone colour; the tile only encodes light.
	for x in w:
		for y in h:
			var value := 0.90
			if y < 5:
				value = 1.0
			elif y >= 121:
				value = 0.36
			elif y >= 111:
				value = 0.62
			img.set_pixel(x, y, Color(value, value, value, 1.0))
	var dash := 0
	while dash < w:
		_fill_rect(img, dash, 32, 54, 8, Color(1, 1, 1, 1))
		dash += 200
	var hatch := 10
	while hatch < w:
		_fill_rect(img, hatch, 60, 20, 3, Color(0.94, 0.94, 0.94, 1))
		hatch += 44
	_save_image(img, "lane_tile.png", WORLD_DIR)


func _write_ground() -> void:
	# One row per height, then stretched: the gradient only runs vertically.
	var h := int(1080.0 - GROUND_TOP)
	var strip := _image(1, h)
	var top := Color("0a1220")
	var mid := Color("182a40")
	var bottom := Color("0b1524")
	for y in h:
		var t := float(y) / float(h - 1)
		var col := top.lerp(mid, clampf(t / 0.45, 0.0, 1.0)) if t < 0.45 else mid.lerp(bottom, clampf((t - 0.45) / 0.55, 0.0, 1.0))
		strip.set_pixel(0, y, col)
	strip.resize(1920, h, Image.INTERPOLATE_NEAREST)
	_save_image(strip, "ground.png", WORLD_DIR)


func _write_fade() -> void:
	# Dissolves the painted strip's floor into the exact colour of the ground's
	# top row, so the join has no hard line.
	var h := 241
	var strip := _image(1, h)
	for y in h:
		var a := pow(float(y) / float(h - 1), 1.3)
		strip.set_pixel(0, y, Color(0.039, 0.071, 0.125, a))
	strip.resize(1920, h, Image.INTERPOLATE_NEAREST)
	_save_image(strip, "fade_down.png", WORLD_DIR)


# --- resources & helpers ---------------------------------------------------

func _sprite_frames(character: String, anims: Array) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for spec: Array in anims:
		var anim_name: String = spec[0]
		var count: int = spec[1]
		var speed: float = spec[2]
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, speed)
		for i in count:
			var path := "res://assets/sprites/%s/%s_%d.png" % [character, anim_name, i]
			var texture := load(path) as Texture2D
			if texture == null:
				push_warning("missing frame " + path)
				continue
			frames.add_frame(anim_name, texture, 1.0)
	return frames


func _build_spritesheets() -> void:
	var elias := _sprite_frames("elias", [
		["idle", 4, 6.0], ["run", 7, 13.0], ["jump", 3, 6.0], ["slide", 4, 11.0], ["hurt", 4, 9.0],
	])
	var guard := _sprite_frames("guard", [["idle", 4, 6.0], ["run", 8, 14.0]])
	ResourceSaver.save(elias, "res://assets/sprites/elias_frames.tres")
	ResourceSaver.save(guard, "res://assets/sprites/guard_frames.tres")
	print("  spritesheets written")


func _new_root(type: String, name: String, script_path := "") -> Node:
	var node: Node
	match type:
		"Node2D":
			node = Node2D.new()
		"Control":
			node = Control.new()
		"CanvasLayer":
			node = CanvasLayer.new()
		_:
			node = Node.new()
	node.name = name
	if script_path != "":
		node.set_script(load(script_path))
	return node


func _add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = _root
	return child


func _save(path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		push_error("pack failed for " + path)
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save failed for %s (%d)" % [path, err])
		return
	print("  scene %s" % path)


func _texture_size(path: String) -> Vector2:
	var texture := load(path) as Texture2D
	return texture.get_size() if texture != null else Vector2(100, 100)


func _label(parent: Node, name: String, text: String, pos: Vector2, box: Vector2, font_size: int,
		color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.position = pos
	label.size = box
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", FONT_OUTLINE)
	label.add_theme_color_override("font_outline_color", Pal.INK)
	_add(parent, label)
	return label


func _style(color: Color, border_color: Color, border := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border)
	style.set_corner_radius_all(4)
	return style


func _button(parent: Node, name: String, text: String, pos: Vector2, box: Vector2, primary := false) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.position = pos
	button.size = box
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Pal.WHITE)
	button.add_theme_color_override("font_hover_color", Pal.INK)
	button.add_theme_color_override("font_pressed_color", Pal.INK)
	button.add_theme_color_override("font_focus_color", Pal.INK)
	var base := Pal.GREEN if primary else Pal.NAVY_SOFT
	button.add_theme_stylebox_override("normal", _style(base, Pal.WHITE))
	button.add_theme_stylebox_override("hover", _style(Pal.YELLOW, Pal.WHITE))
	button.add_theme_stylebox_override("pressed", _style(Pal.YELLOW.darkened(0.15), Pal.WHITE))
	button.add_theme_stylebox_override("focus", _style(Pal.YELLOW, Pal.WHITE))
	_add(parent, button)
	return button


func _bar(parent: Node, name: String, pos: Vector2, box: Vector2, fill: Color, bg := Color(0.03, 0.07, 0.12, 0.85)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name
	bar.position = pos
	bar.size = box
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 0.0
	bar.add_theme_stylebox_override("background", _style(bg, Pal.NAVY_SOFT, 2))
	bar.add_theme_stylebox_override("fill", _style(fill, fill, 0))
	_add(parent, bar)
	return bar


func _background(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Background"
	rect.color = Pal.NAVY
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(parent, rect)
	return rect


# --- world scenes ----------------------------------------------------------

func _build_background() -> void:
	_root = _new_root("Node2D", "Background", "res://scripts/background.gd")
	var textures: Array[Texture2D] = []
	for name in ["zone_home", "zone_street", "zone_school"]:
		textures.append(load("%s/%s.png" % [BG_DIR, name]))
	_root.set("zone_textures", textures)
	_root.set("band_height", BAND_HEIGHT)
	_root.set("zone", 0)
	var scale_factor := BAND_HEIGHT / float(textures[0].get_height())
	var width := textures[0].get_width() * scale_factor
	for i in 2:
		var band := Sprite2D.new()
		band.name = "BandA" if i == 0 else "BandB"
		band.texture = textures[0]
		band.centered = false
		band.scale = Vector2(scale_factor, scale_factor)
		band.position = Vector2(width * i, 0)
		_add(_root, band)
	var fade := Sprite2D.new()
	fade.name = "Fade"
	fade.texture = load("%s/fade_down.png" % WORLD_DIR)
	fade.centered = false
	fade.position = Vector2(0, BAND_HEIGHT - fade.texture.get_height())
	fade.z_index = 1
	_add(_root, fade)
	_root.z_index = -40
	_save("res://scenes/background.tscn")


func _build_track() -> void:
	_root = _new_root("Node2D", "LaneTrack", "res://scripts/lane_track.gd")
	var tile := load("%s/lane_tile.png" % WORLD_DIR) as Texture2D
	for i in 2:
		var sprite := Sprite2D.new()
		sprite.name = "TileA" if i == 0 else "TileB"
		sprite.texture = tile
		sprite.centered = false
		sprite.position = Vector2(tile.get_width() * i, 0)
		_add(_root, sprite)
	_save("res://scenes/lane_track.tscn")


func _build_course() -> void:
	_root = _new_root("Node2D", "Course", "res://scripts/course.gd")
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = load("%s/ground.png" % WORLD_DIR)
	ground.centered = false
	ground.position = Vector2(0, GROUND_TOP)
	# Sits under the strips even though it is the first child.
	ground.z_index = -1
	_add(_root, ground)

	var shades := [0.8, 1.0, 1.16]
	for lane in 3:
		var track := (load("res://scenes/lane_track.tscn") as PackedScene).instantiate() as LaneTrack
		track.name = "Track%d" % lane
		track.lane = lane
		track.shade = shades[lane]
		track.position = Vector2(0, Pal.LANE_Y[lane] + LANE_LIFT)
		_add(_root, track)
	_root.set("lane_heights", Pal.LANE_Y)
	_root.set("active_lane", 1)
	_root.z_index = -20
	_save("res://scenes/course.tscn")


# --- gameplay scenes -------------------------------------------------------

func _build_player() -> void:
	_root = _new_root("Node2D", "Player", "res://scripts/player.gd")
	var frames := load("res://assets/sprites/elias_frames.tres") as SpriteFrames
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.animation = "run"
	sprite.autoplay = "run"
	sprite.centered = true
	sprite.scale = Vector2(1.15, 1.15)
	var size := _texture_size("res://assets/sprites/elias/run_0.png")
	sprite.offset = Vector2(0, -size.y * 0.5)
	_add(_root, sprite)
	_root.position = Vector2(560, 800)
	_root.z_index = 5
	_save("res://scenes/player.tscn")


func _build_pursuer() -> void:
	_root = _new_root("Node2D", "Pursuer", "res://scripts/pursuer.gd")
	var frames := load("res://assets/sprites/guard_frames.tres") as SpriteFrames
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.animation = "run"
	sprite.autoplay = "run"
	sprite.scale = Vector2(1.2, 1.2)
	var size := _texture_size("res://assets/sprites/guard/run_0.png")
	sprite.offset = Vector2(0, -size.y * 0.5)
	_add(_root, sprite)
	_root.z_index = -1
	_root.position = Vector2(320, 800)
	_save("res://scenes/pursuer.tscn")


func _build_obstacles() -> void:
	for prop in ["sign", "manhole", "debris"]:
		_root = _new_root("Node2D", "Obstacle_" + prop, "res://scripts/obstacle.gd")
		_root.set("kind", "jump")
		var texture_path := "%s/haz_%s.png" % [PROP_DIR, prop]
		var size := _texture_size(texture_path)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(texture_path)
		sprite.centered = true
		sprite.offset = Vector2(0, -size.y * 0.5)
		_add(_root, sprite)
		_root.z_index = 2
		_root.position = Vector2(900, 800)
		_save("res://scenes/obstacle_%s.tscn" % prop)

	_root = _new_root("Node2D", "Obstacle_slide", "res://scripts/obstacle.gd")
	_root.set("kind", "slide")
	var gantry := "%s/haz_gantry.png" % PROP_DIR
	var gantry_size := _texture_size(gantry)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(gantry)
	sprite.centered = true
	sprite.offset = Vector2(0, -gantry_size.y * 0.5)
	_add(_root, sprite)
	_root.z_index = 2
	_root.position = Vector2(900, 800)
	_save("res://scenes/obstacle_slide.tscn")


func _build_pickup() -> void:
	_root = _new_root("Node2D", "Pickup", "res://scripts/pickup.gd")
	var glow := Sprite2D.new()
	glow.name = "Glow"
	glow.texture = load("res://assets/ui/glow.png")
	glow.scale = Vector2(1.4, 1.4)
	glow.z_index = -1
	_add(_root, glow)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load("res://assets/sprites/props/item_book.png")
	sprite.scale = Vector2(0.85, 0.85)
	_add(_root, sprite)
	_root.position = Vector2(900, 668)
	_root.z_index = 1
	_save("res://scenes/pickup.tscn")


# --- UI scenes -------------------------------------------------------------

func _build_hud() -> void:
	_root = _new_root("Control", "Hud", "res://scripts/hud.gd")
	(_root as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_root as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hearts := HBoxContainer.new()
	hearts.name = "Hearts"
	hearts.position = Vector2(50, 50)
	hearts.size = Vector2(200, 48)
	hearts.add_theme_constant_override("separation", 6)
	_add(_root, hearts)
	for i in 3:
		var heart := TextureRect.new()
		heart.name = "Heart%d" % (i + 1)
		heart.texture = load("res://assets/ui/heart.png")
		heart.custom_minimum_size = Vector2(42, 42)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.modulate = Pal.RED
		_add(hearts, heart)

	_label(_root, "SpeedLabel", "SPEED", Vector2(50, 102), Vector2(160, 24), 19, Pal.MUTED)
	_bar(_root, "SpeedBar", Vector2(50, 128), Vector2(268, 16), Pal.GREEN_LIGHT)
	_label(_root, "SpeedValue", "0 km/h", Vector2(50, 150), Vector2(200, 28), 20, Pal.WHITE)

	_label(_root, "ScoreCaption", "SCORE", Vector2(1500, 30), Vector2(354, 26), 19, Pal.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_root, "ScoreValue", "000000", Vector2(1500, 56), Vector2(354, 56), 44, Pal.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_root, "ComboValue", "ITEMS 0   COMBO x1", Vector2(1500, 116), Vector2(354, 30), 24, Pal.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_root, "PursuerLabel", "PURSUER!", Vector2(1500, 150), Vector2(354, 30), 26, Pal.RED, HORIZONTAL_ALIGNMENT_RIGHT)

	var progress := Control.new()
	progress.name = "Progress"
	progress.position = Vector2(660, 24)
	progress.size = Vector2(760, 64)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(_root, progress)
	_label(progress, "Caption", "TO CLASSROOM", Vector2(0, 0), Vector2(600, 24), 19, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_bar(progress, "Bar", Vector2(0, 30), Vector2(600, 18), Pal.GREEN_LIGHT)
	for i in 2:
		var tick := ColorRect.new()
		tick.name = "Tick%d" % (i + 1)
		tick.color = Pal.INK
		tick.position = Vector2(200 * (i + 1), 30)
		tick.size = Vector2(3, 18)
		_add(progress, tick)
	_label(progress, "Bell", "BELL 2:15", Vector2(620, 26), Vector2(180, 30), 22, Pal.WHITE)

	_label(_root, "ModeLabel", "", Vector2(0, 34), Vector2(1920, 28), 20, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var prompt := _label(_root, "Prompt", "SPACE // JUMP", Vector2(700, 210), Vector2(520, 56), 30, Pal.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.add_theme_stylebox_override("normal", _style(Color(0.03, 0.07, 0.12, 0.72), Pal.YELLOW, 2))
	prompt.modulate.a = 0.0

	var banner := _label(_root, "Banner", "ZONE", Vector2(0, 380), Vector2(1920, 96), 46, Pal.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	banner.add_theme_stylebox_override("normal", _style(Color(0.03, 0.07, 0.12, 0.65), Color(0, 0, 0, 0), 0))
	banner.modulate.a = 0.0

	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = load("res://assets/ui/vignette.png")
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate = Color(0.85, 0.18, 0.18, 0.0)
	_add(_root, vignette)

	_save("res://scenes/hud.tscn")


func _build_title() -> void:
	_root = _new_root("Control", "TitleScreen", "res://scripts/ui/title_screen.gd")
	(_root as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.03, 0.06, 0.11, 0.68)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(_root, veil)

	var elias := TextureRect.new()
	elias.name = "Elias"
	elias.texture = load("res://assets/sprites/elias/idle_3.png")
	elias.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	elias.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	elias.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elias.position = Vector2(1130, 250)
	elias.size = Vector2(560, 700)
	_add(_root, elias)

	_label(_root, "SchoolShadow", "SCHOOL", Vector2(130, 156), Vector2(700, 120), 104, Pal.GREEN_DARK)
	_label(_root, "School", "SCHOOL", Vector2(124, 150), Vector2(700, 120), 104, Pal.GREEN_LIGHT)
	_label(_root, "RushShadow", "RUSH", Vector2(118, 274), Vector2(800, 190), 168, Pal.INK)
	_label(_root, "Rush", "RUSH", Vector2(110, 266), Vector2(800, 190), 168, Pal.YELLOW)
	_label(_root, "Tagline", "2D THREE-LANE ARCADE RUNNER // 16-BIT", Vector2(126, 456), Vector2(900, 30), 26, Pal.MUTED)
	_label(_root, "Hook", "Wake up late. Dodge the neighborhood.\nOutrun the Pursuer before the bell.", Vector2(126, 492), Vector2(900, 80), 26, Pal.WHITE)
	_label(_root, "Best", "BEST CAMPAIGN 0     RUNS 0", Vector2(126, 596), Vector2(700, 30), 22, Pal.MUTED)

	_button(_root, "Campaign", "CAMPAIGN  [1]", Vector2(126, 654), Vector2(390, 68), true)
	_button(_root, "Endless", "ENDLESS  [2]", Vector2(534, 654), Vector2(390, 68))
	_button(_root, "Training", "TRAINING  [3]", Vector2(942, 654), Vector2(390, 68))

	_label(_root, "Controls", "W / S  or  UP / DOWN   switch lane      SPACE  jump      CTRL  slide      ESC  pause & help",
		Vector2(126, 764), Vector2(1400, 30), 22, Pal.MUTED)
	_label(_root, "QuitHint", "Q  quit", Vector2(126, 800), Vector2(400, 26), 20, Pal.MUTED)
	_label(_root, "Credit", "ARE STUDIO // GROUP 4", Vector2(126, 966), Vector2(700, 26), 20, Pal.MUTED)

	_save("res://scenes/title_screen.tscn")


func _build_pause() -> void:
	_root = _new_root("Control", "PauseScreen", "res://scripts/ui/pause_screen.gd")
	(_root as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.02, 0.04, 0.08, 0.78)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(_root, veil)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(560, 210)
	panel.size = Vector2(800, 530)
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.10, 0.17, 0.98), Pal.GREEN_LIGHT))
	_add(_root, panel)

	_label(_root, "Title", "PAUSED", Vector2(560, 238), Vector2(800, 60), 54, Pal.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_root, "HowTo", "HOW TO PLAY", Vector2(640, 312), Vector2(600, 30), 24, Pal.GREEN_LIGHT)
	_label(_root, "Row1", "W / S  or  UP / DOWN      switch lane", Vector2(640, 350), Vector2(660, 30), 26, Pal.WHITE)
	_label(_root, "Row2", "SPACE      gravity jump over low hazards", Vector2(640, 388), Vector2(660, 30), 26, Pal.WHITE)
	_label(_root, "Row3", "CTRL      low slide under hanging barriers", Vector2(640, 426), Vector2(660, 30), 26, Pal.WHITE)
	_label(_root, "Note", "3 hearts, but two hits in a row and the\nBarangay Guard catches you outright.",
		Vector2(640, 470), Vector2(660, 70), 22, Pal.MUTED)

	_button(_root, "Resume", "RESUME  [ESC]", Vector2(640, 566), Vector2(300, 62), true)
	_button(_root, "Restart", "RESTART", Vector2(960, 566), Vector2(300, 62))
	_button(_root, "Menu", "MAIN MENU", Vector2(640, 648), Vector2(620, 62))

	_save("res://scenes/pause_screen.tscn")


func _build_result() -> void:
	_root = _new_root("Control", "ResultScreen", "res://scripts/ui/result_screen.gd")
	(_root as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0.02, 0.04, 0.08, 0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(_root, veil)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(500, 190)
	panel.size = Vector2(920, 720)
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.10, 0.17, 0.98), Pal.YELLOW))
	_add(_root, panel)

	_label(_root, "Title", "MADE IT BEFORE THE BELL", Vector2(500, 220), Vector2(920, 70), 56, Pal.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_root, "Line", "", Vector2(540, 292), Vector2(840, 40), 24, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_label(_root, "ScoreCap", "SCORE", Vector2(560, 364), Vector2(360, 26), 20, Pal.MUTED)
	_label(_root, "ScoreValue", "000000", Vector2(560, 386), Vector2(360, 50), 40, Pal.WHITE)
	_label(_root, "ItemsCap", "ITEMS", Vector2(980, 364), Vector2(360, 26), 20, Pal.MUTED)
	_label(_root, "ItemsValue", "0", Vector2(980, 386), Vector2(360, 50), 40, Pal.WHITE)
	_label(_root, "DistanceCap", "DISTANCE", Vector2(560, 460), Vector2(360, 26), 20, Pal.MUTED)
	_label(_root, "DistanceValue", "0 m", Vector2(560, 482), Vector2(360, 50), 40, Pal.WHITE)
	_label(_root, "ComboCap", "BEST COMBO", Vector2(980, 460), Vector2(360, 26), 20, Pal.MUTED)
	_label(_root, "ComboValue", "x1", Vector2(980, 482), Vector2(360, 50), 40, Pal.WHITE)

	_label(_root, "Record", "NEW HIGH SCORE", Vector2(500, 558), Vector2(920, 36), 30, Pal.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_button(_root, "Retry", "RUN AGAIN  [ENTER]", Vector2(560, 620), Vector2(380, 66), true)
	_button(_root, "Menu", "MAIN MENU  [ESC]", Vector2(960, 620), Vector2(380, 66))
	_label(_root, "Best", "Best: 0", Vector2(500, 726), Vector2(920, 28), 20, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_root, "Runs", "Total runs: 0", Vector2(500, 754), Vector2(920, 28), 20, Pal.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_save("res://scenes/result_screen.tscn")


# --- root scenes -----------------------------------------------------------

func _build_game() -> void:
	_root = _new_root("Node2D", "Game", "res://scripts/game.gd")

	var world := Node2D.new()
	world.name = "World"
	_add(_root, world)

	var background := (load("res://scenes/background.tscn") as PackedScene).instantiate()
	background.name = "Background"
	_add(world, background)

	var course := (load("res://scenes/course.tscn") as PackedScene).instantiate()
	course.name = "Course"
	_add(world, course)

	var pursuer := (load("res://scenes/pursuer.tscn") as PackedScene).instantiate()
	pursuer.name = "Pursuer"
	_add(world, pursuer)

	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	_add(world, player)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 5
	_add(_root, hud_layer)

	var hud := (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	hud.name = "Hud"
	_add(hud_layer, hud)

	_save("res://scenes/game.tscn")


func _build_main() -> void:
	_root = _new_root("Node", "Main", "res://scripts/main.gd")

	var world := Node2D.new()
	world.name = "MenuWorld"
	_add(_root, world)

	var background := (load("res://scenes/background.tscn") as PackedScene).instantiate() as Background
	background.name = "MenuBackground"
	background.parallax = 0.05
	background.idle_speed = 26.0
	background.z_index = -20
	_add(world, background)

	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = load("%s/ground.png" % WORLD_DIR)
	ground.centered = false
	ground.position = Vector2(0, GROUND_TOP)
	ground.z_index = -2
	_add(world, ground)

	var title := (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	title.name = "TitleScreen"
	_add(_root, title)

	_save("res://scenes/main.tscn")
