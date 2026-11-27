class_name ScoreHud
extends Control
## Score, combo, and School Item dashboard in the top-right corner.
##
## Styled with a translucent dark-amber card container, high-contrast typography,
## and responsive anchoring to align gracefully with the pause button.

const SCORE_FONT_PATH := "res://assets/fonts/Nunito-ExtraBold.ttf"
const SUB_FONT_PATH := "res://assets/fonts/Nunito-SemiBold.ttf"
const SCORE_FONT: Font = preload(SCORE_FONT_PATH)
const SUB_FONT: Font = preload(SUB_FONT_PATH)

const TEXT_COLOR := Color(1.0, 0.94, 0.86)
const AMBER_COLOR := Color(1.0, 0.705882, 0.368627)
## One colour per multiplier rung: cream -> amber -> orange -> coral -> red.
## The step is the only cue that the label just changed tier, so it has to read
## instantly at speed.
const TIER_COLORS: Array[Color] = [
	Color(1.0, 0.94, 0.86),
	Color(1.0, 0.94, 0.86),
	Color(1.0, 0.78, 0.42),
	Color(1.0, 0.62, 0.26),
	Color(1.0, 0.42, 0.28),
	Color(1.0, 0.30, 0.34),
]
## A pickup is a tick; a rung is a small impact (game-feel: scale feedback to
## importance). Screen shake and hit-stop stay reserved for real impacts.
const PICKUP_POP := 1.18
const TIER_POP := 1.35
const COIN_ICON: Texture2D = preload("res://assets/icon/coin/Golden Coin 2nd Outline 64px.png")

var _card: PanelContainer
var _score_label: Label
var _combo_label: Label
var _items_label: Label
var _coins_label: Label
var _last_chain: int = 0
var _last_multiplier: int = 1
var _last_coins: int = 0
var _combo_tween: Tween
var _score_tween: Tween
var _coin_tween: Tween


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
	_score_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_score_label.add_theme_constant_override("outline_size", 4)
	_score_label.add_theme_constant_override("shadow_offset_x", 3)
	_score_label.add_theme_constant_override("shadow_offset_y", 3)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_score_label)

	_combo_label = Label.new()
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label.add_theme_font_override("font", SUB_FONT)
	_combo_label.add_theme_font_size_override("font_size", 30)
	_combo_label.add_theme_color_override("font_color", TIER_COLORS[1])
	_combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_combo_label.add_theme_constant_override("shadow_offset_x", 2)
	_combo_label.add_theme_constant_override("shadow_offset_y", 2)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_combo_label)

	_items_label = Label.new()
	_items_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items_label.add_theme_font_override("font", SUB_FONT)
	_items_label.add_theme_font_size_override("font_size", 24)
	_items_label.add_theme_color_override("font_color", AMBER_COLOR)
	_items_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_items_label.add_theme_constant_override("shadow_offset_x", 2)
	_items_label.add_theme_constant_override("shadow_offset_y", 2)
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_items_label)

	# Coin wallet row: golden coin icon + amber count, centred with the rest of
	# the card. Updated only via set_coins (event-driven, never polled).
	var coin_row := HBoxContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_theme_constant_override("separation", 8)
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
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
	_coins_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_coins_label.add_theme_constant_override("outline_size", 3)
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
		# Actionable readout: chain, and how many pickups buy the next rung.
		var next := GameConfig.combo_next_threshold(chain)
		if next <= 0:
			_combo_label.text = "x%d · MAX" % multiplier
		else:
			_combo_label.text = "x%d · %d/%d" % [multiplier, chain, next]
		_combo_label.add_theme_color_override("font_color", _tier_color(multiplier))
		if _combo_label.is_inside_tree():
			if multiplier > _last_multiplier:
				_pop(_combo_label, TIER_POP, 0.10, 0.16)
				_flash_score()
			elif chain > _last_chain:
				_pop(_combo_label, PICKUP_POP, 0.08, 0.12)
	_last_chain = chain
	_last_multiplier = multiplier


func _tier_color(multiplier: int) -> Color:
	return TIER_COLORS[clampi(multiplier, 1, TIER_COLORS.size() - 1)]


func _pop(label: Label, scale: float, up_time: float, down_time: float) -> void:
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	label.scale = Vector2.ONE
	# Centred text: grow from the middle so the readout stays on the card's
	# centre line while it swells.
	label.pivot_offset = label.size * 0.5
	_combo_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(label, "scale", Vector2(scale, scale), up_time)
	_combo_tween.tween_property(label, "scale", Vector2.ONE, down_time)


## Quick white tint on the score number so the multiplier visibly causes it.
func _flash_score() -> void:
	if not _score_label.is_inside_tree():
		return
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_label.modulate = Color(1.9, 1.9, 1.9)
	_score_tween = create_tween()
	_score_tween.tween_property(_score_label, "modulate", Color.WHITE, 0.22)


func set_items(count: int) -> void:
	_items_label.text = "ITEMS  %d" % count


## Wallet readout. Wired to GameState.coins_changed, so it moves exactly when
## a coin is collected - never per frame.
func set_coins(count: int) -> void:
	_coins_label.text = "COINS  %d" % count
	if count > _last_coins and _coins_label.is_inside_tree():
		if _coin_tween != null and _coin_tween.is_valid():
			_coin_tween.kill()
		_coins_label.scale = Vector2.ONE
		_coins_label.pivot_offset = _coins_label.size * 0.5
		_coin_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_coin_tween.tween_property(_coins_label, "scale", Vector2(1.25, 1.25), 0.08)
		_coin_tween.tween_property(_coins_label, "scale", Vector2.ONE, 0.12)
	_last_coins = count


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


## Text currently shown by a readout ("score", "combo", "items", or "coins").
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


## Colour currently used by a readout ("combo" or "coins"), for the suite.
func label_color(part: String) -> Color:
	match part:
		"combo":
			return _combo_label.get_theme_color("font_color")
		"coins":
			return _coins_label.get_theme_color("font_color")
	return Color.WHITE
