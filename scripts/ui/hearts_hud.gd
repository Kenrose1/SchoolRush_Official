class_name HeartsHud
extends Control
## Heart row with polished glass plate styling and damage pulse feedback.

const FULL_TEXTURE := preload("res://assets/heart/heart.png")
const EMPTY_TEXTURE := preload("res://assets/heart/heart_empty.png")
const SHIELD_TEXTURE := preload("res://assets/icon/upgrades/shield.png")

@onready var _panel: PanelContainer = $Panel
@onready var _row: HBoxContainer = $Panel/Row
@onready var _shield_panel: PanelContainer = $ShieldPanel
@onready var _shield_row: HBoxContainer = $ShieldPanel/ShieldRow
var _hearts: Array[TextureRect] = []
var _shields: Array[TextureRect] = []
var _last_current: int = -1
var _last_shields: int = -1


func _ready() -> void:
	# Collect the editor-placed icons; create any missing ones for safety.
	for child in _row.get_children():
		if child is TextureRect:
			child.pivot_offset = Vector2(22.0, 22.0)
			_hearts.append(child)
	while _hearts.size() < GameConfig.MAX_HEARTS:
		var icon := _make_icon()
		_row.add_child(icon)
		_hearts.append(icon)
	set_hearts(GameConfig.MAX_HEARTS, GameConfig.MAX_HEARTS)


## Show [param current] full hearts out of [param maximum].
func set_hearts(current: int, maximum: int) -> void:
	var shown := maxi(maximum, 0)
	while _hearts.size() < shown:
		var icon := _make_icon()
		_row.add_child(icon)
		_hearts.append(icon)

	for index in _hearts.size():
		_hearts[index].visible = index < shown
		if index < shown:
			var is_full := index < current
			var target_texture = FULL_TEXTURE if is_full else EMPTY_TEXTURE
			if _hearts[index].texture != target_texture and _last_current != -1:
				_play_heart_anim(_hearts[index], is_full)
			_hearts[index].texture = target_texture
	
	# Slight shake on panel when taking damage
	if _last_current != -1 and current < _last_current and _panel:
		var shake := create_tween().set_trans(Tween.TRANS_SINE)
		shake.tween_property(_panel, "position:x", 32.0 - 4.0, 0.05)
		shake.tween_property(_panel, "position:x", 32.0 + 4.0, 0.05)
		shake.tween_property(_panel, "position:x", 32.0, 0.05)
		
	_last_current = current


## Shield charges bought in the shop, drawn on their own movable panel BELOW
## the hearts card. A spent charge disappears entirely (with max 2 you go
## two -> one -> none), and once the last charge is spent the whole panel
## hides too - it comes back when the charges are refilled (e.g. on reset).
func set_shields(current: int, maximum: int) -> void:
	_shield_panel.visible = current > 0
	if maximum > 0 and _shields.is_empty():
		# Build the pip set once, sized for the bought level.
		for i in maximum:
			var icon := _make_shield_icon()
			_shield_row.add_child(icon)
			_shields.append(icon)
	for index in _shields.size():
		_shields[index].visible = index < current
	_last_shields = current


## Number of visible shield pips, for the test suite.
func shield_count() -> int:
	var visible := 0
	for icon in _shields:
		if icon.visible:
			visible += 1
	return visible


func _make_shield_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.pivot_offset = Vector2(22.0, 22.0)
	icon.texture = SHIELD_TEXTURE
	return icon


func _play_heart_anim(heart: TextureRect, was_healed: bool) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if was_healed:
		tw.tween_property(heart, "scale", Vector2(1.3, 1.3), 0.12)
		tw.tween_property(heart, "scale", Vector2.ONE, 0.15)
	else:
		tw.tween_property(heart, "scale", Vector2(0.7, 0.7), 0.1)
		tw.tween_property(heart, "scale", Vector2.ONE, 0.15)


## Texture currently drawn for heart [param index] (used by the test suite).
func get_heart_texture(index: int) -> Texture2D:
	if index < 0 or index >= _hearts.size():
		return null
	return _hearts[index].texture


func heart_count() -> int:
	var visible := 0
	for icon in _hearts:
		if icon.visible:
			visible += 1
	return visible


func _make_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.pivot_offset = Vector2(22.0, 22.0)
	return icon
