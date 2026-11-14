
class_name MainMenu
extends Control
## Main menu: CAMPAIGN / ENDLESS / HOW TO PLAY / QUIT over the school backdrop.
##
## Upgraded with "Morning Rush Vignette" asymmetric layout, animated character
## sprites, floating props, and dynamic button micro-interactions.

const WORLD_SCENE := "res://scenes/main.tscn"
const BEST_FORMAT := "BEST  %06d"

@onready var campaign_button: Button = %Campaign
@onready var endless_button: Button = %Endless
@onready var how_to_button: Button = %HowTo
@onready var settings_button: Button = %Settings
@onready var quit_button: Button = %Quit
@onready var best_label: Label = %BestLabel
@onready var how_to_panel: PanelContainer = %HowToPanel
@onready var back_button: Button = %BackButton
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var shop_button: Button = %Shop
@onready var shop_panel: ShopPanel = %ShopPanel
@onready var elias_sprite: AnimatedSprite2D = %EliasVignette
@onready var tanod_sprite: AnimatedSprite2D = %TanodVignette
@onready var title_label: Label = %TitleLabel
@onready var tag_pill: Label = %UrgencyPill

# Floating props
@onready var prop_book: TextureRect = %PropBook
@onready var prop_pencil: TextureRect = %PropPencil
@onready var prop_bag: TextureRect = %PropBag

var _buttons: Array[Button] = []
var _button_initial_x: Dictionary = {}
var _prop_origins: Dictionary = {}


func _ready() -> void:
	how_to_panel.visible = false
	best_label.text = BEST_FORMAT % GameState.best_campaign
	
	campaign_button.pressed.connect(_on_campaign_pressed)
	endless_button.pressed.connect(_on_endless_pressed)
	how_to_button.pressed.connect(_on_how_to_pressed)
	back_button.pressed.connect(_on_how_to_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_panel.closed.connect(_on_settings_closed)
	shop_button.pressed.connect(_on_shop_pressed)
	shop_panel.closed.connect(_on_shop_closed)
	quit_button.pressed.connect(_on_quit_pressed)

	_buttons = [campaign_button, endless_button, how_to_button, shop_button, settings_button, quit_button]
	for btn in _buttons:
		_setup_button_effects(btn)
	
	_setup_props()
	_start_ambient_animations()
	
	campaign_button.grab_focus()


func _setup_button_effects(btn: Button) -> void:
	btn.pivot_offset = Vector2(0, btn.custom_minimum_size.y * 0.5)
	_button_initial_x[btn] = btn.position.x
	
	btn.mouse_entered.connect(func(): _animate_button_hover(btn, true))
	btn.mouse_exited.connect(func(): _animate_button_hover(btn, false))
	btn.focus_entered.connect(func(): _animate_button_hover(btn, true))
	btn.focus_exited.connect(func(): _animate_button_hover(btn, false))


func _animate_button_hover(btn: Button, is_hovered: bool) -> void:
	if btn.disabled:
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovered:
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.16)
		tw.tween_property(btn, "modulate", Color(1.15, 1.15, 1.15), 0.16)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.2)
		tw.tween_property(btn, "modulate", Color.WHITE, 0.2)


func _setup_props() -> void:
	var props = [prop_book, prop_pencil, prop_bag]
	for p in props:
		if p:
			_prop_origins[p] = p.position


func _start_ambient_animations() -> void:
	# Subtle floating bob for Title & Urgency Pill
	if title_label:
		var title_tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		title_tw.tween_property(title_label, "position:y", title_label.position.y - 6.0, 1.6)
		title_tw.tween_property(title_label, "position:y", title_label.position.y + 2.0, 1.6)
		
	if tag_pill:
		var pill_tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pill_tw.tween_property(tag_pill, "rotation_degrees", -4.0, 1.2)
		pill_tw.tween_property(tag_pill, "rotation_degrees", 4.0, 1.2)

	# Drifting stationery props
	var props = [prop_book, prop_pencil, prop_bag]
	var delays = [0.0, 0.5, 1.0]
	for i in range(props.size()):
		var p: TextureRect = props[i]
		if not p:
			continue
		var base_y := p.position.y
		var prop_tw := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		prop_tw.tween_property(p, "position:y", base_y - 12.0, 2.0 + i * 0.4)
		prop_tw.tween_property(p, "position:y", base_y + 8.0, 2.0 + i * 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if how_to_panel.visible and event.is_action_pressed("ui_cancel"):
		_on_how_to_pressed()
		get_viewport().set_input_as_handled()


func _on_campaign_pressed() -> void:
	GameState.mode = GameConfig.RunMode.CAMPAIGN
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_endless_pressed() -> void:
	GameState.mode = GameConfig.RunMode.ENDLESS
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_how_to_pressed() -> void:
	how_to_panel.visible = not how_to_panel.visible
	if how_to_panel.visible:
		back_button.grab_focus()
	else:
		campaign_button.grab_focus()


## Open the settings panel. The how-to overlay closes first so the two
## overlays never stack.
func _on_settings_pressed() -> void:
	if how_to_panel.visible:
		_on_how_to_pressed()
	settings_panel.open()


## Back out of settings and hand focus to the button that opened it.
func _on_settings_closed() -> void:
	settings_button.grab_focus()


## Open the school store. The how-to overlay closes first so the two
## overlays never stack.
func _on_shop_pressed() -> void:
	if how_to_panel.visible:
		_on_how_to_pressed()
	shop_panel.open()


## Back out of the store and hand focus to the button that opened it.
func _on_shop_closed() -> void:
	shop_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
