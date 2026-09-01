class_name SoccerBall
extends RefCounted

var x: float = 640.0
var y: float = 360.0
var vx: float = 0.0
var vy: float = 0.0
var r: float = 14.0
var owner_id: String = ""
var last_touch: String = GameConst.BLUE
var no_claim_until: float = 0.0


func pos() -> Vector2:
	return Vector2(x, y)


func has_owner() -> bool:
	return not owner_id.is_empty()


func reset(kickoff := true) -> void:
	x = GameConst.WORLD_SIZE.x * 0.5
	y = GameConst.WORLD_SIZE.y * 0.5
	vx = 0.0 if kickoff else randf_range(-40.0, 40.0)
	vy = 0.0
	owner_id = ""
	no_claim_until = GameConst.now() + 0.55


func attach_to(owner: SoccerPlayer) -> void:
	var facing := Vector2(cos(owner.facing), sin(owner.facing))
	if facing.length_squared() < 0.01:
		facing = Vector2.RIGHT if owner.team == GameConst.BLUE else Vector2.LEFT
	else:
		facing = facing.normalized()
	x = owner.x + facing.x * GameConst.BALL_HOLD_DISTANCE
	y = owner.y + facing.y * GameConst.BALL_HOLD_DISTANCE + 8.0
	vx = owner.vx
	vy = owner.vy


func release(velocity: Vector2, source_team: String, claim_lock := 0.55) -> void:
	owner_id = ""
	vx = velocity.x
	vy = velocity.y
	last_touch = source_team
	no_claim_until = GameConst.now() + claim_lock
