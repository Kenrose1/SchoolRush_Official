class_name ScoreHud
extends CanvasLayer
## Minimal score readout in the top-right corner.
##
## M3 placeholder: it only reflects the ScoreSystem. The styled HUD arrives in
## M5 with the font/theme decision.

var _score_label: Label
var _combo_label: Label
var _items_label: Label


func _ready() -> void:
	_score_label = _make_label(Vector2(-360.0, 24.0), Vector2(-28.0, 80.0), HORIZONTAL_ALIGNMENT_RIGHT, 40)
	_combo_label = _make_label(Vector2(-360.0, 76.0), Vector2(-28.0, 124.0), HORIZONTAL_ALIGNMENT_RIGHT, 32)
	_items_label = _make_label(Vector2(-360.0, 122.0), Vector2(-28.0, 168.0), HORIZONTAL_ALIGNMENT_RIGHT, 28)
	set_score(0)
	set_combo(1, 0)
	set_items(0)


func set_score(score: int) -> void:
	_score_label.text = "%06d" % score


func set_combo(multiplier: int, chain: int) -> void:
	if chain <= 0:
		_combo_label.text = ""
	else:
		_combo_label.text = "x%d  COMBO %d" % [multiplier, chain]


func set_items(count: int) -> void:
	_items_label.text = "ITEMS  %d" % count


func _make_label(left: Vector2, right: Vector2, align: HorizontalAlignment, font_size: int) -> Label:
	var label := Label.new()
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = left.x
	label.offset_top = left.y
	label.offset_right = right.x
	label.offset_bottom = right.y
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label
