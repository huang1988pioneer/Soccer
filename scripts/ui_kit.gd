class_name UIKit
extends RefCounted

## Shared Control factories so menu / match HUD stay visually consistent.


static func full_control() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


static func style_box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func panel(parent: Node, rect: Rect2, color: Color = GameConst.PANEL_BLUE, radius: int = 18) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style_box(color, GameConst.PANEL_BORDER, radius))
	parent.add_child(node)
	return node


static func label(parent: Node, text_value: String, position: Vector2, size: Vector2, font_size: int = 16, color: Color = GameConst.TEXT_MAIN) -> Label:
	var node := Label.new()
	node.text = text_value
	node.position = position
	node.size = size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(node)
	return node


static func button(parent: Node, text_value: String, rect: Rect2, primary := false) -> Button:
	var node := Button.new()
	node.text = text_value
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 16 if primary else 14)
	node.add_theme_color_override("font_color", Color("#061832") if primary else GameConst.TEXT_MAIN)
	node.add_theme_color_override("font_hover_color", Color("#061832") if primary else Color.WHITE)
	var normal_color := Color("#ffb34e") if primary else Color("#133e76", 0.86)
	var hover_color := Color("#ffcf63") if primary else Color("#1b5b9a")
	node.add_theme_stylebox_override("normal", style_box(normal_color, Color("#ffdf85", 0.55) if primary else GameConst.PANEL_BORDER, 13))
	node.add_theme_stylebox_override("hover", style_box(hover_color, Color("#fff0a8", 0.8) if primary else Color("#82dfff", 0.72), 13))
	node.add_theme_stylebox_override("pressed", style_box(Color("#e1873f") if primary else Color("#0b315e"), Color("#fff0a8", 0.8), 13))
	parent.add_child(node)
	return node


static func decorate_action_button(action_button: Button, label_text: String, texture: Texture2D) -> Dictionary:
	action_button.text = ""
	var icon := TextureRect.new()
	icon.texture = texture
	icon.position = Vector2((action_button.size.x - 38.0) * 0.5, 2.0)
	icon.size = Vector2(38.0, 38.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_button.add_child(icon)
	var caption := label(action_button, label_text, Vector2(0.0, action_button.size.y - 20.0), Vector2(action_button.size.x, 17.0), 10, GameConst.TEXT_MAIN)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"icon": icon, "label": caption}


static func tint_button(action_button: Button, normal: Color, hover: Color) -> void:
	action_button.add_theme_stylebox_override("normal", style_box(normal, Color("#9aeaff", 0.42), 11))
	action_button.add_theme_stylebox_override("hover", style_box(hover, Color("#fff0b0", 0.72), 11))
	action_button.add_theme_stylebox_override("pressed", style_box(normal.darkened(0.2), Color("#fff0b0", 0.85), 11))


static func mode_card_button(parent: Node, texture: Texture2D, title: String, subtitle: String, rect: Rect2, locked: bool = false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = ""
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_color_override("font_color", Color.TRANSPARENT)
	node.add_theme_stylebox_override("normal", style_box(Color("#0b2a5a", 0.86), GameConst.PANEL_BORDER, 11))
	node.add_theme_stylebox_override("hover", style_box(Color("#195388", 0.9), Color("#9aeaff", 0.72), 11))
	node.add_theme_stylebox_override("pressed", style_box(Color("#0d315f", 0.96), Color("#fff0b0", 0.84), 11))
	var art := TextureRect.new()
	art.texture = texture
	art.position = Vector2.ZERO
	art.size = rect.size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1.0, 1.0, 1.0, 0.9 if not locked else 0.66)
	node.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#03142e", 0.78 if not locked else 0.86)
	shade.position = Vector2(0.0, rect.size.y - 34.0)
	shade.size = Vector2(rect.size.x, 34.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(shade)
	label(node, title, Vector2(8, rect.size.y - 32), Vector2(rect.size.x - 16, 16), 10, GameConst.TEXT_MAIN)
	label(node, subtitle, Vector2(8, rect.size.y - 17), Vector2(rect.size.x - 16, 14), 8, Color("#c5def4"))
	if locked:
		var lock := label(node, "LOCKED", Vector2(rect.size.x - 53, 7), Vector2(46, 14), 7, Color("#e1edff"))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(node)
	return node
