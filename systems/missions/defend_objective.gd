class_name DefendObjective
extends MissionObjective
## 거점 방어: survive_time 동안 버티면 승리. 적만 거점에 있으면 점령 게이지 상승, 100 도달 시 패배.
## 웨이브: 시간에 따라 수/HP 증가 (실드·힐 턴틀링 억제). 적은 UnitPool로 재사용.

const GAUGE_MAX: float = 100.0
const ZONE_FILL: Color = Color(0.29, 0.53, 0.91, 0.08)
const ZONE_RING: Color = Color(0.29, 0.53, 0.91, 0.6)
const ZONE_DANGER: Color = Color(0.85, 0.22, 0.22, 0.9)

var zone_center: Vector2 = Vector2.ZERO
var spawn_points: Array[Vector2] = []
var unit_container: Node

var gauge: float = 0.0
var elapsed: float = 0.0
var wave: int = 0

var _next_wave_in: float = 0.0
var _pool: UnitPool
var _enemies_in: int = 0
var _allies_in: int = 0
var _drawn_gauge: int = -1


func configure(center: Vector2, spawns: Array[Vector2], container: Node) -> void:
	zone_center = center
	spawn_points = spawns
	unit_container = container


func _on_begin() -> void:
	assert(not spawn_points.is_empty() and unit_container != null, "DefendObjective: configure() 필요")
	assert(data.wave_enemy != null, "DefendObjective: wave_enemy 필요")
	_pool = UnitPool.new()
	add_child(_pool)
	_pool.setup(unit_container, mini(data.max_alive, 12), data.wave_enemy)
	_next_wave_in = data.first_wave_delay
	queue_redraw()


func _on_tick(dt: float) -> void:
	elapsed += dt
	if elapsed >= data.survive_time:
		complete("거점 사수 성공")
		return
	_next_wave_in -= dt
	if _next_wave_in <= 0.0:
		_next_wave_in = data.wave_interval
		_spawn_wave()
	_count_zone()
	if _enemies_in > 0 and _allies_in == 0:
		gauge += data.capture_rate * float(_enemies_in) * dt
	elif _allies_in > 0 and _enemies_in == 0:
		gauge -= data.recapture_rate * dt
	gauge = clampf(gauge, 0.0, GAUGE_MAX)
	if gauge >= GAUGE_MAX:
		fail("거점 함락")
		return
	if roundi(gauge) != _drawn_gauge:
		_drawn_gauge = roundi(gauge)
		queue_redraw()


func _on_end(_victory: bool) -> void:
	for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY):
		(n as UnitBase).set_march_goal(Vector2.INF)


func _spawn_wave() -> void:
	var count: int = data.wave_size_start + data.wave_size_growth * wave
	var hp_mult: float = 1.0 + data.wave_hp_growth * float(wave)
	wave += 1
	for i: int in count:
		if _pool.alive_count() >= data.max_alive:
			break
		var sp: Vector2 = spawn_points[i % spawn_points.size()]
		var jitter: Vector2 = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		var u: UnitBase = _pool.acquire(data.wave_enemy, UnitBase.Faction.ENEMY, sp + jitter, hp_mult)
		u.set_march_goal(zone_center)


func _count_zone() -> void:
	var r2: float = data.zone_radius * data.zone_radius
	_enemies_in = 0
	_allies_in = 0
	for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY):
		if (n as Node2D).global_position.distance_squared_to(zone_center) <= r2:
			_enemies_in += 1
	for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ALLY):
		if (n as Node2D).global_position.distance_squared_to(zone_center) <= r2:
			_allies_in += 1


func _progress_text() -> String:
	var remain: int = maxi(0, ceili(data.survive_time - elapsed))
	return "생존 %d초  |  점령 %d%%  |  웨이브 %d" % [remain, roundi(gauge), wave]


func _draw() -> void:
	if data == null:
		return
	var local: Vector2 = to_local(zone_center)
	var ratio: float = gauge / GAUGE_MAX
	draw_circle(local, data.zone_radius, ZONE_FILL)
	draw_arc(local, data.zone_radius, 0.0, TAU, 64, ZONE_RING, 3.0)
	if ratio > 0.0:
		draw_arc(local, data.zone_radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, ZONE_DANGER, 6.0)
