class_name GreenButton
extends TextureButton
## Green atlas button: the plain face tile with a glyph tile on top.
##
## Shared by the control rail and the settings card so every green button in the
## interface is built the same way - same face art, same glyph padding, same
## crisp pixel filtering - instead of each screen inventing its own.

## Build a button of [param button_size] px with a centred glyph of
## [param icon_size] px.
static func create(glyph: Vector2i, button_size: float, icon_size: float) -> GreenButton:
	var button := GreenButton.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Mouse/touch only: never grab keyboard focus, so Space (the jump key)
	# cannot activate a rail button while the player is running.
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(button_size, button_size)
	var face := GameConfig.ui_tile(GameConfig.UI_BUTTON_FACE_TILE)
	button.texture_normal = face
	button.texture_hover = face
	button.texture_pressed = face
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = GameConfig.ui_tile(glyph)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -icon_size * 0.5
	icon.offset_top = -icon_size * 0.5
	icon.offset_right = icon_size * 0.5
	icon.offset_bottom = icon_size * 0.5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(icon)
	return button


## Swap the glyph shown on the face, keeping the button's size and face art.
func set_glyph(glyph: Vector2i) -> void:
	var icon := get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.texture = GameConfig.ui_tile(glyph)
