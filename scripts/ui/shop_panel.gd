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

@onready var wallet_label: Label = %WalletLabel
@onready var wallet_chip: HBoxContainer = %WalletChip
@onready var grid: GridContainer = %UpgradeGrid
@onready var close_button: Button = %CloseButton

## Per-kind card widgets, filled in _ready.
var _cards: Dictionary = {}
## Wallet balance shown in the chip (kept for change detection in _refresh).
var _last_wallet: int = -1


func _ready() -> void:
	# Hidden at runtime; the scene root stays visible so the panel can be
	# styled in the editor (same arrangement as the settings panel).
	visible = false
	_build_cards()
	_build_wallet_icon()
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
		icon.custom_minimum_size = Vector2(44.0, 44.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)

		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override(
			"font_color", Color(1.0, 0.94, 0.86))
		card.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = data["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(250.0, 0.0)
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override(
			"font_color", Color(1.0, 0.94, 0.86, 0.7))
		card.add_child(desc_label)

		var pips := _make_pips(int(data["max_level"]))
		card.add_child(pips)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150.0, 48.0)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
		_cards[kind] = {"pips": pips, "buy": buy, "card": frame}


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
	vbox.add_theme_constant_override("separation", 10)
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
	icon.custom_minimum_size = Vector2(30.0, 30.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_refresh()
	# Pop the bought card so the purchase reads as an event, not a text swap.
	var card: Dictionary = _cards[kind]
	var panel := card["card"] as PanelContainer
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.08)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.14)


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
