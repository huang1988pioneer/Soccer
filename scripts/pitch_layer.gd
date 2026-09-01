class_name PitchLayer
extends Node2D

## Static stadium + pitch. Drawn once per match start instead of every frame.

var background: Texture2D
var crowd: Array[Dictionary] = []


func configure(background_texture: Texture2D, crowd_people: Array[Dictionary]) -> void:
	background = background_texture
	crowd = crowd_people
	queue_redraw()


func _draw() -> void:
	var world := GameConst.WORLD_SIZE
	var pitch := GameConst.PITCH
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, world), false)
	draw_rect(Rect2(Vector2.ZERO, world), Color("#06152f", 0.22))
	draw_rect(Rect2(0, 0, world.x, 78), Color("#04152f", 0.32))
	for person in crowd:
		draw_circle(Vector2(float(person.x), float(person.y)), float(person.r), person.color)
	draw_rect(Rect2(0, 43, world.x, 9), Color("#04172e", 0.36))
	draw_rect(Rect2(0, world.y - 50, world.x, 9), Color("#04172e", 0.44))

	draw_rect(pitch, Color("#198354"))
	for i in 12:
		var stripe := Rect2(pitch.position.x + float(i) * 100.0, pitch.position.y, 100.0, pitch.size.y)
		draw_rect(stripe, Color("#53c37e", 0.12) if i % 2 == 0 else Color("#063e2b", 0.08))
	draw_rect(pitch, Color("#eafff1", 0.88), false, 4.0)
	draw_line(Vector2(640, pitch.position.y), Vector2(640, pitch.end.y), Color("#eafff1", 0.78), 3.0)
	draw_arc(Vector2(640, 360), 86, 0, TAU, 64, Color("#eafff1", 0.78), 3.0)
	draw_circle(Vector2(640, 360), 4, Color("#eafff1"))
	_draw_penalty_box(true)
	_draw_penalty_box(false)
	draw_arc(Vector2(212, 360), 70, -PI / 2, PI / 2, 40, Color("#eafff1", 0.55), 2.0)
	draw_arc(Vector2(1068, 360), 70, PI / 2, PI * 1.5, 40, Color("#eafff1", 0.55), 2.0)

	for left in [true, false]:
		var x := pitch.position.x - 3.0 if left else pitch.end.x + 3.0
		var direction := -1.0 if left else 1.0
		var points := PackedVector2Array([
			Vector2(x, GameConst.GOAL_TOP),
			Vector2(x + direction * 45.0, GameConst.GOAL_TOP),
			Vector2(x + direction * 45.0, GameConst.GOAL_BOTTOM),
			Vector2(x, GameConst.GOAL_BOTTOM)
		])
		draw_polyline(points, Color("#effaff", 0.9), 6.0)
		for y in range(int(GameConst.GOAL_TOP + 14), int(GameConst.GOAL_BOTTOM), 18):
			draw_line(Vector2(x, y), Vector2(x + direction * 45.0, y), Color("#d8f1ff", 0.25), 2.0)


func _draw_penalty_box(left: bool) -> void:
	var pitch := GameConst.PITCH
	var x := pitch.position.x if left else pitch.end.x - 164.0
	draw_rect(Rect2(x, 215, 164, 290), Color("#eafff1", 0.72), false, 3.0)
	var small_x := pitch.position.x if left else pitch.end.x - 74.0
	draw_rect(Rect2(small_x, 284, 74, 152), Color("#eafff1", 0.72), false, 3.0)
