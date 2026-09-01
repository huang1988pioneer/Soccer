extends Node2D

## 喵咪足球大戰
## Godot 4 零外掛 2D 3v3：主場景負責流程與模擬，繪製拆到 PitchLayer / ActorsLayer。

const WORLD_SIZE := GameConst.WORLD_SIZE
const PITCH := GameConst.PITCH
const GOAL_TOP := GameConst.GOAL_TOP
const GOAL_BOTTOM := GameConst.GOAL_BOTTOM
const BLUE := GameConst.BLUE
const RED := GameConst.RED

var mascot_texture: Texture2D = preload("res://assets/maomao-mascot.png")
var menu_background_texture: Texture2D = preload("res://assets/generated/menu-stadium-background-v2.png")
var hero_action_texture: Texture2D = preload("res://assets/generated/hero-action-v2.png")
var teammates_texture: Texture2D = preload("res://assets/generated/cat-teammates-v2.png")
var captain_player_texture: Texture2D = preload("res://assets/generated/character-maid-captain-v1.png")
var calico_player_texture: Texture2D = preload("res://assets/generated/character-calico-midfielder-v1.png")
var white_player_texture: Texture2D = preload("res://assets/generated/character-white-goalkeeper-v1.png")
var special_shot_texture: Texture2D = preload("res://assets/generated/special-shot-v2.png")
var goal_effect_texture: Texture2D = preload("res://assets/generated/goal-effect-v2.png")
var match_background_texture: Texture2D = preload("res://assets/generated/match-stadium-background-v2.png")
var red_player_texture: Texture2D = preload("res://assets/generated/character-red-rival-v1.png")
var goalkeeper_dive_texture: Texture2D = preload("res://assets/generated/goalkeeper-dive-v2.png")
var trophy_texture: Texture2D = preload("res://assets/generated/trophy-badge-v2.png")
var main_cast_lineup_texture: Texture2D = preload("res://assets/generated/main-cast-lineup-v1.png")
var goal_celebration_texture: Texture2D = preload("res://assets/generated/goal-celebration-card-v3.png")
var mode_quick_texture: Texture2D = preload("res://assets/generated/mode-quick-match-v1.png")
var mode_tournament_texture: Texture2D = preload("res://assets/generated/mode-tournament-v1.png")
var mode_story_texture: Texture2D = preload("res://assets/generated/mode-story-v1.png")
var mode_penalty_texture: Texture2D = preload("res://assets/generated/mode-penalty-challenge-v1.png")
var tournament_trophy_texture: Texture2D = preload("res://assets/generated/tournament-trophy-v1.png")
var action_pass_texture: Texture2D = preload("res://assets/generated/action-pass-icon-v1.png")
var action_shoot_texture: Texture2D = preload("res://assets/generated/action-shoot-icon-v1.png")
var action_dash_texture: Texture2D = preload("res://assets/generated/action-dash-icon-v1.png")
var action_tackle_texture: Texture2D = preload("res://assets/generated/action-tackle-icon-v1.png")
var action_skill_texture: Texture2D = preload("res://assets/generated/action-skill-icon-v1.png")

var players: Array[SoccerPlayer] = []
var player_by_id: Dictionary = {}
var blue_players: Array[SoccerPlayer] = []
var red_players: Array[SoccerPlayer] = []
var ball := SoccerBall.new()
var fx := ParticleFx.new()
var crowd: Array[Dictionary] = []

var game_active := false
var game_mode := "quick"
var selected_player_id := "blue-captain"
var paused := false
var goal_lock := false
var final_match := false
var player_score := 0
var cpu_score := 0
var time_left := 120.0
var skill := 42.0
var shots := 0
var passes := 0
var blue_touches := 0
var red_touches := 0
var possession_blue := 50
var combo := 1
var combo_timer := 0.0
var shoot_charging := false
var shoot_started_at := 0
var shoot_fx_timer := 0.0
var skill_fx_timer := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var toast_timer := 0.0
var penalty_round := 0
var penalty_goal := false
var penalty_aim := 0.0
var penalty_keeper_target_y := 360.0
var penalty_shot_timer := 0.0
var penalty_shot_duration := 0.58
var penalty_shot_start := Vector2.ZERO
var penalty_shot_target := Vector2.ZERO
var penalty_shot_active := false
var tournament_round := 0
var tournament_wins := 0
var tournament_losses := 0
var tournament_round_complete := false
var move_target := Vector2.ZERO
var move_target_active := false

var pitch_layer: PitchLayer
var actors_layer: ActorsLayer
var ball_overlay: BallOverlay
var ui_layer: CanvasLayer
var menu_ui: Control
var match_ui: Control
var help_overlay: Control
var pause_overlay: Control
var goal_overlay: Control
var toast_panel: Panel
var toast_label: Label
var hud: Dictionary = {}
var pause_button: Button
var goal_continue_button: Button
var aim_label: Label
var footer_hint_label: Label
var action_buttons: Dictionary = {}
var action_labels: Dictionary = {}
var action_icons: Dictionary = {}
var match_header_label: Label
var match_mode_label: Label
var captain_portrait_sprite: Sprite2D
var captain_name_label: Label
var captain_role_label: Label
var team_row_labels: Array = []
var team_row_buttons: Array = []
var roster_rows: Dictionary = {}
var menu_mascot: Sprite2D
var menu_teammates_art: Sprite2D
var menu_hero_art: TextureRect
var special_shot_art: Sprite2D
var goal_effect_art: Sprite2D
var goal_celebration_art: TextureRect

var panel_blue := GameConst.PANEL_BLUE
var panel_border := GameConst.PANEL_BORDER
var text_main := GameConst.TEXT_MAIN
var text_muted := GameConst.TEXT_MUTED
var gold := GameConst.GOLD


func _ready() -> void:
	_generate_crowd()
	_build_teams()
	pitch_layer = PitchLayer.new()
	pitch_layer.visible = false
	pitch_layer.z_index = 0
	add_child(pitch_layer)
	actors_layer = ActorsLayer.new()
	actors_layer.bind(self)
	actors_layer.visible = false
	actors_layer.z_index = 1
	add_child(actors_layer)
	_build_ui()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	shoot_fx_timer = maxf(0.0, shoot_fx_timer - delta)
	skill_fx_timer = maxf(0.0, skill_fx_timer - delta)
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and is_instance_valid(toast_panel):
			toast_panel.visible = false
	if not game_active:
		return
	if not paused and not goal_lock:
		if game_mode == "penalty":
			_update_penalty(delta)
		else:
			_update_game(delta)
	fx.update(delta)
	actors_layer.queue_redraw()
	if is_instance_valid(ball_overlay):
		ball_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_field_pointer(mouse_event.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_field_pointer(touch_event.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if game_mode == "quick" or game_mode == "tournament":
			_set_move_target(_canvas_to_world(drag_event.position))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if (game_mode == "quick" or game_mode == "tournament") and (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_set_move_target(_canvas_to_world(motion_event.position))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and key_event.pressed:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif game_mode == "penalty":
			if key_event.pressed and not key_event.echo:
				match key_event.keycode:
					KEY_A, KEY_LEFT: penalty_aim = clampf(penalty_aim - 0.12, -1.0, 1.0)
					KEY_D, KEY_RIGHT: penalty_aim = clampf(penalty_aim + 0.12, -1.0, 1.0)
					KEY_SPACE: _penalty_shoot()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_SPACE:
			if key_event.pressed and not key_event.echo:
				_begin_shoot()
			elif not key_event.pressed:
				_finish_shoot()
			get_viewport().set_input_as_handled()
		elif key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_1: _select_player("blue-captain")
				KEY_2: _select_player("blue-mid")
				KEY_3: _select_player("blue-keeper")
				KEY_E: _pass_ball()
				KEY_Q: _tackle()
				KEY_R: _use_skill()
				KEY_SHIFT: _dash()
			get_viewport().set_input_as_handled()


func _canvas_to_world(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position


func _set_move_target(world_position: Vector2) -> void:
	move_target = Vector2(
		clampf(world_position.x, PITCH.position.x + 24.0, PITCH.end.x - 24.0),
		clampf(world_position.y, PITCH.position.y + 24.0, PITCH.end.y - 24.0)
	)
	move_target_active = true


func _handle_field_pointer(viewport_position: Vector2) -> void:
	var world_position := _canvas_to_world(viewport_position)
	if not PITCH.grow(20.0).has_point(world_position):
		return
	if game_mode == "penalty":
		penalty_aim = clampf((world_position.y - WORLD_SIZE.y * 0.5) / 112.0, -1.0, 1.0)
		_show_toast("已瞄準球門落點，按射門出腳。", 0.8)
	else:
		_set_move_target(world_position)
		_show_toast("前往標記位置。", 0.65)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_build_menu_ui()
	_build_match_ui()
	_build_help_overlay()
	_build_pause_overlay()
	_build_goal_overlay()
	_build_toast()
	match_ui.visible = false


func _build_menu_ui() -> void:
	menu_ui = UIKit.full_control()
	ui_layer.add_child(menu_ui)
	var top := UIKit.panel(menu_ui, Rect2(28, 16, 1224, 58), Color("#062653", 0.88), 16)
	UIKit.label(top, "🐾", Vector2(14, 7), Vector2(35, 40), 25, gold)
	var brand := UIKit.label(top, "喵咪足球大戰", Vector2(56, 7), Vector2(250, 40), 18, text_main)
	brand.add_theme_color_override("font_shadow_color", Color("#03122d", 0.8))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	UIKit.label(top, "2D ARCADE FOOTBALL", Vector2(790, 11), Vector2(190, 18), 10, Color("#9aeaff"))
	var resources := UIKit.panel(top, Rect2(984, 7, 225, 43), Color("#031a3f", 0.78), 11)
	UIKit.label(resources, "● 12,680    ◆ 2,350    ϟ 120/120", Vector2(10, 3), Vector2(210, 35), 11, Color("#fff2b4"))

	var feature_panel := UIKit.panel(menu_ui, Rect2(28, 88, 228, 186), Color("#f6e4b8", 0.96), 18)
	feature_panel.add_theme_stylebox_override("panel", UIKit.style_box(Color("#f6e4b8", 0.96), Color("#ffe08a", 0.82), 18))
	UIKit.label(feature_panel, "遊戲特色", Vector2(16, 12), Vector2(160, 27), 17, Color("#17345b"))
	UIKit.label(feature_panel, "✦  3v3 快速對戰", Vector2(16, 50), Vector2(200, 23), 11, Color("#20385a"))
	UIKit.label(feature_panel, "⚽  Q版角色與技能系統", Vector2(16, 77), Vector2(205, 23), 11, Color("#20385a"))
	UIKit.label(feature_panel, "◉  簡單操作 · 蓄力射門", Vector2(16, 104), Vector2(205, 23), 11, Color("#20385a"))
	UIKit.label(feature_panel, "◆  多種遊戲模式", Vector2(16, 131), Vector2(205, 23), 11, Color("#20385a"))
	UIKit.label(feature_panel, "✧  角色養成與裝備", Vector2(16, 158), Vector2(205, 23), 11, Color("#20385a"))

	var roster_panel := UIKit.panel(menu_ui, Rect2(28, 288, 228, 360), Color("#07275a", 0.91), 18)
	UIKit.label(roster_panel, "可選角色", Vector2(16, 12), Vector2(160, 27), 17, text_main)
	UIKit.label(roster_panel, "3 位喵咪球員", Vector2(16, 39), Vector2(180, 18), 10, Color("#9edfff"))
	var roster := ["✦  喵白白", "●  喵布布", "◆  喵小白"]
	var roles := ["前鋒 · 速度型", "中場 · 技巧型", "守門 · 防守型"]
	var ratings := ["92", "86", "79"]
	var roster_ids := ["blue-captain", "blue-mid", "blue-keeper"]
	var roster_textures: Array[Texture2D] = [captain_player_texture, calico_player_texture, white_player_texture]
	for i in roster.size():
		var roster_id: String = roster_ids[i]
		var row := UIKit.panel(roster_panel, Rect2(14, 68 + i * 91, 200, 76), Color("#031a43", 0.72), 12)
		roster_rows[roster_id] = row
		var select_button := Button.new()
		select_button.position = Vector2.ZERO
		select_button.size = Vector2(200, 76)
		select_button.focus_mode = Control.FOCUS_NONE
		select_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		select_button.add_theme_stylebox_override("normal", UIKit.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 12))
		select_button.add_theme_stylebox_override("hover", UIKit.style_box(Color("#1d5b96", 0.18), Color("#82dfff", 0.55), 12))
		select_button.add_theme_stylebox_override("pressed", UIKit.style_box(Color("#133f79", 0.3), Color("#ffdf85", 0.78), 12))
		select_button.pressed.connect(_select_player.bind(roster_id))
		row.add_child(select_button)
		var portrait := TextureRect.new()
		portrait.texture = roster_textures[i]
		portrait.position = Vector2(7, 7)
		portrait.size = Vector2(39, 60)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		UIKit.label(row, roster[i], Vector2(53, 7), Vector2(103, 22), 12, Color("#fff4c4") if i == 0 else text_main)
		UIKit.label(row, roles[i], Vector2(53, 31), Vector2(105, 18), 9, text_muted)
		UIKit.label(row, ratings[i], Vector2(165, 8), Vector2(28, 25), 16, gold)
		UIKit.label(row, ["速度", "技巧", "防守"][i], Vector2(164, 36), Vector2(32, 16), 8, text_muted)
		var stat_bg := ColorRect.new()
		stat_bg.color = Color("#173d6b")
		stat_bg.position = Vector2(53, 58)
		stat_bg.size = Vector2(105, 6)
		stat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stat_bg)
		var stat_fill := ColorRect.new()
		stat_fill.color = Color("#ffcb55") if i == 0 else Color("#6ddaff")
		stat_fill.position = Vector2(53, 58)
		stat_fill.size = Vector2(105.0 * float(int(ratings[i])) / 100.0, 6)
		stat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(stat_fill)
	_refresh_roster_selection()

	var hero := UIKit.panel(menu_ui, Rect2(274, 88, 646, 306), Color("#0b3c77", 0.46), 24)
	hero.clip_contents = true
	menu_hero_art = TextureRect.new()
	menu_hero_art.texture = main_cast_lineup_texture
	menu_hero_art.position = Vector2(187, 0)
	menu_hero_art.size = Vector2(459, 306)
	menu_hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hero_art.modulate = Color(1.0, 1.0, 1.0, 0.92)
	menu_hero_art.z_index = 0
	hero.add_child(menu_hero_art)
	UIKit.label(hero, "2D · 3V3 · QUICK MATCH", Vector2(24, 18), Vector2(280, 22), 10, Color("#a5edff"))
	var title := UIKit.label(hero, "喵咪\n足球大戰", Vector2(24, 48), Vector2(285, 125), 43, text_main)
	title.add_theme_color_override("font_shadow_color", Color("#061328", 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	UIKit.label(hero, "和喵白白一起上場！\n跑動、碰球、蓄力射門，踢出必殺進球。", Vector2(27, 180), Vector2(270, 55), 11, Color("#d2e8ff"))
	var start := UIKit.button(hero, "⚽  開始 3v3 快速賽", Rect2(24, 244, 190, 40), true)
	start.pressed.connect(_start_match)
	var help := UIKit.button(hero, "?  操作說明", Rect2(222, 244, 130, 40), false)
	help.pressed.connect(func(): help_overlay.visible = true)
	menu_mascot = Sprite2D.new()
	menu_mascot.texture = hero_action_texture
	menu_mascot.position = Vector2(662, 244)
	menu_mascot.scale = Vector2(0.18, 0.18)
	menu_mascot.centered = true
	menu_mascot.visible = false
	menu_mascot.z_index = 2
	menu_ui.add_child(menu_mascot)
	UIKit.label(menu_ui, "●  喵白白 · 速度型前鋒", Vector2(572, 366), Vector2(215, 22), 10, Color("#f1fbff"))
	menu_teammates_art = Sprite2D.new()
	menu_teammates_art.texture = teammates_texture
	menu_teammates_art.position = Vector2(810, 548)
	menu_teammates_art.scale = Vector2(0.11, 0.11)
	menu_teammates_art.centered = true
	menu_teammates_art.modulate = Color(1.0, 1.0, 1.0, 0.94)
	menu_teammates_art.z_index = 2
	menu_ui.add_child(menu_teammates_art)

	var skill_panel := UIKit.panel(menu_ui, Rect2(760, 102, 140, 94), Color("#071f51", 0.93), 14)
	UIKit.label(skill_panel, "必殺技", Vector2(14, 9), Vector2(112, 19), 11, Color("#fff0af"))
	UIKit.label(skill_panel, "✧ 海浪射門", Vector2(14, 36), Vector2(112, 18), 10, Color("#dff8ff"))
	UIKit.label(skill_panel, "✦ 蓄力滿格", Vector2(14, 61), Vector2(112, 18), 9, Color("#8adfff"))
	special_shot_art = Sprite2D.new()
	special_shot_art.texture = special_shot_texture
	special_shot_art.position = Vector2(116, 49)
	special_shot_art.scale = Vector2(0.036, 0.036)
	special_shot_art.centered = true
	special_shot_art.modulate = Color(1.0, 1.0, 1.0, 0.9)
	special_shot_art.z_index = 2
	skill_panel.add_child(special_shot_art)

	var menu_panel := UIKit.panel(menu_ui, Rect2(946, 88, 306, 306), Color("#0a356d", 0.9), 18)
	UIKit.label(menu_panel, "主選單", Vector2(16, 12), Vector2(180, 28), 17, text_main)
	var quick_menu := UIKit.button(menu_panel, "⚽  快速比賽", Rect2(16, 51, 274, 40), true)
	quick_menu.pressed.connect(_start_match)
	var tournament := UIKit.button(menu_panel, "🏆  錦標賽", Rect2(16, 97, 274, 40), false)
	UIKit.tint_button(tournament, Color("#1766a9", 0.9), Color("#2488cf", 0.95))
	var trophy_art := Sprite2D.new()
	trophy_art.texture = trophy_texture
	trophy_art.position = Vector2(29, 20)
	trophy_art.scale = Vector2(0.027, 0.027)
	trophy_art.centered = true
	trophy_art.z_index = 2
	tournament.add_child(trophy_art)
	tournament.pressed.connect(func(): _start_match("tournament"))
	var story := UIKit.button(menu_panel, "▣  故事模式", Rect2(16, 143, 274, 40), false)
	UIKit.tint_button(story, Color("#1e8a70", 0.9), Color("#2cb38d", 0.95))
	story.pressed.connect(func(): _show_toast("故事模式正在製作中！", 1.6))
	var training := UIKit.button(menu_panel, "◆  角色養成", Rect2(16, 189, 274, 40), false)
	UIKit.tint_button(training, Color("#674eaa", 0.92), Color("#8468d0", 0.95))
	training.pressed.connect(func(): _show_toast("比賽中累積喵力值，就能解鎖必殺技。", 1.8))
	var shop := UIKit.button(menu_panel, "▤  商店", Rect2(16, 235, 274, 40), false)
	UIKit.tint_button(shop, Color("#117ea8", 0.92), Color("#1da4d0", 0.95))
	shop.pressed.connect(func(): _show_toast("商店即將開張！", 1.6))

	var preview_panel := UIKit.panel(menu_ui, Rect2(274, 408, 646, 240), Color("#083266", 0.28), 18)
	UIKit.label(preview_panel, "遊戲畫面  ·  3v3 對戰", Vector2(16, 10), Vector2(280, 25), 14, text_main)
	UIKit.label(preview_panel, "現在就來試試手感！", Vector2(438, 12), Vector2(185, 20), 9, Color("#ffe9a2"))
	UIKit.label(preview_panel, "● 喵咪隊     2       1     紅隊", Vector2(22, 193), Vector2(310, 22), 10, Color("#effaff"))
	UIKit.label(preview_panel, "01:32", Vector2(302, 193), Vector2(60, 22), 11, gold)
	var mode_panel := UIKit.panel(menu_ui, Rect2(946, 408, 306, 240), Color("#0a356d", 0.9), 18)
	UIKit.label(mode_panel, "遊戲模式", Vector2(16, 12), Vector2(180, 28), 17, text_main)
	var mode_quick := UIKit.mode_card_button(mode_panel, mode_quick_texture, "快速賽", "2:00 · 對戰 CPU", Rect2(14, 49, 132, 80))
	mode_quick.pressed.connect(_start_match)
	var mode_tournament := UIKit.mode_card_button(mode_panel, mode_tournament_texture, "錦標賽", "3 局制 · 先贏 2 局", Rect2(160, 49, 132, 80))
	mode_tournament.pressed.connect(func(): _start_match("tournament"))
	var mode_story := UIKit.mode_card_button(mode_panel, mode_story_texture, "故事模式", "島嶼冒險 · 即將開放", Rect2(14, 137, 132, 80), true)
	mode_story.pressed.connect(func(): _show_toast("故事模式正在製作中，敬請期待！", 1.7))
	var mode_penalty := UIKit.mode_card_button(mode_panel, mode_penalty_texture, "點球挑戰", "5 球制 · 瞄準射門", Rect2(160, 137, 132, 80))
	mode_penalty.pressed.connect(func(): _start_match("penalty"))
	UIKit.label(mode_panel, "✧  先拿到 3 分或時間結束時比分較高者獲勝", Vector2(16, 220), Vector2(274, 16), 7, text_muted)


func _refresh_roster_selection() -> void:
	for player_id in roster_rows.keys():
		var row: Panel = roster_rows[player_id]
		var selected: bool = str(player_id) == selected_player_id
		row.add_theme_stylebox_override("panel", UIKit.style_box(Color("#123f75", 0.92) if selected else Color("#031a43", 0.72), Color("#ffdf85", 0.82) if selected else panel_border, 12))


func _update_captain_card() -> void:
	var player := user_player()
	if player == null:
		return
	var texture: Texture2D = captain_player_texture
	match player.kind:
		"calico": texture = calico_player_texture
		"whitecat": texture = white_player_texture
		_: texture = captain_player_texture
	if is_instance_valid(captain_portrait_sprite):
		captain_portrait_sprite.texture = texture
	if is_instance_valid(captain_name_label):
		captain_name_label.text = player.display_name
	if is_instance_valid(captain_role_label):
		captain_role_label.text = player.ability_text()
	var team_ids := ["blue-captain", "blue-mid", "blue-keeper"]
	var team_ratings := [92, 86, 79]
	for i in mini(team_row_labels.size(), team_ids.size()):
		var teammate := get_player(team_ids[i])
		if teammate == null:
			continue
		var is_selected: bool = teammate.id == selected_player_id
		team_row_labels[i].text = "%d  ●  %s      %s · %s      %d" % [i + 1, teammate.display_name, teammate.role, "1P" if is_selected else "AI", int(team_ratings[i])]
		team_row_labels[i].add_theme_color_override("font_color", Color("#d3e7ff") if is_selected else text_muted)


func _set_controlled_player(player_id: String, announce := true) -> void:
	var selected := get_player(player_id)
	if selected == null or selected.team != BLUE:
		return
	if selected_player_id == player_id:
		_update_captain_card()
		return
	selected_player_id = player_id
	for player in blue_players:
		player.controlled = player.id == selected_player_id
	shoot_charging = false
	dash_timer = 0.0
	move_target_active = false
	_refresh_roster_selection()
	_update_captain_card()
	if announce:
		_show_toast("切換至 %s · %s" % [selected.display_name, selected.role], 1.2)


func _select_player(player_id: String) -> void:
	var selected := get_player(player_id)
	if selected == null or selected.team != BLUE:
		return
	if game_active:
		if game_mode == "penalty":
			_show_toast("點球挑戰固定由目前射手出腳。", 1.1)
			return
		if paused or goal_lock:
			_show_toast("比賽暫停或結算中，暫時無法切換球員。", 1.0)
			return
		_set_controlled_player(player_id, true)
		return
	selected_player_id = player_id
	for player in blue_players:
		player.controlled = player.id == selected_player_id
	_refresh_roster_selection()
	_update_captain_card()
	_show_toast("%s 已加入先發 · %s" % [selected.display_name, selected.role], 1.3)
	queue_redraw()


func _build_match_ui() -> void:
	match_ui = UIKit.full_control()
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(match_ui)
	var top := UIKit.panel(match_ui, Rect2(28, 18, 1224, 52), Color("#0a2450", 0.9), 14)
	UIKit.label(top, "●", Vector2(15, 11), Vector2(20, 28), 16, Color("#65e1a0"))
	UIKit.label(top, "RIVERSIDE STADIUM", Vector2(40, 5), Vector2(220, 19), 10, Color("#82dfff"))
	match_header_label = UIKit.label(top, "快速賽 · 第 1 局", Vector2(40, 22), Vector2(300, 24), 15, text_main)
	pause_button = UIKit.button(top, "Ⅱ  暫停", Rect2(1080, 9, 86, 34), false)
	pause_button.pressed.connect(_toggle_pause)
	var quit := UIKit.button(top, "退出", Rect2(1172, 9, 60, 34), false)
	quit.pressed.connect(_quit_to_menu)

	var board := UIKit.panel(match_ui, Rect2(40, 83, 900, 61), Color("#092d5e", 0.72), 14)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud["blue_score"] = UIKit.label(board, "0", Vector2(235, 8), Vector2(45, 45), 30, text_main)
	hud["blue_name"] = UIKit.label(board, "🐾  喵咪隊", Vector2(18, 9), Vector2(210, 25), 13, text_main)
	UIKit.label(board, "PLAYER", Vector2(20, 33), Vector2(150, 18), 9, text_muted)
	hud["clock"] = UIKit.label(board, "2:00", Vector2(410, 8), Vector2(80, 28), 20, gold)
	match_mode_label = UIKit.label(board, "快速賽", Vector2(414, 34), Vector2(110, 17), 9, text_muted)
	hud["red_score"] = UIKit.label(board, "0", Vector2(615, 8), Vector2(45, 45), 30, text_main)
	hud["red_name"] = UIKit.label(board, "紅隊  🐱", Vector2(660, 9), Vector2(210, 25), 13, text_main)
	UIKit.label(board, "CPU · NOVICE", Vector2(661, 33), Vector2(180, 18), 9, text_muted)

	var captain := UIKit.panel(match_ui, Rect2(963, 83, 289, 176), Color("#0a2c5c", 0.72), 16)
	captain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.label(captain, "目前操作                         1P", Vector2(14, 10), Vector2(255, 22), 11, Color("#b3d1ed"))
	captain_portrait_sprite = Sprite2D.new()
	captain_portrait_sprite.texture = captain_player_texture
	captain_portrait_sprite.position = Vector2(52, 82)
	captain_portrait_sprite.scale = Vector2(0.052, 0.052)
	captain_portrait_sprite.centered = true
	captain_portrait_sprite.z_index = 1
	captain.add_child(captain_portrait_sprite)
	captain_name_label = UIKit.label(captain, "喵白白", Vector2(101, 42), Vector2(150, 24), 16, text_main)
	captain_role_label = UIKit.label(captain, "高速衝刺射門", Vector2(101, 66), Vector2(160, 20), 10, text_muted)
	UIKit.label(captain, "Lv.12     68%", Vector2(101, 91), Vector2(150, 20), 10, Color("#a9d7f6"))
	UIKit.label(captain, "喵力值", Vector2(15, 132), Vector2(100, 18), 10, Color("#c8d9f2"))
	hud["skill"] = UIKit.label(captain, "42%", Vector2(238, 132), Vector2(35, 18), 10, gold)
	var skill_bg := ColorRect.new()
	skill_bg.color = Color("#143967")
	skill_bg.position = Vector2(15, 153)
	skill_bg.size = Vector2(258, 8)
	captain.add_child(skill_bg)
	hud["skill_bar"] = ColorRect.new()
	hud["skill_bar"].color = Color("#ffd462")
	hud["skill_bar"].position = Vector2(15, 153)
	hud["skill_bar"].size = Vector2(108, 8)
	captain.add_child(hud["skill_bar"])

	var team_card := UIKit.panel(match_ui, Rect2(963, 270, 289, 156), Color("#0a2c5c", 0.72), 16)
	team_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.label(team_card, "場上隊友  ·  1/2/3 切換", Vector2(14, 10), Vector2(255, 22), 11, Color("#b3d1ed"))
	team_row_labels.clear()
	team_row_buttons.clear()
	var team_ids := ["blue-captain", "blue-mid", "blue-keeper"]
	var team_rows := ["1  ●  喵白白      前鋒 · 1P      92", "2  ●  喵布布      中場 · AI      86", "3  ●  喵小白      守門 · AI      79"]
	for i in team_rows.size():
		team_row_labels.append(UIKit.label(team_card, team_rows[i], Vector2(15, 40 + i * 34), Vector2(260, 24), 10, Color("#d3e7ff") if i == 0 else text_muted))
		var row_button := Button.new()
		row_button.position = Vector2(5, 35 + i * 34)
		row_button.size = Vector2(279, 31)
		row_button.text = ""
		row_button.focus_mode = Control.FOCUS_NONE
		row_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row_button.tooltip_text = "點擊或按 %d 切換操作球員" % (i + 1)
		row_button.add_theme_stylebox_override("normal", UIKit.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 10))
		row_button.add_theme_stylebox_override("hover", UIKit.style_box(Color("#2b6ca5", 0.18), Color("#82dfff", 0.48), 10))
		row_button.add_theme_stylebox_override("pressed", UIKit.style_box(Color("#133f79", 0.34), Color("#ffdf85", 0.72), 10))
		row_button.pressed.connect(_select_player.bind(team_ids[i]))
		team_card.add_child(row_button)
		team_row_buttons.append(row_button)

	var stats := UIKit.panel(match_ui, Rect2(963, 437, 289, 145), Color("#0a2c5c", 0.72), 16)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.label(stats, "比賽資料                         LIVE", Vector2(14, 10), Vector2(260, 22), 11, Color("#b3d1ed"))
	hud["shots"] = UIKit.label(stats, "射門                                      0", Vector2(15, 42), Vector2(260, 22), 10, text_muted)
	hud["passes"] = UIKit.label(stats, "傳球                                      0", Vector2(15, 68), Vector2(260, 22), 10, text_muted)
	hud["possession"] = UIKit.label(stats, "控球率                                  50%", Vector2(15, 94), Vector2(260, 22), 10, text_muted)
	hud["combo"] = UIKit.label(stats, "連擊                                      x1", Vector2(15, 120), Vector2(260, 22), 10, gold)

	ball_overlay = BallOverlay.new()
	match_ui.add_child(ball_overlay)
	ball_overlay.bind(self)

	action_buttons["pass"] = UIKit.button(match_ui, "", Rect2(650, 594, 74, 58), false)
	action_buttons["shoot"] = UIKit.button(match_ui, "", Rect2(733, 580, 88, 72), true)
	action_buttons["dash"] = UIKit.button(match_ui, "", Rect2(830, 594, 74, 58), false)
	action_buttons["tackle"] = UIKit.button(match_ui, "", Rect2(563, 594, 74, 58), false)
	action_buttons["skill"] = UIKit.button(match_ui, "", Rect2(918, 594, 74, 58), false)
	var pass_art := UIKit.decorate_action_button(action_buttons["pass"], "傳球", action_pass_texture)
	var shoot_art := UIKit.decorate_action_button(action_buttons["shoot"], "射門", action_shoot_texture)
	var dash_art := UIKit.decorate_action_button(action_buttons["dash"], "衝刺", action_dash_texture)
	var tackle_art := UIKit.decorate_action_button(action_buttons["tackle"], "搶球", action_tackle_texture)
	var skill_art := UIKit.decorate_action_button(action_buttons["skill"], "必殺", action_skill_texture)
	action_icons["pass"] = pass_art.icon
	action_icons["shoot"] = shoot_art.icon
	action_icons["dash"] = dash_art.icon
	action_icons["tackle"] = tackle_art.icon
	action_icons["skill"] = skill_art.icon
	action_labels["pass"] = pass_art.label
	action_labels["shoot"] = shoot_art.label
	action_labels["dash"] = dash_art.label
	action_labels["tackle"] = tackle_art.label
	action_labels["skill"] = skill_art.label
	action_buttons["pass"].pressed.connect(_pass_ball)
	action_buttons["dash"].pressed.connect(_dash)
	action_buttons["tackle"].pressed.connect(_tackle)
	action_buttons["skill"].pressed.connect(_use_skill)
	action_buttons["shoot"].button_down.connect(_begin_shoot)
	action_buttons["shoot"].button_up.connect(_finish_shoot)
	aim_label = UIKit.label(match_ui, "長按射門蓄力", Vector2(735, 658), Vector2(180, 20), 10, Color("#ffe5a0"))
	footer_hint_label = UIKit.label(match_ui, "⌁ 1/2/3 切換球員   ·   靠近足球自動控球   ·   SPACE 蓄力射門   ·   E 傳球   ·   SHIFT 衝刺", Vector2(150, 683), Vector2(820, 23), 10, text_muted)
	_update_captain_card()


func _build_help_overlay() -> void:
	help_overlay = UIKit.full_control()
	help_overlay.visible = false
	ui_layer.add_child(help_overlay)
	var dim := ColorRect.new()
	dim.color = Color("#020817", 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(dim)
	var card := UIKit.panel(help_overlay, Rect2(350, 105, 580, 500), Color("#0b2b5c", 0.99), 22)
	UIKit.label(card, "QUICK GUIDE", Vector2(28, 25), Vector2(200, 20), 10, Color("#82dfff"))
	UIKit.label(card, "3 分鐘學會喵咪足球", Vector2(28, 48), Vector2(480, 42), 25, text_main)
	var guides := ["W A S D / 方向鍵|移動目前球員", "1 / 2 / 3|切換目前操作球員", "SPACE（長按）|蓄力射門", "E|傳給前方隊友", "SHIFT|短暫衝刺", "Q|鏟球／搶球", "R|喵力值滿時發動必殺"]
	for i in guides.size():
		var parts: PackedStringArray = guides[i].split("|")
		var gx := 28.0 + float(i % 2) * 260.0
		var gy := 112.0 + float(i / 2) * 62.0
		var row := UIKit.panel(card, Rect2(gx, gy, 240, 48), Color("#061d45", 0.82), 10)
		UIKit.label(row, parts[0], Vector2(8, 2), Vector2(110, 19), 10, gold)
		UIKit.label(row, parts[1], Vector2(8, 22), Vector2(220, 19), 10, text_muted)
	UIKit.label(card, "靠近足球會自動控球。比賽中可用 1/2/3 接管三位主角；點球挑戰則固定由目前射手出腳。", Vector2(29, 365), Vector2(520, 45), 11, text_muted)
	var close := UIKit.button(card, "知道了，開始比賽！", Rect2(150, 425, 280, 48), true)
	close.pressed.connect(func(): help_overlay.visible = false; _start_match())


func _build_pause_overlay() -> void:
	pause_overlay = UIKit.full_control()
	pause_overlay.visible = false
	ui_layer.add_child(pause_overlay)
	var dim := ColorRect.new()
	dim.color = Color("#020817", 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(dim)
	var card := UIKit.panel(pause_overlay, Rect2(420, 210, 440, 265), Color("#0b2b5c", 0.99), 22)
	UIKit.label(card, "MATCH PAUSED", Vector2(30, 31), Vector2(380, 20), 10, Color("#82dfff"))
	UIKit.label(card, "先喘口氣吧！", Vector2(30, 57), Vector2(380, 42), 27, text_main)
	UIKit.label(card, "比賽已暫停，準備好就繼續踢。", Vector2(30, 107), Vector2(380, 25), 12, text_muted)
	var resume := UIKit.button(card, "▶  繼續比賽", Rect2(30, 155, 380, 40), true)
	resume.pressed.connect(func(): _toggle_pause(false))
	var quit := UIKit.button(card, "回到主選單", Rect2(30, 205, 380, 37), false)
	quit.pressed.connect(_quit_to_menu)


func _build_goal_overlay() -> void:
	goal_overlay = UIKit.full_control()
	goal_overlay.visible = false
	ui_layer.add_child(goal_overlay)
	var dim := ColorRect.new()
	dim.color = Color("#020817", 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_overlay.add_child(dim)
	var card := UIKit.panel(goal_overlay, Rect2(385, 155, 510, 390), Color("#11265d", 0.99), 24)
	card.clip_contents = true
	goal_celebration_art = TextureRect.new()
	goal_celebration_art.texture = goal_celebration_texture
	goal_celebration_art.position = Vector2(125, 48)
	goal_celebration_art.size = Vector2(260, 260)
	goal_celebration_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goal_celebration_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goal_celebration_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_celebration_art.modulate = Color(1.0, 1.0, 1.0, 0.72)
	goal_celebration_art.visible = false
	goal_celebration_art.z_index = 0
	card.add_child(goal_celebration_art)
	goal_effect_art = Sprite2D.new()
	goal_effect_art.texture = goal_effect_texture
	goal_effect_art.position = Vector2(255, 95)
	goal_effect_art.scale = Vector2(0.19, 0.19)
	goal_effect_art.centered = true
	goal_effect_art.modulate = Color(1.0, 1.0, 1.0, 0.34)
	goal_effect_art.z_index = 0
	card.add_child(goal_effect_art)
	UIKit.label(card, "NICE SHOT!", Vector2(30, 35), Vector2(450, 22), 11, Color("#a8eaff"))
	hud["goal_title"] = UIKit.label(card, "GOAL!", Vector2(20, 55), Vector2(470, 115), 74, gold)
	hud["goal_subtitle"] = UIKit.label(card, "喵咪隊拿下一分！", Vector2(30, 176), Vector2(450, 25), 14, text_main)
	hud["goal_score"] = UIKit.label(card, "0       —       0", Vector2(30, 210), Vector2(450, 48), 28, text_main)
	goal_continue_button = UIKit.button(card, "繼續比賽  →", Rect2(145, 300, 220, 48), true)
	goal_continue_button.pressed.connect(_continue_after_goal)


func _build_toast() -> void:
	toast_panel = UIKit.panel(ui_layer, Rect2(420, 28, 440, 42), Color("#092b5d", 0.97), 12)
	toast_panel.visible = false
	toast_label = UIKit.label(toast_panel, "", Vector2(12, 2), Vector2(416, 37), 11, text_main)


func _start_match(mode: String = "quick") -> void:
	game_mode = "penalty" if mode == "penalty" else ("tournament" if mode == "tournament" else "quick")
	for player in blue_players:
		player.controlled = player.id == selected_player_id
	game_active = true
	paused = false
	goal_lock = false
	final_match = false
	player_score = 0
	cpu_score = 0
	time_left = 35.0 if game_mode == "penalty" else (90.0 if game_mode == "tournament" else 120.0)
	skill = 42.0
	shots = 0
	passes = 0
	blue_touches = 0
	red_touches = 0
	possession_blue = 50
	combo = 1
	combo_timer = 0.0
	shoot_charging = false
	shoot_fx_timer = 0.0
	skill_fx_timer = 0.0
	penalty_round = 0
	penalty_goal = false
	penalty_aim = 0.0
	penalty_shot_timer = 0.0
	penalty_shot_active = false
	tournament_round = 0
	tournament_wins = 0
	tournament_losses = 0
	tournament_round_complete = false
	fx.clear()
	_reset_positions(true)
	if game_mode == "penalty":
		_prepare_penalty_round()
	if is_instance_valid(match_header_label):
		match_header_label.text = "點球挑戰 · 5 球制" if game_mode == "penalty" else ("錦標賽 · 第 1 / 3 局" if game_mode == "tournament" else "快速賽 · 第 1 局")
	if is_instance_valid(match_mode_label):
		match_mode_label.text = GameConst.mode_label(game_mode)
	if hud.has("red_name"):
		hud["red_name"].text = "守門員  🧤" if game_mode == "penalty" else ("挑戰者  🏆" if game_mode == "tournament" else "紅隊  🐱")
	_configure_action_buttons()
	menu_ui.visible = false
	match_ui.visible = true
	if is_instance_valid(menu_mascot):
		menu_mascot.visible = false
	if is_instance_valid(menu_hero_art):
		menu_hero_art.visible = false
	help_overlay.visible = false
	pause_overlay.visible = false
	goal_overlay.visible = false
	if is_instance_valid(goal_effect_art):
		goal_effect_art.visible = false
	if is_instance_valid(goal_celebration_art):
		goal_celebration_art.texture = goal_celebration_texture
		goal_celebration_art.visible = false
	pitch_layer.visible = true
	actors_layer.visible = true
	pitch_layer.configure(match_background_texture, crowd)
	_update_captain_card()
	_update_hud()
	_show_toast("A / D 瞄準，SPACE 射門！" if game_mode == "penalty" else ("錦標賽開幕！跟著金色箭頭找球，先贏兩局就能捧杯。" if game_mode == "tournament" else "開球！跟著金色箭頭找球，靠近就能控球，再按射門或搶球。"), 2.4)
	queue_redraw()


func _configure_action_buttons() -> void:
	var field_mode := game_mode == "quick" or game_mode == "tournament"
	for key in ["pass", "dash", "tackle", "skill"]:
		if action_buttons.has(key):
			action_buttons[key].visible = field_mode
	if action_labels.has("shoot"):
		action_labels["shoot"].text = "射門"
	if action_icons.has("shoot"):
		action_icons["shoot"].modulate = Color(1.0, 1.0, 1.0, 1.0 if field_mode else 0.9)
	if is_instance_valid(aim_label):
		aim_label.text = "長按射門蓄力" if field_mode else "A / D 瞄準　SPACE 射門"
	if is_instance_valid(footer_hint_label):
		footer_hint_label.text = "⌁ 三局淘汰賽 · 1/2/3 切換球員 · 先贏兩局   ·   SPACE 蓄力射門   ·   E 傳球   ·   SHIFT 衝刺" if game_mode == "tournament" else ("⌁ 1/2/3 切換球員 · 點擊／拖曳球場移動   ·   SPACE 蓄力射門   ·   E 傳球   ·   SHIFT 衝刺" if field_mode else "⌁ 點擊球門落點或 W/S 瞄準   ·   SPACE 出腳   ·   5 球後結算")


func _quit_to_menu() -> void:
	game_active = false
	game_mode = "quick"
	paused = false
	goal_lock = false
	shoot_charging = false
	shoot_fx_timer = 0.0
	skill_fx_timer = 0.0
	penalty_shot_active = false
	tournament_round = 0
	tournament_wins = 0
	tournament_losses = 0
	tournament_round_complete = false
	goal_overlay.visible = false
	pause_overlay.visible = false
	match_ui.visible = false
	menu_ui.visible = true
	pitch_layer.visible = false
	actors_layer.visible = false
	if is_instance_valid(menu_mascot):
		menu_mascot.visible = false
	if is_instance_valid(menu_hero_art):
		menu_hero_art.visible = true
	move_target_active = false
	fx.clear()
	_configure_action_buttons()
	_update_captain_card()
	_refresh_roster_selection()
	queue_redraw()


func _toggle_pause(force: Variant = null) -> void:
	if not game_active or goal_lock:
		return
	if force == null:
		paused = not paused
	else:
		paused = bool(force)
	pause_overlay.visible = paused
	pause_button.text = "▶  繼續" if paused else "Ⅱ  暫停"


func _show_toast(message: String, duration: float = 1.6) -> void:
	toast_label.text = "✦  " + message
	toast_panel.visible = true
	toast_timer = duration


func _update_hud() -> void:
	if hud.is_empty():
		return
	hud["blue_score"].text = str(player_score)
	hud["red_score"].text = str(cpu_score)
	var seconds := maxi(0, int(ceil(time_left)))
	hud["clock"].text = "%d / 5" % mini(penalty_round + 1, 5) if game_mode == "penalty" else "%d:%02d" % [seconds / 60, seconds % 60]
	hud["skill"].text = "%d%%" % int(round(skill))
	hud["skill_bar"].size.x = 258.0 * skill / 100.0
	hud["shots"].text = "射門                                      %d" % shots
	hud["passes"].text = "傳球                                      %d" % passes
	hud["possession"].text = "控球率                                  %d%%" % possession_blue
	hud["combo"].text = "連擊                                      x%d" % combo


func _generate_crowd() -> void:
	crowd.clear()
	for i in 86:
		crowd.append({
			"x": randf_range(22.0, WORLD_SIZE.x - 22.0),
			"y": randf_range(16.0, 40.0) if i % 2 == 0 else randf_range(WORLD_SIZE.y - 40.0, WORLD_SIZE.y - 16.0),
			"r": randf_range(2.0, 4.0),
			"color": [Color("#ffe18b"), Color("#8bdcff"), Color("#ff9f9f"), Color("#f4f7ff")][i % 4]
		})


func _build_teams() -> void:
	players = SoccerPlayer.default_lineup(selected_player_id)
	_index_players()


func _index_players() -> void:
	player_by_id.clear()
	blue_players.clear()
	red_players.clear()
	for player in players:
		player_by_id[player.id] = player
		if player.team == BLUE:
			blue_players.append(player)
		else:
			red_players.append(player)


func _reset_positions(kickoff := true) -> void:
	for player in players:
		player.reset_to_home()
	ball.reset(kickoff)
	dash_timer = 0.0
	dash_cooldown = 0.0
	move_target = Vector2.ZERO
	move_target_active = false


func user_player() -> SoccerPlayer:
	var selected := get_player(selected_player_id)
	if selected != null:
		return selected
	for player in blue_players:
		if player.controlled:
			return player
	return blue_players[0] if not blue_players.is_empty() else null


func get_player(id: String) -> SoccerPlayer:
	if id.is_empty() or not player_by_id.has(id):
		return null
	return player_by_id[id]


func _input_vector() -> Vector2:
	var vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vector.y += 1.0
	if vector.length() > 0.01:
		move_target_active = false
		return vector.normalized()
	if move_target_active:
		var player := user_player()
		if player == null:
			return Vector2.ZERO
		var target_direction := move_target - player.pos()
		if target_direction.length() <= 18.0:
			move_target_active = false
			return Vector2.ZERO
		return target_direction.normalized()
	return Vector2.ZERO


func _update_game(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_finish_match_by_time()
		return
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo = 1
	var player := user_player()
	if player != null:
		_update_controlled(player, delta)
	for teammate in blue_players:
		if not teammate.controlled:
			_update_teammate(teammate, delta)
	for cpu in red_players:
		_update_cpu(cpu, delta)
	_resolve_bumps()
	_update_ball(delta)
	var touch_total := blue_touches + red_touches
	if touch_total > 0:
		possession_blue = int(round(float(blue_touches) / float(touch_total) * 100.0))
	_update_hud()


func _prepare_penalty_round() -> void:
	var shooter := user_player()
	var keeper := get_player("red-keeper")
	if shooter != null:
		shooter.x = 884.0
		shooter.y = 360.0
		shooter.vx = 0.0
		shooter.vy = 0.0
		shooter.facing = 0.0
		ball.owner_id = shooter.id
	if keeper != null:
		keeper.x = 1158.0
		keeper.y = 360.0
		keeper.vx = 0.0
		keeper.vy = 0.0
		keeper.facing = PI
	ball.x = 930.0
	ball.y = 360.0
	ball.vx = 0.0
	ball.vy = 0.0
	ball.last_touch = BLUE
	ball.no_claim_until = GameConst.now() + 0.3
	penalty_aim = 0.0
	penalty_keeper_target_y = 360.0
	penalty_shot_timer = 0.0
	penalty_shot_active = false
	if is_instance_valid(goal_effect_art):
		goal_effect_art.visible = false
	if is_instance_valid(goal_celebration_art):
		goal_celebration_art.visible = false


func _update_penalty(delta: float) -> void:
	var keeper := get_player("red-keeper")
	if penalty_shot_active:
		penalty_shot_timer = maxf(0.0, penalty_shot_timer - delta)
		var progress := 1.0 - penalty_shot_timer / penalty_shot_duration
		var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 1.35)
		ball.x = lerpf(penalty_shot_start.x, penalty_shot_target.x, eased)
		ball.y = lerpf(penalty_shot_start.y, penalty_shot_target.y, eased)
		if keeper != null:
			keeper.y = lerpf(keeper.y, penalty_keeper_target_y, minf(1.0, delta * 9.0))
		if penalty_shot_timer <= 0.0:
			_resolve_penalty_shot()
		_update_hud()
		return
	if keeper != null:
		keeper.y = lerpf(keeper.y, 360.0 + sin(GameConst.now() * 1.5) * 7.0, minf(1.0, delta * 3.0))
	ball.x = 930.0
	ball.y = 360.0
	var shooter := user_player()
	if shooter != null:
		ball.owner_id = shooter.id
	_update_hud()


func _penalty_shoot() -> void:
	if not game_active or game_mode != "penalty" or paused or goal_lock or penalty_shot_active:
		return
	var aim_y := clampf(360.0 + penalty_aim * 112.0, GOAL_TOP + 18.0, GOAL_BOTTOM - 18.0)
	var keeper_slots := [GOAL_TOP + 38.0, 360.0, GOAL_BOTTOM - 38.0]
	penalty_keeper_target_y = float(keeper_slots[randi_range(0, keeper_slots.size() - 1)])
	penalty_goal = absf(aim_y - penalty_keeper_target_y) > 43.0
	penalty_shot_start = ball.pos()
	penalty_shot_target = Vector2(PITCH.end.x + 18.0, aim_y)
	penalty_shot_timer = penalty_shot_duration
	penalty_shot_active = true
	ball.owner_id = ""
	shots += 1
	_show_toast("射門！看看能不能騙過守門員。", 1.0)


func _resolve_penalty_shot() -> void:
	penalty_shot_active = false
	penalty_round += 1
	if penalty_goal:
		player_score += 1
		fx.spawn_goal(1210.0, penalty_shot_target.y, Color("#ffdf69"))
		hud["goal_title"].text = "進球！"
		hud["goal_subtitle"].text = "漂亮的點球，守門員被你騙過了！"
		_show_toast("命中！下一球繼續保持。", 1.1)
	else:
		cpu_score += 1
		fx.spawn_kick(1160.0, penalty_keeper_target_y, Color("#8fdcff"), 16)
		hud["goal_title"].text = "撲救！"
		hud["goal_subtitle"].text = "守門員猜中了方向，再試一次。"
		_show_toast("被守住了，調整瞄準再踢。", 1.1)
	final_match = penalty_round >= 5
	if final_match:
		hud["goal_title"].text = "點球結束！"
		hud["goal_subtitle"].text = "喵咪隊勝利！" if player_score > cpu_score else ("平局！" if player_score == cpu_score else "守門員拿下勝利！")
		goal_continue_button.text = "返回主選單  →"
	else:
		goal_continue_button.text = "下一球  →"
	hud["goal_score"].text = "%d       —       %d" % [player_score, cpu_score]
	goal_lock = true
	paused = true
	if is_instance_valid(goal_effect_art):
		goal_effect_art.visible = penalty_goal
	if is_instance_valid(goal_celebration_art):
		goal_celebration_art.visible = penalty_goal
	_update_hud()
	goal_overlay.visible = true


func _update_controlled(player: SoccerPlayer, delta: float) -> void:
	var input := _input_vector()
	var dashing := dash_timer > 0.0
	var speed: float = player.speed * (1.82 if dashing else 1.0)
	if dashing:
		player.stamina = maxf(0.0, player.stamina - delta * 34.0)
		if player.stamina <= 0.0:
			dash_timer = 0.0
	else:
		player.stamina = minf(100.0, player.stamina + delta * 12.0)
	player.vx = lerpf(player.vx, input.x * speed, minf(1.0, delta * 13.0))
	player.vy = lerpf(player.vy, input.y * speed, minf(1.0, delta * 13.0))
	player.x += player.vx * delta
	player.y += player.vy * delta
	if input.length() > 0.08:
		player.facing = atan2(input.y, input.x)
	player.keep_on_pitch()


func _move_toward(player: SoccerPlayer, target: Vector2, delta: float, scale := 1.0) -> void:
	var direction := (target - player.pos()).normalized()
	var speed: float = player.speed * scale
	player.vx = lerpf(player.vx, direction.x * speed, minf(1.0, delta * 8.0))
	player.vy = lerpf(player.vy, direction.y * speed, minf(1.0, delta * 8.0))
	player.x += player.vx * delta
	player.y += player.vy * delta
	if direction.length() > 0.1:
		player.facing = atan2(direction.y, direction.x)
	player.keep_on_pitch()


func _update_teammate(player: SoccerPlayer, delta: float) -> void:
	var owner := get_player(ball.owner_id)
	var target := player.home()
	if owner != null and owner.team == BLUE:
		if player.role == "中場":
			target = Vector2(clampf(owner.x + 85.0, 120.0, 1110.0), clampf(owner.y - 110.0, 100.0, 620.0))
		else:
			target = Vector2(clampf(owner.x - 115.0, 85.0, 1120.0), clampf(owner.y + 100.0, 100.0, 620.0))
	elif owner != null and owner.team == RED and player.distance_to(ball.pos()) < 240.0:
		target = Vector2(ball.x - 40.0, ball.y)
	else:
		target = Vector2(lerpf(player.home_x, ball.x - 85.0, 0.15), lerpf(player.home_y, ball.y, 0.08))
	_move_toward(player, target, delta, 0.72)


func _nearest_player(point: Vector2, team: String) -> SoccerPlayer:
	var best: SoccerPlayer = null
	var best_distance := INF
	var group := blue_players if team == BLUE else red_players
	for player in group:
		var current := player.distance_to(point)
		if current < best_distance:
			best_distance = current
			best = player
	return best


func _update_cpu(player: SoccerPlayer, delta: float) -> void:
	var owner := get_player(ball.owner_id)
	var nearest := _nearest_player(ball.pos(), RED)
	var target := player.home()
	if owner != null and owner.id == player.id:
		target = Vector2(100.0, clampf(lerpf(player.y, 360.0, 0.01), 100.0, 620.0))
		player.action_cd -= delta
		if player.action_cd <= 0.0 and player.x < 560.0:
			_cpu_shoot(player)
			player.action_cd = randf_range(1.6, 2.8)
	elif owner == null and nearest != null and nearest.id == player.id:
		target = ball.pos()
	elif owner != null and owner.team == BLUE and (player.distance_to(owner.pos()) < 240.0 or player.role == "前鋒"):
		target = Vector2(owner.x + 20.0, owner.y)
	else:
		target = Vector2(lerpf(player.home_x, ball.x + 110.0, 0.07), lerpf(player.home_y, ball.y, 0.06))
	_move_toward(player, target, delta, 0.64 if player.role == "守門" else 0.78)


func _claim_ball(player: SoccerPlayer, ignore_lock := false) -> bool:
	if not ignore_lock and GameConst.now() < ball.no_claim_until:
		return false
	ball.owner_id = player.id
	ball.last_touch = player.team
	if player.team == BLUE:
		blue_touches += 1
	else:
		red_touches += 1
	return true


func _auto_possession() -> void:
	if ball.has_owner() or GameConst.now() < ball.no_claim_until:
		return
	var ball_pos := ball.pos()
	var user := user_player()
	if user != null and user.distance_to(ball_pos) < GameConst.BALL_CLAIM_RADIUS + 16.0:
		_claim_ball(user)
		return
	var best: SoccerPlayer = null
	var best_distance := GameConst.BALL_CLAIM_RADIUS
	for player in players:
		var current := player.distance_to(ball_pos)
		if current < best_distance:
			best_distance = current
			best = player
	if best != null:
		_claim_ball(best)


func _update_ball(delta: float) -> void:
	var owner := get_player(ball.owner_id)
	if owner != null:
		ball.attach_to(owner)
		return
	ball.x += ball.vx * delta
	ball.y += ball.vy * delta
	var speed := Vector2(ball.vx, ball.vy).length()
	var drag := pow(0.58, delta) if speed > 140.0 else pow(0.12, delta)
	ball.vx *= drag
	ball.vy *= drag
	var in_goal_mouth := ball.y > GOAL_TOP and ball.y < GOAL_BOTTOM
	if ball.y < PITCH.position.y + 14.0:
		ball.y = PITCH.position.y + 14.0
		ball.vy = absf(ball.vy) * 0.72
	if ball.y > PITCH.end.y - 14.0:
		ball.y = PITCH.end.y - 14.0
		ball.vy = -absf(ball.vy) * 0.72
	if in_goal_mouth and ball.x < PITCH.position.x - GameConst.GOAL_LINE_DEPTH:
		_score_goal(RED)
		return
	if in_goal_mouth and ball.x > PITCH.end.x + GameConst.GOAL_LINE_DEPTH:
		_score_goal(BLUE)
		return
	if not in_goal_mouth and ball.x < PITCH.position.x + 14.0:
		ball.x = PITCH.position.x + 14.0
		ball.vx = absf(ball.vx) * 0.72
	if not in_goal_mouth and ball.x > PITCH.end.x - 14.0:
		ball.x = PITCH.end.x - 14.0
		ball.vx = -absf(ball.vx) * 0.72
	_auto_possession()


func _resolve_bumps() -> void:
	for i in players.size():
		for j in range(i + 1, players.size()):
			var a: SoccerPlayer = players[i]
			var b: SoccerPlayer = players[j]
			var delta := b.pos() - a.pos()
			var dist := maxf(delta.length(), 0.001)
			if dist < GameConst.BUMP_RADIUS:
				var push := (GameConst.BUMP_RADIUS - dist) / 2.0
				var normal := delta / dist
				a.x -= normal.x * push
				a.y -= normal.y * push
				b.x += normal.x * push
				b.y += normal.y * push
				a.keep_on_pitch()
				b.keep_on_pitch()
	var owner := get_player(ball.owner_id)
	if owner == null:
		return
	var opponents := red_players if owner.team == BLUE else blue_players
	for opponent in opponents:
		if owner.distance_to(opponent.pos()) < 30.0 and randf() < 0.0024:
			ball.owner_id = opponent.id
			ball.last_touch = opponent.team
			if opponent.team == RED:
				red_touches += 1
			else:
				blue_touches += 1
			_show_toast("被碰到掉球了，快搶回來！", 1.0)
			break


func _ensure_user_possession() -> bool:
	var player := user_player()
	if player == null:
		return false
	if ball.owner_id == player.id:
		return true
	var owner := get_player(ball.owner_id)
	if owner != null and owner.team == BLUE and player.distance_to(owner.pos()) < 108.0:
		return _claim_ball(player, true)
	if not ball.has_owner() and player.distance_to(ball.pos()) < 96.0:
		return _claim_ball(player)
	return false


func _begin_shoot() -> void:
	if not game_active or paused or goal_lock or shoot_charging:
		return
	if game_mode == "penalty":
		_penalty_shoot()
		return
	if not _ensure_user_possession():
		var owner := get_player(ball.owner_id)
		if owner != null and owner.team == RED:
			_show_toast("先靠近持球對手，再按搶球！", 1.1)
		else:
			_show_toast("靠近足球後才能射門！", 1.1)
		return
	var player := user_player()
	if player != null and absf(player.vx) + absf(player.vy) < 48.0:
		player.facing = 0.0
	shoot_charging = true
	shoot_started_at = Time.get_ticks_msec()
	aim_label.text = "放開射門！力量正在累積"


func _finish_shoot() -> void:
	if game_mode == "penalty":
		shoot_charging = false
		return
	if not shoot_charging:
		return
	shoot_charging = false
	var player := user_player()
	if player == null or ball.owner_id != player.id:
		return
	var charge := clampf(float(Time.get_ticks_msec() - shoot_started_at) / 1000.0, 0.18, 1.0)
	var direction := Vector2(cos(player.facing), sin(player.facing))
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	_release_ball(direction * (620.0 + charge * 520.0), BLUE, 0.58)
	shoot_fx_timer = 0.24
	shots += 1
	combo_timer = 4.0
	_set_skill(10.0 + charge * 7.0)
	fx.spawn_kick(player.x + direction.x * 30.0, player.y + direction.y * 30.0, Color("#ffe17b"), 8)
	_show_toast("Perfect Timing！超強射門！" if charge > 0.82 else "射門！把球送進球門！", 1.3)
	aim_label.text = "長按射門蓄力"


func _pass_ball() -> void:
	if not game_active or paused or goal_lock:
		return
	if not _ensure_user_possession():
		_show_toast("還沒拿到球，先靠近一點！", 1.1)
		return
	var player := user_player()
	if player == null:
		return
	var target: SoccerPlayer = null
	var best_score := -INF
	var facing := Vector2(cos(player.facing), sin(player.facing))
	for mate in blue_players:
		if mate.id == player.id:
			continue
		var offset := mate.pos() - player.pos()
		var score := offset.dot(facing) - offset.length() * 0.22
		if score > best_score:
			best_score = score
			target = mate
	if target == null:
		return
	var direction := (target.pos() - player.pos()).normalized()
	_release_ball(direction * 560.0, BLUE, 0.38)
	passes += 1
	combo_timer = 4.0
	_set_skill(6.0)
	fx.spawn_kick(player.x + direction.x * 28.0, player.y + direction.y * 28.0, Color("#78dfff"), 5)
	_show_toast("傳給 %s！" % target.display_name, 1.0)


func _dash() -> void:
	if not game_active or paused or goal_lock:
		return
	var player := user_player()
	if player == null:
		return
	if player.stamina < 18.0 or dash_cooldown > 0.0:
		_show_toast("體力還沒恢復！", 0.9)
		return
	dash_timer = 0.27
	dash_cooldown = 0.72
	player.stamina -= 15.0
	fx.spawn_kick(player.x, player.y + 17.0, Color("#6de6ff"), 5)


func _tackle() -> void:
	if not game_active or paused or goal_lock:
		return
	var player := user_player()
	if player == null:
		return
	var owner := get_player(ball.owner_id)
	if owner != null and owner.team == BLUE:
		_show_toast("球已經在我方腳下！", 0.8)
		return
	var target_pos := owner.pos() if owner != null else ball.pos()
	if owner != null and owner.team == RED and player.distance_to(owner.pos()) < GameConst.TACKLE_RADIUS:
		_claim_ball(player, true)
		_lunge_toward(player, owner.pos(), 22.0)
		_set_skill(12.0)
		fx.spawn_kick(player.x, player.y, Color("#9ce7ff"), 10)
		_show_toast("漂亮搶球！", 1.0)
		return
	if not ball.has_owner() and player.distance_to(ball.pos()) < GameConst.TACKLE_RADIUS:
		_claim_ball(player, true)
		_lunge_toward(player, ball.pos(), 18.0)
		_set_skill(7.0)
		_show_toast("把球留下來！", 0.9)
		return
	_lunge_toward(player, target_pos, 26.0)
	dash_timer = maxf(dash_timer, 0.22)
	_show_toast("再靠近一點才能搶到球！", 0.9)


func _use_skill() -> void:
	if not game_active or paused or goal_lock:
		return
	if skill < 100.0:
		_show_toast("喵力值還差 %d%%！" % int(ceil(100.0 - skill)), 1.1)
		return
	if not _ensure_user_possession():
		_show_toast("拿到球才能發動必殺技！", 1.1)
		return
	var player := user_player()
	if player == null:
		return
	var direction := Vector2(cos(player.facing), sin(player.facing))
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	_release_ball(direction * 1180.0, BLUE, 0.72)
	shots += 1
	skill = 0.0
	combo_timer = 7.0
	skill_fx_timer = 0.65
	fx.spawn_kick(player.x + direction.x * 30.0, player.y + direction.y * 30.0, Color("#ffdc62"), 22)
	_show_toast("海浪射門！必殺技發動！", 1.8)


func _lunge_toward(player: SoccerPlayer, target: Vector2, amount: float) -> void:
	var offset := target - player.pos()
	if offset.length() <= 1.0:
		return
	var direction := offset.normalized()
	player.x += direction.x * amount
	player.y += direction.y * amount
	player.facing = atan2(direction.y, direction.x)
	player.keep_on_pitch()


func _release_ball(velocity: Vector2, source_team: String, claim_lock := 0.55) -> void:
	ball.release(velocity, source_team, claim_lock)


func _cpu_shoot(player: SoccerPlayer) -> void:
	var target_y := 360.0 + randf_range(-95.0, 95.0)
	var direction := Vector2(-player.x + 48.0, target_y - player.y).normalized()
	_release_ball(direction * randf_range(560.0, 720.0), RED, 0.5)
	fx.spawn_kick(player.x + direction.x * 27.0, player.y + direction.y * 27.0, Color("#ff9e79"), 6)


func _set_skill(amount: float) -> void:
	skill = clampf(skill + amount, 0.0, 100.0)
	_update_hud()


func _show_tournament_round_result() -> void:
	var round_won := player_score > cpu_score
	var round_lost := player_score < cpu_score
	if round_won:
		tournament_wins += 1
	if round_lost:
		tournament_losses += 1
	tournament_round += 1
	tournament_round_complete = true
	final_match = tournament_round >= 3 or tournament_wins >= 2 or tournament_losses >= 2
	var trophy_won := final_match and tournament_wins > tournament_losses
	var title := "第 %d 局平手" % tournament_round
	if round_won:
		title = "第 %d 局勝利！" % tournament_round
	if round_lost:
		title = "第 %d 局失利" % tournament_round
	if final_match:
		title = "錦標賽結束"
	if trophy_won:
		title = "錦標賽勝利！"
	hud["goal_title"].text = title
	var subtitle := "本局 %d — %d　·　目前戰績 %d 勝 %d 敗" % [player_score, cpu_score, tournament_wins, tournament_losses]
	if final_match:
		subtitle = "錦標賽戰績 %d 勝 %d 敗，再接再厲！" % [tournament_wins, tournament_losses]
	if trophy_won:
		subtitle = "錦標賽戰績 %d 勝 %d 敗，喵咪隊捧起冠軍！" % [tournament_wins, tournament_losses]
	hud["goal_subtitle"].text = subtitle
	goal_continue_button.text = "返回主選單  →" if final_match else "下一局  →"
	if is_instance_valid(goal_celebration_art):
		goal_celebration_art.texture = tournament_trophy_texture if trophy_won else goal_celebration_texture
		goal_celebration_art.visible = true


func _score_goal(team: String) -> void:
	if goal_lock or game_mode == "penalty":
		return
	goal_lock = true
	paused = true
	ball.owner_id = ""
	ball.vx = 0.0
	ball.vy = 0.0
	if team == BLUE:
		player_score += 1
		combo = mini(combo + 1, 9)
		skill = clampf(skill + 30.0, 0.0, 100.0)
		fx.spawn_goal(1210.0, 360.0, Color("#ffdf69"))
	else:
		cpu_score += 1
		combo = 1
		fx.spawn_goal(70.0, 360.0, Color("#ff8a77"))
	final_match = false if game_mode == "tournament" else player_score >= 3 or cpu_score >= 3 or time_left <= 0.0
	hud["goal_title"].text = "GOAL!"
	hud["goal_subtitle"].text = "喵咪隊拿下一分！" if team == BLUE else "紅隊突破了防線！"
	hud["goal_score"].text = "%d       —       %d" % [player_score, cpu_score]
	goal_continue_button.text = "查看比賽結果  →" if final_match else "繼續比賽  →"
	if is_instance_valid(goal_effect_art):
		goal_effect_art.visible = true
	if is_instance_valid(goal_celebration_art):
		goal_celebration_art.texture = goal_celebration_texture
		goal_celebration_art.visible = team == BLUE
	_update_hud()
	goal_overlay.visible = true


func _finish_match_by_time() -> void:
	if goal_lock or game_mode == "penalty":
		return
	goal_lock = true
	paused = true
	if game_mode == "tournament":
		final_match = false
		_show_tournament_round_result()
	else:
		final_match = true
		hud["goal_title"].text = "時間到！"
		hud["goal_subtitle"].text = "平局！兩隊都踢得很精彩" if player_score == cpu_score else ("喵咪隊拿下勝利！" if player_score > cpu_score else "紅隊暫時領先，下次再來挑戰！")
		if is_instance_valid(goal_celebration_art):
			goal_celebration_art.visible = false
	hud["goal_score"].text = "%d       —       %d" % [player_score, cpu_score]
	if is_instance_valid(goal_effect_art):
		goal_effect_art.visible = false
	_update_hud()
	goal_overlay.visible = true


func _continue_after_goal() -> void:
	if final_match:
		_quit_to_menu()
		return
	if game_mode == "penalty":
		goal_overlay.visible = false
		goal_lock = false
		paused = false
		_prepare_penalty_round()
		_show_toast("第 %d 球！W/S 或 A/D 瞄準後按 SPACE。" % (penalty_round + 1), 1.5)
		return
	if game_mode == "tournament" and tournament_round_complete:
		tournament_round_complete = false
		goal_overlay.visible = false
		goal_lock = false
		paused = false
		player_score = 0
		cpu_score = 0
		time_left = 90.0
		combo = 1
		_reset_positions(true)
		if is_instance_valid(match_header_label):
			match_header_label.text = "錦標賽 · 第 %d / 3 局" % (tournament_round + 1)
		_configure_action_buttons()
		_update_hud()
		_show_toast("第 %d / 3 局！先贏兩局就能捧杯。" % (tournament_round + 1), 1.6)
		return
	goal_overlay.visible = false
	goal_lock = false
	paused = false
	_reset_positions(true)
	_show_toast("重新開球！這次換你進攻。", 1.2)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#06152f"))
	if not game_active:
		_draw_menu_backdrop()


func _draw_menu_backdrop() -> void:
	draw_texture_rect(menu_background_texture, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, WORLD_SIZE.y), Color("#062653", 0.08))
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 92), Color("#062653", 0.18))
	var confetti := [Vector2(320, 36), Vector2(476, 72), Vector2(704, 35), Vector2(850, 63), Vector2(1115, 37), Vector2(1220, 112)]
	var confetti_colors := [Color("#ffe06b"), Color("#ff9f7b"), Color("#ffffff"), Color("#79e3ff")]
	for i in confetti.size():
		var p: Vector2 = confetti[i]
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(9, 4), p + Vector2(5, 13), p + Vector2(-4, 8)]), confetti_colors[i % confetti_colors.size()])
	var preview := Rect2(292, 452, 610, 170)
	draw_rect(preview, Color("#178a59", 0.98))
	for i in 6:
		if i % 2 == 0:
			draw_rect(Rect2(preview.position.x + float(i) * 102.0, preview.position.y, 102.0, preview.size.y), Color("#72d993", 0.11))
	draw_rect(preview, Color("#e9fff0", 0.86), false, 2.0)
	draw_line(Vector2(597, 452), Vector2(597, 622), Color("#e9fff0", 0.72), 2.0)
	draw_arc(Vector2(597, 537), 31.0, 0, TAU, 32, Color("#e9fff0", 0.7), 2.0)
	draw_rect(Rect2(292, 496, 66, 82), Color("#e9fff0", 0.7), false, 2.0)
	draw_rect(Rect2(836, 496, 66, 82), Color("#e9fff0", 0.7), false, 2.0)
	_draw_menu_preview_player(captain_player_texture, Vector2(492.0, 532.0), true)
	_draw_menu_preview_player(calico_player_texture, Vector2(430.0, 488.0), false)
	_draw_menu_preview_player(red_player_texture, Vector2(695.0, 535.0), false)
	draw_circle(Vector2(600, 538), 9.0, Color("#fbfdff"))
	draw_circle(Vector2(600, 538), 3.0, Color("#172847"))


func _draw_menu_preview_player(texture: Texture2D, position: Vector2, owner: bool) -> void:
	var max_width := 102.0 if owner else 92.0
	var max_height := 132.0 if owner else 118.0
	var texture_size := texture.get_size()
	var sprite_size := texture_size * minf(max_width / texture_size.x, max_height / texture_size.y)
	draw_texture_rect(texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * 0.86), sprite_size), false)
