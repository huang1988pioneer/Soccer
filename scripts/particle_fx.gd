class_name ParticleFx
extends RefCounted

var live: Array[Dictionary] = []
var _pool: Array[Dictionary] = []


func clear() -> void:
	for particle in live:
		_pool.append(particle)
	live.clear()


func spawn_kick(x: float, y: float, color: Color, count: int) -> void:
	for _i in count:
		_spawn(x, y, randf_range(-100.0, 100.0), randf_range(-100.0, 100.0), randf_range(0.3, 0.7), randf_range(2.0, 5.0), color)


func spawn_goal(x: float, y: float, color: Color) -> void:
	for i in 64:
		var angle := randf_range(-PI, PI)
		var speed := randf_range(90.0, 440.0)
		_spawn(x, y, cos(angle) * speed, sin(angle) * speed, randf_range(0.8, 1.9), randf_range(3.0, 8.0), color if i % 3 else Color("#fff4bb"))


func update(delta: float) -> void:
	var i := live.size() - 1
	while i >= 0:
		var particle: Dictionary = live[i]
		particle.life = float(particle.life) - delta
		if float(particle.life) <= 0.0:
			_pool.append(particle)
			live.remove_at(i)
			i -= 1
			continue
		particle.x = float(particle.x) + float(particle.vx) * delta
		particle.y = float(particle.y) + float(particle.vy) * delta
		var drag := pow(0.08, delta)
		particle.vx = float(particle.vx) * drag
		particle.vy = float(particle.vy) * drag
		particle.size = float(particle.size) * pow(0.4, delta)
		i -= 1


func draw_on(item: CanvasItem) -> void:
	for particle in live:
		item.draw_circle(Vector2(float(particle.x), float(particle.y)), float(particle.size), Color(particle.color, clampf(float(particle.life), 0.0, 1.0)))


func _spawn(x: float, y: float, vx: float, vy: float, life: float, size: float, color: Color) -> void:
	var particle: Dictionary = _pool.pop_back() if not _pool.is_empty() else {}
	particle.x = x
	particle.y = y
	particle.vx = vx
	particle.vy = vy
	particle.life = life
	particle.size = size
	particle.color = color
	live.append(particle)
