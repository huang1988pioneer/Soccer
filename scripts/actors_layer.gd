class_name ActorsLayer
extends Node2D

## Live match actors: players, ball, particles, aim guides.

var host
var _badge_style: StyleBoxFlat
var _sprite_size_cache: Dictionary = {}


func bind(main: Node) -> void:
	host = main
	_badge_style = UIKit.style_box(Color("#fff0a4"), Color.TRANSPARENT, 7)


func _draw() -> void:
	if host == null or not host.game_active:
		return
	if host.game_mode == "penalty":
		_draw_penalty_mode()
		return
	for player in host.players:
		_draw_player(player)
	host.fx.draw_on(self)
	_draw_ball()
	if host.move_target_active:
		_draw_move_target()
	if host.shoot_charging:
		_draw_aim_guide()


func _draw_penalty_mode() -> void:
	var shooter: SoccerPlayer = host.user_player()
	var keeper: SoccerPlayer = host.get_player("red-keeper")
	if shooter != null:
		_draw_player(shooter)
	if keeper != null:
		if host.penalty_shot_active:
			_draw_goalkeeper_dive(keeper)
		else:
			_draw_player(keeper)
	var target_y: float = host.penalty_shot_target.y if host.penalty_shot_active else clampf(360.0 + host.penalty_aim * 112.0, GameConst.GOAL_TOP + 18.0, GameConst.GOAL_BOTTOM - 18.0)
	var target := Vector2(GameConst.PITCH.end.x - 22.0, target_y)
	var ball_position: Vector2 = host.ball.pos()
	if not host.penalty_shot_active:
		draw_dashed_line(ball_position, target, Color("#ffdf73", 0.84), 4.0, 10.0)
		draw_circle(target, 17.0 + sin(GameConst.now() * 5.0) * 2.0, Color("#ffe275", 0.12))
		draw_arc(target, 17.0, 0, TAU, 32, Color("#ffe275", 0.9), 3.0)
		draw_line(target + Vector2(-9, 0), target + Vector2(9, 0), Color("#fff6c2"), 2.0)
		draw_line(target + Vector2(0, -9), target + Vector2(0, 9), Color("#fff6c2"), 2.0)
	else:
		draw_circle(target, 13.0, Color("#9fe8ff", 0.25))
	host.fx.draw_on(self)
	_draw_ball()


func _draw_aim_guide() -> void:
	var player: SoccerPlayer = host.user_player()
	if player == null:
		return
	var charge: float = clampf(float(Time.get_ticks_msec() - int(host.shoot_started_at)) / 1000.0, 0.0, 1.0)
	var direction := Vector2(cos(player.facing), sin(player.facing)).normalized()
	var from := player.pos() + direction * 32.0
	var to := from + direction * (180.0 + charge * 350.0)
	draw_dashed_line(from, to, Color(1.0, 0.88, 0.35, 0.52 + charge * 0.4), 5.0, 12.0)
	draw_circle(from.lerp(to, 0.35 + charge * 0.2), 6.0 + charge * 6.0, Color("#ffdc5e"))


func _draw_move_target() -> void:
	var pulse := 1.0 + sin(GameConst.now() * 6.0) * 0.12
	draw_circle(host.move_target, 18.0 * pulse, Color("#74e6ff", 0.12))
	draw_arc(host.move_target, 14.0 * pulse, 0.0, TAU, 32, Color("#8deaff", 0.9), 2.0)
	draw_line(host.move_target + Vector2(-7, 0), host.move_target + Vector2(7, 0), Color("#dffbff", 0.9), 2.0)
	draw_line(host.move_target + Vector2(0, -7), host.move_target + Vector2(0, 7), Color("#dffbff", 0.9), 2.0)


func _draw_player(player: SoccerPlayer) -> void:
	var position := player.pos()
	var owner: bool = host.ball.owner_id == player.id
	position.y += sin(GameConst.now() * 3.8 + player.pulse) * (1.9 if owner else 0.8)
	_draw_oval(position + Vector2(0, 27), Vector2(33, 11), Color("#05271f", 0.42))
	if player.controlled:
		draw_arc(position + Vector2(0, 3), 38.0 + sin(GameConst.now() * 6.0) * 2.0, 0, TAU, 48, Color("#ffe266", 0.95), 3.0)
		draw_style_box(_badge_style, Rect2(position + Vector2(-20, -51), Vector2(40, 17)))
		draw_string(ThemeDB.fallback_font, position + Vector2(-20, -38), "1P", HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color("#31548c"))
	match player.kind:
		"captain":
			_draw_generated_player(host.captain_player_texture, position, owner)
		"calico":
			_draw_generated_player(host.calico_player_texture, position, owner)
		"whitecat":
			_draw_generated_player(host.white_player_texture, position, owner)
		"redcat":
			_draw_generated_player(host.red_player_texture, position, owner)
		"mascot":
			var sprite_size := Vector2(98, 110) if owner else Vector2(88, 99)
			draw_texture_rect(host.mascot_texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * 0.86), sprite_size), false)
		_:
			_draw_vector_player(player, position, owner)
	draw_string(ThemeDB.fallback_font, position + Vector2(-50, 46), player.display_name, HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color("#eaf8ff"))


func _draw_generated_player(texture: Texture2D, position: Vector2, owner: bool) -> void:
	if texture == null:
		return
	var cache_key := "%s-%s" % [texture.get_rid().get_id(), owner]
	var sprite_size: Vector2
	if _sprite_size_cache.has(cache_key):
		sprite_size = _sprite_size_cache[cache_key]
	else:
		var max_width := 102.0 if owner else 92.0
		var max_height := 132.0 if owner else 118.0
		var texture_size := texture.get_size()
		sprite_size = texture_size * minf(max_width / texture_size.x, max_height / texture_size.y)
		_sprite_size_cache[cache_key] = sprite_size
	draw_texture_rect(texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * 0.86), sprite_size), false)


func _draw_goalkeeper_dive(keeper: SoccerPlayer) -> void:
	var position := keeper.pos()
	var bob := sin(GameConst.now() * 4.0) * 0.8
	_draw_oval(position + Vector2(0, 27), Vector2(43, 12), Color("#05271f", 0.42))
	var sprite_size := Vector2(132, 88)
	draw_texture_rect(host.goalkeeper_dive_texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * 0.72) + Vector2(0, bob), sprite_size), false)


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radius)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_vector_player(player: SoccerPlayer, position: Vector2, owner: bool) -> void:
	var body := Color("#f4f6ff")
	var shirt := Color("#e7eaf5")
	var trim := Color("#7cb8f7")
	var ear := Color("#ffc3c9")
	if player.kind == "calico":
		body = Color("#e99659")
		shirt = Color("#134c90")
		trim = Color("#ffdb79")
		ear = Color("#ffb18d")
	if player.team == GameConst.RED:
		body = Color("#a96d55")
		shirt = Color("#9b304e")
		trim = Color("#ffab6f")
		ear = Color("#e89e87")
	if owner:
		draw_circle(position, 30.0, Color("#67d9ff", 0.18) if player.team == GameConst.BLUE else Color("#ff7e65", 0.18))
	_draw_oval(position + Vector2(0, 9), Vector2(24, 26), shirt)
	draw_rect(Rect2(position + Vector2(-3, -11), Vector2(6, 31)), trim)
	draw_circle(position + Vector2(0, -14), 22, body)
	draw_colored_polygon(PackedVector2Array([position + Vector2(-18, -26), position + Vector2(-14, -47), position + Vector2(-2, -32)]), ear)
	draw_colored_polygon(PackedVector2Array([position + Vector2(18, -26), position + Vector2(14, -47), position + Vector2(2, -32)]), ear)
	draw_circle(position + Vector2(-8, -15), 3.5, Color("#1a2140"))
	draw_circle(position + Vector2(8, -15), 3.5, Color("#1a2140"))
	draw_circle(position + Vector2(0, -6), 3, Color("#f6b3b3"))
	draw_string(ThemeDB.fallback_font, position + Vector2(-20, 13), str(player.number), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)


func _draw_ball() -> void:
	var ball: SoccerBall = host.ball
	var position := ball.pos()
	_draw_oval(position + Vector2(4, 12), Vector2(18, 7), Color("#05291e", 0.28))
	if ball.has_owner():
		draw_circle(position, 29, Color("#70e0ff", 0.20) if ball.last_touch == GameConst.BLUE else Color("#ff7e65", 0.2))
	draw_circle(position, 14, Color("#fbfdff"))
	draw_arc(position, 14, 0, TAU, 30, Color("#172847"), 2)
	draw_circle(position, 5, Color("#182a4b"))
	for i in 5:
		var angle := float(i) * TAU / 5.0 + 0.28
		draw_line(position + Vector2(cos(angle), sin(angle)) * 5.0, position + Vector2(cos(angle), sin(angle)) * 11.0, Color("#182a4b"), 2)
	var selected: SoccerPlayer = host.user_player()
	if host.shoot_charging and selected != null and ball.owner_id == selected.id:
		var charge: float = clampf(float(Time.get_ticks_msec() - int(host.shoot_started_at)) / 1000.0, 0.0, 1.0)
		_draw_action_icon(host.action_shoot_texture, position, 68.0 + charge * 18.0, 0.72)
	elif host.shoot_fx_timer > 0.0:
		_draw_action_icon(host.action_shoot_texture, position, 92.0, clampf(host.shoot_fx_timer / 0.24, 0.0, 1.0))
	if host.skill_fx_timer > 0.0:
		_draw_action_icon(host.action_skill_texture, position, 126.0 + (1.0 - clampf(host.skill_fx_timer / 0.65, 0.0, 1.0)) * 18.0, clampf(host.skill_fx_timer / 0.65, 0.0, 1.0))


func _draw_action_icon(texture: Texture2D, center: Vector2, size: float, alpha: float) -> void:
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale := minf(size / texture_size.x, size / texture_size.y)
	var draw_size := texture_size * scale
	draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, alpha))
