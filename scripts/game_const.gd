class_name GameConst
extends Object

## Shared layout, team ids and palette for the Godot match.

const WORLD_SIZE := Vector2(1280.0, 720.0)
const PITCH := Rect2(48.0, 54.0, 1184.0, 612.0)
const GOAL_TOP := 258.0
const GOAL_BOTTOM := 462.0
const BLUE := "blue"
const RED := "red"

const PANEL_BLUE := Color("#0a2b5b")
const PANEL_BORDER := Color("#4b8fc3", 0.48)
const TEXT_MAIN := Color("#f4f8ff")
const TEXT_MUTED := Color("#9ab3d5")
const GOLD := Color("#ffd266")

const PLAYER_MARGIN := Vector2(23.0, 24.0)
const BALL_CLAIM_RADIUS := 72.0
const TACKLE_RADIUS := 112.0
const BALL_HOLD_DISTANCE := 56.0
const BALL_VISUAL_RADIUS := 16.0
const GOAL_LINE_DEPTH := 22.0
const BUMP_RADIUS := 45.0


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func mode_label(mode: String) -> String:
	match mode:
		"penalty":
			return "點球挑戰"
		"tournament":
			return "錦標賽"
		_:
			return "快速賽"
