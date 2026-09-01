class_name SoccerPlayer
extends RefCounted

var id: String = ""
var team: String = ""
var display_name: String = ""
var role: String = ""
var kind: String = ""
var x: float = 0.0
var y: float = 0.0
var home_x: float = 0.0
var home_y: float = 0.0
var vx: float = 0.0
var vy: float = 0.0
var facing: float = 0.0
var speed: float = 0.0
var stamina: float = 100.0
var controlled: bool = false
var pulse: float = 0.0
var action_cd: float = 0.0
var number: int = 8


func pos() -> Vector2:
	return Vector2(x, y)


func home() -> Vector2:
	return Vector2(home_x, home_y)


func distance_to(point: Vector2) -> float:
	return pos().distance_to(point)


func reset_to_home() -> void:
	x = home_x
	y = home_y
	vx = 0.0
	vy = 0.0
	stamina = 100.0
	facing = 0.0 if team == GameConst.BLUE else PI


func keep_on_pitch() -> void:
	x = clampf(x, GameConst.PITCH.position.x + GameConst.PLAYER_MARGIN.x, GameConst.PITCH.end.x - GameConst.PLAYER_MARGIN.x)
	y = clampf(y, GameConst.PITCH.position.y + GameConst.PLAYER_MARGIN.y, GameConst.PITCH.end.y - GameConst.PLAYER_MARGIN.y)


func ability_text() -> String:
	match id:
		"blue-mid":
			return "精準傳球與盤帶"
		"blue-keeper":
			return "穩定撲救與回防"
		_:
			return "高速衝刺射門"


static func make(player_id: String, player_team: String, player_name: String, player_role: String, player_kind: String, start_x: float, start_y: float, start_speed: float, is_controlled := false, shirt_number := 8) -> SoccerPlayer:
	var player := SoccerPlayer.new()
	player.id = player_id
	player.team = player_team
	player.display_name = player_name
	player.role = player_role
	player.kind = player_kind
	player.x = start_x
	player.y = start_y
	player.home_x = start_x
	player.home_y = start_y
	player.speed = start_speed
	player.controlled = is_controlled
	player.facing = 0.0 if player_team == GameConst.BLUE else PI
	player.pulse = randf_range(0.0, TAU)
	player.action_cd = randf_range(0.5, 1.6)
	player.number = shirt_number
	return player


static func default_lineup(selected_id: String) -> Array[SoccerPlayer]:
	var list: Array[SoccerPlayer] = []
	list.append(make("blue-captain", GameConst.BLUE, "喵白白", "前鋒", "captain", 310, 360, 265, selected_id == "blue-captain", 10))
	list.append(make("blue-mid", GameConst.BLUE, "喵布布", "中場", "calico", 236, 235, 224, selected_id == "blue-mid", 8))
	list.append(make("blue-keeper", GameConst.BLUE, "喵小白", "守門", "whitecat", 120, 360, 190, selected_id == "blue-keeper", 1))
	list.append(make("red-striker", GameConst.RED, "紅啵啵", "前鋒", "redcat", 970, 360, 218, false, 9))
	list.append(make("red-mid", GameConst.RED, "小栗子", "中場", "redcat", 1040, 235, 205, false, 7))
	list.append(make("red-keeper", GameConst.RED, "守門喵", "守門", "redcat", 1160, 360, 180, false, 1))
	return list
