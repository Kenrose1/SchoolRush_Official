extends SceneTree


func _crop(source: String, target: String, rect: Rect2i, zoom: float = 1.0) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		print("missing %s" % source)
		return
	var crop := image.get_region(rect)
	if zoom != 1.0:
		crop.resize(int(crop.get_width() * zoom), int(crop.get_height() * zoom),
			Image.INTERPOLATE_NEAREST)
	print("saved err=%d %s size=%s" % [
		crop.save_jpg(ProjectSettings.globalize_path(target), 0.95),
		target, crop.get_size()])


func _init() -> void:
	_crop("res://tools/sources/_tmp_barricade_check.png",
		"res://tools/sources/_tmp_barricade_zoom.jpg", Rect2i(150, 420, 700, 220))
	_crop("res://tools/sources/_tmp_barricade_slide.png",
		"res://tools/sources/_tmp_barricade_slide_zoom.jpg", Rect2i(150, 420, 700, 220))
	_crop("res://tools/sources/_tmp_barricade_check.png",
		"res://tools/sources/_tmp_hud_zone.jpg", Rect2i(330, 40, 620, 80), 2.0)
	_crop("res://tools/sources/_tmp_barricade_check.png",
		"res://tools/sources/_tmp_hud_score.jpg", Rect2i(805, 5, 390, 140), 2.0)
	_crop("res://tools/sources/_tmp_barricade_check.png",
		"res://tools/sources/_tmp_hud_hearts.jpg", Rect2i(0, 0, 230, 80), 2.5)
	quit(0)
