class_name BallOverlay
extends Control

## Draws the live ball above match HUD panels so it never disappears under UI.

var host


func bind(main: Node) -> void:
	host = main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if host == null or not host.game_active:
		return
	if host.actors_layer == null:
		return
	host.actors_layer.draw_ball_on(self)
