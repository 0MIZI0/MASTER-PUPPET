extends Node
## Headless 검증: 마스터 스킬 4종 효과.

var _fail: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1

func _ready() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _run() -> void:
	var arena: Node = (load("res://scenes/combat_arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await _frames(5)
	var sys: MasterSkillSystem = arena.get_node("MasterSkillSystem") as MasterSkillSystem
	var bus: Node = get_node("/root/EventBus")
	var hud: CombatHUD = arena.get_node("CombatHUD") as CombatHUD
	var bar: HBoxContainer = hud.get_node("SkillDock/SkillBar") as HBoxContainer
	_check(bar.get_child_count() == 4, "HUD 스킬 버튼 4개 (=%d)" % bar.get_child_count())
	var knight: UnitBase = arena.get_node("Units/Ersa") as UnitBase
	var ghoul: UnitBase = arena.get_node("Units/Ghoul1") as UnitBase
	_check(is_equal_approx(sys.mana, 50.0) or sys.mana > 50.0, "시작 마나 50 (=%.1f)" % sys.mana)
	# HEAL
	sys.mana = 100.0
	knight.hp = 50.0
	bus.emit_signal(&"master_skill_requested", 0)
	_check(is_equal_approx(knight.hp, 50.0 + knight.stats.max_hp * 0.35), "HEAL hp=%.1f" % knight.hp)
	_check(sys.mana <= 65.01, "HEAL 마나 차감 (=%.1f)" % sys.mana)
	bus.emit_signal(&"master_skill_requested", 0)
	_check(sys.mana > 60.0, "HEAL 쿨다운 중 재시전 차단 (=%.1f)" % sys.mana)
	# SHIELD
	sys.mana = 100.0
	knight.hp = knight.stats.max_hp
	bus.emit_signal(&"master_skill_requested", 1)
	var shield: float = knight.stats.max_hp * 0.25
	knight.take_damage(shield - 5.0, null)
	_check(is_equal_approx(knight.hp, knight.stats.max_hp), "SHIELD 피해 흡수 hp=%.1f" % knight.hp)
	knight.take_damage(15.0, null)
	_check(is_equal_approx(knight.hp, knight.stats.max_hp - 10.0), "SHIELD 초과분 관통 hp=%.1f" % knight.hp)
	_check(ghoul._shield == 0.0, "적에게 SHIELD 미적용")
	# COMMAND
	sys.mana = 100.0
	var fear0: float = knight.hero_data.fear
	bus.emit_signal(&"master_skill_requested", 2)
	_check(is_equal_approx(knight._buff_mult, 1.35), "COMMAND 공격 배율=%.2f" % knight._buff_mult)
	_check(is_equal_approx(knight.hero_data.fear, maxf(0.0, fear0 - 6.0)), "COMMAND fear %.0f→%.0f" % [fear0, knight.hero_data.fear])
	# RECALL
	sys.mana = 100.0
	bus.emit_signal(&"master_skill_requested", 3)
	await _frames(2)
	_check(knight._has_order and knight._pin_type == PinTypes.Type.RETREAT, "RECALL 후퇴 명령 수신")
	_check(knight._pin_pos.distance_to(Vector2(240, 540)) < 40.0, "RECALL 지점 (%.0f,%.0f)" % [knight._pin_pos.x, knight._pin_pos.y])
	# 마나 부족
	sys.mana = 10.0
	var cd_before: PackedFloat32Array = sys._cooldowns.duplicate()
	bus.emit_signal(&"master_skill_requested", 1)
	_check(is_equal_approx(sys.mana, 10.0), "마나 부족 시 시전 불가")
	# 리젠
	var m0: float = sys.mana
	await _frames(30)
	_check(sys.mana > m0, "마나 리젠 %.2f→%.2f" % [m0, sys.mana])
	print("RESULT fail=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
