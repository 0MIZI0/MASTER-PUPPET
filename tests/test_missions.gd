extends Node
## Headless 검증: 미션 모듈 (섬멸 / 거점 방어 / 풀링).

const ARENA: String = "res://scenes/combat_arena.tscn"

var _fail: int = 0
var _ended: Array = []  ## [victory, reason]


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


func _ready() -> void:
	EventBus.mission_ended.connect(func(v: bool, r: String) -> void: _ended = [v, r])
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _spawn_arena(index: int) -> Node:
	_ended = []
	var script: GDScript = load("res://scenes/combat_arena.gd") as GDScript
	script.set(&"selected_mission", index)
	var arena: Node = (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	await _frames(4)
	return arena


func _run() -> void:
	# ---------------- 섬멸
	var arena: Node = await _spawn_arena(0)
	var obj: MissionObjective = arena.get_node("Mission") as MissionObjective
	_check(obj is AnnihilateObjective, "미션0 = 섬멸")
	var enemies: Array[Node] = get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY)
	_check(enemies.size() == 8, "섬멸: 배치 적 8 (=%d)" % enemies.size())
	for n: Node in enemies:
		(n as UnitBase).take_damage(99999.0, null)
	_check(_ended.size() == 2 and _ended[0] == true, "섬멸: 전멸 시 VICTORY %s" % [_ended])
	arena.free()
	await _frames(2)

	# ---------------- 거점 방어: 함락 패배
	arena = await _spawn_arena(1)
	var d: DefendObjective = arena.get_node("Mission") as DefendObjective
	_check(d != null, "미션1 = 거점 방어")
	await _frames(2)
	_check(get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY).is_empty(), "거점: 배치 적 제거")
	d._on_tick(d.data.first_wave_delay + 0.01)
	var wave1: Array[Node] = get_tree().get_nodes_in_group(UnitBase.GROUP_ENEMY)
	_check(wave1.size() == d.data.wave_size_start, "거점: 1웨이브 %d기 (=%d)" % [d.data.wave_size_start, wave1.size()])
	_check((wave1[0] as UnitBase)._march_goal == d.zone_center, "거점: 적 행군 목표 = 거점")
	for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ALLY):
		(n as Node2D).global_position = Vector2(1700.0, 950.0)
	for n: Node in wave1:
		(n as Node2D).global_position = d.zone_center
	d._on_tick(1.0)
	var expect: float = d.data.capture_rate * float(wave1.size())
	_check(is_equal_approx(d.gauge, expect), "거점: 점령 게이지 +%.1f (=%.1f)" % [expect, d.gauge])
	var ally: Node2D = get_tree().get_first_node_in_group(UnitBase.GROUP_ALLY) as Node2D
	ally.global_position = d.zone_center
	var g0: float = d.gauge
	d._on_tick(1.0)
	_check(is_equal_approx(d.gauge, g0), "거점: 교전 중(양측 존재) 게이지 정지")
	ally.global_position = Vector2(1700.0, 950.0)
	for i: int in 60:
		if d.ended:
			break
		d._on_tick(1.0)
	_check(_ended.size() == 2 and _ended[0] == false and _ended[1] == "거점 함락", "거점: 게이지 100 → DEFEAT %s" % [_ended])

	# ---------------- 풀 재사용
	var pool: UnitPool = d.get_child(0) as UnitPool
	var victim: UnitBase = wave1[0] as UnitBase
	var alive0: int = pool.alive_count()
	victim.take_damage(99999.0, null)
	_check(pool.alive_count() == alive0 - 1 and is_instance_valid(victim), "풀: 사망 시 회수 (free 안 함)")
	var again: UnitBase = pool.acquire(d.data.wave_enemy, UnitBase.Faction.ENEMY, Vector2(900, 900), 2.0)
	_check(is_instance_valid(again) and again.visible and not again.is_dead(), "풀: 재가동")
	_check(is_equal_approx(again.hp, d.data.wave_enemy.max_hp * 2.0), "풀: HP 배율 적용 (=%.0f)" % again.hp)
	arena.free()
	await _frames(2)

	# ---------------- 거점 방어: 생존 승리 + 웨이브 성장
	arena = await _spawn_arena(1)
	d = arena.get_node("Mission") as DefendObjective
	d._on_tick(d.data.first_wave_delay + 0.01)
	d._on_tick(d.data.wave_interval)
	_check(d.wave == 2, "거점: 2웨이브 진행 (=%d)" % d.wave)
	d.gauge = 0.0
	d.elapsed = d.data.survive_time - 0.1
	d._on_tick(0.2)
	_check(_ended.size() == 2 and _ended[0] == true, "거점: 생존 시간 달성 → VICTORY %s" % [_ended])
	arena.free()
	await _frames(2)

	# ---------------- 아군 전멸 = 실패 (공통)
	arena = await _spawn_arena(0)
	for n: Node in get_tree().get_nodes_in_group(UnitBase.GROUP_ALLY):
		(n as UnitBase).take_damage(99999.0, null)
	_check(_ended.size() == 2 and _ended[0] == false and _ended[1] == "분대 전멸", "공통: 분대 전멸 → DEFEAT %s" % [_ended])
	arena.free()

	print("RESULT fail=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
