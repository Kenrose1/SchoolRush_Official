class_name ShopPanel
extends PanelContainer
## School Store: buy persistent upgrades with the coin wallet.
##
## Embedded by the main menu only; the panel knows nothing about its host -
## hosts connect to [signal closed] to restore focus (same contract as
## SettingsPanel). Cards are generated from GameConfig.SHOP_UPGRADES so a new
## upgrade only needs a table row and an icon.

signal closed

const COIN_ICON: Texture2D = preload(
	"res://assets/icon/coin/Golden Coin 2nd Outline 64px.png")

const CARD_ICONS := {
	GameConfig.ShopUpgrade.SPEED: preload("res://assets/icon/upgrades/speed.png"),
	GameConfig.ShopUpgrade.LUCK: preload("res://assets/icon/upgrades/luck.png"),
	GameConfig.ShopUpgrade.JUMP: preload("res://assets/icon/upgrades/jump.png"),
	GameConfig.ShopUpgrade.HEARTS: preload("res://assets/icon/upgrades/heart.png"),
	GameConfig.ShopUpgrade.SHIELD: preload("res://assets/icon/upgrades/shield.png"),
}

## Icon sizes. The upgrade art is authored at 267-332 px, so it is always drawn
## downscaled and needs linear filtering. 64 px is the largest card icon that
## still fits the 1080 design height (the suite guards that fit). The coin is a
## 64 px source, so 40 is close to native.
const CARD_ICON_SIZE := 64.0
const WALLET_ICON_SIZE := 40.0

# Card labels are built in code, so the Nunito weights are applied
# explicitly - the engine default font would otherwise take over.
const NAME_FONT: FontFile = preload(
	"res://assets/fonts/Nunito-ExtraBold.ttf")
const SUB_FONT: FontFile = preload(
	"res://assets/fonts/Nunito-SemiBold.ttf")

## Max-upgrade celebration tuning. The ring is drawn in code (a Line2D circle)
## rather than from a texture: at this size the bundle's twirl art reads as a
## smudge, while a line ring keeps the accent colour exact and stays crisp.
const FX_GOLD := Color(1.0, 0.85, 0.45)
const RING_POINTS := 48
const RING_RADIUS := 120.0
const RING_TIME := 0.55
const PIP_STAGGER := 0.045

@onready var wallet_label: Label = %WalletLabel
@onready var wallet_chip: HBoxContainer = %WalletChip
@onready var grid: GridContainer = %UpgradeGrid
@onready var close_button: Button = %CloseButton
@onready var upgrade_sfx: AudioStreamPlayer = %UpgradeSfx
@onready var max_upgrade_sfx: AudioStreamPlayer = %MaxUpgradeSfx
@onready var max_burst: CPUParticles2D = %MaxUpgradeBurst
@onready var max_ring: Line2D = %MaxUpgradeRing
@onready var max_stamp: Label = %MaxUpgradeStamp

## Per-kind card widgets, filled in _ready.
var _cards: Dictionary = {}
## Wallet balance shown in the chip (kept for change detection in _refresh).
var _last_wallet: int = -1
## Completed purchases - the confirmation chime is counted for the test suite.
var upgrade_play_count: int = 0
## Purchases that completed an upgrade - the fanfare replaces the chime there,
## so the two counters are exclusive and the suite can assert that.
var max_upgrade_play_count: int = 0
## Max-upgrade celebrations fired - one per finishing purchase.
var max_burst_count: int = 0
## Serial for the ring fade, so a re-trigger cannot be hidden by the old tween.
var _ring_serial: int = 0


func _ready() -> void:
	# Hidden at runtime; the scene root stays visible so the panel can be
	# styled in the editor (same arrangement as the settings panel).
	visible = false
	_build_cards()
	_build_wallet_icon()
	_build_max_fx()
	wallet_label.text = str(GameState.coins)
	_last_wallet = GameState.coins
	# Event-driven wallet chip: the panel never polls the wallet.
	GameState.coins_changed.connect(_on_coins_changed)
	close_button.pressed.connect(close)


## Show the store with cards and the wallet synced to live state.
func open() -> void:
	_refresh()
	visible = true
	_focus_first_buy()


## Hide the panel and tell the host to restore focus.
func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Esc backs out of the store. Consuming it keeps the host's own Esc
	# handlers (how-to close, pause toggle) from also firing.
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Card building -----------------------------------------------------------

## One card per entry in GameConfig.SHOP_UPGRADES, in table order.
func _build_cards() -> void:
	for kind: int in GameConfig.SHOP_UPGRADES:
		var data: Dictionary = GameConfig.SHOP_UPGRADES[kind]
		var frame := _make_card_frame()
		var card := frame.get_child(0) as VBoxContainer

		var icon := TextureRect.new()
		icon.texture = CARD_ICONS[kind]
		icon.custom_minimum_size = Vector2.ONE * CARD_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Illustration art, not pixel art: nearest filtering aliases badly at
		# the 4-5x downscale these sources need.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)

		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", NAME_FONT)
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override(
			"font_color", Color(1.0, 0.94, 0.86))
		card.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = data["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(250.0, 0.0)
		desc_label.add_theme_font_override("font", SUB_FONT)
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override(
			"font_color", Color(1.0, 0.94, 0.86, 0.7))
		card.add_child(desc_label)

		var pips := _make_pips(int(data["max_level"]))
		card.add_child(pips)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150.0, 48.0)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buy.add_theme_font_override("font", NAME_FONT)
		buy.add_theme_font_size_override("font_size", 22)
		buy.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
		buy.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.86))
		buy.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.86))
		buy.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.86))
		buy.add_theme_stylebox_override("normal", _buy_style(Color(1.0, 0.705882, 0.368627, 0.25)))
		buy.add_theme_stylebox_override("hover", _buy_style(Color(1.0, 0.705882, 0.368627, 1.0)))
		buy.add_theme_stylebox_override("focus", _buy_style(Color(1.0, 0.705882, 0.368627, 1.0)))
		buy.add_theme_stylebox_override("disabled", _buy_style(Color(1, 1, 1, 0.08)))
		buy.pressed.connect(_on_buy_pressed.bind(kind))
		card.add_child(buy)

		grid.add_child(frame)
		_cards[kind] = {"pips": pips, "buy": buy, "card": frame,
			"name": name_label, "desc": desc_label}


func _make_card_frame() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.85)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.705882, 0.368627, 0.3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 18.0
	card.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	return card


func _make_pips(max_level: int) -> HBoxContainer:
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 6)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in max_level:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14.0, 14.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	return pips


func _buy_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.13, 0.82)
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(12)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _build_wallet_icon() -> void:
	var icon := TextureRect.new()
	icon.texture = COIN_ICON
	icon.custom_minimum_size = Vector2.ONE * WALLET_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_chip.add_child(icon)
	wallet_chip.move_child(icon, 0)


# --- Refresh / purchase ------------------------------------------------------

## Sync every card's pips, price, and disabled state to live state.
func _refresh() -> void:
	wallet_label.text = str(GameState.coins)
	_last_wallet = GameState.coins
	for kind: int in _cards:
		var data: Dictionary = GameConfig.SHOP_UPGRADES[kind]
		var level := GameState.shop_level(kind)
		var max_level := int(data["max_level"])
		var card: Dictionary = _cards[kind]
		var pips: HBoxContainer = card["pips"]
		for i in pips.get_child_count():
			var pip := pips.get_child(i) as ColorRect
			pip.color = Color(1.0, 0.705882, 0.368627) if i < level \
				else Color(1.0, 0.94, 0.86, 0.15)
		var buy := card["buy"] as Button
		if level >= max_level:
			buy.text = "MAX"
			buy.disabled = true
		else:
			var cost := GameConfig.shop_cost(kind, level)
			buy.text = "BUY  %d" % cost
			buy.disabled = GameState.coins < cost


func _on_buy_pressed(kind: int) -> void:
	if not GameState.buy_upgrade(kind):
		return
	# Only a completed purchase makes a sound; unaffordable and maxed cards stay
	# silent. The purchase that finishes a track gets the fanfare INSTEAD of the
	# chime, so the milestone is readable by ear alone.
	var max_level := int(GameConfig.SHOP_UPGRADES[kind]["max_level"])
	var maxed := GameState.shop_level(kind) >= max_level
	if maxed:
		max_upgrade_play_count += 1
		max_upgrade_sfx.play()
	else:
		upgrade_play_count += 1
		upgrade_sfx.play()
	_refresh()
	var card: Dictionary = _cards[kind]
	var panel := card["card"] as PanelContainer
	panel.pivot_offset = panel.size / 2.0
	if maxed:
		_celebrate_max(panel, card)
		return
	# Pop the bought card so the purchase reads as an event, not a text swap.
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.14)


## Finishing an upgrade is the biggest event the store has, so it gets one more
## layer than a normal buy: a bigger spring, a gold border flash, a shockwave
## ring, a star burst, a pip cascade and a MAX! stamp. No shake - a menu should
## not move the player's view.
func _celebrate_max(panel: PanelContainer, card: Dictionary) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.12, 1.12), 0.1)
	tw.tween_property(panel, "scale", Vector2(0.97, 0.97), 0.1)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.16)

	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = FX_GOLD
		create_tween().tween_property(
			style, "border_color", Color(1.0, 0.705882, 0.368627, 0.3), 0.7)

	# Every effect is centred on the card as it was before the spring started,
	# so the ring, burst and stamp stay put while the card itself scales. The
	# stamp sits as a badge on the card's top-right corner - dead centre would
	# bury the name and description, and the button already reads MAX.
	max_burst_count += 1
	var fx := max_burst.get_parent() as Node2D
	var card_rect := panel.get_global_rect()
	_fire_max_burst(fx.to_local(card_rect.get_center()))
	_flash_max_ring(fx.to_local(card_rect.get_center()))
	_pop_max_stamp(fx.to_local(
		card_rect.position + Vector2(card_rect.size.x - 26.0, 36.0)))
	_cascade_pips(card)

	var buy := card["buy"] as Button
	if buy != null:
		buy.modulate = Color(1.7, 1.4, 0.75)
		create_tween().tween_property(buy, "modulate", Color.WHITE, 0.45)


## One-time setup: the ring's circle lives in code so the scene only carries
## the styling, and all three effects start hidden.
func _build_max_fx() -> void:
	max_ring.points = _circle_points(RING_RADIUS)
	max_ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
	max_ring.visible = false
	max_stamp.rotation = deg_to_rad(-14.0)
	max_stamp.visible = false


static func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in RING_POINTS:
		var angle := TAU * float(i) / float(RING_POINTS)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _fire_max_burst(center: Vector2) -> void:
	max_burst.position = center
	max_burst.restart()
	max_burst.emitting = true


func _flash_max_ring(center: Vector2) -> void:
	_ring_serial += 1
	var serial := _ring_serial
	max_ring.position = center
	max_ring.scale = Vector2(0.4, 0.4)
	max_ring.modulate = Color(1.0, 1.0, 1.0, 0.95)
	max_ring.visible = true
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(max_ring, "scale", Vector2(1.3, 1.3), RING_TIME)
	tw.tween_property(max_ring, "modulate:a", 0.0, RING_TIME)
	tw.chain().tween_callback(_hide_ring.bind(serial))


## Fade finished: hide only when no newer ring has taken over.
func _hide_ring(serial: int) -> void:
	if serial == _ring_serial:
		max_ring.visible = false


func _pop_max_stamp(center: Vector2) -> void:
	max_stamp.visible = true
	max_stamp.size = max_stamp.get_combined_minimum_size()
	max_stamp.position = center - max_stamp.size / 2.0
	max_stamp.pivot_offset = max_stamp.size / 2.0
	max_stamp.modulate = Color.WHITE
	max_stamp.scale = Vector2(1.6, 1.6)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(max_stamp, "scale", Vector2.ONE, 0.16)
	tw.tween_interval(0.25)
	tw.tween_property(max_stamp, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: max_stamp.visible = false)


## Light the pips left to right instead of only the last one, so the eye reads
## the whole track completing.
func _cascade_pips(card: Dictionary) -> void:
	var pips := card["pips"] as HBoxContainer
	if pips == null:
		return
	for i in pips.get_child_count():
		var pip := pips.get_child(i) as ColorRect
		if pip == null:
			continue
		pip.color = Color.WHITE
		var tw := create_tween()
		tw.tween_interval(PIP_STAGGER * float(i))
		tw.tween_property(pip, "color", Color(1.0, 0.705882, 0.368627), 0.35)


func _on_coins_changed(count: int) -> void:
	# Only refresh when the balance actually moved (buy flow refreshes too).
	if count == _last_wallet:
		return
	_last_wallet = count
	_refresh()


## Keyboard/gamepad: focus the first affordable BUY (or CLOSE when broke).
func _focus_first_buy() -> void:
	for kind: int in GameConfig.SHOP_UPGRADES:
		var data: Dictionary = GameConfig.SHOP_UPGRADES[kind]
		var level := GameState.shop_level(kind)
		if level < int(data["max_level"]) \
				and GameState.coins >= GameConfig.shop_cost(kind, level):
			(_cards[kind]["buy"] as Button).grab_focus()
			return
	close_button.grab_focus()
