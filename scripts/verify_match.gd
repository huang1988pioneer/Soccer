extends SceneTree

## Headless checks for live-ball visibility helpers, shooting, tackling, and goals.

var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn")
	if packed == null:
		_fail("Main.tscn failed to load")
		_finish()
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if not main.has_method("_start_match"):
		_fail("Main is missing _start_match")
		_finish()
		return
	main.call("_start_match")
	await process_frame
	_check_ball_hold(main)
	_check_shoot_travels(main)
	_check_goal_line(main)
	_check_tackle(main)
	_check_overlay(main)
	_finish()


func _check_ball_hold(main: Node) -> void:
	var player: SoccerPlayer = main.call("user_player")
	if player == null:
		_fail("user_player() is null")
		return
	player.facing = 0.0
	player.x = 400.0
	player.y = 360.0
	var ball: SoccerBall = main.ball
	ball.attach_to(player)
	var offset := ball.pos() - player.pos()
	if offset.length() < 50.0:
		_fail("held ball offset too small: %.1f (sprite will hide it)" % offset.length())
	if offset.x < 40.0:
		_fail("held ball is not clearly in front of the player: %s" % offset)


func _check_shoot_travels(main: Node) -> void:
	main.call("_reset_positions", true)
	var player: SoccerPlayer = main.call("user_player")
	player.x = 640.0
	player.y = 360.0
	player.facing = 0.0
	player.vx = 0.0
	player.vy = 0.0
	var ball: SoccerBall = main.ball
	ball.owner_id = player.id
	ball.attach_to(player)
	var start_x: float = ball.x
	main.shoot_charging = false
	main.call("_begin_shoot")
	if not bool(main.shoot_charging):
		_fail("shoot did not start while the user had the ball")
		return
	main.shoot_started_at = Time.get_ticks_msec() - 900
	main.call("_finish_shoot")
	if ball.has_owner():
		_fail("shoot left the ball attached to a player")
		return
	for _i in 90:
		main.call("_update_ball", 1.0 / 60.0)
	if ball.x - start_x < 220.0:
		_fail("shot travelled only %.1f px; expected a real shot down the pitch" % (ball.x - start_x))


func _check_goal_line(main: Node) -> void:
	main.call("_reset_positions", true)
	main.player_score = 0
	main.cpu_score = 0
	main.goal_lock = false
	main.paused = false
	var ball: SoccerBall = main.ball
	ball.owner_id = ""
	ball.x = 1180.0
	ball.y = 360.0
	ball.vx = 720.0
	ball.vy = 0.0
	ball.no_claim_until = GameConst.now() + 8.0
	for _i in 90:
		if bool(main.goal_lock):
			break
		main.call("_update_ball", 1.0 / 60.0)
	if int(main.player_score) < 1:
		_fail("shot into the net did not count as a goal (ball x=%.1f lock=%s)" % [ball.x, main.goal_lock])


func _check_tackle(main: Node) -> void:
	main.goal_lock = false
	main.paused = false
	main.game_active = true
	main.call("_reset_positions", true)
	var user: SoccerPlayer = main.call("user_player")
	var rival: SoccerPlayer = main.call("get_player", "red-striker")
	if rival == null:
		_fail("missing red striker")
		return
	user.x = 500.0
	user.y = 360.0
	rival.x = 590.0
	rival.y = 360.0
	var ball: SoccerBall = main.ball
	ball.owner_id = rival.id
	ball.last_touch = GameConst.RED
	ball.attach_to(rival)
	main.call("_tackle")
	if ball.owner_id != user.id:
		_fail("tackle in range did not steal the ball (owner=%s dist=%.1f)" % [ball.owner_id, user.distance_to(rival.pos())])


func _check_overlay(main: Node) -> void:
	var overlay = main.get("ball_overlay")
	if overlay == null:
		_fail("ball overlay was not created")
		return
	if not (overlay is CanvasItem):
		_fail("ball overlay is not drawable")


func _fail(message: String) -> void:
	failures.append(message)
	push_error("VERIFY " + message)


func _finish() -> void:
	if failures.is_empty():
		print("VERIFY_OK shoot/tackle/goal/ball-hold")
		quit(0)
	else:
		print("VERIFY_FAIL %d" % failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
