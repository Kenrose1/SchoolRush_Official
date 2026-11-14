class_name ScoreHud
extends Control
## Score, combo, and School Item dashboard in the top-right corner.
##
## Styled with a translucent dark-amber card container, high-contrast typography,
## and responsive anchoring to align gracefully with the pause button.

const SCORE_FONT_PATH := "res://assets/fonts/static/InterTight-ExtraBold.ttf"
const SUB_FONT_PATH := "res://assets/fonts/static/InterTight-SemiBold.ttf"
const SCORE_FONT: Font = preload(SCORE_FONT_PATH)
const SUB_FONT: Font = preload(SUB_FONT_PATH)

const TEXT_COLOR := Color(1.0, 0.94, 0.86)
const AMBER_COLOR := Color(1.0, 0.705882, 0.368627)
const COMBO_COLOR := Color(1.0, 0.42, 0.28)
const COIN_ICON: Texture2D = preload("res://assets/icon/coin/Golden Coin 2nd Outline 64px.png")

var _card: PanelContainer
var _score_label: Label
var _combo_label: Label
var _items_label: Label
var _coins_label: Label
var _last_chain: int = 0


func _ready() -> void:
	# Build the card panel for consistent styling matching the game design
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 0.0
	_card.offset_left = -460.0
	_card.offset_top = 24.0
	_card.offset_right = -116.0
	_card.offset_bottom = 204.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 0.78)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.705882, 0.368627, 0.35)
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_right = 16
	sb.corner_radius_bottom_left = 16
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 12.0
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	_card.add_child(vbox)

	_score_label = Label.new()
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.add_theme_font_override("font", SCORE_FONT)
	_score_label.add_theme_font_size_override("font_size", 42)
	_score_label.add_theme_color_override("font_color", TEXT_COLOR)
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_score_label.add_theme_constant_override("shadow_offset_x", 3)
	_score_label.add_theme_constant_override("shadow_offset_y", 3)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_score_label)

	_combo_label = Label.new()
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.add_theme_font_override("font", SUB_FONT)
	_combo_label.add_theme_font_size_override("font_size", 30)
	_combo_label.add_theme_color_override("font_color", COMBO_COLOR)
	_combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_combo_label.add_theme_constant_override("shadow_offset_x", 2)
	_combo_label.add_theme_constant_override("shadow_offset_y", 2)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.pivot_offset = Vector2(300, 15)
	vbox.add_child(_combo_label)

	_items_label = Label.new()
	_items_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_label.add_theme_font_override("font", SUB_FONT)
	_items_label.add_theme_font_size_override("font_size", 24)
	_items_label.add_theme_color_override("font_color", AMBER_COLOR)
	_items_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_items_label.add_theme_constant_override("shadow_offset_x", 2)
	_items_label.add_theme_constant_override("shadow_offset_y", 2)
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_items_label)

	# Coin wallet row: golden coin icon + amber count, right-aligned with the
	# rest of the card. Updated only via set_coins (event-driven, never polled).
	var coin_row := HBoxContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_theme_constant_override("separation", 8)
	coin_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(coin_row)

	var coin_icon := TextureRect.new()
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_icon.texture = COIN_ICON
	coin_icon.custom_minimum_size = Vector2(24, 24)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_row.add_child(coin_icon)

	_coins_label = Label.new()
	_coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins_label.add_theme_font_override("font", SUB_FONT)
	_coins_label.add_theme_font_size_override("font_size", 24)
	_coins_label.add_theme_color_override("font_color", AMBER_COLOR)
	_coins_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_coins_label.add_theme_constant_override("shadow_offset_x", 2)
	_coins_label.add_theme_constant_override("shadow_offset_y", 2)
	coin_row.add_child(_coins_label)

	set_score(0)
	set_combo(1, 0)
	set_items(0)
	set_coins(0)


func set_score(score: int) -> void:
	_score_label.text = "%06d" % score


func set_combo(multiplier: int, chain: int) -> void:
	if chain <= 0:
		_combo_label.text = ""
	else:
		_combo_label.text = "x%d  COMBO %d" % [multiplier, chain]
		if chain > _last_chain and _combo_label.is_inside_tree():
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_combo_label, "scale", Vector2(1.18, 1.18), 0.08)
			tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)
	_last_chain = chain


func set_items(count: int) -> void:
	_items_label.text = "ITEMS  %d" % count


## Wallet readout. Wired to GameState.coins_changed, so it moves exactly when
## a coin is collected - never per frame.
func set_coins(count: int) -> void:
	_coins_label.text = "COINS  %d" % count


## Theme font used by a readout ("score", "combo", or "items"), for the test suite.
func label_font(part: String) -> Font:
	match part:
		"score":
			return _score_label.get_theme_font("font")
		"combo":
			return _combo_label.get_theme_font("font")
		"items":
			return _items_label.get_theme_font("font")
		"coins":
			return _coins_label.get_theme_font("font")
	return null


## Text currently shown by a readout ("score", "combo", or "items").
func label_text(part: String) -> String:
	match part:
		"score":
			return _score_label.text
		"combo":
			return _combo_label.text
		"items":
			return _items_label.text
		"coins":
			return _coins_label.text
	return ""
