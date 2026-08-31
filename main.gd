extends Node2D

## 喵咪足球大戰
## Godot 4 零外掛 2D 3v3 原型：球場、球物理與互動邏輯以 GDScript 驅動，
## 主選單與進球畫面搭配生成式角色、背景與特效素材。

const WORLD_SIZE := Vector2(1280.0, 720.0)
const PITCH := Rect2(48.0, 54.0, 1184.0, 612.0)
const GOAL_TOP := 258.0
const GOAL_BOTTOM := 462.0
const BLUE := "blue"
const RED := "red"

var mascot_texture: Texture2D = preload("res://assets/maomao-mascot.png")
var menu_background_texture: Texture2D = preload("res://assets/generated/menu-stadium-background-v2.png")
var hero_action_texture: Texture2D = preload("res://assets/generated/hero-action-v2.png")
var teammates_texture: Texture2D = preload("res://assets/generated/cat-teammates-v2.png")
var calico_player_texture: Texture2D = preload("res://assets/generated/calico-player-v2.png")
var white_player_texture: Texture2D = preload("res://assets/generated/white-player-v2.png")
var special_shot_texture: Texture2D = preload("res://assets/generated/special-shot-v2.png")
var goal_effect_texture: Texture2D = preload("res://assets/generated/goal-effect-v2.png")
var match_background_texture: Texture2D = preload("res://assets/generated/match-stadium-background-v2.png")
var red_player_texture: Texture2D = preload("res://assets/generated/red-player-v2.png")
var goalkeeper_dive_texture: Texture2D = preload("res://assets/generated/goalkeeper-dive-v2.png")
var trophy_texture: Texture2D = preload("res://assets/generated/trophy-badge-v2.png")
var menu_hero_team_texture: Texture2D = preload("res://assets/generated/menu-hero-team-v3.png")
var roster_portrait_strip_texture: Texture2D = preload("res://assets/generated/roster-portrait-strip-v3.png")
var goal_celebration_texture: Texture2D = preload("res://assets/generated/goal-celebration-card-v3.png")
var mode_quick_texture: Texture2D = preload("res://assets/generated/mode-quick-match-v1.png")
var mode_tournament_texture: Texture2D = preload("res://assets/generated/mode-tournament-v1.png")
var mode_story_texture: Texture2D = preload("res://assets/generated/mode-story-v1.png")
var mode_penalty_texture: Texture2D = preload("res://assets/generated/mode-penalty-challenge-v1.png")
var players: Array = []
var ball := {
	"x": 640.0, "y": 360.0, "vx": 0.0, "vy": 0.0,
	"r": 14.0, "owner": "", "last_touch": BLUE, "no_claim_until": 0.0
}
var particles: Array = []
var crowd: Array = []

var game_active := false
var game_mode := "quick"
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
var move_target := Vector2.ZERO
var move_target_active := false

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
var match_header_label: Label
var match_mode_label: Label
var menu_mascot: Sprite2D
var menu_teammates_art: Sprite2D
var menu_hero_art: TextureRect
var special_shot_art: Sprite2D
var goal_effect_art: Sprite2D
var goal_celebration_art: TextureRect

var panel_blue := Color("#0a2b5b")
var panel_border := Color("#4b8fc3", 0.48)
var text_main := Color("#f4f8ff")
var text_muted := Color("#9ab3d5")
var gold := Color("#ffd266")


func _ready() -> void:
	_generate_crowd()
	_build_teams()
	_build_ui()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and is_instance_valid(toast_panel):
			toast_panel.visible = false
	if game_active:
		if not paused and not goal_lock:
			if game_mode == "penalty": _update_penalty(delta)
			else: _update_game(delta)
		_update_particles(delta)
		queue_redraw()


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
		if game_mode == "quick":
			_set_move_target(_canvas_to_world(drag_event.position))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if game_mode == "quick" and (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
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
					KEY_A, KEY_LEFT: penalty_aim = clampf(penalty_aim - .12, -1.0, 1.0)
					KEY_D, KEY_RIGHT: penalty_aim = clampf(penalty_aim + .12, -1.0, 1.0)
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
				KEY_E: _pass_ball()
				KEY_Q: _tackle()
				KEY_R: _use_skill()
				KEY_SHIFT: _dash()
			get_viewport().set_input_as_handled()


func _canvas_to_world(viewport_position: Vector2) -> Vector2:
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * viewport_position


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
		penalty_aim = clampf((world_position.y - WORLD_SIZE.y * .5) / 112.0, -1.0, 1.0)
		_show_toast("已瞄準球門落點，按射門出腳。", .8)
	else:
		_set_move_target(world_position)
		_show_toast("前往標記位置。", .65)


# -----------------------------------------------------------------------------
# UI
# -----------------------------------------------------------------------------

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


func _full_control() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


func _panel(parent: Node, rect: Rect2, color: Color = panel_blue, radius: int = 18) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style_box(color, panel_border, radius))
	parent.add_child(panel)
	return panel


func _style_box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 14) -> StyleBoxFlat:
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


func _label(parent: Node, text_value: String, position: Vector2, size: Vector2, font_size: int = 16, color: Color = text_main) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16 if primary else 14)
	button.add_theme_color_override("font_color", Color("#061832") if primary else text_main)
	button.add_theme_color_override("font_hover_color", Color("#061832") if primary else Color.WHITE)
	var normal_color := Color("#ffb34e") if primary else Color("#133e76", 0.86)
	var hover_color := Color("#ffcf63") if primary else Color("#1b5b9a")
	button.add_theme_stylebox_override("normal", _style_box(normal_color, Color("#ffdf85", .55) if primary else panel_border, 13))
	button.add_theme_stylebox_override("hover", _style_box(hover_color, Color("#fff0a8", .8) if primary else Color("#82dfff", .72), 13))
	button.add_theme_stylebox_override("pressed", _style_box(Color("#e1873f") if primary else Color("#0b315e"), Color("#fff0a8", .8), 13))
	parent.add_child(button)
	return button


func _tint_button(button: Button, normal: Color, hover: Color) -> void:
	button.add_theme_stylebox_override("normal", _style_box(normal, Color("#9aeaff", .42), 11))
	button.add_theme_stylebox_override("hover", _style_box(hover, Color("#fff0b0", .72), 11))
	button.add_theme_stylebox_override("pressed", _style_box(normal.darkened(.2), Color("#fff0b0", .85), 11))


func _mode_card_button(parent: Node, texture: Texture2D, title: String, subtitle: String, rect: Rect2, locked: bool = false) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal", _style_box(Color("#0b2a5a", .86), panel_border, 11))
	button.add_theme_stylebox_override("hover", _style_box(Color("#195388", .9), Color("#9aeaff", .72), 11))
	button.add_theme_stylebox_override("pressed", _style_box(Color("#0d315f", .96), Color("#fff0b0", .84), 11))
	var art := TextureRect.new()
	art.texture = texture
	art.position = Vector2.ZERO
	art.size = rect.size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color(1.0, 1.0, 1.0, .9 if not locked else .66)
	button.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color("#03142e", .78 if not locked else .86)
	shade.position = Vector2(0.0, rect.size.y - 34.0)
	shade.size = Vector2(rect.size.x, 34.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(shade)
	_label(button, title, Vector2(8, rect.size.y - 32), Vector2(rect.size.x - 16, 16), 10, text_main)
	_label(button, subtitle, Vector2(8, rect.size.y - 17), Vector2(rect.size.x - 16, 14), 8, Color("#c5def4"))
	if locked:
		var lock := _label(button, "LOCKED", Vector2(rect.size.x - 53, 7), Vector2(46, 14), 7, Color("#e1edff"))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return button


func _build_menu_ui() -> void:
	menu_ui = _full_control()
	ui_layer.add_child(menu_ui)
	var top := _panel(menu_ui, Rect2(28, 16, 1224, 58), Color("#062653", .88), 16)
	_label(top, "🐾", Vector2(14, 7), Vector2(35, 40), 25, gold)
	var brand := _label(top, "喵咪足球大戰", Vector2(56, 7), Vector2(250, 40), 18, text_main)
	brand.add_theme_color_override("font_shadow_color", Color("#03122d", .8))
	brand.add_theme_constant_override("shadow_offset_x", 2)
	brand.add_theme_constant_override("shadow_offset_y", 2)
	_label(top, "2D ARCADE FOOTBALL", Vector2(790, 11), Vector2(190, 18), 10, Color("#9aeaff"))
	var resources := _panel(top, Rect2(984, 7, 225, 43), Color("#031a3f", .78), 11)
	_label(resources, "● 12,680    ◆ 2,350    ϟ 120/120", Vector2(10, 3), Vector2(210, 35), 11, Color("#fff2b4"))

	# Left column: feature list and selectable roster, matching the reference composition.
	var feature_panel := _panel(menu_ui, Rect2(28, 88, 228, 186), Color("#f6e4b8", .96), 18)
	feature_panel.add_theme_stylebox_override("panel", _style_box(Color("#f6e4b8", .96), Color("#ffe08a", .82), 18))
	_label(feature_panel, "遊戲特色", Vector2(16, 12), Vector2(160, 27), 17, Color("#17345b"))
	_label(feature_panel, "✦  3v3 快速對戰", Vector2(16, 50), Vector2(200, 23), 11, Color("#20385a"))
	_label(feature_panel, "⚽  Q版角色與技能系統", Vector2(16, 77), Vector2(205, 23), 11, Color("#20385a"))
	_label(feature_panel, "◉  簡單操作 · 蓄力射門", Vector2(16, 104), Vector2(205, 23), 11, Color("#20385a"))
	_label(feature_panel, "◆  多種遊戲模式", Vector2(16, 131), Vector2(205, 23), 11, Color("#20385a"))
	_label(feature_panel, "✧  角色養成與裝備", Vector2(16, 158), Vector2(205, 23), 11, Color("#20385a"))

	var roster_panel := _panel(menu_ui, Rect2(28, 288, 228, 360), Color("#07275a", .91), 18)
	_label(roster_panel, "可選角色", Vector2(16, 12), Vector2(160, 27), 17, text_main)
	_label(roster_panel, "3 位喵咪球員", Vector2(16, 39), Vector2(180, 18), 10, Color("#9edfff"))
	var roster := ["✦  喵白白", "●  喵布布", "◆  喵小白"]
	var roles := ["前鋒 · 速度型", "中場 · 技巧型", "守門 · 防守型"]
	var ratings := ["92", "86", "79"]
	for i in range(roster.size()):
		var row := _panel(roster_panel, Rect2(14, 68 + i * 91, 200, 76), Color("#031a43", .72), 12)
		var strip_size: Vector2 = roster_portrait_strip_texture.get_size()
		var portrait := TextureRect.new()
		var portrait_atlas := AtlasTexture.new()
		portrait_atlas.atlas = roster_portrait_strip_texture
		portrait_atlas.region = Rect2(strip_size.x / 3.0 * float(i), 0.0, strip_size.x / 3.0, strip_size.y)
		portrait.texture = portrait_atlas
		portrait.position = Vector2(7, 7)
		portrait.size = Vector2(39, 60)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
		_label(row, roster[i], Vector2(53, 7), Vector2(103, 22), 12, Color("#fff4c4") if i == 0 else text_main)
		_label(row, roles[i], Vector2(53, 31), Vector2(105, 18), 9, text_muted)
		_label(row, ratings[i], Vector2(165, 8), Vector2(28, 25), 16, gold)
		_label(row, ["速度", "技巧", "防守"][i], Vector2(164, 36), Vector2(32, 16), 8, text_muted)
		var stat_bg := ColorRect.new(); stat_bg.color = Color("#173d6b"); stat_bg.position = Vector2(53, 58); stat_bg.size = Vector2(105, 6); stat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(stat_bg)
		var stat_fill := ColorRect.new(); stat_fill.color = Color("#ffcb55") if i == 0 else Color("#6ddaff"); stat_fill.position = Vector2(53, 58); stat_fill.size = Vector2(105.0 * float(int(ratings[i])) / 100.0, 6); stat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(stat_fill)

	# Central hero card with a much stronger mascot focus and a small special-move card.
	var hero := _panel(menu_ui, Rect2(274, 88, 646, 306), Color("#0b3c77", .46), 24)
	hero.clip_contents = true
	menu_hero_art = TextureRect.new()
	menu_hero_art.texture = menu_hero_team_texture
	# Keep the generated 3:2 illustration intact and anchor it to the right;
	# cover-cropping would cut the captain's ears and the ball trail.
	menu_hero_art.position = Vector2(187, 0)
	menu_hero_art.size = Vector2(459, 306)
	menu_hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_hero_art.modulate = Color(1.0, 1.0, 1.0, .92)
	menu_hero_art.z_index = 0
	hero.add_child(menu_hero_art)
	_label(hero, "2D · 3V3 · QUICK MATCH", Vector2(24, 18), Vector2(280, 22), 10, Color("#a5edff"))
	var title := _label(hero, "喵咪\n足球大戰", Vector2(24, 48), Vector2(285, 125), 43, text_main)
	title.add_theme_color_override("font_shadow_color", Color("#061328", .9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	_label(hero, "和喵白白一起上場！\n跑動、碰球、蓄力射門，踢出必殺進球。", Vector2(27, 180), Vector2(270, 55), 11, Color("#d2e8ff"))
	var start := _button(hero, "⚽  開始 3v3 快速賽", Rect2(24, 244, 190, 40), true)
	start.pressed.connect(_start_match)
	var help := _button(hero, "?  操作說明", Rect2(222, 244, 130, 40), false)
	help.pressed.connect(func(): help_overlay.visible = true)
	# Sprite2D keeps the hero art at an exact pixel scale; TextureRect can grow
	# to a texture's minimum size when it is nested in a Panel.
	menu_mascot = Sprite2D.new()
	menu_mascot.texture = hero_action_texture
	menu_mascot.position = Vector2(662, 244)
	menu_mascot.scale = Vector2(.18, .18)
	menu_mascot.centered = true
	menu_mascot.visible = false
	menu_mascot.z_index = 2
	menu_ui.add_child(menu_mascot)
	_label(menu_ui, "●  喵白白 · 速度型前鋒", Vector2(572, 366), Vector2(215, 22), 10, Color("#f1fbff"))
	menu_teammates_art = Sprite2D.new()
	menu_teammates_art.texture = teammates_texture
	menu_teammates_art.position = Vector2(810, 548)
	menu_teammates_art.scale = Vector2(.11, .11)
	menu_teammates_art.centered = true
	menu_teammates_art.modulate = Color(1.0, 1.0, 1.0, .94)
	menu_teammates_art.z_index = 2
	menu_ui.add_child(menu_teammates_art)

	var skill_panel := _panel(menu_ui, Rect2(760, 102, 140, 94), Color("#071f51", .93), 14)
	_label(skill_panel, "必殺技", Vector2(14, 9), Vector2(112, 19), 11, Color("#fff0af"))
	_label(skill_panel, "✧ 海浪射門", Vector2(14, 36), Vector2(112, 18), 10, Color("#dff8ff"))
	_label(skill_panel, "✦ 蓄力滿格", Vector2(14, 61), Vector2(112, 18), 9, Color("#8adfff"))
	special_shot_art = Sprite2D.new()
	special_shot_art.texture = special_shot_texture
	special_shot_art.position = Vector2(116, 49)
	special_shot_art.scale = Vector2(.036, .036)
	special_shot_art.centered = true
	special_shot_art.modulate = Color(1.0, 1.0, 1.0, .9)
	special_shot_art.z_index = 2
	skill_panel.add_child(special_shot_art)

	# Right column: colorful main-menu buttons and mode choices.
	var menu_panel := _panel(menu_ui, Rect2(946, 88, 306, 306), Color("#0a356d", .9), 18)
	_label(menu_panel, "主選單", Vector2(16, 12), Vector2(180, 28), 17, text_main)
	var quick_menu := _button(menu_panel, "⚽  快速比賽", Rect2(16, 51, 274, 40), true)
	quick_menu.pressed.connect(_start_match)
	var tournament := _button(menu_panel, "🏆  錦標賽", Rect2(16, 97, 274, 40), false)
	_tint_button(tournament, Color("#1766a9", .9), Color("#2488cf", .95))
	var trophy_art := Sprite2D.new()
	trophy_art.texture = trophy_texture
	trophy_art.position = Vector2(29, 20)
	trophy_art.scale = Vector2(.027, .027)
	trophy_art.centered = true
	trophy_art.z_index = 2
	tournament.add_child(trophy_art)
	tournament.pressed.connect(func(): _show_toast("錦標賽即將開放，先來一場快速賽吧！", 1.8))
	var story := _button(menu_panel, "▣  故事模式", Rect2(16, 143, 274, 40), false)
	_tint_button(story, Color("#1e8a70", .9), Color("#2cb38d", .95))
	story.pressed.connect(func(): _show_toast("故事模式正在製作中！", 1.6))
	var training := _button(menu_panel, "◆  角色養成", Rect2(16, 189, 274, 40), false)
	_tint_button(training, Color("#674eaa", .92), Color("#8468d0", .95))
	training.pressed.connect(func(): _show_toast("比賽中累積喵力值，就能解鎖必殺技。", 1.8))
	var shop := _button(menu_panel, "▤  商店", Rect2(16, 235, 274, 40), false)
	_tint_button(shop, Color("#117ea8", .92), Color("#1da4d0", .95))
	shop.pressed.connect(func(): _show_toast("商店即將開張！", 1.6))

	var preview_panel := _panel(menu_ui, Rect2(274, 408, 646, 240), Color("#083266", .28), 18)
	_label(preview_panel, "遊戲畫面  ·  3v3 對戰", Vector2(16, 10), Vector2(280, 25), 14, text_main)
	_label(preview_panel, "現在就來試試手感！", Vector2(438, 12), Vector2(185, 20), 9, Color("#ffe9a2"))
	_label(preview_panel, "● 喵咪隊     2       1     紅隊", Vector2(22, 193), Vector2(310, 22), 10, Color("#effaff"))
	_label(preview_panel, "01:32", Vector2(302, 193), Vector2(60, 22), 11, gold)
	var mode_panel := _panel(menu_ui, Rect2(946, 408, 306, 240), Color("#0a356d", .9), 18)
	_label(mode_panel, "遊戲模式", Vector2(16, 12), Vector2(180, 28), 17, text_main)
	var mode_quick := _mode_card_button(mode_panel, mode_quick_texture, "快速賽", "2:00 · 對戰 CPU", Rect2(14, 49, 132, 80))
	mode_quick.pressed.connect(_start_match)
	var mode_tournament := _mode_card_button(mode_panel, mode_tournament_texture, "錦標賽", "淘汰賽 · 即將開放", Rect2(160, 49, 132, 80), true)
	mode_tournament.pressed.connect(func(): _show_toast("錦標賽正在準備中，先來一場快速賽吧！", 1.7))
	var mode_story := _mode_card_button(mode_panel, mode_story_texture, "故事模式", "島嶼冒險 · 即將開放", Rect2(14, 137, 132, 80), true)
	mode_story.pressed.connect(func(): _show_toast("故事模式正在製作中，敬請期待！", 1.7))
	var mode_penalty := _mode_card_button(mode_panel, mode_penalty_texture, "點球挑戰", "5 球制 · 瞄準射門", Rect2(160, 137, 132, 80))
	mode_penalty.pressed.connect(func(): _start_match("penalty"))
	_label(mode_panel, "✧  先拿到 3 分或時間結束時比分較高者獲勝", Vector2(16, 220), Vector2(274, 16), 7, text_muted)


func _build_match_ui() -> void:
	match_ui = _full_control()
	# Let empty pitch space pass pointer/touch events to the gameplay node while
	# keeping the nested buttons and panels interactive.
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(match_ui)
	var top := _panel(match_ui, Rect2(28, 18, 1224, 52), Color("#0a2450", .96), 14)
	_label(top, "●", Vector2(15, 11), Vector2(20, 28), 16, Color("#65e1a0"))
	_label(top, "RIVERSIDE STADIUM", Vector2(40, 5), Vector2(220, 19), 10, Color("#82dfff"))
	match_header_label = _label(top, "快速賽 · 第 1 局", Vector2(40, 22), Vector2(300, 24), 15, text_main)
	pause_button = _button(top, "Ⅱ  暫停", Rect2(1080, 9, 86, 34), false)
	pause_button.pressed.connect(_toggle_pause)
	var quit := _button(top, "退出", Rect2(1172, 9, 60, 34), false)
	quit.pressed.connect(_quit_to_menu)

	var board := _panel(match_ui, Rect2(40, 83, 900, 61), Color("#092d5e", .96), 14)
	hud["blue_score"] = _label(board, "0", Vector2(235, 8), Vector2(45, 45), 30, text_main)
	hud["blue_name"] = _label(board, "🐾  喵咪隊", Vector2(18, 9), Vector2(210, 25), 13, text_main)
	_label(board, "PLAYER", Vector2(20, 33), Vector2(150, 18), 9, text_muted)
	hud["clock"] = _label(board, "2:00", Vector2(410, 8), Vector2(80, 28), 20, gold)
	match_mode_label = _label(board, "快速賽", Vector2(414, 34), Vector2(110, 17), 9, text_muted)
	hud["red_score"] = _label(board, "0", Vector2(615, 8), Vector2(45, 45), 30, text_main)
	hud["red_name"] = _label(board, "紅隊  🐱", Vector2(660, 9), Vector2(210, 25), 13, text_main)
	_label(board, "CPU · NOVICE", Vector2(661, 33), Vector2(180, 18), 9, text_muted)

	# Side panel mirrors the concept art's captain / team / match-data cards.
	var captain := _panel(match_ui, Rect2(963, 83, 289, 176), Color("#0a2c5c", .96), 16)
	_label(captain, "目前操作                         1P", Vector2(14, 10), Vector2(255, 22), 11, Color("#b3d1ed"))
	var portrait := Sprite2D.new()
	portrait.texture = mascot_texture
	portrait.position = Vector2(52, 82)
	portrait.scale = Vector2(.052, .052)
	portrait.centered = true
	portrait.z_index = 1
	captain.add_child(portrait)
	_label(captain, "喵白白", Vector2(101, 42), Vector2(150, 24), 16, text_main)
	_label(captain, "高速衝刺射門", Vector2(101, 66), Vector2(160, 20), 10, text_muted)
	_label(captain, "Lv.12     68%", Vector2(101, 91), Vector2(150, 20), 10, Color("#a9d7f6"))
	_label(captain, "喵力值", Vector2(15, 132), Vector2(100, 18), 10, Color("#c8d9f2"))
	hud["skill"] = _label(captain, "42%", Vector2(238, 132), Vector2(35, 18), 10, gold)
	var skill_bg := ColorRect.new(); skill_bg.color = Color("#143967"); skill_bg.position = Vector2(15, 153); skill_bg.size = Vector2(258, 8); captain.add_child(skill_bg)
	hud["skill_bar"] = ColorRect.new(); hud["skill_bar"].color = Color("#ffd462"); hud["skill_bar"].position = Vector2(15, 153); hud["skill_bar"].size = Vector2(108, 8); captain.add_child(hud["skill_bar"])

	var team_card := _panel(match_ui, Rect2(963, 270, 289, 156), Color("#0a2c5c", .96), 16)
	_label(team_card, "場上隊友", Vector2(14, 10), Vector2(140, 22), 12, Color("#b3d1ed"))
	var team_rows := ["●  喵白白      前鋒 · 1P      92", "●  喵布布      中場 · AI      86", "●  喵小白      守門 · AI      79"]
	for i in range(team_rows.size()):
		_label(team_card, team_rows[i], Vector2(15, 40 + i * 34), Vector2(260, 24), 10, Color("#d3e7ff") if i == 0 else text_muted)

	var stats := _panel(match_ui, Rect2(963, 437, 289, 145), Color("#0a2c5c", .96), 16)
	_label(stats, "比賽資料                         LIVE", Vector2(14, 10), Vector2(260, 22), 11, Color("#b3d1ed"))
	hud["shots"] = _label(stats, "射門                                      0", Vector2(15, 42), Vector2(260, 22), 10, text_muted)
	hud["passes"] = _label(stats, "傳球                                      0", Vector2(15, 68), Vector2(260, 22), 10, text_muted)
	hud["possession"] = _label(stats, "控球率                                  50%", Vector2(15, 94), Vector2(260, 22), 10, text_muted)
	hud["combo"] = _label(stats, "連擊                                      x1", Vector2(15, 120), Vector2(260, 22), 10, gold)

	# Touch-friendly action buttons. Desktop users can use E/Space/Shift/Q/R.
	action_buttons["pass"] = _button(match_ui, "↗\n傳球", Rect2(650, 594, 74, 58), false)
	action_buttons["shoot"] = _button(match_ui, "⚽\n射門", Rect2(733, 580, 88, 72), true)
	action_buttons["dash"] = _button(match_ui, "➤\n衝刺", Rect2(830, 594, 74, 58), false)
	action_buttons["tackle"] = _button(match_ui, "✦\n搶球", Rect2(563, 594, 74, 58), false)
	action_buttons["skill"] = _button(match_ui, "✧\n必殺", Rect2(918, 594, 74, 58), false)
	action_buttons["pass"].pressed.connect(_pass_ball)
	action_buttons["dash"].pressed.connect(_dash)
	action_buttons["tackle"].pressed.connect(_tackle)
	action_buttons["skill"].pressed.connect(_use_skill)
	action_buttons["shoot"].button_down.connect(_begin_shoot)
	action_buttons["shoot"].button_up.connect(_finish_shoot)
	aim_label = _label(match_ui, "長按射門蓄力", Vector2(735, 658), Vector2(180, 20), 10, Color("#ffe5a0"))
	footer_hint_label = _label(match_ui, "⌁ 靠近足球自動控球   ·   SPACE 蓄力射門   ·   E 傳球   ·   SHIFT 衝刺", Vector2(210, 683), Vector2(700, 23), 10, text_muted)


func _build_help_overlay() -> void:
	help_overlay = _full_control()
	help_overlay.visible = false
	ui_layer.add_child(help_overlay)
	var dim := ColorRect.new(); dim.color = Color("#020817", .78); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); help_overlay.add_child(dim)
	var card := _panel(help_overlay, Rect2(350, 120, 580, 475), Color("#0b2b5c", .99), 22)
	_label(card, "QUICK GUIDE", Vector2(28, 25), Vector2(200, 20), 10, Color("#82dfff"))
	_label(card, "3 分鐘學會喵咪足球", Vector2(28, 48), Vector2(480, 42), 25, text_main)
	var guides := ["W A S D / 方向鍵|移動喵白白", "SPACE（長按）|蓄力射門", "E|傳給前方隊友", "SHIFT|短暫衝刺", "Q|鏟球／搶球", "R|喵力值滿時發動必殺"]
	for i in range(guides.size()):
		var parts: PackedStringArray = guides[i].split("|")
		var gx := 28.0 + float(i % 2) * 260.0
		var gy := 112.0 + float(i / 2) * 62.0
		var row := _panel(card, Rect2(gx, gy, 240, 48), Color("#061d45", .82), 10)
		_label(row, parts[0], Vector2(8, 2), Vector2(110, 19), 10, gold)
		_label(row, parts[1], Vector2(8, 22), Vector2(220, 19), 10, text_muted)
	_label(card, "靠近足球會自動控球。先拿到 3 分或時間結束時比分較高者獲勝。", Vector2(29, 305), Vector2(510, 45), 11, text_muted)
	var close := _button(card, "知道了，開始比賽！", Rect2(150, 378, 280, 48), true)
	close.pressed.connect(func(): help_overlay.visible = false; _start_match())


func _build_pause_overlay() -> void:
	pause_overlay = _full_control(); pause_overlay.visible = false; ui_layer.add_child(pause_overlay)
	var dim := ColorRect.new(); dim.color = Color("#020817", .72); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); pause_overlay.add_child(dim)
	var card := _panel(pause_overlay, Rect2(420, 210, 440, 265), Color("#0b2b5c", .99), 22)
	_label(card, "MATCH PAUSED", Vector2(30, 31), Vector2(380, 20), 10, Color("#82dfff"))
	_label(card, "先喘口氣吧！", Vector2(30, 57), Vector2(380, 42), 27, text_main)
	_label(card, "比賽已暫停，準備好就繼續踢。", Vector2(30, 107), Vector2(380, 25), 12, text_muted)
	var resume := _button(card, "▶  繼續比賽", Rect2(30, 155, 380, 40), true)
	resume.pressed.connect(func(): _toggle_pause(false))
	var quit := _button(card, "回到主選單", Rect2(30, 205, 380, 37), false)
	quit.pressed.connect(_quit_to_menu)


func _build_goal_overlay() -> void:
	goal_overlay = _full_control(); goal_overlay.visible = false; ui_layer.add_child(goal_overlay)
	var dim := ColorRect.new(); dim.color = Color("#020817", .62); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); goal_overlay.add_child(dim)
	var card := _panel(goal_overlay, Rect2(385, 155, 510, 390), Color("#11265d", .99), 24)
	card.clip_contents = true
	goal_celebration_art = TextureRect.new()
	goal_celebration_art.texture = goal_celebration_texture
	goal_celebration_art.position = Vector2(125, 48)
	goal_celebration_art.size = Vector2(260, 260)
	goal_celebration_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goal_celebration_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goal_celebration_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_celebration_art.modulate = Color(1.0, 1.0, 1.0, .72)
	goal_celebration_art.visible = false
	goal_celebration_art.z_index = 0
	card.add_child(goal_celebration_art)
	goal_effect_art = Sprite2D.new()
	goal_effect_art.texture = goal_effect_texture
	goal_effect_art.position = Vector2(255, 95)
	goal_effect_art.scale = Vector2(.19, .19)
	goal_effect_art.centered = true
	goal_effect_art.modulate = Color(1.0, 1.0, 1.0, .34)
	goal_effect_art.z_index = 0
	card.add_child(goal_effect_art)
	_label(card, "NICE SHOT!", Vector2(30, 35), Vector2(450, 22), 11, Color("#a8eaff"),)
	hud["goal_title"] = _label(card, "GOAL!", Vector2(20, 55), Vector2(470, 115), 74, gold)
	hud["goal_subtitle"] = _label(card, "喵咪隊拿下一分！", Vector2(30, 176), Vector2(450, 25), 14, text_main)
	hud["goal_score"] = _label(card, "0       —       0", Vector2(30, 210), Vector2(450, 48), 28, text_main)
	goal_continue_button = _button(card, "繼續比賽  →", Rect2(145, 300, 220, 48), true)
	goal_continue_button.pressed.connect(_continue_after_goal)


func _build_toast() -> void:
	toast_panel = _panel(ui_layer, Rect2(420, 28, 440, 42), Color("#092b5d", .97), 12)
	toast_panel.visible = false
	toast_label = _label(toast_panel, "", Vector2(12, 2), Vector2(416, 37), 11, text_main)


func _start_match(mode: String = "quick") -> void:
	game_mode = mode if mode == "penalty" else "quick"
	game_active = true
	paused = false
	goal_lock = false
	final_match = false
	player_score = 0
	cpu_score = 0
	time_left = 35.0 if game_mode == "penalty" else 120.0
	skill = 42.0
	shots = 0
	passes = 0
	blue_touches = 0
	red_touches = 0
	possession_blue = 50
	combo = 1
	combo_timer = 0.0
	shoot_charging = false
	penalty_round = 0
	penalty_goal = false
	penalty_aim = 0.0
	penalty_shot_timer = 0.0
	penalty_shot_active = false
	_reset_positions(true)
	if game_mode == "penalty": _prepare_penalty_round()
	if is_instance_valid(match_header_label): match_header_label.text = "點球挑戰 · 5 球制" if game_mode == "penalty" else "快速賽 · 第 1 局"
	if is_instance_valid(match_mode_label): match_mode_label.text = "點球挑戰" if game_mode == "penalty" else "快速賽"
	if hud.has("red_name"): hud["red_name"].text = "守門員  🧤" if game_mode == "penalty" else "紅隊  🐱"
	_configure_action_buttons()
	menu_ui.visible = false
	match_ui.visible = true
	if is_instance_valid(menu_mascot): menu_mascot.visible = false
	if is_instance_valid(menu_hero_art): menu_hero_art.visible = false
	help_overlay.visible = false
	pause_overlay.visible = false
	goal_overlay.visible = false
	if is_instance_valid(goal_effect_art): goal_effect_art.visible = false
	if is_instance_valid(goal_celebration_art): goal_celebration_art.visible = false
	_update_hud()
	_show_toast("A / D 瞄準，SPACE 射門！" if game_mode == "penalty" else "開球！靠近足球就能自動控球。", 2.4)
	queue_redraw()


func _configure_action_buttons() -> void:
	var quick_mode := game_mode == "quick"
	for key in ["pass", "dash", "tackle", "skill"]:
		if action_buttons.has(key): action_buttons[key].visible = quick_mode
	if action_buttons.has("shoot"):
		action_buttons["shoot"].text = "⚽\n射門" if quick_mode else "🎯\n射門"
	if is_instance_valid(aim_label):
			aim_label.text = "長按射門蓄力" if quick_mode else "A / D 瞄準　SPACE 射門"
	if is_instance_valid(footer_hint_label):
		footer_hint_label.text = "⌁ 點擊／拖曳球場移動   ·   SPACE 蓄力射門   ·   E 傳球   ·   SHIFT 衝刺" if quick_mode else "⌁ 點擊球門落點或 W/S 瞄準   ·   SPACE 出腳   ·   5 球後結算"


func _quit_to_menu() -> void:
	game_active = false
	game_mode = "quick"
	paused = false
	goal_lock = false
	shoot_charging = false
	penalty_shot_active = false
	goal_overlay.visible = false
	pause_overlay.visible = false
	match_ui.visible = false
	menu_ui.visible = true
	if is_instance_valid(menu_mascot): menu_mascot.visible = false
	if is_instance_valid(menu_hero_art): menu_hero_art.visible = true
	move_target_active = false
	_configure_action_buttons()
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


# -----------------------------------------------------------------------------
# Game simulation
# -----------------------------------------------------------------------------

func _generate_crowd() -> void:
	for i in range(86):
		crowd.append({
			"x": randf_range(22.0, WORLD_SIZE.x - 22.0),
			"y": randf_range(16.0, 40.0) if i % 2 == 0 else randf_range(WORLD_SIZE.y - 40.0, WORLD_SIZE.y - 16.0),
			"r": randf_range(2.0, 4.0),
			"color": [Color("#ffe18b"), Color("#8bdcff"), Color("#ff9f9f"), Color("#f4f7ff")][i % 4]
		})


func _new_player(id: String, team: String, player_name: String, role: String, kind: String, x: float, y: float, speed: float, controlled := false) -> Dictionary:
	return {"id": id, "team": team, "name": player_name, "role": role, "kind": kind, "x": x, "y": y, "home_x": x, "home_y": y, "vx": 0.0, "vy": 0.0, "facing": 0.0 if team == BLUE else PI, "speed": speed, "stamina": 100.0, "controlled": controlled, "pulse": randf_range(0.0, TAU), "action_cd": randf_range(.5, 1.6), "number": 10 if controlled else 8}


func _build_teams() -> void:
	players.clear()
	players.append(_new_player("blue-captain", BLUE, "喵白白", "前鋒", "mascot", 310, 360, 265, true))
	players.append(_new_player("blue-mid", BLUE, "喵布布", "中場", "calico", 236, 235, 224))
	players.append(_new_player("blue-keeper", BLUE, "喵小白", "守門", "whitecat", 120, 360, 190))
	players.append(_new_player("red-striker", RED, "紅啵啵", "前鋒", "redcat", 970, 360, 218))
	players.append(_new_player("red-mid", RED, "小栗子", "中場", "redcat", 1040, 235, 205))
	players.append(_new_player("red-keeper", RED, "守門喵", "守門", "redcat", 1160, 360, 180))


func _reset_positions(kickoff := true) -> void:
	for player in players:
		player["x"] = player["home_x"]
		player["y"] = player["home_y"]
		player["vx"] = 0.0
		player["vy"] = 0.0
		player["stamina"] = 100.0
		player["facing"] = 0.0 if player["team"] == BLUE else PI
	ball["x"] = 640.0
	ball["y"] = 360.0
	ball["vx"] = 0.0 if kickoff else randf_range(-40.0, 40.0)
	ball["vy"] = 0.0
	ball["owner"] = ""
	ball["no_claim_until"] = _now() + .55
	dash_timer = 0.0
	dash_cooldown = 0.0
	move_target = Vector2.ZERO
	move_target_active = false


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _user_player() -> Dictionary:
	for player in players:
		if player["controlled"]:
			return player
	return players[0]


func _get_player(id: String) -> Dictionary:
	for player in players:
		if player["id"] == id:
			return player
	return {}


func _team_players(team: String) -> Array:
	return players.filter(func(p): return p["team"] == team)


func _distance_to(point: Vector2, player: Dictionary) -> float:
	return Vector2(float(player["x"]), float(player["y"])).distance_to(point)


func _input_vector() -> Vector2:
	var vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): vector.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): vector.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): vector.y += 1.0
	if vector.length() > .01:
		move_target_active = false
		return vector.normalized()
	if move_target_active:
		var player := _user_player()
		var target_direction := move_target - Vector2(float(player["x"]), float(player["y"]))
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
	if combo_timer <= 0.0: combo = 1
	var player := _user_player()
	_update_controlled(player, delta)
	for teammate in players:
		if teammate["team"] == BLUE and not teammate["controlled"]: _update_teammate(teammate, delta)
	for cpu in players:
		if cpu["team"] == RED: _update_cpu(cpu, delta)
	_resolve_bumps()
	_update_ball(delta)
	var touch_total := blue_touches + red_touches
	if touch_total > 0: possession_blue = int(round(float(blue_touches) / float(touch_total) * 100.0))
	_update_hud()


func _prepare_penalty_round() -> void:
	var shooter := _user_player()
	var keeper := _get_player("red-keeper")
	shooter["x"] = 884.0
	shooter["y"] = 360.0
	shooter["vx"] = 0.0
	shooter["vy"] = 0.0
	shooter["facing"] = 0.0
	keeper["x"] = 1158.0
	keeper["y"] = 360.0
	keeper["vx"] = 0.0
	keeper["vy"] = 0.0
	keeper["facing"] = PI
	ball["x"] = 930.0
	ball["y"] = 360.0
	ball["vx"] = 0.0
	ball["vy"] = 0.0
	ball["owner"] = shooter["id"]
	ball["last_touch"] = BLUE
	ball["no_claim_until"] = _now() + .3
	penalty_aim = 0.0
	penalty_keeper_target_y = 360.0
	penalty_shot_timer = 0.0
	penalty_shot_active = false
	if is_instance_valid(goal_effect_art): goal_effect_art.visible = false
	if is_instance_valid(goal_celebration_art): goal_celebration_art.visible = false
	queue_redraw()


func _update_penalty(delta: float) -> void:
	var keeper := _get_player("red-keeper")
	if penalty_shot_active:
		penalty_shot_timer = maxf(0.0, penalty_shot_timer - delta)
		var progress := 1.0 - penalty_shot_timer / penalty_shot_duration
		var eased := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 1.35)
		ball["x"] = lerpf(penalty_shot_start.x, penalty_shot_target.x, eased)
		ball["y"] = lerpf(penalty_shot_start.y, penalty_shot_target.y, eased)
		keeper["y"] = lerpf(float(keeper["y"]), penalty_keeper_target_y, minf(1.0, delta * 9.0))
		if penalty_shot_timer <= 0.0: _resolve_penalty_shot()
		_update_hud()
		return
	keeper["y"] = lerpf(float(keeper["y"]), 360.0 + sin(_now() * 1.5) * 7.0, minf(1.0, delta * 3.0))
	ball["x"] = 930.0
	ball["y"] = 360.0
	ball["owner"] = "blue-captain"
	_update_hud()


func _penalty_shoot() -> void:
	if not game_active or game_mode != "penalty" or paused or goal_lock or penalty_shot_active: return
	var aim_y := clampf(360.0 + penalty_aim * 112.0, GOAL_TOP + 18.0, GOAL_BOTTOM - 18.0)
	var keeper_slots := [GOAL_TOP + 38.0, 360.0, GOAL_BOTTOM - 38.0]
	penalty_keeper_target_y = float(keeper_slots[randi_range(0, keeper_slots.size() - 1)])
	penalty_goal = absf(aim_y - penalty_keeper_target_y) > 43.0
	penalty_shot_start = Vector2(float(ball["x"]), float(ball["y"]))
	penalty_shot_target = Vector2(PITCH.end.x + 18.0, aim_y)
	penalty_shot_timer = penalty_shot_duration
	penalty_shot_active = true
	ball["owner"] = ""
	shots += 1
	_show_toast("射門！看看能不能騙過守門員。", 1.0)


func _resolve_penalty_shot() -> void:
	penalty_shot_active = false
	penalty_round += 1
	if penalty_goal:
		player_score += 1
		_spawn_goal_particles(1210.0, penalty_shot_target.y, Color("#ffdf69"))
		hud["goal_title"].text = "進球！"
		hud["goal_subtitle"].text = "漂亮的點球，守門員被你騙過了！"
		_show_toast("命中！下一球繼續保持。", 1.1)
	else:
		cpu_score += 1
		_spawn_kick_particles(1160.0, penalty_keeper_target_y, Color("#8fdcff"), 16)
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
	if is_instance_valid(goal_effect_art): goal_effect_art.visible = penalty_goal
	if is_instance_valid(goal_celebration_art): goal_celebration_art.visible = penalty_goal
	_update_hud()
	goal_overlay.visible = true



func _update_controlled(player: Dictionary, delta: float) -> void:
	var input := _input_vector()
	var dashing := dash_timer > 0.0
	var speed: float = player["speed"] * (1.82 if dashing else 1.0)
	if dashing:
		player["stamina"] = maxf(0.0, player["stamina"] - delta * 34.0)
		if player["stamina"] <= 0.0: dash_timer = 0.0
	else: player["stamina"] = minf(100.0, player["stamina"] + delta * 12.0)
	player["vx"] = lerpf(float(player["vx"]), input.x * speed, minf(1.0, delta * 13.0))
	player["vy"] = lerpf(float(player["vy"]), input.y * speed, minf(1.0, delta * 13.0))
	player["x"] += float(player["vx"]) * delta
	player["y"] += float(player["vy"]) * delta
	if input.length() > .08: player["facing"] = atan2(input.y, input.x)
	_keep_on_pitch(player)


func _move_toward(player: Dictionary, target: Vector2, delta: float, scale := 1.0) -> void:
	var direction := (target - Vector2(float(player["x"]), float(player["y"]))).normalized()
	var speed: float = player["speed"] * scale
	player["vx"] = lerpf(float(player["vx"]), direction.x * speed, minf(1.0, delta * 8.0))
	player["vy"] = lerpf(float(player["vy"]), direction.y * speed, minf(1.0, delta * 8.0))
	player["x"] += float(player["vx"]) * delta
	player["y"] += float(player["vy"]) * delta
	if direction.length() > .1: player["facing"] = atan2(direction.y, direction.x)
	_keep_on_pitch(player)


func _keep_on_pitch(player: Dictionary) -> void:
	player["x"] = clampf(float(player["x"]), PITCH.position.x + 23.0, PITCH.end.x - 23.0)
	player["y"] = clampf(float(player["y"]), PITCH.position.y + 24.0, PITCH.end.y - 24.0)


func _update_teammate(player: Dictionary, delta: float) -> void:
	var owner := _get_player(str(ball["owner"]))
	var target := Vector2(float(player["home_x"]), float(player["home_y"]))
	if not owner.is_empty() and owner["team"] == BLUE:
		if player["role"] == "中場": target = Vector2(clampf(float(owner["x"]) + 85.0, 120.0, 1110.0), clampf(float(owner["y"]) - 110.0, 100.0, 620.0))
		else: target = Vector2(clampf(float(owner["x"]) - 115.0, 85.0, 1120.0), clampf(float(owner["y"]) + 100.0, 100.0, 620.0))
	elif not owner.is_empty() and owner["team"] == RED and _distance_to(Vector2(float(ball["x"]), float(ball["y"])), player) < 240.0:
		target = Vector2(float(ball["x"]) - 40.0, float(ball["y"]))
	else:
		target = Vector2(lerpf(float(player["home_x"]), float(ball["x"]) - 85.0, .15), lerpf(float(player["home_y"]), float(ball["y"]), .08))
	_move_toward(player, target, delta, .72)


func _nearest_player(point: Vector2, team: String) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for player in players:
		if player["team"] != team: continue
		var current := _distance_to(point, player)
		if current < best_distance: best_distance = current; best = player
	return best


func _update_cpu(player: Dictionary, delta: float) -> void:
	var owner := _get_player(str(ball["owner"]))
	var nearest := _nearest_player(Vector2(float(ball["x"]), float(ball["y"])), RED)
	var target := Vector2(float(player["home_x"]), float(player["home_y"]))
	if not owner.is_empty() and owner["id"] == player["id"]:
		target = Vector2(100.0, clampf(lerpf(float(player["y"]), 360.0, .01), 100.0, 620.0))
		player["action_cd"] = float(player["action_cd"]) - delta
		if float(player["action_cd"]) <= 0.0 and float(player["x"]) < 560.0:
			_cpu_shoot(player); player["action_cd"] = randf_range(1.6, 2.8)
	elif owner.is_empty() and not nearest.is_empty() and nearest["id"] == player["id"]:
		target = Vector2(float(ball["x"]), float(ball["y"]))
	elif not owner.is_empty() and owner["team"] == BLUE and (_distance_to(Vector2(float(owner["x"]), float(owner["y"])), player) < 240.0 or player["role"] == "前鋒"):
		target = Vector2(float(owner["x"]) + 20.0, float(owner["y"]))
	else:
		target = Vector2(lerpf(float(player["home_x"]), float(ball["x"]) + 110.0, .07), lerpf(float(player["home_y"]), float(ball["y"]), .06))
	_move_toward(player, target, delta, .64 if player["role"] == "守門" else .78)


func _claim_ball(player: Dictionary) -> bool:
	if _now() < float(ball["no_claim_until"]): return false
	ball["owner"] = player["id"]
	ball["last_touch"] = player["team"]
	if player["team"] == BLUE: blue_touches += 1
	else: red_touches += 1
	return true


func _auto_possession() -> void:
	if str(ball["owner"]) != "" or _now() < float(ball["no_claim_until"]): return
	var best: Dictionary = {}
	var best_distance := 45.0
	for player in players:
		var current := _distance_to(Vector2(float(ball["x"]), float(ball["y"])), player)
		if current < best_distance: best_distance = current; best = player
	if not best.is_empty(): _claim_ball(best)


func _update_ball(delta: float) -> void:
	var owner := _get_player(str(ball["owner"]))
	if not owner.is_empty():
		ball["x"] = float(owner["x"]) + cos(float(owner["facing"])) * 31.0
		ball["y"] = float(owner["y"]) + sin(float(owner["facing"])) * 31.0
		ball["vx"] = owner["vx"]; ball["vy"] = owner["vy"]
		return
	ball["x"] += float(ball["vx"]) * delta
	ball["y"] += float(ball["vy"]) * delta
	var drag := pow(.085, delta)
	ball["vx"] *= drag; ball["vy"] *= drag
	var in_goal_mouth := float(ball["y"]) > GOAL_TOP and float(ball["y"]) < GOAL_BOTTOM
	if float(ball["y"]) < PITCH.position.y + 14.0: ball["y"] = PITCH.position.y + 14.0; ball["vy"] = absf(float(ball["vy"])) * .72
	if float(ball["y"]) > PITCH.end.y - 14.0: ball["y"] = PITCH.end.y - 14.0; ball["vy"] = -absf(float(ball["vy"])) * .72
	if in_goal_mouth and float(ball["x"]) < -14.0: _score_goal(RED); return
	if in_goal_mouth and float(ball["x"]) > WORLD_SIZE.x + 14.0: _score_goal(BLUE); return
	if not in_goal_mouth and float(ball["x"]) < PITCH.position.x + 14.0: ball["x"] = PITCH.position.x + 14.0; ball["vx"] = absf(float(ball["vx"])) * .72
	if not in_goal_mouth and float(ball["x"]) > PITCH.end.x - 14.0: ball["x"] = PITCH.end.x - 14.0; ball["vx"] = -absf(float(ball["vx"])) * .72
	_auto_possession()


func _resolve_bumps() -> void:
	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var a: Dictionary = players[i]; var b: Dictionary = players[j]
			var delta := Vector2(float(b["x"]) - float(a["x"]), float(b["y"]) - float(a["y"]))
			var dist := maxf(delta.length(), .001)
			var minimum := 45.0
			if dist < minimum:
				var push := (minimum - dist) / 2.0; var normal := delta / dist
				a["x"] -= normal.x * push; a["y"] -= normal.y * push; b["x"] += normal.x * push; b["y"] += normal.y * push
				_keep_on_pitch(a); _keep_on_pitch(b)
	var owner := _get_player(str(ball["owner"]))
	if not owner.is_empty():
		for opponent in players:
			if opponent["team"] == owner["team"]: continue
			if _distance_to(Vector2(float(owner["x"]), float(owner["y"])), opponent) < 40.0 and randf() < .012:
				ball["owner"] = opponent["id"]; ball["last_touch"] = opponent["team"]; red_touches += 1; _show_toast("被紅隊碰到了，快搶回來！", 1.0); break


# -----------------------------------------------------------------------------
# Actions and match state
# -----------------------------------------------------------------------------

func _ensure_user_possession() -> bool:
	var player := _user_player()
	if str(ball["owner"]) == player["id"]: return true
	if str(ball["owner"]) == "" and _distance_to(Vector2(float(ball["x"]), float(ball["y"])), player) < 68.0: return _claim_ball(player)
	return false


func _begin_shoot() -> void:
	if not game_active or paused or goal_lock or shoot_charging: return
	if game_mode == "penalty":
		_penalty_shoot()
		return
	if not _ensure_user_possession(): _show_toast("靠近足球後才能射門！", 1.1); return
	shoot_charging = true; shoot_started_at = Time.get_ticks_msec(); aim_label.text = "放開射門！力量正在累積"


func _finish_shoot() -> void:
	if game_mode == "penalty":
		shoot_charging = false
		return
	if not shoot_charging: return
	shoot_charging = false
	var player := _user_player()
	if str(ball["owner"]) != player["id"]: return
	var charge := clampf(float(Time.get_ticks_msec() - shoot_started_at) / 1000.0, .18, 1.0)
	var direction := Vector2(cos(float(player["facing"])), sin(float(player["facing"]))).normalized()
	var speed := 490.0 + charge * 430.0
	_release_ball(direction * speed, BLUE)
	shots += 1; combo_timer = 4.0; _set_skill(10.0 + charge * 7.0)
	_spawn_kick_particles(float(player["x"]) + direction.x * 30.0, float(player["y"]) + direction.y * 30.0, Color("#ffe17b"), 8)
	_show_toast("Perfect Timing！超強射門！" if charge > .82 else "射門！把球送進球門！", 1.3)
	aim_label.text = "長按射門蓄力"


func _pass_ball() -> void:
	if not game_active or paused or goal_lock: return
	if not _ensure_user_possession(): _show_toast("還沒拿到球，先靠近一點！", 1.1); return
	var player := _user_player(); var target: Dictionary = {}
	var best_score := -INF
	var facing := Vector2(cos(float(player["facing"])), sin(float(player["facing"])))
	for mate in players:
		if mate["team"] != BLUE or mate["id"] == player["id"]: continue
		var offset := Vector2(float(mate["x"]) - float(player["x"]), float(mate["y"]) - float(player["y"]))
		var score := offset.dot(facing) - offset.length() * .22
		if score > best_score: best_score = score; target = mate
	if target.is_empty(): return
	var direction := Vector2(float(target["x"]) - float(player["x"]), float(target["y"]) - float(player["y"])).normalized()
	_release_ball(direction * 470.0, BLUE); passes += 1; combo_timer = 4.0; _set_skill(6.0)
	_spawn_kick_particles(float(player["x"]) + direction.x * 28.0, float(player["y"]) + direction.y * 28.0, Color("#78dfff"), 5)
	_show_toast("傳給 %s！" % target["name"], 1.0)


func _dash() -> void:
	if not game_active or paused or goal_lock: return
	var player := _user_player()
	if float(player["stamina"]) < 18.0 or dash_cooldown > 0.0: _show_toast("體力還沒恢復！", .9); return
	dash_timer = .27; dash_cooldown = .72; player["stamina"] = float(player["stamina"]) - 15.0
	_spawn_kick_particles(float(player["x"]), float(player["y"]) + 17.0, Color("#6de6ff"), 5)


func _tackle() -> void:
	if not game_active or paused or goal_lock: return
	var player := _user_player(); var owner := _get_player(str(ball["owner"]))
	if not owner.is_empty() and owner["team"] == RED and _distance_to(Vector2(float(player["x"]), float(player["y"])), owner) < 76.0:
		ball["owner"] = player["id"]; ball["last_touch"] = BLUE; blue_touches += 1; _set_skill(12.0); _spawn_kick_particles(float(player["x"]), float(player["y"]), Color("#9ce7ff"), 10); _show_toast("漂亮搶球！", 1.0); return
	if str(ball["owner"]) == "" and _distance_to(Vector2(float(ball["x"]), float(ball["y"])), player) < 82.0:
		_claim_ball(player); _set_skill(7.0); _show_toast("把球留下來！", .9); return
	dash_timer = maxf(dash_timer, .16)


func _use_skill() -> void:
	if not game_active or paused or goal_lock: return
	if skill < 100.0: _show_toast("喵力值還差 %d%%！" % int(ceil(100.0 - skill)), 1.1); return
	if not _ensure_user_possession(): _show_toast("拿到球才能發動必殺技！", 1.1); return
	var player := _user_player(); var direction := Vector2(cos(float(player["facing"])), sin(float(player["facing"]))).normalized()
	_release_ball(direction * 1050.0, BLUE); shots += 1; skill = 0.0; combo_timer = 7.0
	_spawn_kick_particles(float(player["x"]) + direction.x * 30.0, float(player["y"]) + direction.y * 30.0, Color("#ffdc62"), 22)
	_show_toast("海浪射門！必殺技發動！", 1.8)


func _release_ball(velocity: Vector2, source_team: String) -> void:
	ball["owner"] = ""; ball["vx"] = velocity.x; ball["vy"] = velocity.y; ball["last_touch"] = source_team; ball["no_claim_until"] = _now() + .17


func _cpu_shoot(player: Dictionary) -> void:
	var target_y := 360.0 + randf_range(-95.0, 95.0)
	var direction := Vector2(-float(player["x"]) + 48.0, target_y - float(player["y"])).normalized()
	_release_ball(direction * randf_range(430.0, 560.0), RED)
	_spawn_kick_particles(float(player["x"]) + direction.x * 27.0, float(player["y"]) + direction.y * 27.0, Color("#ff9e79"), 6)


func _set_skill(amount: float) -> void:
	skill = clampf(skill + amount, 0.0, 100.0)
	_update_hud()


func _score_goal(team: String) -> void:
	if goal_lock: return
	if game_mode == "penalty": return
	goal_lock = true; paused = true
	ball["owner"] = ""; ball["vx"] = 0.0; ball["vy"] = 0.0
	if team == BLUE:
		player_score += 1; combo = mini(combo + 1, 9); skill = clampf(skill + 30.0, 0.0, 100.0); _spawn_goal_particles(1210.0, 360.0, Color("#ffdf69"))
	else:
		cpu_score += 1; combo = 1; _spawn_goal_particles(70.0, 360.0, Color("#ff8a77"))
	final_match = player_score >= 3 or cpu_score >= 3 or time_left <= 0.0
	hud["goal_title"].text = "GOAL!"
	hud["goal_subtitle"].text = "喵咪隊拿下一分！" if team == BLUE else "紅隊突破了防線！"
	hud["goal_score"].text = "%d       —       %d" % [player_score, cpu_score]
	goal_continue_button.text = "查看比賽結果  →" if final_match else "繼續比賽  →"
	if is_instance_valid(goal_effect_art): goal_effect_art.visible = true
	if is_instance_valid(goal_celebration_art): goal_celebration_art.visible = team == BLUE
	_update_hud(); goal_overlay.visible = true


func _finish_match_by_time() -> void:
	if goal_lock or game_mode == "penalty": return
	goal_lock = true; paused = true; final_match = true
	hud["goal_title"].text = "時間到！"
	hud["goal_subtitle"].text = "平局！兩隊都踢得很精彩" if player_score == cpu_score else ("喵咪隊拿下勝利！" if player_score > cpu_score else "紅隊暫時領先，下次再來挑戰！")
	hud["goal_score"].text = "%d       —       %d" % [player_score, cpu_score]
	goal_continue_button.text = "返回主選單  →"
	if is_instance_valid(goal_effect_art): goal_effect_art.visible = false
	if is_instance_valid(goal_celebration_art): goal_celebration_art.visible = false
	_update_hud(); goal_overlay.visible = true


func _continue_after_goal() -> void:
	if final_match: _quit_to_menu(); return
	if game_mode == "penalty":
		goal_overlay.visible = false
		goal_lock = false
		paused = false
		_prepare_penalty_round()
		_show_toast("第 %d 球！W/S 或 A/D 瞄準後按 SPACE。" % (penalty_round + 1), 1.5)
		return
	goal_overlay.visible = false; goal_lock = false; paused = false; _reset_positions(true); _show_toast("重新開球！這次換你進攻。", 1.2)


func _spawn_kick_particles(x: float, y: float, color: Color, count: int) -> void:
	for i in range(count): particles.append({"x": x, "y": y, "vx": randf_range(-100, 100), "vy": randf_range(-100, 100), "life": randf_range(.3, .7), "size": randf_range(2, 5), "color": color})


func _spawn_goal_particles(x: float, y: float, color: Color) -> void:
	for i in range(64):
		var angle := randf_range(-PI, PI); var speed := randf_range(90, 440)
		particles.append({"x": x, "y": y, "vx": cos(angle) * speed, "vy": sin(angle) * speed, "life": randf_range(.8, 1.9), "size": randf_range(3, 8), "color": color if i % 3 else Color("#fff4bb")})


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["life"] = float(particle["life"]) - delta
		particle["x"] += float(particle["vx"]) * delta; particle["y"] += float(particle["vy"]) * delta
		particle["vx"] *= pow(.08, delta); particle["vy"] *= pow(.08, delta); particle["size"] *= pow(.4, delta)
		if float(particle["life"]) <= 0.0: particles.remove_at(i)


# -----------------------------------------------------------------------------
# Rendering
# -----------------------------------------------------------------------------

func _draw() -> void:
	# Logical 1280x720 coordinates are scaled by Godot's canvas stretch setting.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#06152f"))
	if not game_active:
		_draw_menu_backdrop()
		return
	if game_mode == "penalty":
		_draw_penalty_mode()
		return
	_draw_stadium()
	_draw_pitch()
	_draw_goals()
	for player in players: _draw_player(player)
	_draw_ball()
	for particle in particles:
		var alpha := clampf(float(particle["life"]), 0.0, 1.0)
		draw_circle(Vector2(float(particle["x"]), float(particle["y"])), float(particle["size"]), Color(particle["color"], alpha))
	if move_target_active: _draw_move_target()
	if shoot_charging: _draw_aim_guide()


func _draw_menu_backdrop() -> void:
	# The generated stadium illustration supplies the high-density visual layer;
	# live panels and the playable preview remain rendered above it.
	draw_texture_rect(menu_background_texture, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, WORLD_SIZE.y), Color("#062653", .08))
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 92), Color("#062653", .18))
	# Confetti around the top edge echoes the reference image's celebration mood.
	var confetti := [Vector2(320, 36), Vector2(476, 72), Vector2(704, 35), Vector2(850, 63), Vector2(1115, 37), Vector2(1220, 112)]
	var confetti_colors := [Color("#ffe06b"), Color("#ff9f7b"), Color("#ffffff"), Color("#79e3ff")]
	for i in range(confetti.size()):
		var p: Vector2 = confetti[i]
		var points := PackedVector2Array([p, p + Vector2(9, 4), p + Vector2(5, 13), p + Vector2(-4, 8)])
		draw_colored_polygon(points, confetti_colors[i % confetti_colors.size()])
	# Small 3v3 match preview behind the translucent panel.
	var preview := Rect2(292, 452, 610, 170)
	draw_rect(preview, Color("#178a59", .98))
	for i in range(6):
		if i % 2 == 0:
			draw_rect(Rect2(preview.position.x + float(i) * 102.0, preview.position.y, 102.0, preview.size.y), Color("#72d993", .11))
	draw_rect(preview, Color("#e9fff0", .86), false, 2.0)
	draw_line(Vector2(597, 452), Vector2(597, 622), Color("#e9fff0", .72), 2.0)
	draw_arc(Vector2(597, 537), 31.0, 0, TAU, 32, Color("#e9fff0", .7), 2.0)
	draw_rect(Rect2(292, 496, 66, 82), Color("#e9fff0", .7), false, 2.0)
	draw_rect(Rect2(836, 496, 66, 82), Color("#e9fff0", .7), false, 2.0)
	var preview_blue := {"team": BLUE, "kind": "whitecat", "number": 10, "x": 492.0, "y": 532.0}
	var preview_blue_2 := {"team": BLUE, "kind": "calico", "number": 8, "x": 430.0, "y": 488.0}
	var preview_red := {"team": RED, "kind": "redcat", "number": 9, "x": 695.0, "y": 535.0}
	_draw_generated_player(white_player_texture, Vector2(preview_blue["x"], preview_blue["y"]), true)
	_draw_generated_player(calico_player_texture, Vector2(preview_blue_2["x"], preview_blue_2["y"]), false)
	_draw_generated_player(red_player_texture, Vector2(preview_red["x"], preview_red["y"]), false)
	draw_circle(Vector2(600, 538), 9.0, Color("#fbfdff"))
	draw_circle(Vector2(600, 538), 3.0, Color("#172847"))


func _draw_penalty_mode() -> void:
	_draw_stadium()
	_draw_pitch()
	_draw_goals()
	var shooter := _user_player()
	var keeper := _get_player("red-keeper")
	_draw_player(shooter)
	if penalty_shot_active:
		_draw_goalkeeper_dive(keeper)
	else:
		_draw_player(keeper)
	var target_y := penalty_shot_target.y if penalty_shot_active else clampf(360.0 + penalty_aim * 112.0, GOAL_TOP + 18.0, GOAL_BOTTOM - 18.0)
	var target := Vector2(PITCH.end.x - 22.0, target_y)
	var ball_position := Vector2(float(ball["x"]), float(ball["y"]))
	if not penalty_shot_active:
		draw_dashed_line(ball_position, target, Color("#ffdf73", .84), 4.0, 10.0)
		draw_circle(target, 17.0 + sin(_now() * 5.0) * 2.0, Color("#ffe275", .12))
		draw_arc(target, 17.0, 0, TAU, 32, Color("#ffe275", .9), 3.0)
		draw_line(target + Vector2(-9, 0), target + Vector2(9, 0), Color("#fff6c2"), 2.0)
		draw_line(target + Vector2(0, -9), target + Vector2(0, 9), Color("#fff6c2"), 2.0)
	else:
		draw_circle(target, 13.0, Color("#9fe8ff", .25))
	for particle in particles:
		var alpha := clampf(float(particle["life"]), 0.0, 1.0)
		draw_circle(Vector2(float(particle["x"]), float(particle["y"])), float(particle["size"]), Color(particle["color"], alpha))
	_draw_ball()


func _draw_stadium() -> void:
	# Generated match art fills the stadium layer while live pitch geometry is drawn above it.
	draw_texture_rect(match_background_texture, Rect2(Vector2.ZERO, WORLD_SIZE), false)
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, WORLD_SIZE.y), Color("#06152f", .22))
	draw_rect(Rect2(0, 0, WORLD_SIZE.x, 78), Color("#04152f", .32))
	for person in crowd:
		draw_circle(Vector2(float(person["x"]), float(person["y"])), float(person["r"]), person["color"])
	draw_rect(Rect2(0, 43, WORLD_SIZE.x, 9), Color("#04172e", .36))
	draw_rect(Rect2(0, WORLD_SIZE.y - 50, WORLD_SIZE.x, 9), Color("#04172e", .44))


func _draw_pitch() -> void:
	draw_rect(PITCH, Color("#198354"))
	for i in range(12):
		var stripe := Rect2(PITCH.position.x + float(i) * 100.0, PITCH.position.y, 100.0, PITCH.size.y)
		draw_rect(stripe, Color("#53c37e", .12) if i % 2 == 0 else Color("#063e2b", .08))
	draw_rect(PITCH, Color("#eafff1", .88), false, 4.0)
	draw_line(Vector2(640, PITCH.position.y), Vector2(640, PITCH.end.y), Color("#eafff1", .78), 3.0)
	draw_arc(Vector2(640, 360), 86, 0, TAU, 64, Color("#eafff1", .78), 3.0)
	draw_circle(Vector2(640, 360), 4, Color("#eafff1"))
	_draw_penalty(true); _draw_penalty(false)
	draw_arc(Vector2(212, 360), 70, -PI / 2, PI / 2, 40, Color("#eafff1", .55), 2.0)
	draw_arc(Vector2(1068, 360), 70, PI / 2, PI * 1.5, 40, Color("#eafff1", .55), 2.0)


func _draw_penalty(left: bool) -> void:
	var x := PITCH.position.x if left else PITCH.end.x - 164.0
	draw_rect(Rect2(x, 215, 164, 290), Color("#eafff1", .72), false, 3.0)
	var small_x := PITCH.position.x if left else PITCH.end.x - 74.0
	draw_rect(Rect2(small_x, 284, 74, 152), Color("#eafff1", .72), false, 3.0)


func _draw_goals() -> void:
	for left in [true, false]:
		var x := PITCH.position.x - 3.0 if left else PITCH.end.x + 3.0
		var direction := -1.0 if left else 1.0
		var points := PackedVector2Array([Vector2(x, GOAL_TOP), Vector2(x + direction * 45.0, GOAL_TOP), Vector2(x + direction * 45.0, GOAL_BOTTOM), Vector2(x, GOAL_BOTTOM)])
		draw_polyline(points, Color("#effaff", .9), 6.0)
		for y in range(int(GOAL_TOP + 14), int(GOAL_BOTTOM), 18): draw_line(Vector2(x, y), Vector2(x + direction * 45.0, y), Color("#d8f1ff", .25), 2.0)


func _draw_aim_guide() -> void:
	var player := _user_player()
	var charge := clampf(float(Time.get_ticks_msec() - shoot_started_at) / 1000.0, 0.0, 1.0)
	var direction := Vector2(cos(float(player["facing"])), sin(float(player["facing"]))).normalized()
	var from := Vector2(float(player["x"]), float(player["y"])) + direction * 32.0
	var to := from + direction * (180.0 + charge * 350.0)
	draw_dashed_line(from, to, Color(1.0, .88, .35, .52 + charge * .4), 5.0, 12.0)
	draw_circle(from.lerp(to, .35 + charge * .2), 6.0 + charge * 6.0, Color("#ffdc5e"))


func _draw_move_target() -> void:
	var pulse := 1.0 + sin(_now() * 6.0) * .12
	draw_circle(move_target, 18.0 * pulse, Color("#74e6ff", .12))
	draw_arc(move_target, 14.0 * pulse, 0.0, TAU, 32, Color("#8deaff", .9), 2.0)
	draw_line(move_target + Vector2(-7, 0), move_target + Vector2(7, 0), Color("#dffbff", .9), 2.0)
	draw_line(move_target + Vector2(0, -7), move_target + Vector2(0, 7), Color("#dffbff", .9), 2.0)


func _draw_player(player: Dictionary) -> void:
	var position := Vector2(float(player["x"]), float(player["y"]))
	var owner: bool = str(ball["owner"]) == str(player["id"])
	var bob := sin(_now() * 3.8 + float(player["pulse"])) * (1.9 if owner else .8)
	position.y += bob
	_draw_oval(position + Vector2(0, 27), Vector2(33, 11), Color("#05271f", .42))
	if player["controlled"]:
		draw_arc(position + Vector2(0, 3), 38.0 + sin(_now() * 6.0) * 2.0, 0, TAU, 48, Color("#ffe266", .95), 3.0)
		draw_style_box(_style_box(Color("#fff0a4"), Color.TRANSPARENT, 7), Rect2(position + Vector2(-20, -51), Vector2(40, 17)))
		draw_string(ThemeDB.fallback_font, position + Vector2(-20, -38), "1P", HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color("#31548c"))
	if player["kind"] == "mascot":
		var sprite_size := Vector2(98, 110) if owner else Vector2(88, 99)
		draw_texture_rect(mascot_texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * .86), sprite_size), false)
	elif player["kind"] == "calico":
		_draw_generated_player(calico_player_texture, position, owner)
	elif player["kind"] == "whitecat":
		_draw_generated_player(white_player_texture, position, owner)
	elif player["kind"] == "redcat":
		_draw_generated_player(red_player_texture, position, owner)
	else:
		_draw_vector_player(player, position, owner)
	draw_string(ThemeDB.fallback_font, position + Vector2(-50, 46), str(player["name"]), HORIZONTAL_ALIGNMENT_CENTER, 100, 11, Color("#eaf8ff"))


func _draw_generated_player(texture: Texture2D, position: Vector2, owner: bool) -> void:
	var sprite_size := Vector2(92, 99) if owner else Vector2(84, 91)
	draw_texture_rect(texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * .86), sprite_size), false)


func _draw_goalkeeper_dive(keeper: Dictionary) -> void:
	var position := Vector2(float(keeper["x"]), float(keeper["y"]))
	var bob := sin(_now() * 4.0) * .8
	_draw_oval(position + Vector2(0, 27), Vector2(43, 12), Color("#05271f", .42))
	var sprite_size := Vector2(132, 88)
	draw_texture_rect(goalkeeper_dive_texture, Rect2(position - Vector2(sprite_size.x / 2.0, sprite_size.y * .72) + Vector2(0, bob), sprite_size), false)


func _draw_oval(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var angle := TAU * float(i) / 24.0; points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw_vector_player(player: Dictionary, position: Vector2, owner: bool) -> void:
	var body := Color("#f4f6ff")
	var shirt := Color("#e7eaf5")
	var trim := Color("#7cb8f7")
	var ear := Color("#ffc3c9")
	if player["kind"] == "calico": body = Color("#e99659"); shirt = Color("#134c90"); trim = Color("#ffdb79"); ear = Color("#ffb18d")
	if player["team"] == RED: body = Color("#a96d55"); shirt = Color("#9b304e"); trim = Color("#ffab6f"); ear = Color("#e89e87")
	if owner: draw_circle(position, 30.0, Color("#67d9ff", .18) if player["team"] == BLUE else Color("#ff7e65", .18))
	_draw_oval(position + Vector2(0, 9), Vector2(24, 26), shirt)
	draw_rect(Rect2(position + Vector2(-3, -11), Vector2(6, 31)), trim)
	draw_circle(position + Vector2(0, -14), 22, body)
	var left_ear := PackedVector2Array([position + Vector2(-18, -26), position + Vector2(-14, -47), position + Vector2(-2, -32)])
	var right_ear := PackedVector2Array([position + Vector2(18, -26), position + Vector2(14, -47), position + Vector2(2, -32)])
	draw_colored_polygon(left_ear, ear); draw_colored_polygon(right_ear, ear)
	draw_circle(position + Vector2(-8, -15), 3.5, Color("#1a2140")); draw_circle(position + Vector2(8, -15), 3.5, Color("#1a2140"))
	draw_circle(position + Vector2(0, -6), 3, Color("#f6b3b3"))
	draw_string(ThemeDB.fallback_font, position + Vector2(-20, 13), str(player["number"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color.WHITE)


func _draw_ball() -> void:
	var position := Vector2(float(ball["x"]), float(ball["y"]))
	_draw_oval(position + Vector2(4, 12), Vector2(18, 7), Color("#05291e", .28))
	if str(ball["owner"]) != "": draw_circle(position, 29, Color("#70e0ff", .20) if ball["last_touch"] == BLUE else Color("#ff7e65", .2))
	draw_circle(position, 14, Color("#fbfdff")); draw_arc(position, 14, 0, TAU, 30, Color("#172847"), 2)
	draw_circle(position, 5, Color("#182a4b"))
	for i in range(5):
		var angle := float(i) * TAU / 5.0 + .28
		draw_line(position + Vector2(cos(angle), sin(angle)) * 5.0, position + Vector2(cos(angle), sin(angle)) * 11.0, Color("#182a4b"), 2)
