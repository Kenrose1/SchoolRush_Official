class_name HeartsHud
extends CanvasLayer
## Minimal heart row shown in the top-left corner.
##
## M2 placeholder: it only reflects health. Score, combo, and the styled HUD
## arrive in M5. Uses the project's 16x16 heart art, nearest-filtered.

const FULL_TEXTURE := preload("res://assets/heart/heart.png")
const EMPTY_TEXTURE := preload("res://assets/heart/heart_empty.png")

var _row: HBoxContainer
var _hearts: Array[TextureRect] = []


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.position = GameConfig.HUD_MARGIN
	_row.add_theme_constant_override("separation", int(GameConfig.HEART_GAP))
	add_child(_row)
	set_hearts(GameConfig.MAX_HEARTS, GameConfig.MAX_HEARTS)


## Show [param current] full hearts out of [param maximum].
func set_hearts(current: int, maximum: int) -> void:
	var shown := maxi(maximum, 0)
	while _hearts.size() < shown:
		var icon := _make_icon()
		_row.add_child(icon)
		_hearts.append(icon)
	while _hearts.size() > shown:
		var extra: TextureRect = _hearts.pop_back()
		extra.queue_free()

	for index in _hearts.size():
		_hearts[index].texture = FULL_TEXTURE if index < current else EMPTY_TEXTURE


## Texture currently drawn for heart [param index] (used by the test suite).
func get_heart_texture(index: int) -> Texture2D:
	if index < 0 or index >= _hearts.size():
		return null
	return _hearts[index].texture


func heart_count() -> int:
	return _hearts.size()


func _make_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = FULL_TEXTURE
	icon.custom_minimum_size = Vector2(GameConfig.HEART_SIZE, GameConfig.HEART_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon
